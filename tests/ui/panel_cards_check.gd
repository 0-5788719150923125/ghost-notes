extends Node

## panel_cards_check - that every real panel's sections are cards, each with its chip, and that a chip brings its card.
##
##   tests/run_boot_probe.sh tests/ui/panel_cards_check.gd 120
##
## next/notes.md step 2: each mode's sections in colored cards. Checked on the Generative and Cards panels, on a
## note's own panel (a song played by hand) and on Masking's, before a clip is chosen:
##
## - Every section is a card: a key of its panel's, a title, a family with a color, and a chip in the row.
## - A chip brings its card into view: on a panel scrolled to its top, the last card's chip brings it out of the bottom
##   pile, and its rows still show - on the Generative and Cards panels, which overflow the window.
## - Every card says what it is for: its title bar's tooltip is its blurb, and its chip's says it before what a click
##   does - a component's card the blurb of its row, the words "+" offered it with. "+"'s own tooltips are folded as the
##   menu opens (Boot.wrap_items): no line wider than a tooltip is let be.
##
## Controls: before the press the last card lies in the bottom pile, or "brought" proves nothing. A card made with no
## blurb must not pass as saying what it is for, and the menu's widest blurb must be wider than a tooltip unfolded. The
## deck's own mechanics (where a press brings a card, the piles, the fan) are panel_deck_check's.

var _fails: Array = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	get_tree().root.size = Vector2i(1280, 720)
	var bare := Card.new("x.bare", "Bare", &"paper")
	_ok(not _says(bare, null), "the control - a card made with no blurb does not say what it is for")
	bare.free()
	await _panel("Generative", func() -> Node: return ReadingPanel.new(), true)
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
		_ok(_says(card, panel.card_row), "%s: '%s' says what it is for, on its bar and its chip ('%s')" % [name, card.title, card.blurb])
	if overflows:
		await _brings(name, panel)
	panel.queue_free()
	ed.free()
	await _settle(1)


## A chip brings its card: the last one, from the bottom pile of a panel at its top.
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


## A note's own panel: a note with a song and a medium, made in a folder of the gate's own. Its components are
## cards - the Body, the Song, the Medium - keyed by the note's panel, a chip each.
func _note_panel() -> void:
	var keep := NoteStore.root
	NoteStore.root = "user://panel_cards_check"
	var note := NoteStore.create("Cards check", "Words.\n", {"song": {"path": ""}, "medium": {"format": "full"}})
	NoteStore.root = keep
	var np := NotePanel.new()
	np.path = note
	add_child(np)
	await _settle()
	var cards: Array = np._panel.cards()
	var titles: Array = cards.map(func(c: Node) -> String: return (c as Card).title)
	_ok(titles == ["Body", "Song", "Medium"], "a note with a song and a medium: its components are cards (%s)" % str(titles))
	_ok(cards.all(func(c: Node) -> bool: return (c as Card).key.begins_with("note.")), "...each keyed by the note's panel")
	# (a card shown only at times - the Timeline card, while a timeline is open - keeps its chip hidden with it)
	var chips := np._panel.card_row.get_children().filter(func(c: Node) -> bool: return (c as CanvasItem).visible)
	_ok(chips.size() == cards.size(), "...with a chip each (%d shown for %d cards)" % [chips.size(), cards.size()])
	var rows := {"Body": "text", "Song": "song", "Medium": "medium"}
	for c in cards:
		var card: Card = c
		var want := String((Components.REGISTRY.get(rows.get(card.title, ""), {"blurb": "?"}) as Dictionary)["blurb"])
		_ok(card.blurb == want and _says(card, np._panel.card_row), "...'%s' says its component's blurb on its bar and its chip" % card.title)
	await _menu_folds(np._panel)
	np.queue_free()
	await _settle(1)
	DirAccess.remove_absolute(note)
	DirAccess.remove_absolute(note.get_base_dir())


## What a card says it is for: a blurb, its bar's tooltip, and its chip's tooltip leading with it (a chip in [param row];
## null asks of the bar alone). Boot may have folded a tooltip already, so each is read unfolded.
func _says(card: Card, row: CardRow) -> bool:
	if card.blurb.strip_edges().is_empty() or _flat(card.head.tooltip_text) != _flat(card.blurb):
		return false
	if row == null:
		return true
	var chip: Button = row._chips.get(card)
	return chip != null and _flat(chip.tooltip_text).begins_with(_flat(card.blurb))


## [param tip] with Boot's folding taken out: a line break within a paragraph is a space again.
static func _flat(tip: String) -> String:
	return tip.replace("\n\n", "\u0001").replace("\n", " ").replace("\u0001", "\n\n")


## "+" opened as a press opens it, its tooltips folded by then: no line of one is wider than a tooltip may be. The control:
## the widest item's tooltip, unfolded, is wider than that.
func _menu_folds(panel: SidePanel) -> void:
	var pop := panel.plus.get_popup()
	panel.plus.show_popup()
	await _settle(2)
	var font: Font = ThemeDB.fallback_font
	var fsize := ThemeDB.get_default_theme().get_font_size("font_size", "TooltipLabel")
	var widest := 0.0
	var unfolded := 0.0
	var tips := 0
	for i in pop.item_count:
		var tip := pop.get_item_tooltip(i)
		if tip.is_empty():
			continue
		tips += 1
		for line in tip.split("\n"):
			widest = maxf(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x)
		for para in _flat(tip).split("\n\n"):
			unfolded = maxf(unfolded, font.get_string_size(para, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x)
	pop.hide()
	_ok(tips > 0 and unfolded > Boot.TIP_MAX_PX, "the control - '+' offers tooltips (%d), the widest %d px unfolded" % [tips, int(unfolded)])
	_ok(tips > 0 and widest <= Boot.TIP_MAX_PX + 1.0, "'+' folds its tooltips as it opens: the widest line %d px of %d" % [int(widest), int(Boot.TIP_MAX_PX)])


## Masking, before a clip is chosen: the framework's panel with one card, the Clip.
func _masking() -> void:
	var me := MaskEditor.new()
	add_child(me)
	me.open_source("")
	await _settle(1)
	var p: SidePanel = me._src_panel
	var cards: Array = p.cards() if p != null else []
	_ok(cards.size() == 1 and (cards[0] as Card).key == "masking.clip",
		"Masking with no clip: a side panel with a Clip card (%s)" % str(cards.map(func(c: Node) -> String: return (c as Card).key)))
	_ok(cards.size() == 1 and (cards[0] as Card).blurb == String(Components.REGISTRY["clip"]["blurb"]) and _says(cards[0], p.card_row),
		"...which says what a Clip is for")
	me.queue_free()
	await _settle(1)
