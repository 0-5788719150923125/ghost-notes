extends PanelContainer
class_name SidePanel

## SidePanel - a mode's control panel, which CANNOT outgrow the window.
##
## THE BUG THIS EXISTS FOR. Both voice panels were a bare [PanelContainer] placed at a fixed
## corner with no height and no scroll, so the panel was exactly as tall as its contents - and
## a [Control] that is not inside a container is never asked to fit anything. Past about
## twenty rows the bottom of the panel was simply off the bottom of the window: not clipped,
## not scrollable, not resized. The controls down there existed, drew, saved and reloaded, and
## could not be reached at all.
##
## It fails by GROWING, which is why it went unnoticed for so long. Every row added is fine
## until one is not, and the one that breaks it is not the one at fault - the Look filters put
## six rows on a panel that was already at the edge, and what went off the bottom was the
## intro/outro holds that had been there for months.
##
## SO THE PANEL IS BOUND TO THE WINDOW, not to its contents: it takes the smaller of what it
## wants and what there is room for, and scrolls the difference. A panel that fits is
## unchanged - it does not stretch to fill the window - so this is only ever visible when it
## would otherwise have been broken.
##
## TWO SIGNALS KEEP IT TRUE, and both are needed. The window being resized is the obvious one.
## The other is the CONTENT changing height - a voice tab added, a film imported, a status
## line wrapping to three lines - which happens while the window never moves, and which a
## resize handler alone would miss until the next resize.
##
## Add rows to [member body], never to the panel: the panel's own child is the scroll view.
##
## A HEADER IS PINNED over the scrolling body ([method pin_header]): the panel's title row - "‹ Notes", its
## "⋯" and its "–" - stays in view however far the body is scrolled (asked 2026-10-07: "I have to keep
## scrolling to the top, to click those buttons"), and goes with the panel when it is hidden.
##
## A FOOTER CAN BE PINNED under the scrolling body ([method add_footer_card]): a card that stays in
## view however far the body is scrolled, taken off the room the body has. Masking's marker list
## lives there - "the whole manage-markers workflow stays visible together", as its own panel kept it.

## Distance from the window's edge, and the gap left at the bottom. The panel is placed here
## rather than by the caller so that "how much room is there" has one answer.
const MARGIN := 16.0
## Never collapse below this, however small the window gets. A panel scrolled down to nothing
## is not more usable than one that overflows.
const MIN_HEIGHT := 140.0
## Clear space kept to the right of the content, BESIDE the scrollbar rather than under it.
##
## A [ScrollContainer] lays its child out at the full width and draws the scrollbar ON TOP, so
## the right-hand end of every row is underneath it - which on this panel is where the value
## readouts sit, and they were being written over. Reported as "the vertical scroll bar on the
## left-side panel overwrites the label text in a lot of places".
##
## The gutter is held whether the bar is showing or not. Sizing it to the live bar would move
## every row sideways at the moment a row is added or the window is resized, which is a worse
## artifact than a few pixels of margin on a panel that happens to fit.
const GUTTER := 4.0

## THE CONTAINER TO FILL. Everything a panel shows goes in here.
var body: VBoxContainer
## The chips for this panel's cards, under its heading ([CardRow]); null until
## [method add_card_row] is called.
var card_row: CardRow
## The panel's own name in its cards' fold keys ("<prefix>.<card>", see [Card]). One per mode,
## so the Generative panel's Voice and the Cards panel's Voice fold separately.
var card_prefix := ""
## What the restore button says - the panel's own name, so it is clear what comes back.
var title := ""
## THE WAY BACK. Hiding the panel (its – button) left nothing on screen to bring it back but
## F2, which nobody knows: "if I minimize the left-side panel, there is no clear way to
## restore it". A small button in the corner the panel occupied, shown exactly while the
## panel is hidden. A SIBLING, not a child - a child would be hidden with the panel.
var _restore: Button

var _col: VBoxContainer
var _scroll: ScrollContainer
var _pad: MarginContainer
var _footer: VBoxContainer
var _head: VBoxContainer
var _head_pad: MarginContainer      # the header's own margin, matched to the body's (see _apply)
var _foot_pad: MarginContainer      # the footer's own margin, matched to the body's (see _apply)
## Controls already named for making the panel too wide (see [method _check_width]).
var _warned := {}


func _init(width := 380.0) -> void:
	position = Vector2(MARGIN, MARGIN)
	custom_minimum_size = Vector2(width, 0)
	_col = VBoxContainer.new()
	_col.add_theme_constant_override("separation", 6)
	add_child(_col)
	_scroll = ScrollContainer.new()
	# HORIZONTAL SCROLLING OFF, deliberately: with it on, the scroll view's minimum width
	# collapses and the panel narrows to nothing rather than staying as wide as its widest
	# row. Off, the width still comes from the content exactly as it did before.
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# Tabbing to a control below the fold scrolls to it rather than moving focus somewhere
	# invisible.
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


## What other furniture keeps clear of: the scrub bar starts to the right of an open panel.
const GROUP := &"side_panel"

const CardScript := preload("res://src/card.gd")
const CardRowScript := preload("res://src/card_row.gd")


## The chip row, added to [member body] where the panel is in its build - under the heading.
func add_card_row() -> CardRow:
	card_row = CardRowScript.new()
	body.add_child(card_row)
	return card_row


## A new card at the end of [member body], with a chip in [member card_row]; returns the card's
## body, which is where its rows go. [param key] names it in the stored fold.
func add_card(key: String, card_title: String, family: StringName) -> VBoxContainer:
	var card: Card = CardScript.new(("%s.%s" % [card_prefix, key]) if not card_prefix.is_empty() else "",
		card_title, family)
	body.add_child(card)
	if card_row != null:
		card_row.track(card)
	return card.body


