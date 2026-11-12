extends PanelContainer
class_name SidePanel

## SidePanel - a mode's control panel, bound to the window rather than to its contents.
##
## It takes the smaller of what its contents want and what the window has room for, and scrolls the
## difference. A panel that fits is unchanged (it does not stretch to fill the window). Two signals keep
## it true: the window resizing, and the content changing height (a tab added, a status line wrapping).
##
## Add rows to [member body], never to the panel: the panel's own child is the scroll view.
##
## A header is pinned over the scrolling body ([method pin_header]): the panel's title row - "‹", "⋯"
## and "–" - stays in view however far the body is scrolled, and goes with the panel when it is hidden.
## A note's panel names no mode there ([method pin_title_row]).
##
## Its cards are a deck ([PanelDeck]; next/panel_deck.md): one scroll, and the title bars of the cards
## out of view lie in piles at the scroll's top and bottom, so every card is one click away.
##
## A footer can be pinned under the scrolling body ([method add_footer_card]): a card that stays in view
## however far the body is scrolled, taken off the room the body has (Masking's marker list).

## Distance from the window's edge, and the gap left at the bottom. The panel is placed here, so "how
## much room is there" has one answer.
const MARGIN := 16.0
## Never collapse below this, however small the window gets.
const MIN_HEIGHT := 140.0
## Clear space kept to the right of the content, beside the scrollbar rather than under it: a
## [ScrollContainer] lays its child out at full width and draws the bar on top, over the value
## readouts. Held whether the bar shows or not, so rows do not move sideways when the bar appears.
const GUTTER := 4.0

## The container to fill. Everything a panel shows goes in here.
var body: VBoxContainer
## The chips for this panel's cards, under its heading ([CardRow]); null until
## [method add_card_row] is called.
var card_row: CardRow
## The "+" before the chips ([method add_component_row]); null on a panel without one.
var plus: MenuButton
## The panel's own name in its cards' keys ("<prefix>.<card>", see [Card]).
var card_prefix := ""
## The panel's own name in the log ([method _check_width]) - never shown.
var title := ""
## How a component comes off the note: `(component: String) -> void`, set by a panel that shows a note
## before its cards are added - a card added with a component then carries an x that asks and calls
## it ([method add_card]). Unset, cards have none.
var detach := Callable()
## Why a component cannot be detached this moment: `(component: String) -> String`, "" when it can.
var detach_blocker := Callable()
var _detach_buttons: Array = []     # [Button, component, tooltip]
var _detach_t := 0.0
## The way back: a small "›" in the corner the panel occupied, shown while the panel is hidden (after
## a small "‹" home on a note's panel, [method pin_title_row]). A sibling, not a child, which would be
## hidden with the panel.
var _restore: HBoxContainer

var _col: VBoxContainer
var _scroll: ScrollContainer
var _pad: MarginContainer
var _footer: VBoxContainer
var _head: VBoxContainer
var _head_pad: MarginContainer      # the header's own margin, matched to the body's (see _apply)
var _foot_pad: MarginContainer      # the footer's own margin, matched to the body's (see _apply)
var _deck: PanelDeck                # the title bars of the body's cards
## Controls already named for making the panel too wide (see [method _check_width]).
var _warned := {}


func _init(width := 380.0) -> void:
	position = Vector2(MARGIN, MARGIN)
	custom_minimum_size = Vector2(width, 0)
	_col = VBoxContainer.new()
	_col.add_theme_constant_override("separation", 6)
	add_child(_col)
	_scroll = ScrollContainer.new()
	# Horizontal scrolling off: with it on, the scroll view's minimum width collapses and the panel
	# narrows to nothing rather than staying as wide as its widest row.
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# Tabbing to a control below the fold scrolls to it.
	_scroll.follow_focus = true
	_head_pad = MarginContainer.new()
	_head_pad.visible = false
	_col.add_child(_head_pad)
	_head = VBoxContainer.new()
	_head.add_theme_constant_override("separation", 6)
	_head_pad.add_child(_head)
	_col.add_child(_scroll)
	# The content sits inside a margin so the scrollbar has somewhere of its own to be.
	_pad = MarginContainer.new()
	_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_pad)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pad.add_child(body)
	_foot_pad = MarginContainer.new()
	_foot_pad.visible = false
	_col.add_child(_foot_pad)
	_footer = VBoxContainer.new()
	_footer.add_theme_constant_override("separation", 6)
	_foot_pad.add_child(_footer)
	_deck = PanelDeck.new(_scroll, body, room)
	add_child(_deck)


