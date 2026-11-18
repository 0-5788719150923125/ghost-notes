extends SceneTree

## entry_card_check - one entry in a card's list ([EntryCard]): the Props, Environment and Pictures cards' entries all.
##
##   godot --headless --path . --script res://tests/ui/entry_card_check.gd
##
## What it holds:
##   - a click on its head opens it, showing its options, and another closes it, saying so each time (control: an entry with
##     nothing to show never opens, nor does a press of another button);
##   - a fixed entry is always open, and a click does not close it;
##   - its × takes it away only on a second press, the first arming it (control: one press does nothing), and disarms by itself;
##   - a grayed × says why and does nothing however often it is pressed;
##   - framed in the color of the card it stands on.

var _fails := 0


func _initialize() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + what)
	if not cond:
		_fails += 1


func _click(e: EntryCard, button := MOUSE_BUTTON_LEFT) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = true
	e._pressed(ev)


func _run() -> void:
	var card := Card.new("test.list", "List", &"environment")
	root.add_child(card)
	var e := EntryCard.new("Dust", "motes in the light", "what it is")
	var b := Button.new()
	b.text = "Roll"
	e.options.add_child(b)
	var said: Array = []
	e.toggled.connect(func(on: bool) -> void: said.append(on))
	card.body.add_child(e)
	await process_frame
	_ok(not e.options.visible and e.opens(), "closed at first, its options hidden")
	_click(e)
	_ok(e.open and e.options.visible and said == [true], "a click opens it, showing its options")
	_click(e)
	_ok(not e.open and not e.options.visible and said == [true, false], "another closes it")
	_click(e, MOUSE_BUTTON_RIGHT)
	_ok(not e.open and said.size() == 2, "the control: another button's press opens nothing")
	var bare := EntryCard.new("Nothing to do")
	card.body.add_child(bare)
	_click(bare)
	_ok(not bare.open and not bare.opens(), "the control: an entry with nothing to show never opens")
	var fixed := EntryCard.new("A share")
	fixed.options.add_child(Label.new())
	fixed.fixed = true
	card.body.add_child(fixed)
	_click(fixed)
	_ok(fixed.options.visible and not fixed.opens(), "a fixed entry is always open, and a click does not close it")
	# its ×
	var gone := [0]
	e.set_remove(func() -> void: gone[0] += 1, "Take it away.")
	var x: Button = e._x
	_ok(x.visible and not x.disabled and x.text == "×" and x.tooltip_text == "Take it away.", "its × stands at its head, saying what it does")
	x.pressed.emit()
	_ok(gone[0] == 0 and e.armed() and x.text == "Remove?", "the control: one press only arms it")
	x.pressed.emit()
	_ok(gone[0] == 1 and not e.armed() and x.text == "×", "a second takes it away")
	x.pressed.emit()
	e._disarm()
	_ok(gone[0] == 1 and not e.armed(), "armed, it calms down again by itself")
	var off := EntryCard.new("The terminal")
	card.body.add_child(off)
	await process_frame
	var never := [0]
	off.set_remove(func() -> void: never[0] += 1, "Take it off.", "The desk works it.")
	off._x.pressed.emit()
	off._x.pressed.emit()
	_ok(off._x.disabled and off._x.tooltip_text == "The desk works it." and never[0] == 0, "a grayed × says why and does nothing")
	var frame := e.get_theme_stylebox("panel") as StyleBoxFlat
	var hue := Card.family_color(&"environment")
	_ok(frame != null and Color(frame.border_color, 1.0).is_equal_approx(hue), "framed in the color of the card it stands on")
	card.queue_free()
	await process_frame
	print("entry_card_check: %s" % ("ALL OK" if _fails == 0 else "%d FAILED" % _fails))
	quit(1 if _fails > 0 else 0)
