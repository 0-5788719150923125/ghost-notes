extends Node

## panel_deck_check - a side panel's cards as a deck ([PanelDeck]; next/panel_deck.md).
##
##   tests/run_boot_probe.sh tests/ui/panel_deck_check.gd 120
##
## - The piles: with more than fits, the bars of the cards below the view lie at its foot and those scrolled past at its top, in
##   order, each showing, all inside the view, the last whole (control: a panel that fits has no pile, every bar over its card,
##   and a bar in the middle of a scroll moves with its card).
## - A bar is the card's own: what is on it works from a pile, and the pointer finds it there rather than what scrolls under it
##   (control: off the bars, the pointer finds what scrolls).
## - A title shows whole in a pile, on a component's card too, whose x must not make its bar taller and push the title under the
##   next bar (control: a bar made taller by what is on it does hide its title's line).
## - A press brings its card into view whole, wherever its bar lies: one cut off by the bottom pile comes up until its foot
##   clears it, one in the bottom pile comes whole, one in the top pile comes under the bars above it, and one taller than the
##   room comes with its bar there (control: a card already whole in view stays where it is, and a press never folds it). A
##   chip's press brings its card as a bar's does. The wheel over a bar scrolls.
## - The fan: pointing at a bar in a pile moves those on it off it (control: a bar the other side of it stays).
## - A view at the end stays there as what is in the cards grows, in the last card or above it, a list built again and a list
##   gone shorter too, and a panel that fits follows its last card past the window's foot (controls: a view at the top, or
##   short of the end, stays where it is; the wheel lets go of the end; a panel that fits does not follow a card above its
##   last, or a new card; a card a press brings is never dragged back to the end, and one pressed where it stands whole
##   keeps its bar under the pointer).
## - A small window closes the piles up, and a large one holds them at their peek. A card freed takes its bar along.

var _fails: Array = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	get_tree().root.size = Vector2i(1280, 720)
	await _fits()
	await _piles()
	await _titles_show()
	await _presses()
	await _fan()
	await _keeps_the_end()
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


## A panel in the tree with [param count] cards, each [param rows] rows tall.
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


## A panel that fits has no pile
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


## The piles
func _piles() -> void:
	var panel := await _panel(8, 40)
	var all := _cards(panel)
	var n := all.size()
	# The last bar taller than the rest, as the Pipeline's is: the one before it must show as much as any
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
	# The pointer finds a bar in a pile, off it what scrolls
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
	# The middle: a bar in the middle of the scroll moves with its card
	var mid: Card = all[3]
	bar.value = mid.position.y + panel.body.position.y - 3.0 * close - 100.0
	await _settle()
	var with_card := absf(mid.head.global_position.y - mid.global_position.y) < 1.0
	_ok(panel._deck.side_of(mid) == 0 and with_card, "in the middle of a scroll, a bar moves with its card")
	var moved := absf((all[0] as Card).head.global_position.y - panel._scroll.global_position.y) < 1.0
	_ok(moved and panel._deck.side_of(all[0]) == -1 and panel._deck.side_of(all[n - 1]) == 1, "...with a pile above it and a pile below")
	# The end: all but the last are in the top pile
	bar.value = bar.max_value
	await _settle()
	var high := true
	for i in n - 1:
		var card: Card = all[i]
		high = high and panel._deck.side_of(card) == -1 and absf(_bar_y(panel, card) - float(i) * close) < 1.0
	_ok(high, "scrolled to the end, the cards scrolled past have their bars in a pile at the top, in order")
	# Nothing is out of reach
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


## A title shows whole in a pile
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


## Whether [param card]'s foot lies above the bars of the bottom pile, or on them.
func _clears_pile(panel: SidePanel, card: Card) -> bool:
	var all := _cards(panel)
	var i := all.find(card)
	var foot := card.global_position.y + card.size.y
	if i + 1 < all.size():
		return foot <= (all[i + 1] as Card).head.global_position.y + 1.0
	return foot <= panel._scroll.global_position.y + panel._scroll.size.y + 1.0


## Lets a glide run out.
func _glided() -> void:
	await get_tree().create_timer(0.4).timeout
	await _settle()


