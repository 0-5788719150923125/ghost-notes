extends Container
class_name Card

## Card - one component's settings on a side panel: a titled box that folds, bordered in its
## FAMILY's color (next/notes.md, "A card").
##
## THE COLOR IS THE FAMILY'S, not the component's - Scratch's categories, Blender's sockets and
## TouchDesigner's operator families all do it this way, because hues run out near eight. Every
## hue is drawn at one saturation and value (as Blockly fixes its categories'), so any hue fits
## the set; and the color never stands alone - the title says what the card is.
##
## THE FOLD IS THE VIEWER'S. It is kept in ghost.cfg (`[folds]`, one key per panel and card),
## never in the note: folding changes nothing the show does, so it must not churn the author's
## files. A fold made by a click (or by the chips, through [method fold] / [method expand])
## arrives as `folding_changed`, is written, and slides; the stored fold is put back by assigning
## [member folded], which raises no signal, writes nothing back and is there at once.
##
## NOT A FOLDABLECONTAINER, SINCE 2026-11-02 (next/panel_deck.md; the user: "cards stack or unstack, overlap or expand"):
## that class draws its title bar itself, so a bar could not leave its card, lie over the next one or slide. Here the bar is a
## control of its own, [member head]: on a panel a [PanelDeck] holds it, on one layer over everything that scrolls;
## anywhere else it stands at the card's top. [member head]'s the only title bar there is, so what is on it is live wherever it lies.
##
## Add rows to [member body], never to the card.

## The families: a label and a hue in degrees, in the order cards stand on a panel. A family is a
## component's ([constant Components.FAMILIES], step 7); the card draws it.
const FAMILIES := Components.FAMILIES
## One saturation and value for every hue. Measured against Godot's default dark panel: the
## border reads at a glance and the title stays legible on its tint.
const SAT := 0.55
const VAL := 0.82
## The paper's gray, at the same value.
const PAPER := Color(0.72, 0.74, 0.78)
## HOW LONG A CARD TAKES TO OPEN OR CLOSE, seconds: what stands under it slides with it.
const SLIDE := 0.16
## WHAT A TITLE BAR'S TINT LIES ON. Solid: what scrolls passes under a bar in a pile, and must not show through it.
const UNDER := Color(0.1, 0.1, 0.11)

## The [Settings] section that holds every card's fold (`[cards]` until 2026-10-06, when the Cards
## panel took that name for its own settings).
const SECTION := "folds"

## A fold made by a click or by [method fold] / [method expand]; assigning [member folded] raises none.
signal folding_changed(is_folded: bool)

## Which panel and which card, for the stored fold: "<panel>.<key>".
var key := ""
var family: StringName = &"paper"
## Everything the card shows goes in here.
var body: VBoxContainer
## A note's own recoloring of this card (next/notes.md: "the family's hue is a default"), or
## an invalid color for the family's.
var tint := Color(0, 0, 0, 0)
## ITS TITLE BAR: the name, and whatever [method add_title_bar_control] put on it.
var head: PanelContainer
## WHAT A PRESS ON THE BAR DOES, `(card, event) -> void`: a [PanelDeck]'s, which knows where the bar lies. Unset, a click folds.
var on_head := Callable()

## Its name on the bar.
var title := "":
	set(t):
		title = t
		if _name != null:
			_name.text = t

## FOLDED: only its bar shows. Assigned, it is so at once and says nothing ([method fold] and [method expand] slide, and say).
var folded: bool:
	get:
		return _folded
	set(f):
		if f != _folded:
			_folded = f
			_settle(false)

var _folded := false
var _open := 1.0                    # how far open it stands, 0 to 1: it slides between them
var _slide: Tween
var _rest := -1.0                   # the height it folds to, a deck's ([method set_rest]); below 0, its bar's
var _hover := false
var _name: Label
var _arrow: TextureRect
var _bar_row: HBoxContainer
var _window: Control                # shows as much of the body as the card stands open: the body slides out from under it
var _box: StyleBoxFlat              # the frame round the body


func _init(p_key := "", p_title := "", p_family: StringName = &"paper") -> void:
	key = p_key
	family = p_family
	head = PanelContainer.new()
	head.gui_input.connect(_on_head_input)
	head.mouse_entered.connect(func() -> void: _set_hover(true))
	head.mouse_exited.connect(func() -> void: _set_hover(false))
	head.minimum_size_changed.connect(_changed)
	add_child(head)
	_bar_row = HBoxContainer.new()
	_bar_row.add_theme_constant_override("separation", 4)
	head.add_child(_bar_row)
	_arrow = TextureRect.new()
	_arrow.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_row.add_child(_arrow)
	_name = Label.new()
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name.add_theme_font_size_override("font_size", 14)
	_bar_row.add_child(_name)
	title = p_title
	_window = Control.new()
	_window.clip_contents = true
	_window.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_window)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	body.minimum_size_changed.connect(_changed)
	_window.add_child(body)
	_style()
	_changed()


