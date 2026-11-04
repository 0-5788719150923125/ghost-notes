extends Node

## text_field_check - words too long for a line on a card ([TextField]; the user, 2026-11-03: "the inner scrolling of
## the YouTube card's "description" can be pretty annoying and unexpected ... it's annoying that I even have to scroll
## it, to read it").
##
##   tests/run_boot_probe.sh tests/ui/text_field_check.gd 60
##
## THE WHEEL OVER THE WORDS SCROLLS THE PANEL: a real wheel event, at a real place on a real panel (THE CONTROL: the box
## it took the place of, in that place, keeps the wheel and the panel stays where it was).
## THE CARD SHOWS THEIR FIRST LINES, no taller for thousands more (THE CONTROL: one line is shorter than that), and no
## words is a dimmed placeholder.
## A LEFT CLICK OPENS THE WINDOW on all of them (THE CONTROL: a right click does not).
## IT ANSWERS AS THE BOX DID: a hand's edit reaches the words and the preview and says so, once; words arriving say
## nothing, and reach the window if it is open. Done and Esc shut it, and the words stay.
## SPACE IS THE WORDS' WHILE IT IS OPEN: the box stood in the main window, where the transport asked whether someone was
## typing, and the window has a focus of its own - a key goes to it, and nothing behind hears it (THE CONTROL: shut, it does).

## Hears what keys reach the main window's nodes, as the transport does.
class Ears extends Node:
	var keys := 0

	func _input(e: InputEvent) -> void:
		if e is InputEventKey:
			keys += 1

	func _unhandled_input(e: InputEvent) -> void:
		if e is InputEventKey:
			keys += 1


var _fails: Array = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	get_tree().root.size = Vector2i(1280, 720)
	await _wheel()
	await _preview()
	await _window()
	if _fails.is_empty():
		print("text_field_check: ALL OK")
		get_tree().quit(0)
		return
	print("text_field_check: %d FAILURE(S)" % _fails.size())
	for f in _fails:
		print("   ", f)
	get_tree().quit(1)


func _ok(cond: bool, msg: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + msg)
	if not cond:
		_fails.append(msg)


func _settle(frames := 6) -> void:
	for i in frames:
		await get_tree().process_frame


func _long(lines: int) -> String:
	var out := PackedStringArray()
	for i in lines:
		out.append("Line %d of what this video is, with words enough to read." % i)
	return "\n".join(out)


## A real panel that scrolls, [param it] on its one card with room above and far more below.
func _panel_with(it: Control) -> SidePanel:
	var panel := SidePanel.new()
	add_child(panel)
	var box := panel.add_card("c", "Card", &"paper")
	var above := Control.new()
	above.custom_minimum_size.y = 120.0
	box.add_child(above)
	box.add_child(it)
	var below := Control.new()
	below.custom_minimum_size.y = 3000.0
	box.add_child(below)
	await _settle()
	return panel


## In the viewport's own coordinates: the window is stretched.
func _press(at: Vector2, button: MouseButton) -> void:
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = button
		ev.pressed = pressed
		ev.factor = 1.0
		ev.position = at
		ev.global_position = at
		get_viewport().push_input(ev, true)
	await _settle()


func _key(code: Key, typed: String) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.unicode = typed.unicode_at(0) if pressed else 0
		ev.pressed = pressed
		get_viewport().push_input(ev)
	await _settle()


## Where the panel has scrolled to after the wheel turned once over [param target].
func _wheel_over(panel: SidePanel, target: Control) -> float:
	var bar := panel._scroll.get_v_scroll_bar()
	_ok(is_zero_approx(bar.value) and bar.max_value > bar.page, "the panel scrolls, and starts at its top")
	await _press(target.get_global_rect().get_center(), MOUSE_BUTTON_WHEEL_DOWN)
	return bar.value


