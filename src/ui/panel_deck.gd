extends Control
class_name PanelDeck

## PanelDeck - a side panel's cards as a deck (next/panel_deck.md).
##
## One scroll, and every card one click away. A card scrolled past leaves its title bar in a pile at
## the top of the panel, one still to come has its bar in a pile at the bottom, each bar's top
## [constant PEEK] showing, so the way to any card is in sight wherever the list is scrolled. A panel
## that fits has no pile.
##
## The bars are one layer, over the scroll, in the order of the cards: a later one lies on an earlier
## one, and all of them on whatever is scrolling. Each is the card's own [member Card.head], never a
## copy, so what is on it (the Pipeline's Generate, a card's x) works from a pile. A card keeps the
## room for its bar in the scroll, and the bar is put over it ([method _place]): where the card is,
## held inside the piles.
##
## A press on a bar brings its card into view whole, wherever the bar lies, or its start where it is
## taller than the view ([method reveal]); a chip's press does the same ([method Card.reveal]). A card
## never folds. The fan: pointing at a bar in a pile spreads the pile there, so the whole bar shows.
##
## A view at the end stays there: what grows while the view is at the end of the scroll keeps it at the
## end ([method _on_length]), and a turn of the wheel lets go. A panel that fits is at its end only
## trivially, so it follows its last card alone.

## How much of each bar in a pile shows, at most: a title's whole line, the foot of the bar under the next one's.
const PEEK := 21.0
## ...and at the least, in a window too small to give each that.
const PEEK_LEAST := 5.0
## What a pile leaves for what is being read: the piles close up before they take this.
const ROOM := 200.0
## A bar's height, for working out how close the piles must lie.
const BAR := 30.0
## How long bringing a card into view takes, seconds.
const GLIDE := 0.22
## How quickly a pile fans, per second.
const FAN := 18.0
## How near the end of the scroll counts as at it, px.
const AT_END := 1.0

var _scroll: ScrollContainer
var _body: VBoxContainer
var _room: Callable                 # () -> float: the most the panel's scroll view can be
var _clip: Control                  # the bars' layer: exactly over the scroll view
var _glider: Tween
var _sides := {}                    # Card -> -1 in the top pile, 1 in the bottom one, 0 where it is
var _lift := {}                     # Card -> how far the fan has moved its bar
var _above := 0.0                   # how far down the top pile covers what scrolls
var _below := 0.0                   # ...and where the bottom one begins
var _at_end := true                 # whether the view stands at the end of what scrolls
var _end := 0.0                     # the furthest it could scroll, at the last look
var _last_id := 0                   # the last card, by id, at the last look: it may have been freed since
var _last_tall := 0.0               # ...and its height then


## Over [param scroll], whose content holds [param body]; [param room] says the most the scroll view can be, however much is
## in it (not how tall it is now: a pile's closeness must not change the height it is worked out from).
func _init(scroll: ScrollContainer, body: VBoxContainer, room: Callable) -> void:
	_scroll = scroll
	_body = body
	_room = room
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clip = Control.new()
	_clip.clip_contents = true
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_clip)


## Takes [param card]'s bar onto the layer: from here on it is put where it should lie, and its presses are the deck's.
func adopt(card: Card) -> void:
	var bar := card.head
	if bar.get_parent() != null:
		bar.get_parent().remove_child(bar)
	_clip.add_child(bar)
	bar.gui_input.connect(_on_head.bind(card))
	card.reveal_asked.connect(reveal.bind(card))
	card.visibility_changed.connect(_place)


func _ready() -> void:
	var bar := _scroll.get_v_scroll_bar()
	bar.value_changed.connect(func(_v: float) -> void:
		_at_end = bar.value >= bar.max_value - bar.page - AT_END
		_place())
	bar.changed.connect(_on_length)
	_body.sort_children.connect(_place)
	_scroll.sort_children.connect(_place)
	_scroll.gui_input.connect(func(ev: InputEvent) -> void:
		if _is_wheel(ev):
			_stop_glide())
	get_viewport().gui_focus_changed.connect(func(c: Control) -> void:
		if c != null and _body.is_ancestor_of(c):
			_keep_in_view.call_deferred(c))
	_place()