## A press
func _presses() -> void:
	# A card whole in view stays where it is, and is never folded
	var panel := await _panel(3, 4)
	var first: Card = _cards(panel)[0]
	var tall := first.size.y
	var y := first.head.global_position.y
	_ok(first.body.is_visible_in_tree() and tall > first.head.size.y + 50.0, "the control: a card whole in view, its rows showing")
	_click(first)
	await _glided()
	_ok(first.body.is_visible_in_tree() and absf(first.size.y - tall) < 0.5, "a press on its bar never folds it")
	_ok(absf(first.head.global_position.y - y) < 0.5, "...and it stays where it is")
	# Cards shorter than the view, more of them than fit: each about 0.6 of it (a row and its gap are 32 px), so the second stands
	# in view with its foot under the bottom pile, whatever the window makes of the view
	var room := panel.room()
	panel.free()
	await _settle(1)
	panel = await _panel(8, int(room * 0.6 / 32.0))
	var all := _cards(panel)
	var bar := panel._scroll.get_v_scroll_bar()
	var cut: Card = all[1]
	var from := _bar_y(panel, cut)
	_ok(panel._deck.side_of(cut) == 0 and not _clears_pile(panel, cut), "the control: a card in view, its foot under the bottom pile")
	_click(cut)
	await _glided()
	_ok(panel._deck.side_of(cut) == 0 and _clears_pile(panel, cut) and _bar_y(panel, cut) < from - 1.0,
		"a press brings it up until it shows whole (%d to %d)" % [int(from), int(_bar_y(panel, cut))])
	var far: Card = all[5]
	_ok(panel._deck.side_of(far) == 1, "the control: a later card in the bottom pile")
	_click(far)
	await _glided()
	_ok(panel._deck.side_of(far) == 0 and _clears_pile(panel, far), "a press on it in the pile brings it, whole")
	bar.value = bar.max_value
	await _settle()
	var high: Card = all[2]
	_ok(panel._deck.side_of(high) == -1, "the control: scrolled to the end, an earlier card in the top pile")
	_click(high)
	await _glided()
	_ok(panel._deck.side_of(high) == 0 and absf(_bar_y(panel, high) - 2.0 * panel._deck.peek()) < 1.0 and _clears_pile(panel, high),
		"a press on it in the pile brings it, its bar under the bars above it, whole")
	# A chip's press
	var chips := CardRow.new()
	add_child(chips)
	chips.track(all[6])
	bar.value = 0.0
	await _settle()
	_ok(panel._deck.side_of(all[6]) == 1, "the control: at the top, a card in the bottom pile")
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	(chips._chips[all[6]] as Button).gui_input.emit(ev)
	await _glided()
	_ok(panel._deck.side_of(all[6]) == 0 and _clears_pile(panel, all[6]), "a press on its chip brings it, whole")
	chips.free()
	panel.free()
	await _settle(1)
	# A card taller than the room comes with its bar under the bars above it
	panel = await _panel(8, 40)
	all = _cards(panel)
	far = all[5]
	_ok(panel._deck.side_of(far) == 1 and far.size.y > panel._scroll.size.y, "the control: a card taller than the view, in the bottom pile")
	_click(far)
	await _glided()
	_ok(panel._deck.side_of(far) == 0 and absf(_bar_y(panel, far) - 5.0 * panel._deck.peek()) < 1.0,
		"a press brings it, its bar under the bars above it and its start showing")
	# The wheel
	bar = panel._scroll.get_v_scroll_bar()
	bar.value = 200.0
	await _settle()
	var was := bar.value
	_click(all[7], MOUSE_BUTTON_WHEEL_DOWN)
	_ok(bar.value > was, "the wheel over a bar scrolls the panel (%d to %d)" % [int(was), int(bar.value)])
	panel.free()
	await _settle(1)


## The fan
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


## [param count] more rows on [param card], as a list's growing does.
func _grow(card: Card, count: int) -> void:
	for r in count:
		var l := Label.new()
		l.text = "more"
		l.custom_minimum_size.y = 24.0
		card.body.add_child(l)


func _at_end(panel: SidePanel) -> bool:
	var bar := panel._scroll.get_v_scroll_bar()
	return bar.value >= bar.max_value - bar.page - 1.0


## Whether [param card]'s last row can be read.
func _foot_shows(panel: SidePanel, card: Card) -> bool:
	var rows := card.body.get_children()
	var below: float = panel._scroll.global_position.y + panel._scroll.size.y
	return (rows[rows.size() - 1] as Control).get_global_rect().end.y <= below + 1.0


