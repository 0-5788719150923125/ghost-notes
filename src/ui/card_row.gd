extends HFlowContainer
class_name CardRow

## CardRow - the chips under a panel's title, one per [Card] in its color (next/notes.md, "The
## component row"). A click opens or closes that card; Ctrl-click opens it alone and folds the
## rest, as Blender's panel headers do. A chip shows ● while its card is open and ○ while it is
## folded, so the row also answers "what is open" without scrolling the panel.

var _cards: Array = []          # [Card]
var _chips := {}                # Card -> Button
var _shown := {}                # Card -> the fold its chip was last painted for


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
	chip.tooltip_text = ("Open or fold the %s card. Ctrl-click opens it alone and folds the rest."
		% card.title)
	chip.gui_input.connect(func(ev: InputEvent) -> void: _on_chip(card, ev))
	add_child(chip)
	_chips[card] = chip
	_paint(card)


## THE CHIPS FOLLOW THEIR CARDS BY LOOKING, every frame - a handful of booleans. A fold set by
## assignment raises no signal (FoldableContainer emits `folding_changed` only for fold(),
## expand() and a click), and that is exactly how a card puts back its stored fold, so a wired
## chip came up "open" on a folded card at every launch.
func _process(_delta: float) -> void:
	for c in _cards:
		var card: Card = c
		if not is_instance_valid(card):
			continue
		if _shown.get(card) != [card.folded, card.visible]:
			_paint(card)


func _on_chip(card: Card, ev: InputEvent) -> void:
	var mb := ev as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	if mb.ctrl_pressed:
		solo(card)
	elif card.folded:
		card.expand()
	else:
		card.fold()


## Open [param card] and fold every other card in the row.
func solo(card: Card) -> void:
	for c in _cards:
		if c == card:
			if c.folded:
				c.expand()
		elif not c.folded:
			c.fold()


func _paint(card: Card) -> void:
	var chip: Button = _chips.get(card)
	if chip == null or not is_instance_valid(chip):
		return
	_shown[card] = [card.folded, card.visible]
	# A card its panel hides (a mode that does not use it) has no chip either.
	chip.visible = card.visible
	chip.text = ("○ " if card.folded else "● ") + card.title
	var c := card.color()
	chip.add_theme_color_override("font_color", c.lightened(0.3) if not card.folded else Color(c, 0.75))
	chip.add_theme_color_override("font_hover_color", c.lightened(0.55))
	var box := StyleBoxFlat.new()
	box.bg_color = Color(c, 0.16 if not card.folded else 0.06)
	box.border_color = Color(c, 0.7)
	box.set_border_width_all(1)
	box.set_corner_radius_all(9)
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 1
	box.content_margin_bottom = 1
	for s in ["normal", "hover", "pressed", "focus"]:
		chip.add_theme_stylebox_override(s, box)
