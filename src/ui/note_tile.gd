extends PanelContainer
class_name NoteTile

## NoteTile - one note on the notes list, a square card (2026-10-31, the user: "something closer to what a
## notes app should look like ... a Google Keep kind of look ... Literal square shapes, in different colors,
## perhaps keyed to the underlying, dominant components"). Every tile is the same size ([method set_side]):
## the note's title, the first of its words ([method NoteStore.preview_of]), a chip for each component on it
## and when it last changed. A click opens it; on the desktop an × asks to delete it.
##
## DRAWN AS A [Card] IS ("let's emulate the card styling first, to see if we like that design"): flat, a
## one-pixel border in the note's color, the title in a band tinted by it, the rest dark. Each chip is drawn
## the same way in its component's FAMILY color, so the chips read as the cards inside the note do.
##
## THE NOTE'S COLOR IS ITS COMPONENTS', MIXED ("Synesthesia, but with components and color"):
## [method color_of]. Each component has a hue of its own - its family's, nudged across [constant SPREAD] by
## its place among its kin, so a Table and a Proof are both the producers' violet and still told apart - and
## the note's hue is their mean on the color wheel, the one that shows the note (its `presentation` slot)
## counting most, then the one that times it (`clock`), then the rest, each [constant PULL] of the one before.
## So notes made of the same things are the same color, and notes made of similar things are near it. Drawn
## at the cards' one saturation and value ([constant Card.SAT], [constant Card.VAL]); a note of words alone is
## the paper's gray. Nothing in the note's file says its color: it changes as components come and go.
##
## A TAP IS A PRESS AND A RELEASE IN PLACE ([constant TAP_SLOP]): the tile passes its presses on, so a finger
## dragged across it scrolls the list on a phone instead of opening the note under it.

signal opened(path: String)
signal delete_asked(path: String)

## Degrees a family's components are spread across, centered on the family's hue.
const SPREAD := 40.0
## How much each component after the first counts toward the note's hue, against the one before it.
const PULL := 0.2
## How far a press may move, in pixels at scale 1, and still be a tap.
const TAP_SLOP := 8.0
const COL_DATE := Color(0.5, 0.56, 0.66)
const COL_WORDS := Color(0.78, 0.8, 0.84)
const COL_BODY := Color(0.045, 0.045, 0.062)

var path := ""
var title := ""
## The note's color ([method color_of]).
var color := Card.PAPER
## The size of everything on it: 1 on a desktop, larger on a phone.
var s := 1.0

var _band: PanelContainer
var _title: Label
var _words: Label
var _chips: HFlowContainer
var _x: Button
var _hover := false
var _down := Vector2.ZERO
var _pressing := false


## [param summary] is [method NoteStore.summary_of]'s; [param mtime] when the note last changed. With
## [param deletable] the tile carries an ×.
func _init(p_path: String, summary: Dictionary, mtime: int, p_scale := 1.0, deletable := true) -> void:
	path = p_path
	title = String(summary.get("title", p_path.get_file().get_basename()))
	s = p_scale
	color = color_of(summary.get("attached", []))
	tooltip_text = p_path
	mouse_filter = Control.MOUSE_FILTER_PASS
	clip_contents = true
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)

	_band = PanelContainer.new()
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_band)
	_title = _label(title, 16, color.lightened(0.35))
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_band.add_child(_title)

	var pad := MarginContainer.new()
	pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, roundi((10.0 if side != "top" else 8.0) * s))
	col.add_child(pad)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", roundi(8 * s))
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(inner)

	_words = _label(String(summary.get("preview", "")), 13, COL_WORDS)
	_words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_words.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_words.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_words.add_theme_constant_override("line_spacing", roundi(2 * s))
	inner.add_child(_words)

	_chips = HFlowContainer.new()
	_chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chips.add_theme_constant_override("h_separation", roundi(4 * s))
	_chips.add_theme_constant_override("v_separation", roundi(4 * s))
	for k in chips_of(summary.get("attached", [])):
		_chips.add_child(_chip(k))
	inner.add_child(_chips)

	var foot := HBoxContainer.new()
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(foot)
	var date := _label(NoteTile.when(mtime), 11, COL_DATE)
	date.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	date.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	foot.add_child(date)
	if deletable:
		_x = Button.new()
		_x.text = "×"
		_x.flat = true
		_x.focus_mode = Control.FOCUS_NONE
		_x.tooltip_text = "Delete this note"
		_x.add_theme_font_size_override("font_size", roundi(15 * s))
		_x.add_theme_color_override("font_color", COL_DATE)
		_x.add_theme_constant_override("h_separation", 0)
		_x.pressed.connect(func() -> void: delete_asked.emit(path))
		foot.add_child(_x)
	_style()


## EVERY TILE THIS SIZE: [param px] square, its title held to two lines.
func set_side(px: float) -> void:
	custom_minimum_size = Vector2(px, px)
	var font := _title.get_theme_font("font")
	var fs := _title.get_theme_font_size("font_size")
	var w := px - 2.0 - 2.0 * roundf(10.0 * s)
	var h := font.get_multiline_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, w, fs, 2).y
	_title.custom_minimum_size = Vector2(0, ceilf(h))


## The pointer is over it: the border and the band brighten, as a card's title bar does.
func set_hover(on: bool) -> void:
	if on != _hover:
		_hover = on
		_style()


func _gui_input(e: InputEvent) -> void:
	var mb := e as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if mb.pressed:
		_down = mb.position
		_pressing = true
	elif _pressing:
		_pressing = false
		if mb.position.distance_to(_down) <= TAP_SLOP * s and Rect2(Vector2.ZERO, size).has_point(mb.position):
			opened.emit(path)