## A view at the end stays there
func _keeps_the_end() -> void:
	var panel := await _panel(8, 40)
	var all := _cards(panel)
	var last: Card = all[7]
	var bar := panel._scroll.get_v_scroll_bar()
	_ok(bar.value == 0.0 and not _at_end(panel), "the control: a panel opens at its top, with more to scroll")
	_grow(last, 6)
	await _settle(2)
	_ok(bar.value == 0.0, "the control: a view at the top stays there as the last card grows")
	bar.value = bar.max_value - bar.page - 40.0
	await _settle(2)
	var short := bar.value
	_grow(last, 6)
	await _settle(2)
	_ok(is_equal_approx(bar.value, short), "the control: a view 40 px short of the end stays where it is")
	bar.value = bar.max_value
	await _settle(2)
	var was := bar.value
	_grow(last, 6)
	await _settle(2)
	_ok(bar.value > was + 100.0 and _at_end(panel) and _foot_shows(panel, last),
		"at the end, rows added to the last card: it stays at the end, its new last row in sight (%d to %d)" % [int(was), int(bar.value)])
	was = bar.value
	_grow(all[2], 6)
	await _settle(2)
	_ok(bar.value > was + 100.0 and _at_end(panel) and _foot_shows(panel, last), "...and rows added to a card above it")
	# The list built again, longer: what it had freed, and more, in one frame
	var rows := last.body.get_children()
	for r in rows.slice(rows.size() - 4):
		last.body.remove_child(r)
		r.queue_free()
	_grow(last, 10)
	await _settle(2)
	_ok(_at_end(panel) and _foot_shows(panel, last), "...and a list built again, longer")
	# Shorter, then longer, frames apart
	rows = last.body.get_children()
	for r in rows.slice(rows.size() - 10):
		last.body.remove_child(r)
		r.queue_free()
	await _settle(2)
	_ok(_at_end(panel), "a list grown shorter leaves it at the end")
	_grow(last, 12)
	await _settle(2)
	_ok(_at_end(panel) and _foot_shows(panel, last), "...and it follows the list longer again")
	# The wheel lets go
	_click(last, MOUSE_BUTTON_WHEEL_UP)
	await _settle(2)
	var away := bar.value
	_ok(not _at_end(panel), "the control: the wheel takes it from the end")
	_grow(last, 6)
	await _settle(2)
	_ok(is_equal_approx(bar.value, away), "...and from there it is left where it is")
	# A card a press brings is not dragged back to the end
	var above: Card = all[1]
	bar.value = bar.max_value
	await _settle(2)
	_ok(panel._deck.side_of(above) == -1 and _at_end(panel), "the control: at the end, an earlier card lies in the top pile")
	_click(above)
	await _glided()
	_ok(panel._deck.side_of(above) == 0 and not _at_end(panel), "a press brings it, and the view is not dragged back to the end")
	# ...and the last card itself, long, shows its bar and its first rows, not its foot
	bar.value = bar.max_value
	await _settle(2)
	_ok(_at_end(panel) and panel._deck.side_of(last) == -1, "the control: at the end, the long last card's bar lies in the top pile")
	_click(last)
	await _glided()
	_ok(panel._deck.side_of(last) == 0 and not _at_end(panel), "a press on the last card's bar shows its start, not its foot")
	panel.free()
	await _settle(1)
	# A short card whole where it stands: nothing has to bring it, so nothing takes the view from the end, and its bar stays under the pointer
	panel = await _panel(2, 40)
	for key in ["short", "foot"]:
		var box := panel.add_card(key, key, &"paper")
		for r in (3 if key == "short" else 14):
			var l := Label.new()
			l.custom_minimum_size.y = 24.0
			box.add_child(l)
	await _settle()
	all = _cards(panel)
	var short_card: Card = all[2]
	bar = panel._scroll.get_v_scroll_bar()
	bar.value = bar.max_value
	await _settle(2)
	var bar_y := _bar_y(panel, short_card)
	_ok(panel._deck.side_of(short_card) == 0 and _clears_pile(panel, short_card) and _at_end(panel),
		"the control: at the end, a short card lies whole where it is, in no pile")
	_click(short_card)
	await _glided()
	_ok(absf(_bar_y(panel, short_card) - bar_y) < 1.0 and _at_end(panel),
		"a press leaves its bar under the pointer and the view at the end (%d to %d)" % [int(bar_y), int(_bar_y(panel, short_card))])
	panel.free()
	await _settle(1)
	# A panel that fits follows its last card past the window's foot
	panel = await _panel(3, 2)
	all = _cards(panel)
	bar = panel._scroll.get_v_scroll_bar()
	_ok(bar.max_value - bar.page < 1.0, "the control: a panel that fits has nothing to scroll")
	_grow(all[2], 60)
	await _settle(4)
	_ok(bar.value > 0.0 and _at_end(panel) and _foot_shows(panel, all[2]), "a panel that fits, its last card grown past the window: it follows (%d)" % int(bar.value))
	panel.free()
	await _settle(1)
	# ...and nothing else
	panel = await _panel(3, 2)
	all = _cards(panel)
	bar = panel._scroll.get_v_scroll_bar()
	_grow(all[0], 60)
	await _settle(4)
	_ok(bar.value == 0.0 and bar.max_value - bar.page > 100.0, "the control: its first card grown past the window, it stays at the top")
	panel.free()
	await _settle(1)
	panel = await _panel(2, 2)
	bar = panel._scroll.get_v_scroll_bar()
	var new_box := panel.add_card("new", "New", &"paper")
	for r in 60:
		var l := Label.new()
		l.custom_minimum_size.y = 24.0
		new_box.add_child(l)
	await _settle(4)
	_ok(bar.value == 0.0 and bar.max_value - bar.page > 100.0, "the control: a new card past the window's foot does not move it")
	panel.free()
	await _settle(1)


## A small window
func _sizes() -> void:
	_ok(is_equal_approx(PanelDeck.peek_for(8, 1000.0), PanelDeck.PEEK), "a large window holds the piles at their peek")
	var tight := PanelDeck.peek_for(8, 300.0)
	_ok(tight < PanelDeck.PEEK and tight >= PanelDeck.PEEK_LEAST, "a small one closes them up (%d px)" % int(tight))
	_ok(8.0 * tight + PanelDeck.BAR + PanelDeck.ROOM <= 300.0 + 0.5, "...leaving room for what is being read")
	_ok(is_equal_approx(PanelDeck.peek_for(8, 100.0), PanelDeck.PEEK_LEAST), "...and never past its least")


## A card freed
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
