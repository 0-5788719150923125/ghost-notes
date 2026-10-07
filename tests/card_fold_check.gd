extends Node

## card_fold_check - that every mode panel's sections are cards that fold, and keep their fold.
##
##   tests/run_boot_probe.sh tests/card_fold_check.gd 120
##
## next/notes.md step 2: each mode's sections in colored FoldableContainers; "a fold is the
## viewer's, remembered in ghost.cfg". Checked on the Generative, Synthesis and Cards panels, on a
## note's own panel (a song played by hand) and on Masking's, before a clip is chosen:
##
##   EVERY SECTION IS A CARD: a key, a title, a family with a color, and a chip in the row.
##   THE CHIP FOLDS ITS CARD, Ctrl-click opens it alone, and the card's own title bar folds it.
##   A FOLD IS WRITTEN (Settings `[folds]`) and A PANEL BUILT AGAIN COMES BACK FOLDED - the
##   stored fold is read at build. A probe never flushes Settings to disk, so this runs against
##   the in-memory copy, which is the same table the app writes through.
##
## THE CONTROL: a card nobody folded must come back open, or "comes back folded" proves nothing.

var _fails: Array = []
## Every stored fold this touches, put back at the end (in memory: a probe never writes the file).
var _restore := {}


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await _panel("Generative", func() -> Node: return GenerativeEditor.new())
	await _panel("Synthesis", func() -> Node: return SynthEditor.new())
	await _panel("Cards", func() -> Node: return CardsEditor.new())
	await _note_panel()
	await _masking()
	for k in _restore:
		Settings.write(Card.SECTION, k, _restore[k])
	if _fails.is_empty():
		print("card_fold_check: ALL OK")
		get_tree().quit(0)
		return
	print("card_fold_check: %d FAILURE(S)" % _fails.size())
	for f in _fails:
		print("   ", f)
	get_tree().quit(1)


func _ok(cond: bool, msg: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + msg)
	if not cond:
		_fails.append(msg)


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
	await get_tree().process_frame
	return [ed, panel]


func _panel(name: String, make: Callable) -> void:
	var built := await _build(make)
	var ed: Node = built[0]
	var panel: SidePanel = built[1]
	var cards: Array = panel.cards()
	_ok(cards.size() >= 3, "%s: the panel's sections are cards (%d)" % [name, cards.size()])
	_ok(panel.card_row != null and panel.card_row.get_child_count() == cards.size(),
		"%s: a chip for every card" % name)
	for c in cards:
		var card: Card = c
		_ok(not card.key.is_empty() and card.key.begins_with(panel.card_prefix + "."),
			"%s: '%s' has a key of its panel's (%s)" % [name, card.title, card.key])
		_ok(Card.FAMILIES.has(card.family), "%s: '%s' is of a known family (%s)" % [name, card.title, card.family])
		if not _restore.has(card.key):
			_restore[card.key] = Settings.read(Card.SECTION, card.key, false)
		# start open, whatever the person running this has folded
		card.folded = false
	await get_tree().process_frame

	# THE CHIP FOLDS ITS CARD, and the fold is written
	var first: Card = cards[0]
	var chip: Button = panel.card_row._chips[first]
	_click(chip, false)
	await get_tree().process_frame
	_ok(first.folded, "%s: clicking '%s''s chip folds it" % [name, first.title])
	_ok(bool(Settings.read(Card.SECTION, first.key, false)), "%s: ...and the fold is written" % name)
	_ok(chip.text.begins_with("○"), "%s: ...and the chip says so (%s)" % [name, chip.text])
	_click(chip, false)
	await get_tree().process_frame
	_ok(not first.folded and not bool(Settings.read(Card.SECTION, first.key, true)),
		"%s: clicking it again opens it, and that is written too" % name)

	# CTRL-CLICK OPENS ONE ALONE
	var second: Card = cards[1]
	_click(panel.card_row._chips[second], true)
	await get_tree().process_frame
	var alone := not second.folded
	for c in cards:
		if c != second and not (c as Card).folded:
			alone = false
	_ok(alone, "%s: ctrl-clicking '%s''s chip opens it alone" % [name, second.title])

	# THE TITLE BAR FOLDS ITS CARD TOO (FoldableContainer's own click)
	second.fold()
	await get_tree().process_frame
	_ok(second.folded and bool(Settings.read(Card.SECTION, second.key, false)),
		"%s: folding '%s' by its title bar is written" % [name, second.title])

	# A PANEL BUILT AGAIN COMES BACK AS IT WAS LEFT: here, every card folded but the last.
	var last: Card = cards[cards.size() - 1]
	if last.folded:
		last.expand()
	var want := {}
	for c in cards:
		want[(c as Card).key] = (c as Card).folded
	panel.queue_free()
	ed.free()
	await get_tree().process_frame
	var again := await _build(make)
	var panel2: SidePanel = again[1]
	var back := true
	var open_back := false
	for c in panel2.cards():
		var card: Card = c
		if card.folded != bool(want.get(card.key, false)):
			back = false
			print("    %s: '%s' came back %s" % [name, card.title, "folded" if card.folded else "open"])
		if card == panel2.cards()[panel2.cards().size() - 1] and not card.folded:
			open_back = true
	_ok(back, "%s: a panel built again brings every card back folded or open as it was left" % name)
	_ok(open_back, "%s: the control - the card left open comes back open" % name)
	# ...AND THE CHIPS SAY SO. A stored fold is put back by assignment, which raises no signal; a
	# chip wired to the signal came up "open" on a folded card at every launch.
	await get_tree().process_frame
	var chips_agree := true
	for c in panel2.cards():
		var card: Card = c
		var its: Button = panel2.card_row._chips[card]
		if its.text.begins_with("○") != card.folded:
			chips_agree = false
			print("    %s: '%s' is %s and its chip says %s" % [name, card.title,
				"folded" if card.folded else "open", its.text])
	_ok(chips_agree, "%s: every chip agrees with its card after a rebuild" % name)
	panel2.queue_free()
	(again[0] as Node).free()
	await get_tree().process_frame


