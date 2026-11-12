extends Node

## panel_cards_check - that every real panel's sections are cards, each with its chip, and that a chip brings its card.
##
##   tests/run_boot_probe.sh tests/ui/panel_cards_check.gd 120
##
## next/notes.md step 2: each mode's sections in colored cards. Checked on the Generative, Synthesis and Cards panels, on a
## note's own panel (a song played by hand) and on Masking's, before a clip is chosen:
##
##   EVERY SECTION IS A CARD: a key of its panel's, a title, a family with a color, and a chip in the row.
##   A CHIP BRINGS ITS CARD INTO VIEW (2026-11-09: a card no longer folds, so neither its bar nor its chip folds it): on a
##   panel scrolled to its top, the last card's chip brings it out of the bottom pile, and its rows still show - on the
##   Generative and Cards panels, which overflow the window (Synthesis' three cards fit it, and have no pile).
##
## THE CONTROL: before the press the last card lies in the bottom pile, or "brought" proves nothing. The deck's own
## mechanics (where a press brings a card, the piles, the fan) are panel_deck_check's.

var _fails: Array = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	get_tree().root.size = Vector2i(1280, 720)
	await _panel("Generative", func() -> Node: return ReadingPanel.new(), true)
	await _panel("Synthesis", func() -> Node: return SynthEditor.new(), false)
	await _panel("Cards", func() -> Node:
		var cards := ReadingPanel.new()
		cards.workspace = "table"
		return cards, true)
	await _note_panel()
	await _masking()
	if _fails.is_empty():
		print("panel_cards_check: ALL OK")
		get_tree().quit(0)
		return
	print("panel_cards_check: %d FAILURE(S)" % _fails.size())
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


## Build [param make]'s panel by hand, as panel_fit_check does (an editor's _ready would start the
## voice host), into the tree so the cards are ready.
func _build(make: Callable) -> Array:
	var ed: Node = make.call()
	ed._build_panel()
	# not the author's document: a built panel comes up synced to whatever they have open
	ed._doc._sync = false
	ed._doc._fields = {}
	var panel: SidePanel = ed._panel
	ed.remove_child(panel)
	add_child(panel)
	await _settle()
	return [ed, panel]


func _panel(name: String, make: Callable, overflows: bool) -> void:
	var built := await _build(make)
	var ed: Node = built[0]
	var panel: SidePanel = built[1]
	var cards: Array = panel.cards()
	_ok(cards.size() >= 3, "%s: the panel's sections are cards (%d)" % [name, cards.size()])
	# a card the panel has hidden (a Pipeline card with nothing to list) has no chip showing, as it has no place in cards()
	_ok(panel.card_row != null and panel.card_row.get_children().filter(func(c: Control) -> bool: return c.visible).size() == cards.size(),
		"%s: a chip for every card" % name)
	for c in cards:
		var card: Card = c
		_ok(not card.key.is_empty() and card.key.begins_with(panel.card_prefix + "."),
			"%s: '%s' has a key of its panel's (%s)" % [name, card.title, card.key])
		_ok(Card.FAMILIES.has(card.family), "%s: '%s' is of a known family (%s)" % [name, card.title, card.family])
	if overflows:
		await _brings(name, panel)
	panel.queue_free()
	ed.free()
	await _settle(1)


## A CHIP BRINGS ITS CARD: the last one, from the bottom pile of a panel at its top.
func _brings(name: String, panel: SidePanel) -> void:
	var cards: Array = panel.cards()
	var last: Card = cards[cards.size() - 1]
	panel._scroll.get_v_scroll_bar().value = 0.0
	await _settle()
	_ok(panel._deck.side_of(last) == 1, "%s: the control - at the top, '%s' lies in the bottom pile" % [name, last.title])
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	(panel.card_row._chips[last] as Button).gui_input.emit(ev)
	await get_tree().create_timer(0.4).timeout
	await _settle()
	_ok(panel._deck.side_of(last) == 0 and last.body.is_visible_in_tree(), "%s: its chip brings '%s' into view, its rows showing" % [name, last.title])


## A NOTE'S OWN PANEL: a note with a song, a medium and a storyboard, made in a folder of the gate's
## own. Its components are cards - the Body, the Song, the Medium, the Storyboard - keyed by the
## note's panel, a chip each.
func _note_panel() -> void:
	var keep := NoteStore.root
	NoteStore.root = "user://panel_cards_check"
	var note := NoteStore.create("Cards check", "Words.\n", {"song": {"path": ""},
		"medium": {"format": "full"}, "scenes": {"storyboard": "default"}})
	NoteStore.root = keep
	var np := NotePanel.new()
	np.path = note
	add_child(np)
	await _settle()
	var cards: Array = np._panel.cards()
	var titles: Array = cards.map(func(c: Node) -> String: return (c as Card).title)
	_ok(titles == ["Body", "Song", "Medium", "Storyboard"], "a note with a song, a medium and a storyboard: its components are cards (%s)" % str(titles))
	_ok(cards.all(func(c: Node) -> bool: return (c as Card).key.begins_with("note.")), "...each keyed by the note's panel")
	# (a card shown only at times - the Timeline card, while a timeline is open - keeps its chip hidden with it)
	var chips := np._panel.card_row.get_children().filter(func(c: Node) -> bool: return (c as CanvasItem).visible)
	_ok(chips.size() == cards.size(), "...with a chip each (%d shown for %d cards)" % [chips.size(), cards.size()])
	np.queue_free()
	await _settle(1)
	DirAccess.remove_absolute(note)
	DirAccess.remove_absolute(note.get_base_dir())


## MASKING, before a clip is chosen: the framework's panel with one card, the Clip.
func _masking() -> void:
	var me := MaskEditor.new()
	add_child(me)
	me.open_source("")
	await _settle(1)
	var p: SidePanel = me._src_panel
	var cards: Array = p.cards() if p != null else []
	_ok(cards.size() == 1 and (cards[0] as Card).key == "masking.clip",
		"Masking with no clip: a side panel with a Clip card (%s)" % str(cards.map(func(c: Node) -> String: return (c as Card).key)))
	me.queue_free()
	await _settle(1)
