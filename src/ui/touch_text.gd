class_name TouchText
extends TextEdit

## TouchText - a TextEdit a finger can use (2026-10-31, the user on a phone: "the note is unscrollable because
## clicking and swiping selects/highlights the text, instead of scrolling the body"). Godot 4.7's TextEdit knows
## only a mouse: Android hands it a finger as one (`input_devices/pointing/emulate_mouse_from_touch`), and a mouse
## dragged over a TextEdit selects. With [member touch] on, the left button's presses and drags are taken here,
## before the TextEdit sees them, and read as a phone's notes app reads a finger:
##
## - A DRAG SCROLLS, and a flick runs on, slowing ([constant FRICTION]); a press stops it.
## - A TAP puts the caret there and takes focus, and the keyboard comes up then and only then. Until a tap the box
##   cannot take focus at all ([member Control.focus_mode] NONE): Godot gives a box focus on a press, before the
##   box sees it, and the keyboard comes with focus - every swipe had opened it.
## - A LONG PRESS ([constant LONG_MS], held within [constant SLOP]) selects the word under it, and a drag before
##   letting go carries the selection on; a double tap selects the word too.
## - MARKERS under each end of a selection drag that end ([method _draw_marks]), and a bar of Cut, Copy, Paste and
##   Select all stands over it ([method _place_bar]).
##
## Godot's own does none of it in 4.7 (its touch handles came later), and its drag-and-drop of a selection - off
## here - moved the words a swipe began on. The wheel, the right button and the keys reach the TextEdit as ever;
## with [member touch] off it is a plain TextEdit. [method tick] and [member now_ms] are a gate's seams.

## How long a press must be held, unmoved, to select, in ms (Android's own long press is 400-500).
const LONG_MS := 450
## Two taps this close in time (ms) select a word.
const DOUBLE_MS := 320
## How far a finger may wander and still be pressing in place, at scale 1 (px).
const SLOP := 12.0
## A flick's speed is multiplied by exp(-FRICTION) each second.
const FRICTION := 3.2
## Slower than this (px a second) a flick has stopped, or never was one.
const FLICK_LEAST := 60.0
## How far back a flick's speed is read when the finger lets go, in ms.
const FLICK_WINDOW := 90
## A marker's knob's radius, at scale 1 (px); a finger takes it from this many radii away.
const KNOB := 11.0
const KNOB_REACH := 1.8
## Lines a second a held selection scrolls with the finger at the box's top or bottom edge.
const EDGE_SPEED := 12.0

## Whether a finger drives it (a phone). Off, it is a plain TextEdit.
var touch := false:
	set(v):
		touch = v
		drag_and_drop_selection_enabled = not v
		if not has_focus():
			focus_mode = Control.FOCUS_NONE if v else Control.FOCUS_ALL
		set_process(v)
## The size of the markers and the bar: 1 on a desktop, larger on a phone.
var s := 1.0
## The markers' color.
var accent := Color("8ab4f8"):
	set(v):
		accent = v
		if _marks != null:
			_marks.queue_redraw()
## A gate's clock, in ms; -1 reads the real one.
var now_ms := -1

var _mode := ""                     # "", "press", "scroll", "extend" (a long press held), "handle"
var _down := Vector2.ZERO           # where the finger came down (or where a scroll took up from)
var _down_ms := 0
var _at := Vector2.ZERO             # where it is now
var _scroll0 := 0.0                 # the scroll when it came down
var _track: Array[Vector2] = []     # (ms since it came down, y) of its last moves, for a flick's speed
var _fling := 0.0                   # px a second; positive runs on toward the end of the words
var _word: Array[Vector2i] = []     # the long-pressed word's ends, (column, line)
var _fixed := Vector2i.ZERO         # the end that stays while the other is dragged
var _grip := Vector2.ZERO           # a marker's drag: the finger less the point its knob hangs from
var _marks_on := false
var _last_tap_ms := -100000
var _last_tap := Vector2.ZERO
var _marks: Control
var _bar: PanelContainer
var _buttons := {}