## What other furniture keeps clear of: the scrub bar starts to the right of an open panel.
const GROUP := Shell.PANELS

const CardScript := preload("res://src/ui/card.gd")
const CardRowScript := preload("res://src/ui/card_row.gd")


## The chip row, added to [member body] where the panel is in its build - under the heading.
func add_card_row() -> CardRow:
	card_row = CardRowScript.new()
	body.add_child(card_row)
	return card_row


## The component row: "+", then the chips ([CardRow]), under the heading. "+" offers what a note with
## [param attached] - `() -> Array`, asked as the menu opens - can take next
## ([method Components.attach_menu]: the impossible left out; the not-ready, the unmet and what there is
## no room for grayed with the reason), and hands the key of the one picked to [param attach].
func add_component_row(attached: Callable, attach: Callable) -> CardRow:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	body.add_child(row)
	plus = MenuButton.new()
	plus.text = "+"
	plus.flat = false
	plus.tooltip_text = ("Attach what this note should have next - each one grayed, with the reason, "
		+ "when it cannot be had yet.")
	plus.about_to_popup.connect(func() -> void:
		var pop := plus.get_popup()
		Components.attach_menu(pop, attached.call())
		if pop.item_count == 0:
			pop.add_item("Nothing else can be attached here")
			pop.set_item_metadata(0, "")
			pop.set_item_disabled(0, true))
	plus.get_popup().id_pressed.connect(func(id: int) -> void:
		var pop := plus.get_popup()
		var i := pop.get_item_index(id)
		if i >= 0 and not pop.is_item_disabled(i):
			attach.call(String(pop.get_item_metadata(i))))
	# drawn as a chip, the row's own shape (see CardRow._paint), in no family's color
	plus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	plus.add_theme_font_size_override("font_size", 13)
	var chip := StyleBoxFlat.new()
	chip.bg_color = Color(1, 1, 1, 0.08)
	chip.border_color = Color(1, 1, 1, 0.4)
	chip.set_border_width_all(1)
	chip.set_corner_radius_all(9)
	chip.content_margin_left = 9
	chip.content_margin_right = 9
	chip.content_margin_top = 0
	chip.content_margin_bottom = 1
	for st in ["normal", "hover", "pressed", "focus"]:
		plus.add_theme_stylebox_override(st, chip)
	row.add_child(plus)
	card_row = CardRowScript.new()
	card_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(card_row)
	return card_row


## A new card at the end of [member body], with a chip in [member card_row]; returns the card's body,
## where its rows go. [param key] names it on the panel. A component's card ([param component], its key
## in [constant Components.REGISTRY]) can be taken off the note from its title bar ([member detach]).
## [param about] is the title bar's and the chip's tooltip; when empty, a component's card says its
## row's blurb ([method Components.card_blurb]).
func add_card(key: String, card_title: String, family: StringName, component := "", about := "") -> VBoxContainer:
	var card: Card = CardScript.new(("%s.%s" % [card_prefix, key]) if not card_prefix.is_empty() else "",
		card_title, family)
	card.blurb = about if not about.is_empty() else Components.card_blurb(key, component)
	body.add_child(card)
	_deck.adopt(card)
	if card_row != null:
		card_row.track(card)
	if not component.is_empty() and detach.is_valid():
		_add_detach(card, component)
	return card.body


## The x on a component's card: asked first, its settings in the note go with it. Grayed, with the
## reason, while it cannot ([member detach_blocker]: a component another one brings stays with it).
func _add_detach(card: Card, component: String) -> void:
	var x := Button.new()
	x.text = "×"
	x.flat = true
	x.focus_mode = Control.FOCUS_NONE
	x.add_theme_font_size_override("font_size", 14)
	# No taller than the title beside it, or in a pile the next bar cuts through its words.
	var snug := StyleBoxEmpty.new()
	snug.content_margin_left = 4
	snug.content_margin_right = 4
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		x.add_theme_stylebox_override(st, snug)
	var label := String((Components.REGISTRY.get(component, {"label": card.title}) as Dictionary)["label"])
	var tip := "Detach %s from this note. Its settings here are removed with it." % label
	x.tooltip_text = tip
	x.pressed.connect(func() -> void:
		if x.disabled:
			return
		var ask := ConfirmationDialog.new()
		ask.title = "Detach %s?" % label
		ask.dialog_autowrap = true
		ask.dialog_text = ("%s comes off this note, and its settings in the note are removed. "
			+ "The note's words, and everything else attached, stay as they are.") % label
		ask.ok_button_text = "Detach"
		ask.confirmed.connect(func() -> void:
			ask.queue_free()
			detach.call(component))
		ask.canceled.connect(ask.queue_free)
		add_sibling(ask)
		ask.popup_centered(Vector2i(480, 0)))
	card.add_title_bar_control(x)
	_detach_buttons.append([x, component, tip])