## A NOTE'S OWN PANEL: a Manual note (a song, a picture, a storyboard), made in a folder of the gate's
## own. Its components are cards - the Script, the Song, the Picture, the Storyboards - keyed by the
## note's panel, a chip each, and a fold is kept like the panels' cards.
func _note_panel() -> void:
	var keep := NoteStore.root
	NoteStore.root = "user://card_fold_check"
	var note := NoteStore.create("manual", "Fold check", "Words.\n")
	NoteStore.root = keep
	var np := NotePanel.new()
	np.path = note
	add_child(np)
	await get_tree().process_frame
	var cards: Array = np._panel.cards()
	var titles: Array = cards.map(func(c: Node) -> String: return (c as Card).title)
	_ok(titles == ["Script", "Song", "Picture", "Storyboards"], "a Manual note: its components are cards (%s)" % str(titles))
	_ok(cards.all(func(c: Node) -> bool: return (c as Card).key.begins_with("note.")), "...each keyed by the note's panel")
	_ok(np._panel.card_row.get_child_count() == cards.size(), "...with a chip each")
	if not cards.is_empty():
		var card: Card = cards[cards.size() - 1]
		if not _restore.has(card.key):
			_restore[card.key] = Settings.read(Card.SECTION, card.key, false)
		card.folded = false
		card.fold()
		_ok(bool(Settings.read(Card.SECTION, card.key, false)), "...and a fold is written")
	np.queue_free()
	await get_tree().process_frame
	DirAccess.remove_absolute(note)
	DirAccess.remove_absolute(note.get_base_dir())


## MASKING, before a clip is chosen: the framework's panel with one card, the Clip.
func _masking() -> void:
	var me := MaskEditor.new()
	add_child(me)
	me.open_source("")
	await get_tree().process_frame
	var p: SidePanel = me._src_panel
	var cards: Array = p.cards() if p != null else []
	_ok(cards.size() == 1 and (cards[0] as Card).key == "masking.clip",
		"Masking with no clip: a side panel with a Clip card (%s)" % str(cards.map(func(c: Node) -> String: return (c as Card).key)))
	me.queue_free()
	await get_tree().process_frame


func _click(chip: Button, ctrl: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.ctrl_pressed = ctrl
	chip.gui_input.emit(ev)
