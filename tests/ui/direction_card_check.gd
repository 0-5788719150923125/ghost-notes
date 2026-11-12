extends SceneTree

## The gate of THE DIRECTION'S CARD ([DirectionCard], [Direction]; next/direction.md): a component any note can have, the card that
## keeps it, and its Refine. No writer runs: a refine's answer is handed in as the writer's would be.
##
##   godot --headless --path . --script res://tests/ui/direction_card_check.gd
##
## - IT IS A COMPONENT: a row of its own with a card, attached by its block alone, shown by the reading's panel and a table's (the
##   control: the voice lab's shows none).
## - THE CARD KEEPS IT: what is applied is what is captured, the writer with it, and a direction of several lines with quotes and
##   colons comes back whole through the note's frontmatter; [method Direction.text_of] reads its words (the control: a block with
##   none, or none at all, is "").
## - REFINE IS TOLD THE NOTE AND THE DIRECTION, and the note only where there is one (the control: a note with no words has no note
##   in the prompt); its answer is the direction, unfenced - and a refine that failed changes nothing (the control).
## - REFINE IS WHERE THE WORDS ARE (the user, 2026-11-11: "It's pointless to force the user to back-out of the Direction text"):
##   Refine stands in the direction's window, not on the card; a refine landing with the window open puts its words in the box,
##   and says nothing of a hand's edit (the control: a typed edit does).

var _fails := 0


func _init() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		print("  FAIL: " + what)


func _run() -> void:
	await process_frame
	for check in [_component, _keeps, _refine, _in_window]:
		var done: Variant = await (check as Callable).call()
		_ok(done == true, "%s stopped part way (a script error - see above)" % (check as Callable).get_method())
	for i in 3:
		await process_frame
	print("direction_card_check: %s (%d failure%s)" % ["ALL OK" if _fails == 0 else "FAILED", _fails, "" if _fails == 1 else "s"])
	quit(1 if _fails > 0 else 0)


func _component() -> bool:
	var row: Dictionary = Components.REGISTRY.get("direction", {})
	_ok(String(row.get("block", "")) == Direction.KEY and String(row.get("script", "")) == "res://src/ui/direction_card.gd",
		"the Direction is a component with a card of its own (%s)" % str(row))
	_ok(Components.attach_blocks("direction") == {"direction": {}}, "it is attached by its block alone")
	var hosts := func(ws: String) -> Array: return Registry.field(Components.WORKSPACES, ws, "hosts", []) as Array
	_ok((hosts.call("reading") as Array).has("direction") and (hosts.call("table") as Array).has("direction"),
		"the reading's panel and a table's show it")
	_ok(not (hosts.call("lab") as Array).has("direction"), "CONTROL: the voice lab's shows none")
	return true


func _keeps() -> bool:
	var card := DirectionCard.for_note({})
	root.add_child(card)
	var said := "# A Turing machine\n\nExplain what a \"Turing machine\" is: a tape, a head, rules.\n- Keep it under 20 minutes."
	card.apply({"text": said, "writer": "claude", "writer_model": "", "writer_effort": "high"})
	var got := card.capture()
	_ok(String(got["text"]) == said and String(got["writer"]) == "claude" and String(got["writer_effort"]) == "high",
		"what is applied is what is captured (%s)" % str(got))
	var doc := MiniYaml.emit({"ghost": {Direction.KEY: got}})
	var back: Variant = MiniYaml.parse(doc).get("data")
	var block: Variant = (back as Dictionary).get("ghost", {}).get(Direction.KEY) if back is Dictionary else null
	_ok(Direction.text_of(block) == said.strip_edges(), "a direction of several lines comes back whole through the frontmatter")
	_ok(Direction.text_of({}) == "" and Direction.text_of(null) == "" and Direction.text_of({"text": "  "}) == "",
		"CONTROL: a block with no words, or none at all, is no direction")
	card.queue_free()
	return true


func _refine() -> bool:
	var p := DirectionCard.prompt("Theorem-Grooving", "A desk under a lamp, a legal pad, a pen.", "Explain a Turing machine")
	_ok(String(p["prompt"]).contains("A desk under a lamp") and String(p["prompt"]).contains("Explain a Turing machine")
		and String(p["prompt"]).contains("Theorem-Grooving") and not String(p["system"]).is_empty(),
		"Refine is told the note, its title and the direction")
	var bare := DirectionCard.prompt("", "  ", "Explain a Turing machine")
	_ok(not String(bare["prompt"]).contains("<note>") and String(bare["prompt"]).contains("Explain a Turing machine"),
		"CONTROL: a note with no words has no note in the prompt")
	var card := DirectionCard.for_note({})
	root.add_child(card)
	card.apply({"text": "Explain a Turing machine"})
	card.land({"ok": true, "text": "```markdown\n# A Turing machine\n\nWhat it is, and why every computer is one.\n```"})
	_ok(card.text() == "# A Turing machine\n\nWhat it is, and why every computer is one.", "a refine's answer is the direction, unfenced (%s)" % card.text())
	card.land({"ok": false, "error": "stopped"})
	_ok(card.text() == "# A Turing machine\n\nWhat it is, and why every computer is one.", "CONTROL: a refine that failed changes nothing")
	card.queue_free()
	return true


func _in_window() -> bool:
	var card := DirectionCard.for_note({})
	root.add_child(card)
	_ok(card._field._actions == [card._refine] and card._refine.get_parent() == null,
		"Refine stands in the direction's window, alone, not on the card")
	card._field._build_window()
	_ok(card._refine.get_parent() == card._field._foot and card._said.get_parent() == card._field._col, "and the window has them, and what the writer is doing")
	card.apply({"text": "Explain a Turing machine"})
	var typed := [0]
	card._field.text_changed.connect(func() -> void: typed[0] += 1)
	card.land({"ok": true, "text": "# A Turing machine\n\nWhat it is."})
	for i in 2:
		await process_frame
	var box: TextEdit = card._field._edit
	_ok(box.text == "# A Turing machine\n\nWhat it is." and typed[0] == 0, "a refine lands in the open window's box, and is no hand's edit (%d)" % typed[0])
	box.insert_text_at_caret(" now")
	for i in 2:
		await process_frame
	_ok(typed[0] >= 1, "CONTROL: a typed edit is a hand's")
	card.queue_free()
	return true
