extends HFlowContainer
class_name CardRow

## CardRow - the chips under a panel's title, one per [Card] in its color (next/notes.md, "The
## component row"). A click brings that card into view whole, as a press on its title bar does
## ([method Card.reveal]); a card never folds (2026-11-09), so a chip has no open or folded to show.

var _cards: Array = []          # [Card]
var _chips := {}                # Card -> Button
var _shown := {}                # Card -> whether it stood when its chip was last painted


func _init() -> void:
	add_theme_constant_override("h_separation", 4)
	add_theme_constant_override("v_separation", 4)


## Show [param card] in the row, after the ones already there.
func track(card: Card) -> void:
	_cards.append(card)
	var chip := Button.new()
	chip.flat = false
	chip.focus_mode = Control.FOCUS_NONE
	chip.add_theme_font_size_override("font_size", 11)
	chip.gui_input.connect(func(ev: InputEvent) -> void: _on_chip(card, ev))
	add_child(chip)
	_chips[card] = chip
	_paint(card)


## THE CHIPS FOLLOW THEIR CARDS BY LOOKING, every frame - a handful of booleans: a card its panel
## hides (a Pipeline card with nothing to list) has no chip either.
func _process(_delta: float) -> void:
	follow()


## Each chip painted again where its card has changed: every frame - and at once for a panel that has just hidden a card, so
## its chip is not seen for a frame.
func follow() -> void:
	for c in _cards:
		var card: Card = c
		if not is_instance_valid(card):
			continue
		if _shown.get(card) != card.visible:
			_paint(card)


## A CHIP SAYS WHAT ITS CARD IS FOR (2026-11-11, the user: "If you mouse over the colored components near the + button, they
## don't tell you anything useful"): the card's [member Card.blurb], then what a click does.
static func tip_of(card: Card) -> String:
	var click := "Click to bring the %s card into view." % card.title
	return click if card.blurb.is_empty() else card.blurb + "\n\n" + click


func _on_chip(card: Card, ev: InputEvent) -> void:
	var mb := ev as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	card.reveal()


func _paint(card: Card) -> void:
	var chip: Button = _chips.get(card)
	if chip == null or not is_instance_valid(chip):
		return
	_shown[card] = card.visible
	chip.visible = card.visible
	chip.text = card.title
	chip.tooltip_text = tip_of(card)
	var c := card.color()
	chip.add_theme_color_override("font_color", c.lightened(0.3))
	chip.add_theme_color_override("font_hover_color", c.lightened(0.55))
	var box := StyleBoxFlat.new()
	box.bg_color = Color(c, 0.16)
	box.border_color = Color(c, 0.7)
	box.set_border_width_all(1)
	box.set_corner_radius_all(9)
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 1
	box.content_margin_bottom = 1
	for s in ["normal", "hover", "pressed", "focus"]:
		chip.add_theme_stylebox_override(s, box)
