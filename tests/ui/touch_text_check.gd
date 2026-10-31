extends SceneTree

## The gate of [TouchText] - a TextEdit a finger can use - driven through the viewport as Android hands it a
## finger (a mouse, emulated), its clock the gate's ([member TouchText.now_ms], [method TouchText.tick]). No
## renderer.
##
##   godot --headless --path . --script res://tests/ui/touch_text_check.gd
##
## - A DRAG SCROLLS, selects nothing and takes no focus (so brings no keyboard) - against a plain TextEdit given
##   the same press, which takes focus with it, and the keyboard, and takes the press as the start of a
##   selection, its caret moved there: the user's report (2026-10-31: "the note is unscrollable because clicking
##   and swiping selects/highlights the text"). Its selecting drag follows the system's pointer, which a headless
##   run does not move, so the selection itself is not shown here.
## - A FLICK RUNS ON after the finger lets go, slows and stops; a press stops it.
## - A TAP puts the caret where it lands and takes focus; focus gone, the box cannot take it from a drag again.
## - A LONG PRESS selects the word under it and takes no focus - against a press let go sooner, which selects
##   nothing; held and dragged, the selection runs on from the word, and letting go shows the markers and the bar.
## - A MARKER dragged moves its own end, the other staying; dragged past the other, the other stays put still.
## - THE BAR, pressed through the viewport: Select all selects the words whole, Cut takes the selection out.
## - A DOUBLE TAP selects the word.

const WORDS := "alpha bravo charlie delta echo foxtrot golf hotel india juliet kilo lima mike november oscar papa"

var _fails := 0
var _clock := 1000
var _boxes: Array[TextEdit] = []


func _init() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		print("  FAIL: " + what)


func _run() -> void:
	root.size = Vector2i(1200, 900)      # a headless window is 64 px square, and a press outside it hovers nothing
	for check: Callable in [_drag, _flick, _tap, _long_press, _markers, _bar, _double_tap]:
		var done: Variant = await check.call()
		_ok(done == true, "%s stopped part way (a script error - see above)" % check.get_method())
		for b in _boxes:
			b.queue_free()
		_boxes.clear()
		await process_frame
	print("touch_text_check: %s (%d failure%s)" % ["ALL OK" if _fails == 0 else "FAILED", _fails, "" if _fails == 1 else "s"])
	quit(1 if _fails > 0 else 0)


## A box of 80 lines of words, drawn once (its rows are where positions are looked up).
func _make(touch: bool) -> TextEdit:
	var t: TextEdit = TouchText.new() if touch else TextEdit.new()
	var lines := PackedStringArray()
	for i in 80:
		lines.append("%d %s" % [i, WORDS])
	t.text = "\n".join(lines)
	t.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	root.add_child(t)
	t.position = Vector2.ZERO
	t.size = Vector2(420, 320)
	if touch:
		var tt := t as TouchText
		tt.touch = true
		tt.set_process(false)        # the gate's clock drives it
		tt.now_ms = _clock
	_boxes.append(t)
	await process_frame
	await process_frame
	return t


func _time(t: TextEdit, ms: int) -> void:
	_clock += ms
	if t is TouchText:
		(t as TouchText).now_ms = _clock


## Events in the canvas's own coordinates: the project stretches its canvas, and a window's would be scaled.
func _button(p: Vector2, down: bool) -> void:
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = down
	mb.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	mb.position = p
	mb.global_position = p
	root.push_input(mb, true)


func _motion(p: Vector2) -> void:
	var mm := InputEventMouseMotion.new()
	mm.button_mask = MOUSE_BUTTON_MASK_LEFT
	mm.position = p
	mm.global_position = p
	root.push_input(mm, true)


## A finger from [param a] to [param b] in [param steps] moves, [param ms] apart, then let go.
func _swipe(t: TextEdit, a: Vector2, b: Vector2, steps := 8, ms := 16) -> void:
	_button(a, true)
	for i in steps:
		_time(t, ms)
		_motion(a.lerp(b, float(i + 1) / steps))
	_button(b, false)


func _tap_at(t: TextEdit, p: Vector2) -> void:
	var over := InputEventMouseMotion.new()      # a button takes a press only while the pointer is over it
	over.position = p
	over.global_position = p
	root.push_input(over, true)
	_button(p, true)
	_time(t, 60)
	_button(p, false)


func _drag() -> bool:
	var t: TouchText = await _make(true)
	var s0 := t.scroll_vertical
	_swipe(t, Vector2(200, 280), Vector2(200, 60))
	_ok(t.scroll_vertical > s0 + 3.0, "a drag up of 220 px scrolled %.2f lines" % (t.scroll_vertical - s0))
	_ok(not t.has_selection(), "a drag selected '%s'" % t.get_selected_text())
	_ok(not t.has_focus(), "a drag took focus - the keyboard would come up with every scroll")
	# the control: Godot's own TextEdit, in the same place, the same press
	t.queue_free()
	_boxes.erase(t)
	await process_frame
	var plain: TextEdit = await _make(false)
	var at := plain.get_line_column_at_pos(Vector2i(200, 280))
	_button(Vector2(200, 280), true)
	_ok(plain.has_focus() and plain.get_caret_line() == at.y and plain.get_caret_column() == at.x,
		"CONTROL: a plain TextEdit took neither focus nor the press - the report would not show here")
	_button(Vector2(200, 280), false)
	return true


