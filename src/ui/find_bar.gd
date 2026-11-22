extends PanelContainer
class_name FindBar

## FindBar - find and replace in a [TextEdit], as a code editor has it: a small panel over the text's top-right corner
## with a Find box and a Replace box, drawn over the words, never moving them. Every match is highlighted
## ([method TextEdit.set_search_text]) and the current one selected. It stands beside the text in a holder
## ([method stack]), never inside it, so no key typed in its boxes reaches the words.
##
## Keys, from anywhere in the window it stands in: Ctrl+F opens it on Find (a selection on one line becomes what is
## found) and closes it again, as its button does; Ctrl+H opens it on Replace; Escape closes it. Enter in Find goes to the next match and Shift+Enter to the one before;
## F3 and Shift+F3 do the same from anywhere. Enter in Replace replaces the current match and goes on to the next;
## Ctrl+Enter replaces every match. Aa matches case. A replacement is one step Ctrl+Z takes back, Replace All too.
##
## A window that closes on Escape asks [member visible] first: its `window_input` comes before this bar's `_input`.
## Matches never span lines (the boxes take one line), so a replacement leaves every match before it where it was.

## The most matches counted, highlighted and replaced at once.
const MOST := 20000
const HIT_FILL := Color(0.95, 0.68, 0.2, 0.32)
const HIT_EDGE := Color(1.0, 0.75, 0.28, 0.85)
const NONE_COLOR := Color(1.0, 0.5, 0.45)
## How wide the panel is, and how far it stands from the text's top and right edges (the right past the scroll bar).
const WIDE := 400.0
const INSET := Vector2(20, 6)

## The text searched.
var target: TextEdit

var _find: LineEdit
var _replace: LineEdit
var _case: Button
var _count: Label
## Every match, (line, column), in order; [member _at] maps each to its index.
var _hits: Array[Vector2i] = []
var _at := {}
## What a replacement said, shown until the search changes.
var _said := ""


func _init(edit: TextEdit) -> void:
	target = edit
	visible = false
	# the current match stays selected while the boxes have the keys
	target.deselect_on_focus_loss_enabled = false
	target.add_theme_color_override("search_result_color", HIT_FILL)
	target.add_theme_color_override("search_result_border_color", HIT_EDGE)
	target.text_changed.connect(_text_moved)
	target.text_set.connect(_text_moved)

	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.12, 0.13, 0.15, 0.97)
	box.border_color = Color(1, 1, 1, 0.12)
	box.set_border_width_all(1)
	box.set_corner_radius_all(4)
	box.set_content_margin_all(5)
	box.shadow_color = Color(0, 0, 0, 0.4)
	box.shadow_size = 6
	add_theme_stylebox_override("panel", box)
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	offset_right = -INSET.x
	offset_left = -INSET.x - WIDE
	offset_top = INSET.y
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 3)
	add_child(rows)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 4)
	rows.add_child(top)
	_find = _box("Find")
	_find.text_changed.connect(func(_t: String) -> void: _search(true))
	top.add_child(_find)
	_case = Button.new()
	_case.text = "Aa"
	_case.toggle_mode = true
	_case.flat = true
	_case.focus_mode = Control.FOCUS_NONE
	_case.tooltip_text = "Match case: \"Ghost\" finds Ghost and not ghost."
	_case.toggled.connect(func(_on: bool) -> void: _search(true))
	top.add_child(_case)
	_count = Label.new()
	_count.custom_minimum_size = Vector2(76, 0)
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count.add_theme_font_size_override("font_size", 12)
	top.add_child(_count)
	top.add_child(_button("‹", "The match before (Shift+Enter, Shift+F3).", step.bind(-1)))
	top.add_child(_button("›", "The next match (Enter, F3).", step.bind(1)))
	top.add_child(_button("×", "Close (Escape, Ctrl+F).", close))

	var low := HBoxContainer.new()
	low.add_theme_constant_override("separation", 4)
	rows.add_child(low)
	_replace = _box("Replace")
	low.add_child(_replace)
	var one := _button("Replace", "Replace the current match and go on to the next (Enter in Replace).", replace_one)
	one.flat = false
	low.add_child(one)
	var all := _button("Replace All", "Replace every match, as one step Ctrl+Z takes back (Ctrl+Enter in Replace).",
		replace_all)
	all.flat = false
	low.add_child(all)


