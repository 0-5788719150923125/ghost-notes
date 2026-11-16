extends Window
class_name PropRefine

## PropRefine - the 3D view's Refine ([PropViewer], [PropVersions]): what to change in the prop shown, in words, and who changes it -
## the agent, its model and how hard it thinks ([AgentPick]) - then the agent at work: a bar that keeps moving and the line it
## reports (what it is doing, for how long, and how long since it last said anything) until its version lands or it is stopped. It
## stays open, its words kept, for the next change. The writer picked is every prop's for the rest of the run.

## What to change, and who changes it (`{agent, model, effort}`).
signal asked(direction: String, pick: Dictionary)
## The refining under way given up.
signal stopped

const SIZE := Vector2i(580, 400)

## The writer picked last ([member last_pick]), so each refine starts where the one before left off.
static var last_pick := {}

var _text: TextEdit
var _pick: AgentPick
var _bar: ProgressBar
var _line: Label
var _go: Button
var _stop: Button
var _working := false


func _init() -> void:
	visible = false
	title = "Refine"
	min_size = Vector2i(420, 300)
	close_requested.connect(hide)
	window_input.connect(func(e: InputEvent) -> void:
		if e is InputEventKey and (e as InputEventKey).pressed and (e as InputEventKey).keycode == KEY_ESCAPE:
			hide())
	var bg := PanelContainer.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 10)
	bg.add_child(pad)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	pad.add_child(col)
	var say := Label.new()
	say.text = "What to change. The agent changes only what you ask; every other part, size and color stays as it is."
	say.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(say)
	_text = TextEdit.new()
	_text.custom_minimum_size = Vector2(0, 110)
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_text.placeholder_text = "Which part is wrong, and how it should be instead."
	col.add_child(_text)
	_pick = AgentPick.writer("Who refines the prop.")
	if not last_pick.is_empty():
		_pick.set_choice(String(last_pick.get("agent", "")), String(last_pick.get("model", "")), String(last_pick.get("effort", "")))
	_pick.changed.connect(func() -> void: last_pick = _pick.choice())
	col.add_child(_pick)
	_bar = ProgressBar.new()
	_bar.indeterminate = true
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, 6)
	_bar.visible = false
	col.add_child(_bar)
	_line = Label.new()
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.add_theme_font_size_override("font_size", 11)
	_line.modulate = Color(1, 1, 1, 0.8)
	col.add_child(_line)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	var room := Control.new()
	room.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(room)
	_stop = Button.new()
	_stop.text = "Stop"
	_stop.tooltip_text = "Give this refining up: nothing is added."
	_stop.visible = false
	_stop.pressed.connect(func() -> void: stopped.emit())
	row.add_child(_stop)
	_go = Button.new()
	_go.text = "Refine"
	_go.tooltip_text = "Have the agent make a new version from the one shown. It is added beside the others; Use this one in the view makes it the prop."
	_go.pressed.connect(_ask)
	row.add_child(_go)


## Opened for the prop called [param name], over [param host].
func open_for(name: String, host: Window) -> void:
	title = "Refine - %s" % name
	_pick.mark_available()
	if not visible:
		popup()
		size = SIZE
		if host != null:
			position = host.position + (host.size - size) / 2
	_text.grab_focus()


## Whether the agent is at work: the bar moves and Stop shows, and the words wait.
func working(on: bool) -> void:
	_working = on
	_bar.visible = on
	_stop.visible = on
	_go.disabled = on
	_text.editable = not on


## [param line] said under the words: what the agent is doing, or how it went.
func say(line: String) -> void:
	_line.text = line


## The words written, and the writer picked.
func direction() -> String:
	return _text.text


func pick() -> Dictionary:
	return _pick.choice()


## The words set (a gate's, or a direction to start from).
func set_direction(text: String) -> void:
	_text.text = text


func _ask() -> void:
	if _working:
		return
	if _text.text.strip_edges().is_empty():
		say("Say what to change first.")
		return
	last_pick = _pick.choice()
	asked.emit(_text.text.strip_edges(), _pick.choice())