func _init() -> void:
	_marks = Control.new()
	_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marks.z_index = 1
	_marks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_marks.draw.connect(_draw_marks)
	add_child(_marks, false, Node.INTERNAL_MODE_FRONT)
	_make_bar()
	set_process(false)
	draw.connect(_on_drawn)
	caret_changed.connect(func() -> void:
		if _marks_on and not has_selection():
			_hide_marks())
	text_changed.connect(_hide_bar)
	focus_exited.connect(func() -> void:
		if touch:
			focus_mode = Control.FOCUS_NONE)


## Take focus, the keyboard with it - what a tap does, for whoever hands the words focus (Enter in a title).
func take_focus() -> void:
	focus_mode = Control.FOCUS_ALL
	if has_focus():
		_sync_keyboard()
	else:
		grab_focus()


func _process(delta: float) -> void:
	tick(delta)


## One step of what runs on without the finger: a long press coming due, a held selection scrolling at the
## edge, a flick slowing.
func tick(delta: float) -> void:
	if _mode == "press" and _now() - _down_ms >= LONG_MS:
		_long_press()
	if _mode == "extend" or _mode == "handle":
		var lh := float(get_line_height())
		var step := 0.0
		if _at.y < lh * 0.8:
			step = -EDGE_SPEED * delta
		elif _at.y > size.y - lh * 0.8:
			step = EDGE_SPEED * delta
		if step != 0.0:
			scroll_vertical += step
			_follow(_at)
	if _fling != 0.0:
		var was := scroll_vertical
		scroll_vertical += _fling * delta / float(get_line_height())
		_fling *= exp(-FRICTION * delta)
		if absf(_fling) < FLICK_LEAST or is_equal_approx(was, scroll_vertical):
			_fling = 0.0