func _flick() -> bool:
	var t: TouchText = await _make(true)
	_swipe(t, Vector2(200, 280), Vector2(200, 120), 5, 12)
	var let_go := t.scroll_vertical
	for i in 4:
		t.tick(0.05)
	_ok(t.scroll_vertical > let_go + 1.0, "a flick ran on %.2f lines" % (t.scroll_vertical - let_go))
	for i in 120:
		t.tick(0.05)
	var settled := t.scroll_vertical
	t.tick(0.05)
	_ok(is_equal_approx(settled, t.scroll_vertical), "a flick had not stopped after 6 s")
	# a press stops one
	_time(t, 1000)
	_swipe(t, Vector2(200, 280), Vector2(200, 120), 5, 12)
	_time(t, 1000)
	_button(Vector2(200, 150), true)
	var held := t.scroll_vertical
	t.tick(0.05)
	_ok(is_equal_approx(held, t.scroll_vertical), "a press did not stop a flick")
	_button(Vector2(200, 150), false)
	return true


func _tap() -> bool:
	var t: TouchText = await _make(true)
	var p := Vector2(90, 50)
	var want := t.get_line_column_at_pos(Vector2i(p))
	_tap_at(t, p)
	_ok(t.has_focus(), "a tap did not take focus")
	_ok(not t.has_selection() and t.get_caret_line() == want.y and t.get_caret_column() == want.x,
		"a tap put the caret at %d:%d, not %d:%d" % [t.get_caret_line(), t.get_caret_column(), want.y, want.x])
	t.release_focus()
	_ok(t.focus_mode == Control.FOCUS_NONE, "focus gone, the box can be given focus by a drag again")
	return true


func _long_press() -> bool:
	var t: TouchText = await _make(true)
	var p := Vector2(120, 60)
	# the control: let go before the long press comes due - a tap, no selection
	_button(p, true)
	_time(t, TouchText.LONG_MS - 150)
	t.tick(0.0)
	_ok(not t.has_selection(), "CONTROL: a press held %d ms selected - the long press is not timed" % (TouchText.LONG_MS - 150))
	_button(p, false)
	t.release_focus()
	_time(t, 1000)
	_button(p, true)
	_time(t, TouchText.LONG_MS + 20)
	t.tick(0.0)
	var word := t.get_selected_text()
	_ok(not word.is_empty() and not word.contains(" ") and (WORDS.split(" ").has(word) or word.is_valid_int()),
		"a long press selected '%s', not the word under it" % word)
	_ok(not t.has_focus(), "a long press took focus")
	# held and dragged on, two rows down
	_motion(p + Vector2(0, t.get_line_height() * 2.0))
	var run := t.get_selected_text()
	_ok(run.begins_with(word) and run.length() > word.length() + 5, "a held long press dragged on selected '%s'" % run)
	_button(p + Vector2(0, t.get_line_height() * 2.0), false)
	_ok(t._marks_on and t._bar.visible, "letting go of a long press shows no markers or bar")
	return true


func _markers() -> bool:
	var t: TouchText = await _make(true)
	var p := Vector2(120, 60)
	_button(p, true)
	_time(t, TouchText.LONG_MS + 20)
	t.tick(0.0)
	_button(p, false)
	await process_frame
	var first := Vector2i(t.get_selection_from_column(), t.get_selection_from_line())
	var last := Vector2i(t.get_selection_to_column(), t.get_selection_to_line())
	# the last marker, dragged three rows down
	var knob := t._knob_of(1)
	_time(t, 1000)
	_swipe(t, knob, knob + Vector2(0, t.get_line_height() * 3.0), 4)
	var now_first := Vector2i(t.get_selection_from_column(), t.get_selection_from_line())
	var now_last := Vector2i(t.get_selection_to_column(), t.get_selection_to_line())
	_ok(now_first == first, "dragging the last marker moved the first end (%s to %s)" % [first, now_first])
	_ok(now_last.y > last.y or (now_last.y == last.y and now_last.x > last.x),
		"dragging the last marker down did not carry its end on (%s to %s)" % [last, now_last])
	# the first marker, dragged past the last: the last stays where it was
	await process_frame
	knob = t._knob_of(0)
	_time(t, 1000)
	_swipe(t, knob, knob + Vector2(0, t.get_line_height() * 6.0), 6)
	var after := Vector2i(t.get_selection_from_column(), t.get_selection_from_line())
	_ok(t.has_selection() and after == now_last, "the first marker dragged past the last left %s, not %s" % [after, now_last])
	return true


func _bar() -> bool:
	var t: TouchText = await _make(true)
	var p := Vector2(120, 60)
	_button(p, true)
	_time(t, TouchText.LONG_MS + 20)
	t.tick(0.0)
	_button(p, false)
	await process_frame
	await process_frame
	var all: Button = t._buttons["Select all"]
	_time(t, 1000)
	_tap_at(t, all.get_global_rect().get_center())
	_ok(t.get_selected_text() == t.text, "Select all, pressed, selected %d of %d characters" % [t.get_selected_text().length(), t.text.length()])
	await process_frame
	var cut: Button = t._buttons["Cut"]
	_ok(cut.visible, "the bar offers no Cut over a selection")
	_time(t, 1000)
	_tap_at(t, cut.get_global_rect().get_center())
	_ok(t.text.is_empty(), "Cut, pressed over everything, left %d characters" % t.text.length())
	return true


func _double_tap() -> bool:
	var t: TouchText = await _make(true)
	var p := Vector2(120, 60)
	_tap_at(t, p)
	_time(t, 120)
	_tap_at(t, p)
	var word := t.get_selected_text()
	_ok(not word.is_empty() and not word.contains(" "), "a double tap selected '%s'" % word)
	return true