func _ready() -> void:
	if not key.is_empty():
		# Assigned, not fold()ed: putting the stored fold back must not write it again.
		folded = bool(Settings.read(SECTION, key, Settings.read(SECTION, was_key(key), false)))
	folding_changed.connect(func(is_folded: bool) -> void:
		if not key.is_empty():
			Settings.write(SECTION, key, is_folded))


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_SORT_CHILDREN:
			_lay_out()
		NOTIFICATION_DRAW:
			var from := _bar_height()
			if size.y > from + 0.5:
				draw_style_box(_box, Rect2(0.0, from, size.x, size.y - from))
		NOTIFICATION_PREDELETE:
			# a bar a deck holds does not go with the card by itself
			if is_instance_valid(head) and head.get_parent() != self:
				head.queue_free()


## Folds it: slides shut, and says so. Nothing happens if it is folded.
func fold() -> void:
	_go(true)


## Opens it: slides open, and says so. Nothing happens if it is open.
func expand() -> void:
	_go(false)


## Whether it is sliding open or shut now: its height is changing because it was told to, not because of what is in it.
func sliding() -> bool:
	return _slide != null and _slide.is_running()


func _go(to: bool) -> void:
	if to == _folded:
		return
	_folded = to
	_settle(true)
	folding_changed.emit(to)


## Stands at its fold: at once, or sliding there.
func _settle(sliding: bool) -> void:
	if _slide != null:
		_slide.kill()
		_slide = null
	var to := 0.0 if _folded else 1.0
	if sliding and is_inside_tree():
		_window.visible = true
		_slide = create_tween()
		_slide.tween_method(_set_open, _open, to, SLIDE).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_slide.tween_callback(func() -> void: _window.visible = not _folded)
	else:
		_open = to
		_window.visible = not _folded
		_changed()
	_style()


func _set_open(t: float) -> void:
	_open = t
	_changed()


## Anything that changes how much room it wants.
func _changed() -> void:
	if _window != null and body != null:
		_window.custom_minimum_size.x = body.get_combined_minimum_size().x
	update_minimum_size()
	queue_sort()
	queue_redraw()


func _bar_height() -> float:
	return head.get_combined_minimum_size().y


## ITS HEIGHT WITH NOTHING HIDDEN: its bar, and its body in full.
func open_height() -> float:
	return _bar_height() + _box.get_margin(SIDE_TOP) + body.get_combined_minimum_size().y + _box.get_margin(SIDE_BOTTOM)


## ITS HEIGHT FOLDED, a deck's to say: less than its bar, whose foot then lies under the next card's. Below 0, its bar's.
func set_rest(height: float) -> void:
	if not is_equal_approx(height, _rest):
		_rest = height
		_changed()


func _get_minimum_size() -> Vector2:
	var closed := _rest if _rest >= 0.0 else _bar_height()
	var wide := head.get_combined_minimum_size().x
	if _window.visible:
		wide = maxf(wide, _window.custom_minimum_size.x + _box.get_margin(SIDE_LEFT) + _box.get_margin(SIDE_RIGHT))
	return Vector2(wide, lerpf(closed, open_height(), _open))


func _lay_out() -> void:
	var from := _bar_height()
	if head.get_parent() == self:
		fit_child_in_rect(head, Rect2(0.0, 0.0, size.x, from))
	var top := from + _box.get_margin(SIDE_TOP)
	var left := _box.get_margin(SIDE_LEFT)
	var wide := size.x - left - _box.get_margin(SIDE_RIGHT)
	fit_child_in_rect(_window, Rect2(left, top, wide, maxf(0.0, size.y - top - _box.get_margin(SIDE_BOTTOM))))
	body.position = Vector2.ZERO
	body.size = Vector2(wide, body.get_combined_minimum_size().y)
	queue_redraw()


## [param c] on its title bar, after what is there, standing there folded or open.
func add_title_bar_control(c: Control) -> void:
	_bar_row.add_child(c)