func _gui_input(e: InputEvent) -> void:
	if not touch:
		return
	var mb := e as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			_press(mb.position)
		else:
			_release(mb.position)
		accept_event()
		return
	var mm := e as InputEventMouseMotion
	if mm != null and (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_move(mm.position)
		accept_event()


func _now() -> int:
	return now_ms if now_ms >= 0 else Time.get_ticks_msec()


func _press(p: Vector2) -> void:
	_fling = 0.0
	_at = p
	if _marks_on and has_selection():
		var ends := _ends()
		var which := _knob_at(p)
		if which >= 0:
			_mode = "handle"
			_fixed = ends[1 - which]
			_grip = p - _point_of(ends[which])
			_hide_bar()
			return
	_mode = "press"
	_down = p
	_down_ms = _now()
	_scroll0 = scroll_vertical
	_track = [Vector2(0.0, p.y)]


func _move(p: Vector2) -> void:
	_at = p
	var since := float(_now() - _down_ms)
	_track.append(Vector2(since, p.y))
	while _track.size() > 2 and since - _track[0].x > FLICK_WINDOW:
		_track.pop_front()
	match _mode:
		"press":
			if p.distance_to(_down) > SLOP * s:
				_mode = "scroll"
				_hide_bar()
				_down = p           # taken up from here, so the words do not jump by the slop
				_scroll0 = scroll_vertical
		"scroll":
			scroll_vertical = _scroll0 - (p.y - _down.y) / float(get_line_height())
		"extend", "handle":
			_follow(p)


func _release(p: Vector2) -> void:
	match _mode:
		"press":
			_tap(p)
		"scroll":
			if _track.size() >= 2:
				var first := _track[0]
				var last := _track[_track.size() - 1]
				var dt := (last.x - first.x) / 1000.0
				if dt > 0.0:
					var v := -(last.y - first.y) / dt
					if absf(v) >= FLICK_LEAST:
						_fling = v
		"extend", "handle":
			_show_marks()
			_show_bar()
			if has_focus():
				_sync_keyboard()
	_mode = ""


func _tap(p: Vector2) -> void:
	var now := _now()
	var double := now - _last_tap_ms <= DOUBLE_MS and p.distance_to(_last_tap) <= SLOP * s * 2.0
	_last_tap_ms = now
	_last_tap = p
	if double:
		_last_tap_ms = -100000
		_select_word_at(p)
		_show_marks()
		_show_bar()
		if has_focus():
			_sync_keyboard()
		return
	_hide_marks()
	_hide_bar()
	deselect()
	var lc := get_line_column_at_pos(Vector2i(p))
	set_caret_line(lc.y, false)
	set_caret_column(lc.x, false)
	take_focus()


func _long_press() -> void:
	_mode = "extend"
	_select_word_at(_down)
	_show_marks()


func _select_word_at(p: Vector2) -> void:
	var lc := get_line_column_at_pos(Vector2i(p))
	deselect()
	set_caret_line(lc.y, false)
	set_caret_column(lc.x, false)
	select_word_under_caret(0)
	if has_selection():
		_word = [Vector2i(get_selection_from_column(), get_selection_from_line()),
			Vector2i(get_selection_to_column(), get_selection_to_line())]
	else:
		_word = [lc, lc]


## The finger at [param p] while a selection is held: a long press carries it on from its word, a marker moves
## its own end.
func _follow(p: Vector2) -> void:
	if _mode == "handle":
		var at := p - _grip - Vector2(0.0, get_line_height() * 0.5)
		var lc := get_line_column_at_pos(Vector2i(at))
		select(_fixed.y, _fixed.x, lc.y, lc.x)
		return
	if _word.size() < 2:
		return
	var lc := get_line_column_at_pos(Vector2i(p))
	if _before(lc, _word[0]):
		select(_word[1].y, _word[1].x, lc.y, lc.x)
	elif _before(_word[1], lc):
		select(_word[0].y, _word[0].x, lc.y, lc.x)
	else:
		select(_word[0].y, _word[0].x, _word[1].y, _word[1].x)


static func _before(a: Vector2i, b: Vector2i) -> bool:
	return a.y < b.y or (a.y == b.y and a.x < b.x)


## The selection's two ends, (column, line), the first first.
func _ends() -> Array[Vector2i]:
	return [Vector2i(get_selection_from_column(), get_selection_from_line()),
		Vector2i(get_selection_to_column(), get_selection_to_line())]


## Where a marker hangs from: the foot of the row at that column, or far off when the row is not shown.
func _point_of(lc: Vector2i) -> Vector2:
	var r := get_rect_at_line_column(lc.y, lc.x)
	if r.position.x < 0:
		return Vector2(-1e9, -1e9)
	return Vector2(r.position.x, r.position.y + get_line_height())


## The middle of a marker's knob: below and outside its end, the first to the left, the last to the right.
func _knob_of(which: int) -> Vector2:
	var k := KNOB * s
	return _point_of(_ends()[which]) + Vector2(-k if which == 0 else k, k)


## Which marker's knob [param p] takes (0 the first, 1 the last), or -1.
func _knob_at(p: Vector2) -> int:
	var best := -1
	var best_d := KNOB * s * KNOB_REACH
	for which in 2:
		var d := p.distance_to(_knob_of(which))
		if d <= best_d:
			best = which
			best_d = d
	return best


func _show_marks() -> void:
	_marks_on = has_selection()
	_marks.queue_redraw()


func _hide_marks() -> void:
	_marks_on = false
	_marks.queue_redraw()


## Each marker a knob with a square corner pointing up at its end, as a phone draws them.
func _draw_marks() -> void:
	if not _marks_on or not has_selection():
		return
	var k := KNOB * s
	var ends := _ends()
	for which in 2:
		var a := _point_of(ends[which])
		if a.x < -1e8:
			continue
		var c := _knob_of(which)
		_marks.draw_circle(c, k, accent, true, -1.0, true)
		_marks.draw_rect(Rect2(Vector2(a.x - k if which == 0 else a.x, a.y), Vector2(k, k)), accent)


## The TextEdit has drawn: its rows are where the markers and the bar look them up.
func _on_drawn() -> void:
	if _marks_on:
		_marks.queue_redraw()
	if _bar.visible:
		_place_bar()


# --- the bar --------------------------------------------------------------------------------------

func _make_bar() -> void:
	_bar = PanelContainer.new()
	_bar.visible = false
	_bar.z_index = 2
	_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	var row := HBoxContainer.new()
	_bar.add_child(row)
	for act: String in ["Cut", "Copy", "Paste", "Select all"]:
		var b := Button.new()
		b.text = act
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE        # a press on it must not take focus from the words
		b.pressed.connect(_act.bind(act))
		row.add_child(b)
		_buttons[act] = b
	add_child(_bar, false, Node.INTERNAL_MODE_FRONT)


func _style_bar() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.17, 0.18, 0.2, 0.98)
	box.set_corner_radius_all(roundi(8 * s))
	box.set_content_margin_all(roundf(4 * s))
	box.shadow_color = Color(0, 0, 0, 0.4)
	box.shadow_size = roundi(6 * s)
	_bar.add_theme_stylebox_override("panel", box)
	for act: String in _buttons:
		var b: Button = _buttons[act]
		b.add_theme_font_size_override("font_size", roundi(15 * s))
		b.add_theme_constant_override("h_separation", 0)