## WHICH COMPONENTS A TILE NAMES: all but the words (every note has them), in the order their cards stand.
static func chips_of(attached: Array) -> Array:
	var order: Array = Components.FAMILIES.keys()
	var keys: Array = Components.REGISTRY.keys()
	var out := attached.filter(func(k: String) -> bool:
		return Components.REGISTRY.has(k) and StringName(Components.REGISTRY[k]["family"]) != &"paper")
	out.sort_custom(func(a: String, b: String) -> bool:
		var fa := order.find(Components.REGISTRY[a]["family"])
		var fb := order.find(Components.REGISTRY[b]["family"])
		return fa < fb if fa != fb else keys.find(a) < keys.find(b))
	return out


## A COMPONENT'S OWN HUE, in degrees: its family's, nudged by its place among the family's components
## across [constant SPREAD]; -1 for one with no hue (the words).
static func hue_of(key: String) -> float:
	var fam: StringName = Components.REGISTRY[key]["family"]
	var base := float((Components.FAMILIES.get(fam, {"hue": -1.0}) as Dictionary)["hue"])
	if base < 0.0:
		return -1.0
	var kin: Array = Components.REGISTRY.keys().filter(func(k: String) -> bool:
		return StringName(Components.REGISTRY[k]["family"]) == fam)
	if kin.size() < 2:
		return base
	return fposmod(base + (float(kin.find(key)) / float(kin.size() - 1) - 0.5) * SPREAD, 360.0)


## How much a component says what its note is: 2 for the one it is seen in, 1 for the one that times it.
static func standing_of(key: String) -> int:
	var slots: Array = Components.REGISTRY[key]["slots"]
	return 2 if slots.has("presentation") else (1 if slots.has("clock") else 0)


## THE NOTE'S COLOR from the components on it ([param attached], [method Components.attached_of]).
static func color_of(attached: Array) -> Color:
	var keys: Array = Components.REGISTRY.keys()
	var hued := attached.filter(func(k: String) -> bool:
		return Components.REGISTRY.has(k) and hue_of(k) >= 0.0)
	if hued.is_empty():
		return Card.PAPER
	hued.sort_custom(func(a: String, b: String) -> bool:
		var sa := standing_of(a)
		var sb := standing_of(b)
		return sa > sb if sa != sb else keys.find(a) < keys.find(b))
	var v := Vector2.ZERO
	var w := 1.0
	for k in hued:
		v += Vector2.from_angle(deg_to_rad(hue_of(k))) * w
		w *= PULL
	return Color.from_hsv(fposmod(rad_to_deg(v.angle()), 360.0) / 360.0, Card.SAT, Card.VAL)


## When a note last changed, as a list says it: "today", "yesterday", "Oct 3", "2025-12-01".
static func when(mtime: int) -> String:
	if mtime <= 0:
		return ""
	var now := int(Time.get_unix_time_from_system())
	var today := Time.get_datetime_dict_from_unix_time(now)
	var then := Time.get_datetime_dict_from_unix_time(mtime)
	var day := func(d: Dictionary) -> int:
		return int(Time.get_unix_time_from_datetime_dict({"year": d["year"], "month": d["month"], "day": d["day"]}) / 86400)
	var ago: int = int(day.call(today)) - int(day.call(then))
	if ago <= 0:
		return "today"
	if ago == 1:
		return "yesterday"
	var months := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	if int(then["year"]) == int(today["year"]):
		return "%s %d" % [months[int(then["month"]) - 1], int(then["day"])]
	return "%04d-%02d-%02d" % [int(then["year"]), int(then["month"]), int(then["day"])]


func _label(text: String, size_px: int, c: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", roundi(size_px * s))
	l.add_theme_color_override("font_color", c)
	return l


func _chip(key: String) -> Label:
	var fc := Card.family_color(StringName(Components.REGISTRY[key]["family"]))
	var l := _label(Registry.label(Components.REGISTRY, key), 11, fc.lightened(0.35))
	var box := StyleBoxFlat.new()
	box.bg_color = Color(fc, 0.12)
	box.border_color = Color(fc, 0.85)
	box.set_border_width_all(1)
	box.set_corner_radius_all(roundi(3 * s))
	box.content_margin_left = roundf(5 * s)
	box.content_margin_right = roundf(5 * s)
	box.content_margin_top = roundf(1 * s)
	box.content_margin_bottom = roundf(1 * s)
	l.add_theme_stylebox_override("normal", box)
	return l


func _style() -> void:
	var c := color
	var outer := StyleBoxFlat.new()
	outer.bg_color = COL_BODY
	outer.border_color = Color(c.lightened(0.25), 1.0) if _hover else Color(c, 0.85)
	outer.set_border_width_all(1)
	outer.set_corner_radius_all(4)
	outer.set_content_margin_all(1)
	add_theme_stylebox_override("panel", outer)
	var band := StyleBoxFlat.new()
	band.bg_color = Color(c, 0.28 if _hover else 0.18)
	band.corner_radius_top_left = 3
	band.corner_radius_top_right = 3
	band.content_margin_left = roundf(10 * s)
	band.content_margin_right = roundf(10 * s)
	band.content_margin_top = roundf(7 * s)
	band.content_margin_bottom = roundf(7 * s)
	_band.add_theme_stylebox_override("panel", band)
	_title.add_theme_color_override("font_color", c.lightened(0.6 if _hover else 0.35))
	if _x != null:
		_x.modulate = Color(1, 1, 1, 1.0 if _hover else 0.45)
