extends VBoxContainer
class_name TextField

## TextField - words too long for a line on a card: a heading, their first lines, and a click from a window to
## write them in, the way the Body card shows a note's words ([ScriptWriter] draws its preview with this one's).
##
## NOTHING ON A CARD SCROLLS OF ITS OWN (2026-11-03, the user, of the YouTube card's Description: "the inner
## scrolling ... can be pretty annoying and unexpected. At the same time, that text is hard to read, and it's annoying
## that I even have to scroll it, to read it"): a box with a scroll of its own under a panel that scrolls takes the
## wheel from the panel the moment the pointer crosses it, and shows a few small lines of what wants reading. The
## preview hands the wheel on, and the words are read and written in the window, at a size meant for reading.
## docs.py's rule "one scroll" holds it.
##
## IT ANSWERS AS THE BOX IT TOOK THE PLACE OF: [member text], and [signal text_changed] for a hand's edit, as it is
## typed, never for a value arriving. A card asks [method editing] where it asked `has_focus()`.

## The hand changed the words. Assigning [member text] does not say so.
signal text_changed

## How many lines of the words a card shows.
const PREVIEW_LINES := 6
## How much of them is laid out for those lines.
const PREVIEW_CHARS := 480

## The words, whole.
var text := "":
	set(v):
		text = v
		if _edit != null and _edit.text != v:
			_edit.text = v
		_show()

var _title := ""
var _placeholder := ""
var _tip := ""
var _preview: Label
var _window: Window      # made when first opened: most never are
var _edit: TextEdit


## [param heading] names it on the card and on its window, [param placeholder] stands in for no words, and [param
## tip] says what they are for, on the card's tooltip and at the window's foot.
func _init(heading := "", placeholder := "", tip := "") -> void:
	_title = heading
	_placeholder = placeholder
	_tip = tip
	add_theme_constant_override("separation", 2)
	var head := Label.new()
	head.text = heading
	head.add_theme_font_size_override("font_size", 12)
	add_child(head)
	_preview = preview_label(open)
	_preview.tooltip_text = (tip + "\n\nClick to edit.") if not tip.is_empty() else "Click to edit."
	add_child(_preview)
	_show()


## Is the window open on it? Words arriving then would be written over the hand's.
func editing() -> bool:
	return _window != null and _window.visible


## The window, over whatever is playing: nothing behind it stops, and an edit is seen as it is typed.
func open() -> void:
	if _window == null:
		_build_window()
	pop_up(_window, self, Vector2(0.5, 0.6))
	_edit.grab_focus()


func _show() -> void:
	if _preview != null:
		show_words(_preview, text, _placeholder)


func _build_window() -> void:
	_window = Window.new()
	_window.title = _title
	_window.visible = false
	_window.transient = true
	_window.min_size = Vector2i(560, 320)
	_window.close_requested.connect(_window.hide)
	_window.window_input.connect(func(e: InputEvent) -> void:
		if e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE:
			_window.hide())
	add_child(_window)

	var bg := PanelContainer.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_window.add_child(bg)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	bg.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	margin.add_child(col)

	_edit = TextEdit.new()
	_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_edit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_edit.placeholder_text = _placeholder
	_edit.caret_blink = true
	_edit.add_theme_font_size_override("font_size", 16)
	_edit.add_theme_constant_override("line_spacing", 6)
	_edit.text = text
	_edit.text_changed.connect(func() -> void:
		text = _edit.text
		text_changed.emit())
	col.add_child(_edit)

	var foot := HBoxContainer.new()
	col.add_child(foot)
	var hint := Label.new()
	hint.text = _tip
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.add_theme_font_size_override("font_size", 11)
	hint.modulate = Color(1, 1, 1, 0.55)
	foot.add_child(hint)
	var done := Button.new()
	done.text = "Done"
	done.pressed.connect(_window.hide)
	foot.add_child(done)


## The first lines of some words on a card, a click from [param on_click]: a few lines of what they hold, as tall as
## they are and no taller.
static func preview_label(on_click: Callable) -> Label:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.max_lines_visible = PREVIEW_LINES
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color(0.78, 0.8, 0.84))
	l.mouse_filter = Control.MOUSE_FILTER_STOP
	l.mouse_default_cursor_shape = Control.CURSOR_IBEAM
	l.tooltip_text = "Click to edit."
	var box := StyleBoxFlat.new()
	box.bg_color = Color(1, 1, 1, 0.035)
	box.set_corner_radius_all(3)
	box.set_content_margin_all(6)
	l.add_theme_stylebox_override("normal", box)
	l.gui_input.connect(func(e: InputEvent) -> void:
		var mb := e as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			on_click.call())
	return l


## [param words] on a [method preview_label], dimmed [param placeholder] where there are none.
static func show_words(l: Label, words: String, placeholder: String) -> void:
	var shown := Manuscript.preview_of(words, PREVIEW_CHARS)
	l.text = shown if not shown.is_empty() else placeholder
	l.modulate = Color(1, 1, 1, 1.0 if not shown.is_empty() else 0.5)


## [param w] up, centered, sized as [param share] of the window it opens over. THE SIZE IS SET AGAIN AFTER THE POPUP:
## measured, popup() and popup_centered() both came back 1280 wide whatever was asked for (1574 on a 1080p window),
## which also left popup_centered's window left of center.
static func pop_up(w: Window, over: Node, share: Vector2) -> void:
	var host := over.get_tree().root.get_visible_rect().size if over.is_inside_tree() \
		else Vector2(1600, 900)
	var want := Vector2i(int(host.x * share.x), int(host.y * share.y)).max(w.min_size)
	w.popup(Rect2i((Vector2i(host) - want) / 2, want))
	w.size = want