## A card pinned under the scrolling body, with a chip in [member card_row]; returns the card's body.
## It stays in view however far the body is scrolled. [param about] as [method add_card]'s.
func add_footer_card(key: String, card_title: String, family: StringName, about := "") -> VBoxContainer:
	var card: Card = CardScript.new(("%s.%s" % [card_prefix, key]) if not card_prefix.is_empty() else "",
		card_title, family)
	card.blurb = about if not about.is_empty() else Components.card_blurb(key)
	_footer.add_child(card)
	if not _foot_pad.visible:
		_foot_pad.visible = true
		_footer.minimum_size_changed.connect(_fit)
	if card_row != null:
		card_row.track(card)
	_fit()
	return card.body


## [param row] pinned over the scrolling body (taken out of wherever it was). Rows pinned later go
## under the first.
func pin_header(row: Control) -> void:
	if row.get_parent() != null:
		row.get_parent().remove_child(row)
	_head.add_child(row)
	if not _head_pad.visible:
		_head_pad.visible = true
		_head.minimum_size_changed.connect(_fit)
	_fit()


## The title row of a note's panel, pinned ([method pin_header]): "‹" at its left, "⋯" and - where
## [param hides] - "–" at its right, and no name between them. Hidden, the panel leaves a small "‹"
## before its "›", one style; the "‹" is the same button shown or hidden ([method Shell.back_button]).
## [param owner] is the panel's mode, which [Shell] is asked through.
func pin_title_row(owner: Node, hides := true) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(Shell.back_button(owner))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(gap)
	row.add_child(Shell.note_menu(owner))
	if hides:
		var hide := Button.new()
		hide.text = "–"
		hide.tooltip_text = "Hide panel (F2)"
		hide.focus_mode = Control.FOCUS_NONE
		hide.custom_minimum_size = Vector2(28, 28)
		hide.pressed.connect(func() -> void: visible = false)
		row.add_child(hide)
	var home := Shell.back_button(owner)
	_corner().add_child(home)
	_corner().move_child(home, 0)
	pin_header(row)
	return row


## The corner the panel leaves when hidden ([member _restore]), made the first time it is asked for.
func _corner() -> HBoxContainer:
	if _restore == null:
		_restore = HBoxContainer.new()
		_restore.add_theme_constant_override("separation", 4)
		var open := Button.new()
		open.text = "›"
		open.tooltip_text = "Show the panel again (F2)"
		open.focus_mode = Control.FOCUS_NONE
		open.custom_minimum_size = Vector2(28, 28)
		open.pressed.connect(func() -> void: visible = true)
		_restore.add_child(open)
		# it fades with the rest of the furniture while a show plays alone ([constant Shell.FADES])
		_restore.add_to_group(Shell.FADES)
	return _restore


## Every card standing on the panel, top to bottom, a pinned one last - not one it has hidden (a Pipeline card with
## nothing to list), which has no chip either.
func cards() -> Array:
	return (body.get_children() + _footer.get_children()).filter(func(c: Node) -> bool: return c is Card and (c as Card).visible)


func _ready() -> void:
	add_to_group(GROUP)
	var corner := _corner()
	corner.position = position
	corner.visible = not visible
	add_sibling.call_deferred(corner)
	# The content's height, not just the window's - see the note at the top.
	body.minimum_size_changed.connect(_fit)
	_scroll.get_v_scroll_bar().visibility_changed.connect(_fit)
	get_viewport().size_changed.connect(_fit)
	_fit()
	# The wheel scrolls the panel, never a slider: every slider made here is drag-only.
	_no_wheel(self)
	get_tree().node_added.connect(func(n: Node) -> void:
		if is_ancestor_of(n):
			_no_wheel(n))


func _process(delta: float) -> void:
	# whether a component can come off follows what else is attached; twice a second is plenty
	if _detach_buttons.is_empty():
		return
	_detach_t -= delta
	if _detach_t > 0.0:
		return
	_detach_t = 0.5
	for row in _detach_buttons:
		var x: Button = row[0]
		if not is_instance_valid(x):
			continue
		var why := String(detach_blocker.call(String(row[1]))) if detach_blocker.is_valid() else ""
		x.disabled = not why.is_empty()
		x.tooltip_text = why if not why.is_empty() else String(row[2])