func _show_bar() -> void:
	_style_bar()
	var chosen := has_selection()
	_buttons["Cut"].visible = chosen and editable
	_buttons["Copy"].visible = chosen
	_buttons["Paste"].visible = editable
	_bar.visible = true
	_place_bar()


func _hide_bar() -> void:
	_bar.visible = false


## Over the selection's first row, or under its last marker where there is no room above.
func _place_bar() -> void:
	_bar.size = _bar.get_combined_minimum_size()
	var lh := float(get_line_height())
	var gap := 6.0 * s
	var first := Vector2(get_caret_draw_pos().x, get_caret_draw_pos().y)
	var last := first
	if has_selection():
		var ends := _ends()
		first = _point_of(ends[0])
		last = _point_of(ends[1])
	var x := first.x if first.y != last.y else (first.x + last.x) * 0.5
	var y := first.y - lh - gap - _bar.size.y
	if y < 0.0:
		y = last.y + KNOB * s * 2.0 + gap
	_bar.position = Vector2(clampf(x - _bar.size.x * 0.5, 0.0, maxf(size.x - _bar.size.x, 0.0)),
		clampf(y, 0.0, maxf(size.y - _bar.size.y, 0.0)))


func _act(act: String) -> void:
	match act:
		"Cut":
			cut()
		"Copy":
			copy()
			deselect()
		"Paste":
			paste()
		"Select all":
			select_all()
			_show_marks()
			_place_bar()
			return
	_hide_bar()
	if has_focus():
		_sync_keyboard()


## Tell the system's keyboard where the caret or the selection is, as Godot's TextEdit does on every release
## of the mouse it no longer sees here - typing then lands where the words are chosen.
func _sync_keyboard() -> void:
	if not editable or not virtual_keyboard_enabled or not DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		return
	var start := _index_of(get_caret_line(), get_caret_column())
	var end := -1
	if has_selection():
		start = _index_of(get_selection_from_line(), get_selection_from_column())
		end = _index_of(get_selection_to_line(), get_selection_to_column())
	DisplayServer.virtual_keyboard_show(text, get_global_rect(), DisplayServer.KEYBOARD_TYPE_MULTILINE, -1, start, end)


## The character index of (line, column) in the whole text.
func _index_of(line: int, column: int) -> int:
	var n := 0
	for i in line:
		n += get_line(i).length() + 1
	return n + column
