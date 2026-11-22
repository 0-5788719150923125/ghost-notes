extends SceneTree

## find_bar_check - find and replace in an editor's words ([FindBar]), driven by the keys a hand presses, through a
## [TextField]'s window as the app opens one (the Body's editor builds the same bar over its [CodeEdit]).
##
##   godot --headless --path . --script res://tests/ui/find_bar_check.gd
##
## - Ctrl+F opens it in the window, a selection on one line becoming what is found; Escape closes the bar and leaves the
##   window open, and a second Escape closes the window (control: with the bar shut, the first Escape closes it).
## - Ctrl+F again closes it, as its button opens and closes it.
## - It stands over the words' top-right corner and moves nothing: the text box keeps its place and size (control: the
##   holder's own rect, which the bar lies inside).
## - Every match is counted, case or not (control: Aa finds fewer); Enter steps to the next, Shift+Enter back, round the end.
## - Enter in Replace replaces the current match and selects the next; Ctrl+Enter replaces every match; each is one step
##   Ctrl+Z takes back, and the field is told of each as of a hand's edit.

const TEXT := "Ghost notes\nghost town and GHOST\nno match here\nghostghost"

var _fails := 0


func _init() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		print("  FAIL: " + what)


func _run() -> void:
	await process_frame
	for check in [_find, _replace, _escape, _toggle]:
		var done: Variant = await (check as Callable).call()
		_ok(done == true, "%s stopped part way (a script error - see above)" % (check as Callable).get_method())
	print("find_bar_check: %s (%d failure%s)" % ["ALL OK" if _fails == 0 else "FAILED", _fails, "" if _fails == 1 else "s"])
	quit(1 if _fails > 0 else 0)


func _key(code: Key, ctrl := false, shift := false) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	e.ctrl_pressed = ctrl
	e.shift_pressed = shift
	root.push_input(e)
	var up := e.duplicate() as InputEventKey
	up.pressed = false
	root.push_input(up)


## A TextField's window open on [constant TEXT], and its bar.
func _field() -> Array:
	var f := TextField.new("Words")
	root.add_child(f)
	f.text = TEXT
	f.open()
	await process_frame
	return [f, f._find as FindBar]


func _type(bar: FindBar, box: LineEdit, words: String) -> void:
	box.text = words
	box.text_changed.emit(words)


func _sel(bar: FindBar) -> Vector2i:
	var t := bar.target
	return Vector2i(t.get_selection_from_line(), t.get_selection_from_column()) if t.has_selection() else Vector2i(-1, -1)


func _find() -> bool:
	var got: Array = await _field()
	var f: TextField = got[0]
	var bar: FindBar = got[1]
	var t := bar.target
	t.select(1, 0, 1, 5)
	_key(KEY_F, true)
	_ok(bar.visible, "Ctrl+F opens the bar")
	_ok(bar._find.text == "ghost", "a selection on one line is what is found (%s)" % bar._find.text)
	_ok(bar._find.has_focus(), "the Find box takes the keys")
	_ok(bar._hits.size() == 5, "every match, any case, is counted (%d)" % bar._hits.size())
	_ok(_sel(bar) == Vector2i(1, 0), "the match at the caret is the current one (%s)" % _sel(bar))
	_ok(bar._count.text == "2 of 5", "the count says which (%s)" % bar._count.text)
	_key(KEY_ENTER)
	_ok(_sel(bar) == Vector2i(1, 15), "Enter goes to the next match (%s)" % _sel(bar))
	_key(KEY_ENTER, false, true)
	_key(KEY_ENTER, false, true)
	_ok(_sel(bar) == Vector2i(0, 0), "Shift+Enter goes back (%s)" % _sel(bar))
	_key(KEY_ENTER, false, true)
	_ok(_sel(bar) == Vector2i(3, 5), "and round the start to the last (%s)" % _sel(bar))
	_ok(t.text == TEXT, "finding changes nothing")
	bar._case.button_pressed = true
	_ok(bar._hits.size() == 3, "Aa matches case: fewer found (%d)" % bar._hits.size())
	_type(bar, bar._find, "nothing like it")
	_ok(bar._hits.is_empty() and bar._count.text == "No results", "nothing found says so (%s)" % bar._count.text)
	f.queue_free()
	await process_frame
	return true


func _replace() -> bool:
	var got: Array = await _field()
	var f: TextField = got[0]
	var bar: FindBar = got[1]
	var t := bar.target
	var told := [0]
	f.text_changed.connect(func() -> void: told[0] += 1)
	t.set_caret_line(0)
	t.set_caret_column(0)
	bar.open()
	_type(bar, bar._find, "ghost")
	_type(bar, bar._replace, "spirit")
	bar._replace.grab_focus()
	_key(KEY_ENTER)
	_ok(t.text == TEXT.replace("Ghost notes", "spirit notes"), "Enter in Replace replaces the current match:\n%s" % t.text)
	_ok(bar._hits.size() == 4 and _sel(bar) == Vector2i(1, 0), "and the next is selected (%d, %s)" % [bar._hits.size(), _sel(bar)])
	await process_frame
	_ok(f.text == t.text and told[0] >= 1, "the field is told, as of a hand's edit")
	_key(KEY_ENTER, true)
	var all := "spirit notes\nspirit town and spirit\nno match here\nspiritspirit"
	_ok(t.text == all, "Ctrl+Enter replaces every match:\n%s" % t.text)
	_ok(bar._hits.is_empty() and bar._count.text == "Replaced 4", "and says how many (%s)" % bar._count.text)
	t.undo()
	_ok(t.text == TEXT.replace("Ghost notes", "spirit notes"), "Replace All is one step back:\n%s" % t.text)
	t.undo()
	_ok(t.text == TEXT, "and one replacement one more:\n%s" % t.text)
	f.queue_free()
	await process_frame
	return true


func _escape() -> bool:
	var got: Array = await _field()
	var f: TextField = got[0]
	var bar: FindBar = got[1]
	var w := f.window()
	_key(KEY_F, true)
	_ok(bar.visible, "Ctrl+F reaches the bar through the window")
	_key(KEY_ESCAPE)
	_ok(not bar.visible and w.visible, "Escape closes the bar and leaves the window")
	_ok(bar.target.has_focus(), "the words take the keys again")
	_key(KEY_ESCAPE)
	_ok(not w.visible, "a second Escape closes the window (control)")
	f.queue_free()
	await process_frame
	return true


func _toggle() -> bool:
	var got: Array = await _field()
	var f: TextField = got[0]
	var bar: FindBar = got[1]
	var t := bar.target
	await process_frame
	var was := t.get_global_rect()
	_key(KEY_F, true)
	await process_frame
	await process_frame
	_ok(bar.visible, "Ctrl+F opens it")
	_ok(t.get_global_rect() == was, "the words do not move (%s, was %s)" % [t.get_global_rect(), was])
	var r := bar.get_global_rect()
	_ok(r.size.x > 0 and was.encloses(r), "it stands over them (%s in %s)" % [r, was])
	_ok(r.end.x > was.get_center().x and r.position.y < was.get_center().y, "in their top-right corner (%s)" % r)
	_ok(bar.get_parent() == t.get_parent() and bar.get_index() > t.get_index(), "beside the box, drawn after it, never in it")
	_key(KEY_F, true)
	_ok(not bar.visible and f.window().visible, "Ctrl+F again closes it, and only it")
	var b := bar.button()
	f.window().add_child(b)
	b.pressed.emit()
	_ok(bar.visible, "its button opens it")
	b.pressed.emit()
	_ok(not bar.visible, "and closes it")
	f.queue_free()
	await process_frame
	return true