## A [Slider] takes the mouse wheel by default, so scrolling a long panel would drag every knob under
## the pointer. The wheel event is left unhandled and carries on up to the scroll view. A [SpinBox]
## only takes the wheel while being typed in, so it is left alone.
static func _no_wheel(n: Node) -> void:
	if n is Slider:
		(n as Slider).scrollable = false
	for c in n.get_children():
		_no_wheel(c)


func _notification(what: int) -> void:
	# A panel built outside the tree and reparented later (every gate) gets its viewport here.
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		if _restore != null and is_instance_valid(_restore):
			_restore.visible = not visible
		if visible:
			_fit()


## Take the smaller of what the contents want and what the window has room for. Deferred: it is reached
## from `minimum_size_changed`, which fires during the layout pass computing that minimum.
func _fit() -> void:
	if not is_inside_tree():
		return
	_apply.call_deferred()


## The most the scroll view can be: the window, less the panel's place, its header and its footer.
func room() -> float:
	var left: float = get_viewport().get_visible_rect().size.y - position.y - MARGIN
	if _head_pad.visible:
		left -= _head_pad.get_combined_minimum_size().y + float(_col.get_theme_constant("separation"))
	if _foot_pad.visible:
		left -= _foot_pad.get_combined_minimum_size().y + float(_col.get_theme_constant("separation"))
	return left


func _apply() -> void:
	if not is_inside_tree() or _scroll == null or not is_instance_valid(_scroll):
		return
	# The bar's own width, asked of the bar (a theme decides it).
	var bar := _scroll.get_v_scroll_bar()
	var w: int = int(bar.get_combined_minimum_size().x + GUTTER) if bar != null else int(GUTTER)
	_pad.add_theme_constant_override("margin_right", w)
	# The pinned cards line up with the body's: while its bar shows, the scroll view gives the body that much less.
	var beside: int = int(bar.size.x) if bar != null and bar.visible else 0
	_foot_pad.add_theme_constant_override("margin_right", w + beside)
	_head_pad.add_theme_constant_override("margin_right", w)
	var want: float = _pad.get_combined_minimum_size().y
	# `want` when it fits, the room when it does not, never below the floor: a short panel stays short.
	_scroll.custom_minimum_size.y = maxf(minf(want, room()), MIN_HEIGHT)
	# Then shrink the panel itself onto that: a Control outside a container keeps the size it was last given.
	size = get_combined_minimum_size()
	_check_width()


## The width is declared, not enforced: the panel is as wide as its widest row (horizontal scrolling is
## off, see [method _init]), so one control asking for more pushes the whole panel out across the stage.
## The culprit is named once in the log.
func _check_width() -> void:
	if get_combined_minimum_size().x <= custom_minimum_size.x + 0.5:
		return
	for c in overwide(self):
		var key := str((c as Control).get_path())
		if _warned.has(key):
			continue
		_warned[key] = true
		push_warning("ghost: the %s panel is %d px wide, not %d - %s asks for %d px" % [
			title if not title.is_empty() else "side", int(get_combined_minimum_size().x),
			int(custom_minimum_size.x), describe(c as Control), int((c as Control).get_combined_minimum_size().x)])


## The controls that make [param panel] wider than it was declared: the innermost visible ones
## asking for more than the room inside it (a row whose controls only add up to too much is
## itself the culprit). Empty when the panel fits.
static func overwide(panel: SidePanel) -> Array:
	var chrome := panel.get_combined_minimum_size().x - panel.body.get_combined_minimum_size().x
	var room := panel.custom_minimum_size.x - chrome
	var out: Array = []
	_collect_overwide(panel.body, room, out)
	return out


## Adds the innermost too-wide controls under [param n] to [param out]; true when it added any.
static func _collect_overwide(n: Control, room: float, out: Array) -> bool:
	var inner := false
	for c in n.get_children():
		var k := c as Control
		if k != null and k.visible and k.get_combined_minimum_size().x > room + 0.5:
			inner = _collect_overwide(k, room, out) or inner
	if inner or n.get_combined_minimum_size().x <= room + 0.5:
		return inner
	out.append(n)
	return true


## A control as a log line can name it: its class, and the first words on it or inside it.
static func describe(c: Control) -> String:
	var words := PackedStringArray()
	for n in [c] + c.find_children("*", "Control", true, false):
		var t := ""
		if n is Label:
			t = (n as Label).text
		elif n is Button:
			t = (n as Button).text
		if not t.strip_edges().is_empty():
			words.append("'%s'" % t.strip_edges().substr(0, 40))
		if words.size() >= 4:
			break
	return "%s %s" % [c.get_class(), " ".join(words)]
