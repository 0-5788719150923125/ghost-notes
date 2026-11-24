extends AcceptDialog
class_name KeysWindow

## KeysWindow - every keyboard shortcut, in a small window: F1 anywhere, or the "?" on a note's panel
## ([method SidePanel.pin_title_row]).
##
## A list, not a binding: each key is handled where it acts (main's F1, F11, N and Esc and the interface's size; the
## transport's Space, arrows and Home; a panel's F2; the find bar; the storyboard's editor and the Timeline; the
## feedback console). A key added there is a row added to [constant SECTIONS]. The mode a panel belongs to can add
## its own first: a `shortcuts()` on it returning `[title, [[keys, what], ...]]` (Masking's).
##
## Not modal: the keys can be tried with it open (a click on the window behind gives the keys back to it). One at a
## time ([method toggle]); F1, Esc or Close puts it away.

## [title, rows]; a row is [keys, what they do].
const SECTIONS := [
	["Anywhere", [
		["F1", "These shortcuts"],
		["F11", "Full screen"],
		["Ctrl + =  /  −", "Interface larger / smaller"],
		["Ctrl + 0", "Interface at this screen's size"],
		["`", "Feedback console (the key under Esc)"],
		["Esc", "Quit, when nothing open takes it"],
	]],
	["Playing", [
		["Space", "Play / pause"],
		["←  /  →", "Back / ahead 10 s (Shift: a minute)"],
		["Home", "Back to the start"],
		["N", "Next scene"],
	]],
	["A note's panel", [
		["F2", "Hide / show the panel"],
		["Ctrl + F", "Find in the script"],
		["Ctrl + H", "Find and replace"],
		["F3  /  Shift + F3", "Next / previous match"],
		["Ctrl + Z", "Undo typing"],
	]],
	["Storyboard and Timeline, the pointer over them", [
		["Ctrl + Z", "Undo"],
		["Ctrl + Y", "Redo (Ctrl + Shift + Z too)"],
		["Delete", "Remove the entry picked"],
		["Ctrl + wheel", "Zoom at the pointer"],
	]],
	["The notes list", [
		["Enter", "Open the first note found"],
		["Esc", "Clear the search"],
	]],
]

const COL_HEAD := Color(0.50, 0.57, 0.68)
const COL_KEY := Color(1.0, 0.85, 0.5)
const COL_TEXT := Color(0.78, 0.84, 0.94)
const COL_DIM := Color(0.50, 0.57, 0.68)
## Which sections stand in the left column; the rest stand in the right.
const LEFT := 2

## The group the one open is found by ([method toggle]).
const GROUP := &"keys_window"

## The mode's own section, first: [title, rows] (empty: none).
var own: Array = []


## Open the keys over [param host]'s window, beside its side panel - or put them away, when they are up. [param host]'s
## `shortcuts()`, where it has one, is a section of its own, first.
static func toggle(host: Node) -> void:
	if host == null or not host.is_inside_tree():
		return
	var up := host.get_tree().get_first_node_in_group(GROUP) as KeysWindow
	if up != null:
		up.hide()
		return
	var w := KeysWindow.new()
	if host.has_method("shortcuts"):
		w.own = host.call("shortcuts")
	host.add_child(w)
	w.popup()
	Shell.center_beside(w, host)


func _init() -> void:
	title = "Keyboard shortcuts"
	ok_button_text = "Close"
	exclusive = false
	transient = true
	add_to_group(GROUP)


func _ready() -> void:
	_build()
	visibility_changed.connect(func() -> void:
		if not visible:
			queue_free())
	# F1 puts it away again while it has the keys (main's F1 does not hear them then)
	window_input.connect(func(e: InputEvent) -> void:
		var k := e as InputEventKey
		if k != null and k.pressed and not k.echo and k.keycode == KEY_F1:
			hide()
			set_input_as_handled())


func _build() -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	add_child(col)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 36)
	col.add_child(cols)
	var sections: Array = SECTIONS.duplicate()
	if own.size() == 2:
		sections.push_front(own)
	var left := _column(cols)
	var right := _column(cols)
	for i in sections.size():
		_section(left if i < LEFT + (1 if own.size() == 2 else 0) else right, sections[i])
	_line_up(left)
	_line_up(right)
	var size_now := UiScale.describe()
	if not size_now.is_empty():
		var said := Label.new()
		said.text = size_now
		said.add_theme_font_size_override("font_size", 12)
		said.add_theme_color_override("font_color", COL_DIM)
		col.add_child(said)


func _column(row: HBoxContainer) -> VBoxContainer:
	var c := VBoxContainer.new()
	c.add_theme_constant_override("separation", 14)
	row.add_child(c)
	return c


## A heading and its keys, in [param into].
func _section(into: VBoxContainer, section: Array) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	into.add_child(box)
	var head := Label.new()
	head.text = String(section[0])
	head.add_theme_font_size_override("font_size", 12)
	head.add_theme_color_override("font_color", COL_HEAD)
	box.add_child(head)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 3)
	box.add_child(grid)
	for pair in section[1]:
		var key := Label.new()
		key.text = String(pair[0])
		key.add_to_group(&"keys_window_key")
		key.add_theme_font_size_override("font_size", 14)
		key.add_theme_color_override("font_color", COL_KEY)
		grid.add_child(key)
		var what := Label.new()
		what.text = String(pair[1])
		what.add_theme_font_size_override("font_size", 14)
		what.add_theme_color_override("font_color", COL_TEXT)
		grid.add_child(what)


## Every key in [param column] as wide as its widest, so the words beside them start at one edge.
func _line_up(column: VBoxContainer) -> void:
	var keys := column.find_children("*", "Label", true, false).filter(func(l: Node) -> bool:
		return l.is_in_group(&"keys_window_key"))
	var wide := 0.0
	for l in keys:
		wide = maxf(wide, (l as Label).get_minimum_size().x)
	for l in keys:
		(l as Label).custom_minimum_size.x = wide