## A card PINNED UNDER the scrolling body, with a chip in [member card_row]; returns the card's body.
## It stays in view however far the body is scrolled, and the body gets the room that is left.
func add_footer_card(key: String, card_title: String, family: StringName) -> VBoxContainer:
	var card: Card = CardScript.new(("%s.%s" % [card_prefix, key]) if not card_prefix.is_empty() else "",
		card_title, family)
	_footer.add_child(card)
	if not _foot_pad.visible:
		_foot_pad.visible = true
		_footer.minimum_size_changed.connect(_fit)
	if card_row != null:
		card_row.track(card)
	_fit()
	return card.body


## [param row] PINNED OVER the scrolling body (taken out of wherever it was): in view however far the body is
## scrolled, the body getting the room that is left. Rows pinned later go under the first.
func pin_header(row: Control) -> void:
	if row.get_parent() != null:
		row.get_parent().remove_child(row)
	_head.add_child(row)
	if not _head_pad.visible:
		_head_pad.visible = true
		_head.minimum_size_changed.connect(_fit)
	_fit()


## Every card on the panel, top to bottom, the pinned ones last.
func cards() -> Array:
	return (body.get_children() + _footer.get_children()).filter(func(c: Node) -> bool: return c is Card)


func _ready() -> void:
	add_to_group(GROUP)
	_restore = Button.new()
	_restore.text = ("▸  " + title) if not title.is_empty() else "▸"
	_restore.tooltip_text = "Show the panel again (F2)"
	_restore.focus_mode = Control.FOCUS_NONE
	_restore.position = position
	_restore.visible = not visible
	_restore.pressed.connect(func() -> void: visible = true)
	add_sibling.call_deferred(_restore)
	# The content's height, not just the window's - see the note at the top.
	body.minimum_size_changed.connect(_fit)
	get_viewport().size_changed.connect(_fit)
	_fit()
	# THE WHEEL SCROLLS THE PANEL, NEVER A SLIDER. Every slider already here, and every one a
	# mode adds later (a voice tab, a rebuilt section), is made drag-only.
	_no_wheel(self)
	get_tree().node_added.connect(func(n: Node) -> void:
		if is_ancestor_of(n):
			_no_wheel(n))


## A [Slider] takes the mouse wheel by default, so scrolling down a long panel dragged every
## knob the pointer passed over and silently changed it ("scrolling through the UI is
## constantly, accidentally scrolling values for options"). The wheel event is left unhandled,
## so it carries on up to the scroll view. A [SpinBox] only takes the wheel while it is being
## typed in, which is deliberate, so it is left alone.
static func _no_wheel(n: Node) -> void:
	if n is Slider:
		(n as Slider).scrollable = false
	for c in n.get_children():
		_no_wheel(c)


func _notification(what: int) -> void:
	# A panel built outside the tree and reparented later (which every gate does, and which
	# main does for the voice editors) gets its viewport here rather than in _init.
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		if _restore != null and is_instance_valid(_restore):
			_restore.visible = not visible
		if visible:
			_fit()


## Take the smaller of what the contents want and what the window has room for.
##
## DEFERRED, because it is reached from `minimum_size_changed` - which fires DURING the
## layout pass that is computing that minimum, and writing a size back into it from there is
## either ignored or re-entrant depending on where in the pass it lands.
func _fit() -> void:
	if not is_inside_tree():
		return
	_apply.call_deferred()


func _apply() -> void:
	if not is_inside_tree() or _scroll == null or not is_instance_valid(_scroll):
		return
	# The bar's own width, asked of the bar rather than guessed - a theme decides it, and a
	# hard-coded 12 is wrong the moment one is applied.
	var bar := _scroll.get_v_scroll_bar()
	var w: int = int(bar.get_combined_minimum_size().x + GUTTER) if bar != null else int(GUTTER)
	_pad.add_theme_constant_override("margin_right", w)
	_foot_pad.add_theme_constant_override("margin_right", w)     # the pinned cards line up with the body's
	_head_pad.add_theme_constant_override("margin_right", w)
	var room: float = get_viewport().get_visible_rect().size.y - position.y - MARGIN
	if _head_pad.visible:
		room -= _head_pad.get_combined_minimum_size().y + float(_col.get_theme_constant("separation"))
	if _foot_pad.visible:
		room -= _foot_pad.get_combined_minimum_size().y + float(_col.get_theme_constant("separation"))
	var want: float = _pad.get_combined_minimum_size().y
	# `want` when it fits, the room when it does not, and never below the floor. Taking the
	# minimum is what keeps a short panel short: this must not become a full-height sidebar
	# on a panel with four rows in it.
	_scroll.custom_minimum_size.y = maxf(minf(want, room), MIN_HEIGHT)
	# ...and shrink the panel itself onto that. A Control outside a container keeps whatever
	# size it was last given, so without this the panel stays at its old height and the scroll
	# view is laid out inside a box that is still too tall.
	size = get_combined_minimum_size()
	_check_width()


## THE WIDTH IS DECLARED, NOT GROWN INTO - but nothing enforces it: the panel is as wide as its
## widest row (horizontal scrolling is off, see [method _init]), so one control asking for more -
## an OptionButton sized to its longest item, a row of one control too many - pushes the whole
## panel out across the stage. Clipping it would hide that control instead, so the culprit is
## NAMED, once, and found from the log rather than by eye.
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
