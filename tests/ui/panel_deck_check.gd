extends Node

## panel_deck_check - a side panel's cards as a deck ([PanelDeck]; next/panel_deck.md; the user, 2026-11-02: "cards stack or
## unstack, overlap or expand", and of the panel pinned under the scroll, "They should all be scrollable").
##
##   tests/run_boot_probe.sh tests/ui/panel_deck_check.gd 120
##
## THE PILES: with more than fits, the bars of the cards below the view lie at its foot and those scrolled past at its top, in
## order, each showing, all inside the view, the last whole (THE CONTROL: a panel that fits has no pile, every bar over its card,
## and a bar in the middle of a scroll moves with its card).
## A BAR IS THE CARD'S OWN: what is on it works from a pile, and the pointer finds it there rather than what scrolls under it
## (THE CONTROL: off the bars, the pointer finds what scrolls).
## A TITLE SHOWS WHOLE IN A PILE, on a component's card too, whose × must not make its bar taller and push the title under the next
## bar (THE CONTROL: a bar made taller by what is on it does hide its title's line).
## FOLDED CARDS OVERLAP, a later bar on an earlier one (THE CONTROL: over a line that is no card, a bar keeps its height).
## A PRESS: where its card is, a bar folds or opens it; in a pile, it brings the card into view, opening it if it is folded, and
## an open card in a pile is not folded by it. OPENING SLIDES: the height passes between its ends, what is under it going with
## it, and an assigned fold is there at once and says nothing (THE CONTROL: fold() says). THE WHEEL over a bar scrolls.
## THE FAN: pointing at a bar in a pile moves those on it off it (THE CONTROL: a bar the other side of it stays).
## A SMALL WINDOW closes the piles up, and a large one holds them at their peek. A CARD FREED takes its bar along.

var _fails: Array = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	get_tree().root.size = Vector2i(1280, 720)
	await _fits()
	await _piles()
	await _titles_show()
	await _folded_overlap()
	await _presses()
	await _slides()
	await _fan()
	_sizes()
	await _freed()
	if _fails.is_empty():
		print("panel_deck_check: ALL OK")
		get_tree().quit(0)
		return
	print("panel_deck_check: %d FAILURE(S)" % _fails.size())
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


## A panel in the tree with [param count] cards, each [param rows] rows tall, all open; a stored fold is never read (no key).
func _panel(count: int, rows: int) -> SidePanel:
	var panel := SidePanel.new()
	add_child(panel)
	for i in count:
		var box := panel.add_card("c%d" % i, "Card %d" % i, &"paper")
		for r in rows:
			var l := Label.new()
			l.text = "row %d" % r
			l.custom_minimum_size.y = 24.0
			box.add_child(l)
	await _settle()
	return panel


func _cards(panel: SidePanel) -> Array:
	return panel.cards()


## A bar's top in the scroll view's coordinates.
func _bar_y(panel: SidePanel, card: Card) -> float:
	return card.head.global_position.y - panel._scroll.global_position.y


func _click(card: Card, button := MOUSE_BUTTON_LEFT) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = true
	ev.factor = 1.0
	card.head.gui_input.emit(ev)