func _process(delta: float) -> void:
	if is_visible_in_tree():
		_place(delta)


## How much of each of [param count] bars a pile shows, in a scroll view of at most [param room]: all of them, and
## [constant ROOM] besides, fit between the piles while they can.
static func peek_for(count: int, room: float) -> float:
	if count <= 0:
		return PEEK
	return clampf((room - BAR - ROOM) / float(count), PEEK_LEAST, PEEK)


## Where bar [param i] of [param n] lies in the top pile.
static func top_spot(i: int, peek: float) -> float:
	return float(i) * peek


## Where bar [param i] of [param n] lies in the bottom pile of a view [param view] high: the last, [param last_tall] high, whole on
## its foot, and each one before it showing [param peek], whatever its own height (the Pipeline's bar is taller than a title's).
static func bottom_spot(i: int, n: int, view: float, peek: float, last_tall: float) -> float:
	return view - last_tall - float(n - 1 - i) * peek


## The cards standing now, top to bottom.
func cards() -> Array:
	return _body.get_children().filter(func(c: Node) -> bool: return c is Card and (c as Card).visible)


## Whether [param card]'s bar lies in a pile: -1 the top one, 1 the bottom one, 0 not.
func side_of(card: Card) -> int:
	return int(_sides.get(card, 0))


## How much of each bar a pile shows now.
func peek() -> float:
	return peek_for(cards().size(), float(_room.call()) if is_inside_tree() else INF)


## Where [param card]'s top is in the scroll view, whatever covers it.
func _natural(card: Card) -> float:
	return _body.position.y + card.position.y - _scroll.get_v_scroll_bar().value


## Every bar where it should lie: over its card, held inside the piles. [param delta] moves the fan on.
func _place(delta := 0.0) -> void:
	if not is_inside_tree():
		return
	_clip.position = _scroll.global_position - global_position
	_clip.size = _scroll.size
	for c in _body.get_children():
		if c is Card:
			(c as Card).head.visible = (c as Card).visible
	var shown := cards()
	var n := shown.size()
	var close := peek_for(n, float(_room.call()))
	var view := _scroll.size.y
	var ys: Array = []
	_sides = {}
	var last_tall: float = (shown[n - 1] as Card).head.get_combined_minimum_size().y if n > 0 else 0.0
	for i in n:
		var card: Card = shown[i]
		var at := _natural(card)
		var top := top_spot(i, close)
		var bottom := bottom_spot(i, n, view, close, last_tall)
		var side := -1 if at < top else (1 if at > bottom else 0)
		_sides[card] = side
		ys.append(top if side < 0 else (bottom if side > 0 else at))
	_fan(shown, delta, close)
	_above = 0.0
	_below = view
	var left := _body.position.x
	for i in n:
		var card: Card = shown[i]
		var bar := card.head
		if bar.get_index() != i:
			_clip.move_child(bar, i)
		var tall := bar.get_combined_minimum_size().y
		var y: float = ys[i] + float(_lift.get(card, 0.0))
		var spot := Vector2(left + card.position.x, y)
		if bar.position != spot:
			bar.position = spot
		var wide := Vector2(card.size.x, tall)
		if bar.size != wide:
			bar.size = wide
		if _sides[card] < 0:
			_above = maxf(_above, y + tall)
		elif _sides[card] > 0:
			_below = minf(_below, y)


## The fan: the bar pointed at in a pile shows whole, the bars that lie on it moved off it. Eased; a pile not pointed at closes.
func _fan(shown: Array, delta: float, close: float) -> void:
	var at := shown.find(_pointed_at())
	var side: int = _sides[shown[at]] if at >= 0 else 0
	for i in shown.size():
		var card: Card = shown[i]
		var want := 0.0
		if side != 0 and at < shown.size() - 1 and _sides[card] == side:
			# to the bar's whole height and no further: past it, what scrolls would show between two bars
			var spread := maxf(0.0, (shown[at] as Card).head.size.y - close)
			if side < 0 and i > at:
				want = spread
			elif side > 0 and i <= at:
				want = -spread
		var now := float(_lift.get(card, 0.0))
		if delta > 0.0 and now != want:
			now = lerpf(now, want, 1.0 - exp(-FAN * delta))
			if absf(now - want) < 0.25:
				now = want
			_lift[card] = now