## The text box and the bar over it, in one holder that takes the box's place in its container: the box fills it and
## the bar stands over its top-right corner. Called once, before the box has a parent.
func stack() -> Control:
	var hold := Control.new()
	hold.size_flags_horizontal = target.size_flags_horizontal
	hold.size_flags_vertical = target.size_flags_vertical
	hold.custom_minimum_size = target.custom_minimum_size
	hold.add_child(target)
	target.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hold.add_child(self)
	return hold


## A button that opens the bar and closes it again, for a window's foot.
func button() -> Button:
	var b := Icons.button("search", 16, "Find and replace (Ctrl+F).")
	b.pressed.connect(toggle)
	return b


## The bar opened on Find, or closed if it is up.
func toggle() -> void:
	if visible:
		close()
	else:
		open()


## The bar up, its Find box taking the keys ([param on_replace]: the Replace box): a selection on one line is what is
## found, else what was found last.
func open(on_replace := false) -> void:
	var picked := target.get_selected_text() if target.has_selection() else ""
	if not picked.is_empty() and not picked.contains("\n"):
		_find.set_block_signals(true)
		_find.text = picked
		_find.set_block_signals(false)
	visible = true
	_search(true)
	var box := _replace if on_replace and not _find.text.is_empty() else _find
	box.grab_focus()
	box.select_all()


## The bar away and the highlights gone; the text takes the keys again, the last match still selected.
func close() -> void:
	if not visible:
		return
	visible = false
	target.set_search_text("")
	target.grab_focus()


## The match [param dir] from the current one (1 the next, -1 the one before), round the end to the start.
func step(dir: int) -> void:
	_said = ""
	if _hits.is_empty():
		return
	var i := _current()
	if i >= 0:
		_select(posmod(i + dir, _hits.size()))
	elif dir > 0:
		_select(_first_from(_caret()))
	else:
		_select(posmod(_first_from(_caret()) - 1, _hits.size()))


## The current match replaced and the next one selected; with none selected, the next one is selected first.
func replace_one() -> void:
	_said = ""
	var i := _current()
	if i < 0:
		step(1)
		return
	var h := _hits[i]
	var put := _replace.text
	target.begin_complex_operation()
	target.remove_text(h.x, h.y, h.x, h.y + _find.text.length())
	if not put.is_empty():
		target.insert_text(put, h.x, h.y, false, false)
	target.end_complex_operation()
	_collect()
	if _hits.is_empty():
		target.deselect()
		target.set_caret_line(h.x)
		target.set_caret_column(h.y + put.length())
	else:
		_select(_first_from(Vector2i(h.x, h.y + put.length())))
	_show_count()


## Every match replaced, as one step.
func replace_all() -> void:
	if _hits.is_empty():
		return
	var n := _hits.size()
	var gone := _find.text.length()
	var put := _replace.text
	target.begin_complex_operation()
	for k in range(n - 1, -1, -1):
		var h := _hits[k]
		target.remove_text(h.x, h.y, h.x, h.y + gone)
		if not put.is_empty():
			target.insert_text(put, h.x, h.y, false, false)
	target.end_complex_operation()
	_collect()
	_said = "Replaced %d" % n
	_show_count()


## The keys the bar answers, before the box that has them: Ctrl+F and Ctrl+H anywhere in its window, the rest while
## it is up.
func _input(e: InputEvent) -> void:
	var k := e as InputEventKey
	if k == null or not k.pressed or not is_visible_in_tree() and not _opens(k):
		return
	if _opens(k):
		if k.echo:
			pass
		elif k.keycode == KEY_F:
			toggle()
		elif visible and _replace.has_focus():
			close()
		else:
			open(true)
	elif k.keycode == KEY_ESCAPE:
		close()
	elif k.keycode == KEY_F3:
		step(-1 if k.shift_pressed else 1)
	elif (k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER) and _find.has_focus():
		step(-1 if k.shift_pressed else 1)
	elif (k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER) and _replace.has_focus():
		if k.ctrl_pressed:
			replace_all()
		else:
			replace_one()
	else:
		return
	get_viewport().set_input_as_handled()


