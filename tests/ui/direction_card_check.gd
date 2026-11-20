extends SceneTree

## direction_card_check - the Direction's card ([DirectionCard], [Direction]; next/direction.md): a component any
## note can have, the card that keeps it, and its Refine…. No writer runs: a writer's change is handed in as its tools would.
##
##   godot --headless --path . --script res://tests/ui/direction_card_check.gd
##
## - It is a component: a row of its own with a card, attached by its block alone, shown by the reading's panel and a table's
##   (control: the voice lab's shows none).
## - The card keeps it: what is applied is what is captured, and a direction of several lines with quotes and colons comes back
##   whole through the note's frontmatter; [method Direction.text_of] reads its words (control: a block with none, or none at
##   all, is ""). Who refined it, where an older note kept that on the card, becomes its conversation's first pick.
## - The card is the direction's lines alone: no heading over them and no writer's row (both moved into Refine…).
## - Refine… stands in the direction's window, not on the card; the writer is told it works on a Direction, what the note is
##   made of, and can read the note (control: the card's own text is not the note); a writer's change lands in the open
##   window's box as one step its undo takes back, and the card is told so it keeps it.

const ROOT := "user://direction_card_check"

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
	for check in [_component, _keeps, _refine, _in_window]:
		var done: Variant = await (check as Callable).call()
		_ok(done == true, "%s stopped part way (a script error - see above)" % (check as Callable).get_method())
	for i in 3:
		await process_frame
	_wipe(ProjectSettings.globalize_path(ROOT))
	print("direction_card_check: %s (%d failure%s)" % ["ALL OK" if _fails == 0 else "FAILED", _fails, "" if _fails == 1 else "s"])
	quit(1 if _fails > 0 else 0)


func _wipe(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for d in DirAccess.get_directories_at(dir):
		_wipe(dir.path_join(d))
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.remove_absolute(dir)


func _component() -> bool:
	var row: Dictionary = Components.REGISTRY.get("direction", {})
	_ok(String(row.get("block", "")) == Direction.KEY and String(row.get("script", "")) == "res://src/ui/direction_card.gd",
		"the Direction is a component with a card of its own (%s)" % str(row))
	_ok(Components.attach_blocks("direction") == {"direction": {}}, "it is attached by its block alone")
	var hosts := func(ws: String) -> Array: return Registry.field(Components.WORKSPACES, ws, "hosts", []) as Array
	_ok((hosts.call("reading") as Array).has("direction") and (hosts.call("table") as Array).has("direction"),
		"the reading's panel and a table's show it")
	_ok(not (hosts.call("reading") as Array).has("clip"), "CONTROL: the reading's panel shows no clip")
	return true


func _keeps() -> bool:
	var card := DirectionCard.for_note({})
	root.add_child(card)
	var said := "# A Turing machine\n\nExplain what a \"Turing machine\" is: a tape, a head, rules.\n- Keep it under 20 minutes."
	card.apply({"text": said, "writer": "codex", "writer_model": "", "writer_effort": "high"})
	var got := card.capture()
	_ok(String(got["text"]) == said and not got.has("writer"), "what is applied is what is captured, and no writer is kept on the card (%s)" % str(got))
	_ok(card.chat().pick == {"agent": "codex", "model": "", "effort": "high"}, "who refined it becomes the conversation's first pick (%s)" % str(card.chat().pick))
	var doc := MiniYaml.emit({"ghost": {Direction.KEY: got}})
	var back: Variant = MiniYaml.parse(doc).get("data")
	var block: Variant = (back as Dictionary).get("ghost", {}).get(Direction.KEY) if back is Dictionary else null
	_ok(Direction.text_of(block) == said.strip_edges(), "a direction of several lines comes back whole through the frontmatter")
	_ok(Direction.text_of({}) == "" and Direction.text_of(null) == "" and Direction.text_of({"text": "  "}) == "",
		"CONTROL: a block with no words, or none at all, is no direction")
	card.queue_free()
	return true


func _refine() -> bool:
	var note := ProjectSettings.globalize_path(ROOT).path_join("note.md")
	DirAccess.make_dir_recursive_absolute(note.get_base_dir())
	var f := FileAccess.open(note, FileAccess.WRITE)
	f.store_string("---\ntitle: Theorem-Grooving\n---\nA desk under a lamp, a legal pad, a pen.\n")
	f.close()
	var card := DirectionCard.for_note({"path": note, "blocks": {"direction": {}, "voice": {}}})
	root.add_child(card)
	card.apply({"text": "Explain a Turing machine"})
	var about := card.about()
	var parts: Array = (about["parts"] as Array).map(func(p: Dictionary) -> String: return String(p["label"]))
	_ok(bool(about["direction"]) and String(about["title"]) == "Theorem-Grooving" and parts.has("Direction") and parts.has("Voice"),
		"the writer is told it works on a Direction, the note's title and what the note is made of (%s)" % str(about))
	var chat := card.chat()
	_ok(String(chat.read_note.call()).strip_edges() == "A desk under a lamp, a legal pad, a pen." and String(chat.read_text.call()) == "Explain a Turing machine",
		"it can read the note (control: the card's own text is not the note)")
	var sys := WriterChat.system_of(about, true)
	_ok(sys.contains("Theorem-Grooving") and sys.contains("The note is not yours"), "its system prompt says so")
	card.queue_free()
	return true


func _in_window() -> bool:
	var card := DirectionCard.for_note({})
	root.add_child(card)
	_ok(card._field._actions == [card._refine_btn] and card._refine_btn.get_parent() == null,
		"Refine… stands in the direction's window, alone, not on the card")
	_ok(card.find_children("*", "AgentPick", true, false).is_empty(), "no writer's row on the card")
	var heads := card._field.get_children().filter(func(c: Node) -> bool: return c is Label and (c as Label).visible and (c as Label).text == "Prompt")
	_ok(heads.is_empty() and not (card._field.get_child(0) as Label).visible, "no heading over the direction")
	card._field.window()
	_ok(card._refine_btn.get_parent() == card._field._foot and card._field._window.title == "Direction", "and the window has it, and is called Direction")
	card.apply({"text": "Explain a Turing machine"})
	var told := [0]
	card._field.text_changed.connect(func() -> void: told[0] += 1)
	var box: TextEdit = card._field._edit
	box.clear_undo_history()
	card.chat().apply.call(8, 0, "what ")
	for i in 2:
		await process_frame
	_ok(box.text == "Explain what a Turing machine" and card.text() == "Explain what a Turing machine" and told[0] >= 1,
		"a writer's change lands in the open window's box, and the card is told (%d)" % told[0])
	box.undo()
	_ok(box.text == "Explain a Turing machine", "one step the window's undo takes back (%s)" % box.text)
	card.queue_free()
	return true
