extends ConfirmationDialog
class_name DeleteDialog

## DeleteDialog - "Delete this note?", asked before a note goes (2026-10-06, the user: "add a delete
## option to every note, and probably an x to each note on the home screen. If we click the x,
## prompt for confirmation to delete the note"). Asked from the notes list's × and from every
## note's own "⋯" (see [method Chrome.note_menu]).
##
## IT ASKS; THE CALLER DOES. The list trashes a note that is not open; a note that is open is left
## first - its panel writes what it holds into the file as it goes - and only then trashed, so the
## answer is handed back ([member then]) rather than acted on here. The file goes to the system's
## trash ([method NoteStore.trash]). A note that is in the list only because it was added by hand -
## a chapter in another project - can instead just leave the list, its file untouched.

## The note asked about.
var path := ""
## Called with the answer: "trash", or "forget" (leave the list, keep the file).
var then: Callable


## Ask about [param note] over [param host]; [param on_answer] gets "trash" or "forget".
static func ask(host: Node, note: String, on_answer: Callable) -> DeleteDialog:
	var d := DeleteDialog.new()
	d.path = note
	d.then = on_answer
	host.add_child(d)
	d.popup_centered(Vector2i(560, 0))
	return d


func _ready() -> void:
	title = "Delete this note?"
	dialog_autowrap = true
	ok_button_text = "Move to trash"
	var name := NoteStore.title_of(path)
	if NoteStore.is_own(path):
		dialog_text = "“%s” goes to the system trash." % name
	elif NoteStore.is_added(path):
		dialog_text = ("“%s” is a file in another folder:\n%s\n\nIt can go to the system trash, or "
			+ "just leave this list - the file stays where it is.") % [name, path]
		add_button("Only remove it from the list", true, "forget")
	else:
		dialog_text = "“%s” is a file in a folder this list shows:\n%s\n\nIt goes to the system trash." % [name, path]
	confirmed.connect(func() -> void: _answer("trash"))
	custom_action.connect(func(action: StringName) -> void:
		hide()
		_answer(String(action)))
	canceled.connect(queue_free)


func _answer(what: String) -> void:
	if then.is_valid():
		then.call(what)
	queue_free()