func _wheel() -> void:
	var field := TextField.new("Description", "None yet", "What it is for.")
	field.text = _long(200)
	var panel := await _panel_with(field)
	var moved := await _wheel_over(panel, field._preview)
	_ok(moved > 0.0, "the wheel over the words scrolls the panel (to %.0f)" % moved)
	panel.free()
	# THE CONTROL: what the user was scrolling
	var box := TextEdit.new()
	box.custom_minimum_size.y = 120.0
	box.text = _long(200)
	var old := await _panel_with(box)
	var kept := await _wheel_over(old, box)
	_ok(is_zero_approx(kept), "CONTROL: a TextEdit in that place keeps the wheel, and the panel stays (at %.0f)" % kept)
	old.free()


func _preview() -> void:
	var field := TextField.new("Description", "None yet", "What it is for.")
	var panel := await _panel_with(field)
	var label := field._preview
	_ok(label.text == "None yet" and label.modulate.a < 1.0, "no words: the placeholder, dimmed")
	field.text = "A line."
	await _settle()
	var one := label.size.y
	_ok(label.text == "A line." and is_equal_approx(label.modulate.a, 1.0), "words: those, not dimmed")
	field.text = _long(40)
	await _settle()
	var some := label.size.y
	field.text = _long(4000)
	await _settle()
	var many := label.size.y
	_ok(label.text.begins_with("Line 0 of"), "the card shows their first lines")
	_ok(is_equal_approx(some, many), "no taller for thousands more lines (%.0f, %.0f)" % [some, many])
	_ok(label.get_visible_line_count() == TextField.PREVIEW_LINES,
		"they stop at %d lines (%d)" % [TextField.PREVIEW_LINES, label.get_visible_line_count()])
	_ok(some > one, "CONTROL: one line is shorter than that (%.0f, %.0f)" % [one, some])
	panel.free()


func _window() -> void:
	var field := TextField.new("Description", "None yet", "What it is for.")
	var said := [0]
	field.text_changed.connect(func() -> void: said[0] += 1)
	var words := _long(300)
	field.text = words
	_ok(said[0] == 0, "words arriving say nothing, as a box's did")
	var panel := await _panel_with(field)
	var at := field._preview.get_global_rect().get_center()
	await _press(at, MOUSE_BUTTON_RIGHT)
	_ok(not field.editing(), "CONTROL: a right click opens nothing")
	await _press(at, MOUSE_BUTTON_LEFT)
	_ok(field.editing(), "a click on the words opens the window")
	if not field.editing():
		panel.free()
		return
	_ok(field._window.get_parent() == field and field._edit.text == words, "it holds all of them")
	_ok(field._window.title == "Description", "and is named for what they are")

	field._edit.insert_text_at_caret("Typed. ")
	await _settle()
	_ok(field.text == "Typed. " + words, "an edit reaches the words")
	_ok(field._preview.text.begins_with("Typed. Line 0"), "and the preview, as it is typed")
	_ok(said[0] == 1, "and says so, once (%d)" % said[0])

	var ears := Ears.new()
	add_child(ears)
	var said_before: int = said[0]
	var was_text := field.text
	await _key(KEY_SPACE, " ")
	_ok(ears.keys == 0, "a space typed in the window reaches nothing behind it (heard %d)" % ears.keys)
	_ok(field.text.length() == was_text.length() + 1 and said[0] == said_before + 1, "it is a space in the words")

	field.text = "Arrived."
	await _settle()
	_ok(field._edit.text == "Arrived." and said[0] == said_before + 1, "words arriving while it is open reach the window and say nothing")

	var done: Button = field._window.find_children("*", "Button", true, false)[0]
	done.pressed.emit()
	_ok(not field.editing() and field.text == "Arrived.", "Done shuts it, and the words stay")
	field.open()
	await _settle()
	_ok(field.editing() and field._edit.text == "Arrived.", "it opens again on them")
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	field._window.window_input.emit(esc)
	_ok(not field.editing(), "Esc shuts it")
	await _key(KEY_SPACE, " ")
	_ok(ears.keys > 0, "CONTROL: shut, a space reaches the main window (heard %d)" % ears.keys)
	ears.free()
	panel.free()