func _opens(k: InputEventKey) -> bool:
	return (k.ctrl_pressed or k.meta_pressed) and not k.alt_pressed and (k.keycode == KEY_F or k.keycode == KEY_H) \
		and get_parent() != null and target.is_visible_in_tree()


func _flags() -> int:
	return TextEdit.SEARCH_MATCH_CASE if _case.button_pressed else 0


## Every match found again and highlighted; [param go] selects the first at or after the caret, as typing in Find does.
func _search(go: bool) -> void:
	_said = ""
	target.set_search_flags(_flags())
	target.set_search_text(_find.text if visible else "")
	_collect()
	if go and not _hits.is_empty():
		var from := _caret()
		if target.has_selection():
			from = Vector2i(target.get_selection_from_line(), target.get_selection_from_column())
		_select(_first_from(from))
	_show_count()


## The matches, each found from the end of the one before until the search comes round to the start.
func _collect() -> void:
	_hits.clear()
	_at.clear()
	var q := _find.text
	if q.is_empty() or not visible:
		return
	var at := target.search(q, _flags(), 0, 0)
	while at.x >= 0 and _hits.size() < MOST:
		var h := Vector2i(at.y, at.x)
		_at[h] = _hits.size()
		_hits.append(h)
		var next := target.search(q, _flags(), at.y, at.x + q.length())
		if next.y < at.y or (next.y == at.y and next.x <= at.x):
			break
		at = next


## The text changed under the bar: the matches counted again, the selection left where it is.
func _text_moved() -> void:
	if visible:
		_collect()
		_show_count()


## The index of the match the selection is, else -1.
func _current() -> int:
	if not target.has_selection():
		return -1
	var line := target.get_selection_from_line()
	var col := target.get_selection_from_column()
	if target.get_selection_to_line() != line or target.get_selection_to_column() - col != _find.text.length():
		return -1
	return int(_at.get(Vector2i(line, col), -1))


func _caret() -> Vector2i:
	return Vector2i(target.get_caret_line(), target.get_caret_column())


## The first match at or after [param p] (line, column), round to the first.
func _first_from(p: Vector2i) -> int:
	for i in _hits.size():
		var h := _hits[i]
		if h.x > p.x or (h.x == p.x and h.y >= p.y):
			return i
	return 0


## Match [param i] selected and brought into view (centered when it was out of it or under the bar).
func _select(i: int) -> void:
	var h := _hits[i]
	target.select(h.x, h.y, h.x, h.y + _find.text.length())
	var under := ceili((position.y + size.y) / maxf(target.get_line_height(), 1.0)) if visible else 0
	if h.x < target.get_first_visible_line() + under or h.x > target.get_last_full_visible_line():
		target.center_viewport_to_caret()
	_show_count()


func _show_count() -> void:
	_count.remove_theme_color_override("font_color")
	if not _said.is_empty():
		_count.text = _said
	elif _find.text.is_empty():
		_count.text = ""
	elif _hits.is_empty():
		_count.text = "No results"
		_count.add_theme_color_override("font_color", NONE_COLOR)
	else:
		var i := _current()
		var more := "+" if _hits.size() >= MOST else ""
		_count.text = ("%d of %d%s" % [i + 1, _hits.size(), more]) if i >= 0 else ("%d%s found" % [_hits.size(), more])


func _box(hint: String) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = hint
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	e.custom_minimum_size = Vector2(150, 0)
	e.add_theme_font_size_override("font_size", 13)
	return e


func _button(words: String, tip: String, act: Callable) -> Button:
	var b := Button.new()
	b.text = words
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = tip
	b.add_theme_font_size_override("font_size", 13)
	b.pressed.connect(act)
	return b
