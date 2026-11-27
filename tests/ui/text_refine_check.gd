extends SceneTree

## text_refine_check - Refine… for a note's text ([TextRefine]; next/refine.md): the chat window on a conversation
## ([WriterChat]), a writer's change landing in a text box, and the Body card's editor offering it ([ScriptWriter]). No writer
## runs: turns are written into the conversation as a run's would be, and a send is refused (a gate starts no agent).
##
##   godot --headless --path . --script res://tests/ui/text_refine_check.gd
##
## - A change lands as one step the box's undo takes back, the caret where it was (control: the text before it differs).
## - A turn reads as a chat: the author's words shown as written (control: a bracket in them is no tag), a change as the lines
##   taken out struck and the lines put in, a line added alone (control: the lines kept round it are not shown), and what it
##   cost with what came from the cache.
## - The window draws each turn, the last again as it grows, and starts again on a new conversation pressed twice (control:
##   pressed once it is kept). Enter sends, and a refused send keeps the words and says why (control: Shift+Enter sends nothing).
## - Docked into the window it is opened from ([RefineDock]), never a window of its own: that window widens by the refine, its
##   own content keeping its width at the left and the refine standing at its right, as tall as it; the Refine button is a toggle,
##   pressed while it is open, and pressed again it folds away and the window narrows back to what it was (control: folded, the
##   content has its whole width back). On a window too wide to widen, it widens to the screen and moves onto it.
## - The Body's editor has Refine… before Done, and its writer is told what the words are for and the marks its palette offers:
##   a show's brief and its own marks (control: a reading's words are a script, with a speaker cue among its marks). A card
##   built again (the panel rebuilt mid-turn) takes up the conversation live for its words (control: one with none reads nothing).

const ROOT := "user://text_refine_check"

var _fails := 0


func _init() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		print("  FAIL: " + what)


func _run() -> void:
	await process_frame
	TextRefine.root = ROOT
	_wipe(ProjectSettings.globalize_path(ROOT))
	for check in [_splice, _reads, _window, _beside, _body]:
		var done: Variant = await (check as Callable).call()
		_ok(done == true, "%s stopped part way (a script error - see above)" % (check as Callable).get_method())
	for i in 3:
		await process_frame
	_wipe(ProjectSettings.globalize_path(ROOT))
	print("text_refine_check: %s (%d failure%s)" % ["ALL OK" if _fails == 0 else "FAILED", _fails, "" if _fails == 1 else "s"])
	quit(1 if _fails > 0 else 0)


