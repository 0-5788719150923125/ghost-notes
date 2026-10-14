extends FoldableContainer
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
## arrives as `folding_changed` and is written; the stored fold is put back by assigning
## [member FoldableContainer.folded], which raises no signal and so writes nothing back.
##
## Add rows to [member body], never to the card: a FoldableContainer hides its direct children
## when folded, and the body is the one child it has.

## The families: a label and a hue in degrees, in the order cards stand on a panel. A family is a
## component's ([constant Components.FAMILIES], step 7); the card draws it.
const FAMILIES := Components.FAMILIES
## One saturation and value for every hue. Measured against Godot's default dark panel: the
## border reads at a glance and the title stays legible on its tint.
const SAT := 0.55
const VAL := 0.82
## The paper's gray, at the same value.
const PAPER := Color(0.72, 0.74, 0.78)

## The [Settings] section that holds every card's fold (`[cards]` until 2026-10-06, when the Cards
## panel took that name for its own settings).
const SECTION := "folds"

## Which panel and which card, for the stored fold: "<panel>.<key>".
var key := ""
var family: StringName = &"paper"
## Everything the card shows goes in here.
var body: VBoxContainer
## A note's own recoloring of this card (next/notes.md: "the family's hue is a default"), or
## an invalid color for the family's.
var tint := Color(0, 0, 0, 0)


func _init(p_key := "", p_title := "", p_family: StringName = &"paper") -> void:
	key = p_key
	title = p_title
	family = p_family
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	add_child(body)
	_style()


func _ready() -> void:
	if not key.is_empty():
		# Assigned, not fold()ed: putting the stored fold back must not write it again.
		folded = bool(Settings.read(SECTION, key, false))
	folding_changed.connect(func(is_folded: bool) -> void:
		if not key.is_empty():
			Settings.write(SECTION, key, is_folded))


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
	var open := _box(c, Color(c, 0.18), true)
	open.corner_radius_bottom_left = 0
	open.corner_radius_bottom_right = 0
	add_theme_stylebox_override("title_panel", open)
	var open_hover := _box(c, Color(c, 0.28), true)
	open_hover.corner_radius_bottom_left = 0
	open_hover.corner_radius_bottom_right = 0
	add_theme_stylebox_override("title_hover_panel", open_hover)
	add_theme_stylebox_override("title_collapsed_panel", _box(c, Color(c, 0.12), true))
	add_theme_stylebox_override("title_collapsed_hover_panel", _box(c, Color(c, 0.24), true))
	var panel := _box(c, Color(0.0, 0.0, 0.0, 0.18), false)
	panel.corner_radius_top_left = 0
	panel.corner_radius_top_right = 0
	panel.border_width_top = 0
	add_theme_stylebox_override("panel", panel)
	add_theme_color_override("font_color", c.lightened(0.35))
	add_theme_color_override("hover_font_color", c.lightened(0.6))
	add_theme_color_override("collapsed_font_color", c.lightened(0.2))
	add_theme_font_size_override("font_size", 14)


static func _box(border: Color, bg: Color, title_bar: bool) -> StyleBoxFlat:
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
