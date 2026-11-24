extends Node

## keys_window_check - the keyboard shortcuts (KeysWindow): the "?" on a note's panel opens them beside the panel, and
## again puts them away; the mode's own come first; F1 and Esc put them away from inside, and the Esc never reaches
## the window behind (where it quits).
##
##   tests/run_boot_probe.sh tests/ui/keys_window_check.gd 60
##
## Holds:
##   - a panel's title row has "?" (tooltip naming F1) and "‹", and no "⋯" (a MenuButton) any more;
##   - "?" opens one window, every section of SECTIONS in it, not modal; "?" again closes it and frees it;
##   - a mode with `shortcuts()` (here a stand-in) has its section first, its keys in it;
##   - F1 pressed in the window closes it; so does Esc, and the Esc is handled there (the control: an Esc sent
##     to the app with nothing open is not handled by any window, so it would reach main).

var _fails: Array = []


class Mode extends Node:
	func shortcuts() -> Array:
		return ["Stand-in", [["Q", "a key of its own"]]]


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	get_window().size = Vector2i(1600, 900)
	var mode := Mode.new()
	add_child(mode)
	var panel := SidePanel.new()
	mode.add_child(panel)
	var row := panel.pin_title_row(mode)
	await _frames(3)
	var q: Button = null
	for b in row.find_children("*", "Button", true, false):
		if (b as Button).text == "?":
			q = b
	_ok(q != null and q.tooltip_text.contains("F1"), "the title row has \"?\", its tooltip naming F1")
	_ok(row.find_children("*", "MenuButton", true, false).is_empty(), "...and no \"⋯\"")
	if q == null:
		_finish()
		return
	q.pressed.emit()
	await _frames(3)
	var w := get_tree().get_first_node_in_group(KeysWindow.GROUP) as KeysWindow
	_ok(w != null and w.visible and not w.exclusive, "\"?\" opens the keys, not modal")
	if w != null:
		var words := _words(w)
		var all := true
		for section in KeysWindow.SECTIONS:
			if not words.has(String(section[0])):
				all = false
		_ok(all, "every section is in it")
		_ok(words.find("Stand-in") >= 0 and words.find("Stand-in") < words.find(String(KeysWindow.SECTIONS[0][0]))
			and words.has("a key of its own"), "the mode's own section comes first")
		var beside := panel.get_global_rect().end.x
		_ok(float(w.position.x) >= beside, "...beside the panel (at %d, the panel ends at %.0f)" % [w.position.x, beside])
	q.pressed.emit()
	await _frames(3)
	_ok(get_tree().get_first_node_in_group(KeysWindow.GROUP) == null, "\"?\" again puts them away")
	# F1 and Esc from inside
	for key in [KEY_F1, KEY_ESCAPE]:
		q.pressed.emit()
		await _frames(3)
		w = get_tree().get_first_node_in_group(KeysWindow.GROUP) as KeysWindow
		if w == null:
			_ok(false, "the keys open again")
			continue
		w.grab_focus()
		await _frames(1)
		var e := _key(key)
		get_window().push_input(e)
		await _frames(3)
		_ok(get_tree().get_first_node_in_group(KeysWindow.GROUP) == null, "%s in the window puts it away" % OS.get_keycode_string(key))
		if key == KEY_ESCAPE:
			_ok(not _esc_reached, "...and the Esc stops there")
	# the control: with nothing open, an Esc reaches the window behind
	get_window().push_input(_key(KEY_ESCAPE))
	await _frames(2)
	_ok(_esc_reached, "the control: with nothing open, an Esc reaches the window behind")
	_finish()


var _esc_reached := false


## Labels' words under [param n], in order.
func _words(n: Node) -> PackedStringArray:
	var out := PackedStringArray()
	for l in n.find_children("*", "Label", true, false):
		out.append((l as Label).text)
	return out


func _key(k: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = k
	e.physical_keycode = k
	e.pressed = true
	return e


func _unhandled_input(event: InputEvent) -> void:
	# main's place: an Esc that reaches here would have quit the app
	var k := event as InputEventKey
	if k != null and k.pressed and k.keycode == KEY_ESCAPE:
		_esc_reached = true


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _finish() -> void:
	if _fails.is_empty():
		print("keys_window_check: ALL OK")
		get_tree().quit(0)
		return
	print("keys_window_check: %d FAILURE(S)" % _fails.size())
	for m in _fails:
		print("   ", m)
	get_tree().quit(1)


func _ok(cond: bool, msg: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + msg)
	if not cond:
		_fails.append(msg)