func _wipe(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for d in DirAccess.get_directories_at(dir):
		_wipe(dir.path_join(d))
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.remove_absolute(dir)


func _splice() -> bool:
	var te := TextEdit.new()
	root.add_child(te)
	te.text = "The cat sat.\nThe dog sat.\nThe end."
	te.clear_undo_history()
	te.set_caret_line(2)
	te.set_caret_column(3)
	var before := te.text
	var at := before.find("dog sat")
	TextRefine.splice(te, at, "dog sat".length(), "dog slept\nand dreamed")
	_ok(te.text == "The cat sat.\nThe dog slept\nand dreamed.\nThe end." and te.text != before, "a change lands where it was named (%s)" % te.text)
	_ok(te.get_caret_line() == 3 and te.get_caret_column() == 3, "the caret stays with the words it was in (%d:%d)" % [te.get_caret_line(), te.get_caret_column()])
	te.undo()
	_ok(te.text == before, "one step the undo takes back (%s)" % te.text)
	te.queue_free()
	return true


func _reads() -> bool:
	var turn := {"you": "Make [b]this[/b] darker.", "agent": "claude", "model": "opus", "effort": "high", "events": [
		{"said": "I'll darken the **first** line."}, {"tool": "edit", "old": "The cat sat.", "new": "The cat brooded.", "count": 1}],
		"reply": "Darkened it.", "usage": {"fresh": 900, "cached": 12000, "out": 80, "usd": 0.012}, "error": ""}
	var b := TextRefine.turn_bbcode(turn)
	_ok(b.contains("Make [lb]b]this[lb]/b] darker.") and not b.contains("Make [b]"), "CONTROL: a bracket in the author's words is no tag")
	_ok(b.contains("[s]The cat sat.[/s]") and b.contains("+ The cat brooded.") and b.contains("[b]first[/b]"),
		"a change as the lines taken out struck and the lines put in, the writer's words drawn")
	_ok(b.contains("12K from the cache") and b.contains("$0.012") and b.contains("Darkened it."), "what it cost, and what came from the cache (%s)" % b)
	_ok(TextRefine.usage_line({}) == "", "CONTROL: a turn that says nothing of its cost shows none")
	var added := TextRefine.edit_bbcode("\nThe end.", "\n<!-- speaker: Mo -->\nThe end.")
	_ok(added.contains("+ <!-- speaker: Mo -->") and not added.contains("The end.") and not added.contains("[s]"),
		"a line added shows alone (control: the line kept beside it is not shown as taken out and put back: %s)" % added)
	_ok(TextRefine.turn_bbcode({"you": "x", "error": "stopped"}).contains("Stopped.") and not TextRefine.turn_bbcode({"you": "x", "error": "stopped"}).contains("Stopped: stopped"),
		"a turn stopped says so once")
	return true


func _window() -> bool:
	var chat := WriterChat.at(TextRefine.folder_for("", "window"))
	var held := ["The cat sat."]
	chat.read_text = func() -> String: return String(held[0])
	chat.apply = func(at: int, gone: int, put: String) -> void: held[0] = String(held[0]).substr(0, at) + put + String(held[0]).substr(at + gone)
	chat.turns.append({"you": "Shorter.", "agent": "claude", "events": [], "reply": "Cut it.", "usage": {}, "error": ""})
	var w := TextRefine.new(chat, "Body")
	root.add_child(w)
	_ok(w._labels.size() == 1 and not w._empty.visible, "each turn drawn")
	chat.turns.append({"you": "Darker.", "agent": "claude", "events": [], "reply": "", "usage": {}, "error": "", "running": true})
	chat.changed.emit()
	(chat.turns[1] as Dictionary)["reply"] = "Darkened."
	chat.changed.emit()
	_ok(w._labels.size() == 2 and (w._labels[1] as RichTextLabel).text.contains("Darkened."), "the last drawn again as it grows")
	w._box.text = "Make it rhyme."
	var shift := InputEventKey.new()
	shift.pressed = true
	shift.keycode = KEY_ENTER
	shift.shift_pressed = true
	w._box_key(shift)
	_ok(chat.turns.size() == 2 and w._box.text == "Make it rhyme.", "CONTROL: Shift+Enter sends nothing")
	var enter := InputEventKey.new()
	enter.pressed = true
	enter.keycode = KEY_ENTER
	w._box_key(enter)
	_ok(chat.turns.size() == 2 and w._box.text == "Make it rhyme." and not w._line.text.is_empty(),
		"Enter sends; refused, the words stay and it says why (%s)" % w._line.text)
	w._forget_pressed()
	_ok(chat.turns.size() == 2, "CONTROL: a new conversation pressed once keeps this one")
	w._forget_pressed()
	_ok(chat.turns.is_empty() and w._labels.is_empty() and w._empty.visible, "pressed twice it starts again")
	w.queue_free()
	return true


func _beside() -> bool:
	var host := Window.new()
	host.min_size = Vector2i(560, 320)
	root.add_child(host)
	var screen := Vector2i(root.get_visible_rect().size)
	host.popup(Rect2i(int(screen.x * 0.1), int(screen.y * 0.09), int(screen.x * 0.5), int(screen.y * 0.82)))
	host.size = Vector2i(int(screen.x * 0.5), int(screen.y * 0.82))
	var content := VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(content)
	var was := host.size
	await process_frame
	var content_w := content.size.x
	var button := Button.new()
	var w := TextRefine.new(WriterChat.at(TextRefine.folder_for("", "beside")), "Body")
	root.add_child(w)
	_ok(w.toggle(host, button), "the Refine button opens it")
	await process_frame
	_ok(w.get_parent() == host and host.size.x == was.x + RefineDock.WIDTH and host.size.y == was.y,
		"docked into its window, which widens by it (host %s, was %s)" % [host.size, was])
	_ok(absf(content.size.x - content_w) < 1.0 and absf(w.position.x - content_w) < 1.0 and absf(w.size.y - float(host.size.y)) < 1.0,
		"its own content keeps its width at the left, the refine at its right as tall as the window (content %.0f, refine %s+%s)" % [content.size.x, w.position, w.size])
	_ok(button.toggle_mode and button.button_pressed, "the button shows it open")
	_ok(not w.toggle(host, button), "pressed again it folds away")
	await process_frame
	_ok(not w.visible and host.size == was and absf(content.size.x - float(was.x)) < 1.0 and not button.button_pressed,
		"the window narrows back to what it was, the content its whole width again (host %s, content %.0f)" % [host.size, content.size.x])
	host.size = Vector2i(int(screen.x * 0.9), host.size.y)
	host.position = Vector2i(int(screen.x * 0.05), host.position.y)
	w.toggle(host, button)
	await process_frame
	_ok(host.position.x >= 0 and host.position.x + host.size.x <= screen.x,
		"on a window too wide to widen, it widens to the screen and stays on it (host %s+%s, screen %s)" % [host.position, host.size, screen])
	w.fold()
	w.queue_free()
	host.queue_free()
	return true


func _body() -> bool:
	var table = load("res://src/ui/script_writer.gd").new()
	table.setup("text_refine_check", PackedStringArray(), "table")
	table.doc._sync = false
	root.add_child(table)
	var foot: HBoxContainer = null
	for b in table._window.find_children("*", "Button", true, false):
		if (b as Button).text == "Refine…":
			foot = (b as Button).get_parent()
	var names: Array = foot.get_children().map(func(c: Node) -> String: return (c as Button).text if c is Button else "") if foot != null else []
	_ok(names.has("Refine…") and names.find("Refine…") == names.find("Done") - 1, "the editor has Refine… before Done (%s)" % str(names))
	var about: Dictionary = table.about()
	var marks: Array = (about["marks"] as Array).map(func(m: Dictionary) -> String: return String(m["label"]))
	_ok(bool(about["brief"]) and not bool(about["script"]) and marks.has("The deck"), "a show's brief, with its own marks (%s)" % str(marks))
	var reading = load("res://src/ui/script_writer.gd").new()
	reading.setup("text_refine_check", PackedStringArray(), "generative")
	reading.doc._sync = false
	root.add_child(reading)
	reading.refine_parts = func() -> Array: return ["voice"]
	var r: Dictionary = reading.about()
	_ok(bool(r["script"]) and (r["marks"] as Array).any(func(m: Dictionary) -> bool: return String(m["example"]).begins_with("<!-- speaker:"))
		and (r["parts"] as Array).size() == 1, "CONTROL: a reading's words are a script, a speaker cue among its marks, and its parts named")
	var chat: WriterChat = reading.chat()
	reading.text_edit.text = "Once."
	chat.apply.call(4, 0, " upon a time")
	_ok(reading.text_edit.text == "Once upon a time." and String(chat.read_text.call()) == "Once upon a time.", "the writer's change lands in the editor")
	# a panel built again mid-turn takes up the conversation live for its words
	reading.refine_folder = func() -> String: return ROOT.path_join("note")
	reading._chat = null
	var live: WriterChat = reading.chat()
	var again = load("res://src/ui/script_writer.gd").new()
	again.setup("text_refine_check", PackedStringArray(), "generative")
	again.doc._sync = false
	again.refine_folder = func() -> String: return ROOT.path_join("note")
	root.add_child(again)
	var other = load("res://src/ui/script_writer.gd").new()
	other.setup("text_refine_check", PackedStringArray(), "generative")
	other.doc._sync = false
	other.refine_folder = func() -> String: return ROOT.path_join("another")
	root.add_child(other)
	_ok(again._chat == live and live.read_text == Callable(again, "_words"), "a panel built again takes up the conversation live for its words")
	_ok(other._chat == null, "CONTROL: one with none live reads nothing")
	table.queue_free()
	reading.queue_free()
	again.queue_free()
	other.queue_free()
	return true