func _on_head_input(ev: InputEvent) -> void:
	if on_head.is_valid():
		on_head.call(self, ev)
		return
	var mb := ev as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		head.accept_event()
		if _folded:
			expand()
		else:
			fold()


func _set_hover(on: bool) -> void:
	if on != _hover:
		_hover = on
		_style()


## A CARD RENAMED KEEPS ITS FOLD: the key it was stored under before, read when the new one holds nothing yet
## (the new one is written at the next fold). The card's key on the right, its old one on the left.
const RENAMED := {"body": "script"}     # 2026-10-31: the Script card became Body


## [param k] ("<panel>.<card>") as it was stored before its card was renamed, or itself.
static func was_key(k: String) -> String:
	var card := k.get_slice(".", k.get_slice_count(".") - 1)
	if not RENAMED.has(card):
		return k
	return k.substr(0, k.length() - card.length()) + String(RENAMED[card])


## This card's color: the note's tint when it set one, else the family's.
func color() -> Color:
	if tint.a > 0.0:
		return tint
	return family_color(family)


## A LABELED DIAL, as every card's are: the name, the slider and its readout on one row of
## [param box]. [param apply] takes each new value.
static func slider_row(box: Container, label: String, lo: float, hi: float, step: float,
		initial: float, tip: String, apply: Callable) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(72, 0)
	l.add_theme_font_size_override("font_size", 12)
	row.add_child(l)
	var sl := HSlider.new()
	sl.min_value = lo
	sl.max_value = hi
	sl.step = step
	sl.value = clampf(initial, lo, hi)
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.tooltip_text = tip
	sl.value_changed.connect(apply)
	row.add_child(sl)
	readout(row, sl)
	return sl


## A dial's value beside it on [param row], kept current as it moves.
static func readout(row: HBoxContainer, sl: HSlider, suffix := "") -> Label:
	var v := Label.new()
	v.custom_minimum_size = Vector2(42, 0)
	v.add_theme_font_size_override("font_size", 12)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.tooltip_text = sl.tooltip_text
	v.text = ("%.2f" % sl.value) + suffix
	sl.value_changed.connect(func(nv: float) -> void:
		v.text = ("%.2f" % nv) + suffix)
	row.add_child(v)
	return v


## Set a dial and its readout without telling anyone: a value arriving, not a hand moving it.
static func put_slider(sl: HSlider, label: Label, v: float, suffix := "") -> void:
	sl.set_value_no_signal(v)
	label.text = ("%.2f" % v) + suffix


static func family_color(f: StringName) -> Color:
	var hue := float((FAMILIES.get(f, FAMILIES[&"paper"]) as Dictionary)["hue"])
	if hue < 0.0:
		return PAPER
	return Color.from_hsv(hue / 360.0, SAT, VAL)


## Recolor (a note's choice) and redraw.
func set_tint(c: Color) -> void:
	tint = c
	_style()


func _style() -> void:
	var c := color()
	var bar := _bar_box(c, UNDER.lerp(c, (0.24 if _hover else 0.12) if _folded else (0.28 if _hover else 0.18)))
	if not _folded:
		bar.corner_radius_bottom_left = 0
		bar.corner_radius_bottom_right = 0
	head.add_theme_stylebox_override("panel", bar)
	_box = _frame(c, Color(0.0, 0.0, 0.0, 0.18), false)
	_box.corner_radius_top_left = 0
	_box.corner_radius_top_right = 0
	_box.border_width_top = 0
	var ink := c.lightened(0.6 if _hover else (0.2 if _folded else 0.35))
	_name.add_theme_color_override("font_color", ink)
	_arrow.modulate = ink
	_arrow.texture = get_theme_icon(&"folded_arrow" if _folded else &"expanded_arrow", &"FoldableContainer")
	queue_redraw()


## A title bar: a frame, and a soft shadow on the bar it lies over, so a pile reads as cards one on another.
static func _bar_box(border: Color, bg: Color) -> StyleBoxFlat:
	var s := _frame(border, bg, true)
	s.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	s.shadow_size = 3
	s.shadow_offset = Vector2(0.0, -1.0)
	return s


static func _frame(border: Color, bg: Color, title_bar: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = Color(border, 0.85)
	s.set_border_width_all(1)
	s.set_corner_radius_all(4)
	if title_bar:
		s.content_margin_left = 8
		s.content_margin_right = 8
		s.content_margin_top = 3
		s.content_margin_bottom = 3
	else:
		s.content_margin_left = 8
		s.content_margin_right = 6
		s.content_margin_top = 8
		s.content_margin_bottom = 8
	return s
