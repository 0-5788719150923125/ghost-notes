extends PanelContainer
class_name EntryCard

## EntryCard - one entry in a card's list (a prop on the Props card, an element on the Environment card, a picture on the Pictures
## card), one look for every such list: a small card of its own inside the card it is on, framed in that card's color, its picture,
## its name and a line, and a × in its top-right corner as the card's own has. The × takes the entry away, pressed twice (the first
## arms it, [constant ARMED] seconds), or stands grayed saying why it cannot. A click on the entry opens it to show what can be done
## with it ([member options]), and again closes it; one with nothing to show never opens, and a [member fixed] one is always open.
##
## Its list keeps which entries are open ([signal toggled]): a list drawn again opens them again.

## The entry was opened ([param open] true) or closed by a click.
signal toggled(open: bool)

## How long a first press of the × stays armed (seconds).
const ARMED := 3.0

## What it can do, shown while it is open: whoever makes the entry fills it.
var options: VBoxContainer
## Its name and its line, for whoever wants to say more on them (a status said as it changes).
var name_label: Label
var line_label: Label
## Always open, with no click to close it.
var fixed := false:
	set(v):
		fixed = v
		_show()
## Whether it is open now.
var open := false:
	set(v):
		open = v
		_show()

var _head: HBoxContainer
var _words: VBoxContainer
var _x: Button
var _act := Callable()
var _word := "Remove?"
var _hover := false
var _color := Color(0.72, 0.74, 0.78)


## An entry called [param name], said by [param line] under it, [param tip] on hover.
func _init(name: String, line := "", tip := "") -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	add_child(col)
	_head = HBoxContainer.new()
	_head.add_theme_constant_override("separation", 8)
	_head.mouse_filter = Control.MOUSE_FILTER_STOP
	_head.tooltip_text = tip
	_head.gui_input.connect(_pressed)
	_head.mouse_entered.connect(func() -> void:
		_hover = true
		_style())
	_head.mouse_exited.connect(func() -> void:
		_hover = false
		_style())
	col.add_child(_head)
	_words = VBoxContainer.new()
	_words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_words.add_theme_constant_override("separation", 0)
	_words.mouse_filter = Control.MOUSE_FILTER_PASS
	_head.add_child(_words)
	name_label = Label.new()
	name_label.text = name
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.clip_text = true
	name_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_words.add_child(name_label)
	line_label = Label.new()
	line_label.text = line
	line_label.visible = not line.is_empty()
	line_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line_label.add_theme_font_size_override("font_size", 11)
	line_label.modulate = Color(1, 1, 1, 0.65)
	line_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_words.add_child(line_label)
	_x = Button.new()
	_x.text = "×"
	_x.flat = true
	_x.focus_mode = Control.FOCUS_NONE
	_x.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_x.add_theme_font_size_override("font_size", 14)
	var snug := StyleBoxEmpty.new()
	snug.content_margin_left = 4
	snug.content_margin_right = 4
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		_x.add_theme_stylebox_override(st, snug)
	_x.pressed.connect(_x_pressed)
	_x.visible = false
	_head.add_child(_x)
	var calm := Timer.new()
	calm.name = "Calm"
	calm.one_shot = true
	calm.wait_time = ARMED
	calm.timeout.connect(_disarm)
	add_child(calm)
	options = VBoxContainer.new()
	options.add_theme_constant_override("separation", 4)
	col.add_child(options)
	_show()
	_style()


func _ready() -> void:
	# framed in the color of the card it is on
	var n: Node = get_parent()
	while n != null and not (n is Card):
		n = n.get_parent()
	if n is Card:
		_color = (n as Card).color()
	_show()


## [param c] at the start of its head, before its name: its picture.
func set_picture(c: Control) -> void:
	_head.add_child(c)
	_head.move_child(c, 0)


## Its ×: pressed twice, it calls [param act]; [param tip] on hover. With [param off] said, it stands grayed saying that instead.
## [param word] is what it says when armed.
func set_remove(act: Callable, tip: String, off := "", word := "Remove?") -> void:
	_act = act
	_word = word
	_x.visible = true
	_x.disabled = not off.is_empty() or not act.is_valid()
	_x.tooltip_text = off if not off.is_empty() else tip
	_disarm()


## Whether its × is armed: pressed once, waiting for the second.
func armed() -> bool:
	return bool(_x.get_meta("armed", false))


## Whether a click opens it: it has something to show and is not always open.
func opens() -> bool:
	return not fixed and options.get_child_count() > 0


func _pressed(e: InputEvent) -> void:
	if not (e is InputEventMouseButton) or not (e as InputEventMouseButton).pressed or (e as InputEventMouseButton).button_index != MOUSE_BUTTON_LEFT:
		return
	if not opens():
		return
	_head.accept_event()
	open = not open
	toggled.emit(open)


func _x_pressed() -> void:
	if _x.disabled:
		return
	if not armed():
		_x.set_meta("armed", true)
		_x.text = _word
		_x.add_theme_color_override("font_color", Color(1.0, 0.55, 0.5))
		var calm := get_node_or_null("Calm") as Timer
		if calm != null and calm.is_inside_tree():
			calm.start()
		return
	_disarm()
	if _act.is_valid():
		_act.call()


func _disarm() -> void:
	_x.set_meta("armed", false)
	_x.text = "×"
	_x.remove_theme_color_override("font_color")


func _show() -> void:
	if options == null:
		return
	options.visible = fixed or open
	_head.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if opens() else Control.CURSOR_ARROW
	_style()


func _style() -> void:
	if options == null:
		return
	var s := StyleBoxFlat.new()
	s.bg_color = Color(1, 1, 1, 0.07 if _hover and opens() else (0.05 if open else 0.03))
	s.border_color = Color(_color, 0.45 if open or _hover else 0.28)
	s.set_border_width_all(1)
	s.set_corner_radius_all(4)
	s.content_margin_left = 6
	s.content_margin_right = 2
	s.content_margin_top = 4
	s.content_margin_bottom = 6
	add_theme_stylebox_override("panel", s)