func _point_at(at: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = at
	ev.global_position = at
	# in the viewport's own coordinates: the window is stretched
	get_viewport().push_input(ev, true)


## A PANEL THAT FITS HAS NO PILE
func _fits() -> void:
	var panel := await _panel(3, 2)
	var all := _cards(panel)
	var still := true
	for c in all:
		var card: Card = c
		still = still and panel._deck.side_of(card) == 0 and absf(card.head.global_position.y - card.global_position.y) < 1.0
		still = still and absf(card.head.size.x - card.size.x) < 1.0 and absf(card.head.global_position.x - card.global_position.x) < 1.0
	_ok(still, "a panel that fits: every bar lies exactly over its card, in no pile")
	_ok(panel._scroll.get_v_scroll_bar().max_value <= panel._scroll.size.y + 1.0, "...and it has nothing to scroll")
	_ok((all[0] as Card).head.get_parent() == panel._deck._clip and not panel._scroll.is_ancestor_of((all[0] as Card).head),
		"a bar stands on the deck's layer, outside what scrolls")
	panel.free()
	await _settle(1)


## THE PILES
func _piles() -> void:
	var panel := await _panel(8, 40)
	var all := _cards(panel)
	var n := all.size()
	# THE LAST BAR TALLER THAN THE REST, as the Pipeline's is: the one before it must show as much as any
	var taller := Button.new()
	taller.text = "Generate"
	taller.custom_minimum_size.y = (all[0] as Card).head.size.y + 10.0
	(all[n - 1] as Card).add_title_bar_control(taller)
	await _settle()
	var view: float = panel._scroll.size.y
	var close: float = panel._deck.peek()
	var bar := panel._scroll.get_v_scroll_bar()
	_ok(bar.max_value > view + 100.0, "the control: the cards are far taller than the view (%d of %d)" % [int(bar.max_value), int(view)])
	_ok(panel._deck.side_of(all[0]) == 0 and absf((all[0] as Card).head.global_position.y - (all[0] as Card).global_position.y) < 1.0,
		"at the top, the first bar lies over its card")
	var low := true
	var ordered := true
	for i in range(1, n):
		var card: Card = all[i]
		low = low and panel._deck.side_of(card) == 1 and _bar_y(panel, card) + card.head.size.y <= view + 1.0
		if i > 1:
			ordered = ordered and absf(_bar_y(panel, card) - _bar_y(panel, all[i - 1]) - close) < 1.0
	_ok((all[n - 1] as Card).head.size.y > (all[n - 2] as Card).head.size.y + 5.0, "the control: the last bar is the taller")
	_ok(low, "the cards below the view have their bars in a pile at its foot, inside it")
	_ok(ordered, "...in order, each showing %d px" % int(close))
	var last: Card = all[n - 1]
	_ok(absf(_bar_y(panel, last) + last.head.size.y - view) < 1.0, "...the last whole, on the view's foot")
	_ok(last.head.is_visible_in_tree() and (all[n - 2] as Card).head.get_index() < last.head.get_index(), "...a later bar over an earlier one")
	# THE POINTER FINDS A BAR IN A PILE, off it what scrolls
	var x: float = last.head.global_position.x + 20.0
	_point_at(Vector2(x, last.head.global_position.y + 4.0))
	await _settle(2)
	var hit := get_viewport().gui_get_hovered_control()
	_ok(hit == last.head or (hit != null and last.head.is_ancestor_of(hit)), "the pointer on a bar in a pile finds it (%s)" % str(hit))
	_point_at(Vector2(x, (all[0] as Card).body.global_position.y + 30.0))
	await _settle(2)
	hit = get_viewport().gui_get_hovered_control()
	_ok(hit != null and panel._scroll.is_ancestor_of(hit), "the control: off the bars it finds what scrolls (%s)" % str(hit))
	_point_at(Vector2(1000, 600))
	# THE MIDDLE: a bar in the middle of the scroll moves with its card
	var mid: Card = all[3]
	bar.value = mid.position.y + panel.body.position.y - 3.0 * close - 100.0
	await _settle()
	var with_card := absf(mid.head.global_position.y - mid.global_position.y) < 1.0
	_ok(panel._deck.side_of(mid) == 0 and with_card, "in the middle of a scroll, a bar moves with its card")
	var moved := absf((all[0] as Card).head.global_position.y - panel._scroll.global_position.y) < 1.0
	_ok(moved and panel._deck.side_of(all[0]) == -1 and panel._deck.side_of(all[n - 1]) == 1, "...with a pile above it and a pile below")
	# THE END: all but the last are in the top pile
	bar.value = bar.max_value
	await _settle()
	var high := true
	for i in n - 1:
		var card: Card = all[i]
		high = high and panel._deck.side_of(card) == -1 and absf(_bar_y(panel, card) - float(i) * close) < 1.0
	_ok(high, "scrolled to the end, the cards scrolled past have their bars in a pile at the top, in order")
	# NOTHING IS OUT OF REACH
	var rows := last.body.get_children()
	var below: float = panel._scroll.global_position.y + view
	_ok((rows[rows.size() - 1] as Control).get_global_rect().end.y <= below + 1.0, "...and its last row can be read")
	panel.free()
	await _settle(1)


## Whether [param card]'s title's whole line lies within the [param close] of its bar a pile shows (a descender's width to spare).
func _line_shows(card: Card, close: float) -> bool:
	var font := card._name.get_theme_font(&"font")
	var tall := font.get_height(card._name.get_theme_font_size(&"font_size"))
	var inside := card._name.global_position.y - card.head.global_position.y + (card._name.size.y - tall) * 0.5
	return inside + tall <= close + 2.5


## A TITLE SHOWS WHOLE IN A PILE
func _titles_show() -> void:
	var panel := SidePanel.new()
	add_child(panel)
	panel.detach = func(_key: String) -> void: pass
	var plain := panel.add_card("plain", "Plain", &"paper")
	var comp := panel.add_card("comp", "Component", &"voice", "voice")
	for box in [plain, comp]:
		var l := Label.new()
		l.text = "row"
		(box as VBoxContainer).add_child(l)
	await _settle()
	var all := _cards(panel)
	var close: float = panel._deck.peek()
	var bare: Card = all[0]
	var with_x: Card = all[1]
	var has_x := with_x.head.find_children("*", "Button", true, false).size() == 1
	_ok(has_x, "the control: a component's card has its × on its bar")
	_ok(absf(with_x.head.size.y - bare.head.size.y) < 0.5, "the × does not make its bar taller (%d and %d)" % [int(with_x.head.size.y), int(bare.head.size.y)])
	_ok(_line_shows(bare, close) and _line_shows(with_x, close), "a title's whole line shows in a pile's %d px" % int(close))
	var tall := Button.new()
	tall.custom_minimum_size.y = bare.head.size.y + 16.0
	bare.add_title_bar_control(tall)
	await _settle()
	_ok(not _line_shows(bare, close), "the control: a bar made taller by what is on it hides its title's line")
	panel.free()
	await _settle(1)


## FOLDED CARDS OVERLAP
func _folded_overlap() -> void:
	var panel := await _panel(4, 3)
	var line := Label.new()
	line.text = "a line that is no card"
	panel.body.add_child(line)
	var all := _cards(panel)
	for c in all:
		(c as Card).folded = true
	await _settle()
	var a: Card = all[0]
	var b: Card = all[1]
	_ok(a.head.get_global_rect().intersects(b.head.get_global_rect()), "a run of folded cards overlaps: a bar's foot under the next one's")
	_ok(absf(b.head.global_position.y - a.head.global_position.y - panel._deck.peek()) < 1.0, "...by their peek")
	_ok(not a.body.is_visible_in_tree(), "a folded card's body is not showing")
	var d: Card = all[3]
	_ok(not d.head.get_global_rect().intersects(line.get_global_rect().grow(-1.0)), "the control: over a line that is no card, a bar keeps its whole height")
	panel.free()
	await _settle(1)


## A PRESS
func _presses() -> void:
	var panel := await _panel(8, 40)
	var all := _cards(panel)
	var said := []
	var first: Card = all[0]
	first.folding_changed.connect(func(f: bool) -> void: said.append(f))
	first.folded = true
	_ok(said.is_empty(), "an assigned fold says nothing")
	first.folded = false
	_click(first)
	_ok(first.folded and said == [true], "a press on a bar where its card is folds it, and says so")
	_click(first)
	_ok(not first.folded and said == [true, false], "...and opens it again")
	await _settle(20)
	# A PILE'S OPEN CARD IS BROUGHT, NOT FOLDED
	var far: Card = all[5]
	_ok(panel._deck.side_of(far) == 1 and not far.folded, "the control: a later card is open, in the bottom pile")
	_click(far)
	await get_tree().create_timer(0.4).timeout
	await _settle()
	_ok(not far.folded, "a press on it in a pile does not fold it")
	_ok(panel._deck.side_of(far) == 0 and absf(far.head.global_position.y - far.global_position.y) < 1.0, "...it brings the card to view")
	# A PILE'S FOLDED CARD IS OPENED AND BROUGHT
	var last: Card = all[7]
	last.folded = true
	await _settle()
	_click(last)
	await get_tree().create_timer(0.4).timeout
	await _settle()
	_ok(not last.folded and panel._deck.side_of(last) == 0, "a press on a folded card in a pile opens it, and brings it")
	_ok(last.body.is_visible_in_tree() and last.body.get_global_rect().position.y < panel._scroll.global_position.y + panel._scroll.size.y,
		"...its body showing")
	# OPENED FROM ANYWHERE: another bar's fold, as a chip does
	var chip_card: Card = all[1]
	chip_card.folded = true
	await _settle()
	panel._scroll.get_v_scroll_bar().value = panel._scroll.get_v_scroll_bar().max_value
	await _settle()
	chip_card.expand()
	await get_tree().create_timer(0.4).timeout
	await _settle()
	_ok(panel._deck.side_of(chip_card) == 0, "a card opened from elsewhere comes into view")
	# THE WHEEL
	var bar := panel._scroll.get_v_scroll_bar()
	bar.value = 200.0
	await _settle()
	var was := bar.value
	_click(all[7], MOUSE_BUTTON_WHEEL_DOWN)
	_ok(bar.value > was, "the wheel over a bar scrolls the panel (%d to %d)" % [int(was), int(bar.value)])
	panel.free()
	await _settle(1)


## OPENING SLIDES
func _slides() -> void:
	var panel := await _panel(3, 4)
	var all := _cards(panel)
	var c: Card = all[0]
	var under: Card = all[1]
	var tall := c.size.y
	var from := under.global_position.y
	c.fold()
	await _settle(2)
	var mid := c.size.y
	_ok(c.folded and mid < tall - 0.5 and mid > c.head.size.y * 0.5, "folding slides: its height on the way is %d, of %d" % [int(mid), int(tall)])
	_ok(under.global_position.y < from - 0.5, "...and what is under it goes with it")
	await get_tree().create_timer(0.3).timeout
	await _settle()
	_ok(c.size.y <= c.head.size.y + 0.5 and not c.body.is_visible_in_tree(), "...to its bar")
	c.expand()
	await _settle(2)
	_ok(c.body.is_visible_in_tree() and c.size.y < tall - 0.5, "opening slides too")
	await get_tree().create_timer(0.3).timeout
	await _settle()
	_ok(absf(c.size.y - tall) < 1.0, "...back to its height")
	c.folded = true
	await _settle(2)
	_ok(c.size.y <= c.head.size.y + 0.5, "the control: an assigned fold is there at once")
	panel.free()
	await _settle(1)


## THE FAN
func _fan() -> void:
	var panel := await _panel(8, 40)
	var all := _cards(panel)
	var at: Card = all[4]
	var other: Card = all[6]
	var from := _bar_y(panel, at)
	var stays := _bar_y(panel, other)
	_ok(panel._deck.side_of(at) == 1, "the control: the card pointed at is in the pile")
	_point_at(at.head.global_position + Vector2(20.0, 3.0))
	await _settle(30)
	var hovered := get_viewport().gui_get_hovered_control()
	_ok(hovered == at.head or (hovered != null and at.head.is_ancestor_of(hovered)), "the pointer is on it (%s)" % str(hovered))
	_ok(_bar_y(panel, at) < from - 1.0, "pointing at a bar in a pile lifts it (%d to %d)" % [int(from), int(_bar_y(panel, at))])
	_ok(absf(_bar_y(panel, other) - stays) < 0.5, "the control: a bar that lies after it stays")
	var clear: float = (all[5] as Card).head.global_position.y - at.head.global_position.y
	_ok(clear >= at.head.size.y - 0.5, "...until its whole bar shows (%d of %d)" % [int(clear), int(at.head.size.y)])
	_point_at(Vector2(1000, 600))
	await _settle(30)
	_ok(absf(_bar_y(panel, at) - from) < 1.0, "the pointer gone, the pile closes")
	panel.free()
	await _settle(1)


## A SMALL WINDOW
func _sizes() -> void:
	_ok(is_equal_approx(PanelDeck.peek_for(8, 1000.0), PanelDeck.PEEK), "a large window holds the piles at their peek")
	var tight := PanelDeck.peek_for(8, 300.0)
	_ok(tight < PanelDeck.PEEK and tight >= PanelDeck.PEEK_LEAST, "a small one closes them up (%d px)" % int(tight))
	_ok(8.0 * tight + PanelDeck.BAR + PanelDeck.ROOM <= 300.0 + 0.5, "...leaving room for what is being read")
	_ok(is_equal_approx(PanelDeck.peek_for(8, 100.0), PanelDeck.PEEK_LEAST), "...and never past its least")


## A CARD FREED
func _freed() -> void:
	var panel := await _panel(3, 2)
	var card: Card = _cards(panel)[1]
	var bar := card.head
	_ok(is_instance_valid(bar), "the control: its bar is here")
	card.get_parent().remove_child(card)
	card.free()
	await _settle(2)
	_ok(not is_instance_valid(bar), "a card freed takes its bar along")
	_ok(panel.cards().size() == 2, "...and the panel carries on")
	panel.free()
	await _settle(1)
