extends VBoxContainer
class_name EpisodePacing

## EpisodePacing - the Episode card's Pacing rows: the numbers a show's hands at the table are paced by ([TableTune]), only those
## pacing the laws its acts use (a show that paints nothing is offered no brush's), each a slider within its bounds and unset at
## its default. Kept in the show's block (`table: tune:`). Shown only while the episode offers a row; looked at again every second
## (an agent's new acts can change what is offered), drawn again only when that changed.

const POLL := 60              # frames between looks

var _rows: Callable           # () -> Dictionary: key -> field, as a form draws them
var _values: Callable         # () -> Dictionary: key -> number, what the show tells
var _set: Callable            # (key, value or null)
var _form: SchemaForm
var _seen := 0


func _init(rows: Callable, values: Callable, set_value: Callable) -> void:
	_rows = rows
	_values = values
	_set = set_value
	add_theme_constant_override("separation", 4)
	var head := Label.new()
	head.text = "Pacing"
	head.add_theme_font_size_override("font_size", 12)
	add_child(head)
	var said := Label.new()
	said.text = "How this show's hands work at the table. Unset is the default; the table is set with a change the next time it stands."
	said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	said.add_theme_font_size_override("font_size", 11)
	said.modulate = Color(1, 1, 1, 0.6)
	add_child(said)
	_form = SchemaForm.new()
	_form.edited.connect(func(key: String, value: Variant) -> void:
		_set.call(key, value)
		refresh(true))
	add_child(_form)
	refresh()


func _process(_delta: float) -> void:
	if Engine.get_process_frames() % POLL == 0:
		refresh()


## What is offered, looked at again: shown with rows and hidden without, drawn again where the rows or their values changed
## ([param force]: drawn again regardless).
func refresh(force := false) -> void:
	var rows: Dictionary = _rows.call() if _rows.is_valid() else {}
	var values: Dictionary = _values.call() if _values.is_valid() else {}
	visible = not rows.is_empty()
	var h := hash([JSON.stringify(rows), JSON.stringify(values)])
	if h == _seen and not force:
		return
	_seen = h
	_form.show_fields(rows, values)


## How many rows are offered now.
func row_count() -> int:
	return (_rows.call() as Dictionary).size() if _rows.is_valid() else 0