## The card whose bar the pointer is on, null for none.
func _pointed_at() -> Card:
	var c := get_viewport().gui_get_hovered_control()
	while c != null and c != _clip:
		if c.get_parent() == _clip:
			for k in _body.get_children():
				if k is Card and (k as Card).head == c:
					return k
			return null
		c = c.get_parent() as Control
	return null


func _on_head(ev: InputEvent, card: Card) -> void:
	if _is_wheel(ev):
		# the bars are not inside the scroll view, so the wheel does not reach it by itself
		_stop_glide()
		var mb := ev as InputEventMouseButton
		var bar := _scroll.get_v_scroll_bar()
		var way := -1.0 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0
		bar.value += way * bar.page / 8.0 * (mb.factor if mb.factor > 0.0 else 1.0)
		card.head.accept_event()
		return
	var press := ev as InputEventMouseButton
	if press == null or not press.pressed or press.button_index != MOUSE_BUTTON_LEFT:
		return
	card.head.accept_event()
	reveal(card)


## Brings [param card] into view whole: from the top pile its bar comes just under the bars above it; from anywhere below, as far
## up as shows it whole above the bottom pile, or, taller than that room, its bar just under the bars above it. A card already
## whole in view is left where it is.
func reveal(card: Card) -> void:
	var shown := cards()
	var i := shown.find(card)
	if i < 0 or not is_inside_tree():
		return
	var n := shown.size()
	var close := peek_for(n, float(_room.call()))
	var view := _scroll.size.y
	var at := _natural(card)
	var top := top_spot(i, close)
	var to := top
	if at >= top:
		var last_tall: float = (shown[n - 1] as Card).head.get_combined_minimum_size().y
		var free := bottom_spot(i + 1, n, view, close, last_tall) if i + 1 < n else view
		to = clampf(free - card.get_combined_minimum_size().y, top, at)
	if absf(at - to) >= 1.0:
		_glide_to(_scroll.get_v_scroll_bar().value + at - to)


## How far there is to scroll has changed: a view that was at the end goes to the new one, unless the viewer is what moved it.
func _on_length() -> void:
	var bar := _scroll.get_v_scroll_bar()
	var end := bar.max_value - bar.page
	var had := _end
	_end = end
	var grew := _last_grew()
	if _at_end and end > had and not _moving() and (had > 0.0 or grew):
		# not here: this is the middle of the scroll's own layout, which takes no further request to lay out
		_go_to_end.call_deferred()
	else:
		_at_end = bar.value >= end - AT_END


func _go_to_end() -> void:
	var bar := _scroll.get_v_scroll_bar()
	bar.value = bar.max_value - bar.page


## Whether the last card is taller than at the last look, and the same card (one that has just come to stand has not grown).
func _last_grew() -> bool:
	var shown := cards()
	if shown.is_empty():
		_last_id = 0
		return false
	var last: Card = shown[shown.size() - 1]
	var tall := last.get_combined_minimum_size().y
	var grew := last.get_instance_id() == _last_id and tall > _last_tall
	_last_id = last.get_instance_id()
	_last_tall = tall
	return grew


## Whether the scroll is moving because the viewer asked for it.
func _moving() -> bool:
	return _glider != null and _glider.is_running()


func _glide_to(value: float) -> void:
	_stop_glide()
	_glider = create_tween()
	_glider.tween_property(_scroll.get_v_scroll_bar(), "value", value, GLIDE).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _stop_glide() -> void:
	if _glider != null:
		_glider.kill()
		_glider = null


static func _is_wheel(ev: InputEvent) -> bool:
	var mb := ev as InputEventMouseButton
	return mb != null and mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN)


## What has focus is not left under a pile: the scroll view follows focus into its own rectangle and knows nothing of what lies
## over it. A control taller than the room between the piles is left to it.
func _keep_in_view(c: Control) -> void:
	if not is_instance_valid(c) or not c.is_inside_tree() or c.size.y >= _below - _above:
		return
	var y := c.global_position.y - _scroll.global_position.y
	var bar := _scroll.get_v_scroll_bar()
	if y < _above:
		bar.value -= _above - y
	elif y + c.size.y > _below:
		bar.value += y + c.size.y - _below
