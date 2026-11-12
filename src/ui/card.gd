extends Container
class_name Card

## Card - one component's settings on a side panel: a titled box, bordered in its family's color
## (next/notes.md, "A card").
##
## The color is the family's, not the component's. Every hue is drawn at one saturation and value, so
## any hue fits the set; the color never stands alone - the title says what the card is.
##
## It never folds: a press on its bar, or on its chip, asks for it to be brought into view whole
## ([method reveal]), which the [PanelDeck] that holds its bar does.
##
## Not a FoldableContainer (next/panel_deck.md): that class draws its title bar itself, so a bar could
## not leave its card. Here the bar is a control of its own, [member head]: on a panel a [PanelDeck]
## holds it, on one layer over everything that scrolls, and takes its presses; anywhere else it stands
## at the card's top. [member head] is the only title bar there is, so what is on it is live wherever it lies.
##
## What it is for, on hover ([member blurb]): its title bar's tooltip, and its chip's ([CardRow]) - a
## component's card says its row's blurb, the one "+" offered it with ([method SidePanel.add_card]).
##
## Add rows to [member body], never to the card.

## The families: a label and a hue in degrees, in the order cards stand on a panel. A family is a
## component's ([constant Components.FAMILIES], step 7); the card draws it.
const FAMILIES := Components.FAMILIES
## One saturation and value for every hue, against Godot's default dark panel: the border reads at a
## glance and the title stays legible on its tint.
const SAT := 0.55
const VAL := 0.82
## The paper's gray, at the same value.
const PAPER := Color(0.72, 0.74, 0.78)
## What a title bar's tint lies on. Solid: what scrolls passes under a bar in a pile, and must not show through it.
const UNDER := Color(0.1, 0.1, 0.11)

## Asked to be brought into view whole ([method reveal]): by a press on its bar or its chip.
signal reveal_asked

## Which panel and which card: "<panel>.<key>".
var key := ""
var family: StringName = &"paper"
## Everything the card shows goes in here.
var body: VBoxContainer
## A note's own recoloring of this card (next/notes.md: "the family's hue is a default"), or
## an invalid color for the family's.
var tint := Color(0, 0, 0, 0)
## Its title bar: the name, and whatever [method add_title_bar_control] put on it.
var head: PanelContainer

## Its name on the bar.
var title := "":
	set(t):
		title = t
		if _name != null:
			_name.text = t

## What the card is for, in a sentence or two: its title bar's tooltip, and its chip's.
var blurb := "":
	set(t):
		blurb = t
		if head != null:
			head.tooltip_text = t

var _hover := false
var _name: Label
var _bar_row: HBoxContainer
var _box: StyleBoxFlat              # the frame round the body


func _init(p_key := "", p_title := "", p_family: StringName = &"paper") -> void:
	key = p_key
	family = p_family
	head = PanelContainer.new()
	head.mouse_entered.connect(func() -> void: _set_hover(true))
	head.mouse_exited.connect(func() -> void: _set_hover(false))
	head.minimum_size_changed.connect(_changed)
	add_child(head)
	_bar_row = HBoxContainer.new()
	_bar_row.add_theme_constant_override("separation", 4)
	head.add_child(_bar_row)
	_name = Label.new()
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name.add_theme_font_size_override("font_size", 14)
	_bar_row.add_child(_name)
	title = p_title
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	body.minimum_size_changed.connect(_changed)
	add_child(body)
	_style()
	_changed()


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


## Asks to be brought into view whole, or its start where it is taller than the view: the [PanelDeck] holding its bar
## answers. A card no deck holds (a footer's) is always in view, and nothing answers.
func reveal() -> void:
	reveal_asked.emit()


## Anything that changes how much room it wants.
func _changed() -> void:
	update_minimum_size()
	queue_sort()
	queue_redraw()


func _bar_height() -> float:
	return head.get_combined_minimum_size().y


func _get_minimum_size() -> Vector2:
	if body == null or _box == null:
		return Vector2.ZERO
	var inner := body.get_combined_minimum_size()
	var wide := maxf(head.get_combined_minimum_size().x, inner.x + _box.get_margin(SIDE_LEFT) + _box.get_margin(SIDE_RIGHT))
	return Vector2(wide, _bar_height() + _box.get_margin(SIDE_TOP) + inner.y + _box.get_margin(SIDE_BOTTOM))


func _lay_out() -> void:
	var from := _bar_height()
	if head.get_parent() == self:
		fit_child_in_rect(head, Rect2(0.0, 0.0, size.x, from))
	var top := from + _box.get_margin(SIDE_TOP)
	var left := _box.get_margin(SIDE_LEFT)
	fit_child_in_rect(body, Rect2(left, top, size.x - left - _box.get_margin(SIDE_RIGHT), maxf(0.0, size.y - top - _box.get_margin(SIDE_BOTTOM))))
	queue_redraw()


## [param c] on its title bar, after what is there.
func add_title_bar_control(c: Control) -> void:
	_bar_row.add_child(c)


func _set_hover(on: bool) -> void:
	if on != _hover:
		_hover = on
		_style()


## This card's color: the note's tint when it set one, else the family's.
func color() -> Color:
	if tint.a > 0.0:
		return tint
	return family_color(family)


## A labeled dial, as every card's are: the name, the slider and its readout on one row of
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
	var bar := _bar_box(c, UNDER.lerp(c, 0.28 if _hover else 0.18))
	bar.corner_radius_bottom_left = 0
	bar.corner_radius_bottom_right = 0
	head.add_theme_stylebox_override("panel", bar)
	_box = _frame(c, Color(0.0, 0.0, 0.0, 0.18), false)
	_box.corner_radius_top_left = 0
	_box.corner_radius_top_right = 0
	_box.border_width_top = 0
	_name.add_theme_color_override("font_color", c.lightened(0.6 if _hover else 0.35))
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
