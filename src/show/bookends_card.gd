extends VBoxContainer
class_name BookendsCard

## BookendsCard - the intro and the outro: seconds held before the first word and after the last
## (next/notes.md step 5: one card per section, in every panel that has it - the Cards panel used
## to declare both sliders a second time). Its block in a document is `bookends:`.
##
## Like the Look they are the DIRECTOR'S, so they hold in every session a picture is made in. What
## the picture DOES during them is the presentation's, so a panel may say it in its own words:
## [method _init] takes the two tooltips, and the defaults are a written chapter's.
##
## THE OPENING IS PICKED HERE TOO (2026-10-28, the user: "default to no intro blur/title display, or we
## can enable it via a pick list"): what the picture does through the intro ([Openings]: none, out of
## focus, the show's name over it), the Director's beside the holds ([method Director.set_opening]).
## Shown only while the medium in use draws an opening ([method Medium.uses] "opening") - a dial that
## does nothing is a control the author cannot trust.

## The block this card keeps under a document's `ghost:` key.
const KEY := "bookends"

const INTRO_TIP := ("Seconds of held opening before the narration starts, so the video fades up "
	+ "onto something instead of beginning mid-word. If Ambience is on, the bed plays alone "
	+ "through it. On the tablet the hand waits for it too: the screen wakes when it ends. "
	+ "Applies to the next reading or render, not the take already playing. Under about "
	+ "4s the bed is still swelling when the voice arrives; 0 turns the intro off.")
const OUTRO_TIP := ("Seconds held after the last word, fading picture and sound out together. The "
	+ "ambience bed takes about 7s to decay, so a shorter outro will cut its tail off. "
	+ "0 ends the video on the final syllable.")

var _intro: HSlider
var _outro: HSlider
var _opening: OptionButton
var _opening_row: HBoxContainer


## This card for a note's panel, from what the panel says of itself ([method NoteCards.make]):
## `intro_tip` / `outro_tip` - what the holds are, in that workspace's words.
static func for_note(ctx: Dictionary) -> BookendsCard:
	return BookendsCard.new(String(ctx.get("intro_tip", INTRO_TIP)), String(ctx.get("outro_tip", OUTRO_TIP)))


func _init(intro_tip := INTRO_TIP, outro_tip := OUTRO_TIP) -> void:
	add_theme_constant_override("separation", 8)
	_intro = Card.slider_row(self, "Intro", Director.INTRO_MIN, Director.INTRO_MAX, 0.5,
		Director.intro_hold, intro_tip, func(v: float) -> void: Director.set_intro_hold(v))
	_outro = Card.slider_row(self, "Outro", Director.OUTRO_MIN, Director.OUTRO_MAX, 0.5,
		Director.outro_hold, outro_tip, func(v: float) -> void: Director.set_outro_hold(v))
	_opening_row = HBoxContainer.new()
	_opening_row.add_theme_constant_override("separation", 8)
	add_child(_opening_row)
	var l := Label.new()
	l.text = "Opening"
	l.custom_minimum_size = Vector2(72, 0)
	l.add_theme_font_size_override("font_size", 12)
	_opening_row.add_child(l)
	_opening = OptionButton.new()
	_opening.fit_to_longest_item = false
	_opening.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tips := PackedStringArray(["What the picture does through the intro, before the show begins."])
	for k in Openings.ROWS:
		_opening.add_item(Registry.label(Openings.ROWS, k))
		_opening.set_item_metadata(_opening.item_count - 1, k)
		tips.append("%s: %s" % [Registry.label(Openings.ROWS, k), Registry.blurb(Openings.ROWS, k)])
	_opening.tooltip_text = "\n\n".join(tips)
	_opening.item_selected.connect(func(i: int) -> void: Director.set_opening(String(_opening.get_item_metadata(i))))
	_opening_row.add_child(_opening)
	_show_opening()


func _enter_tree() -> void:
	if not Director.medium_changed.is_connected(_show_opening):
		Director.medium_changed.connect(_show_opening)


func _ready() -> void:
	_show_opening()


func _exit_tree() -> void:
	if Director.medium_changed.is_connected(_show_opening):
		Director.medium_changed.disconnect(_show_opening)


## The opening picked, and its row shown only while the medium in use draws one.
func _show_opening() -> void:
	for i in _opening.item_count:
		if String(_opening.get_item_metadata(i)) == Director.opening:
			_opening.select(i)
	_opening_row.visible = Medium.uses(Director.resolved_medium(), "opening")


## The block for a document.
func capture() -> Dictionary:
	return {"intro": snappedf(Director.intro_hold, 0.01), "outro": snappedf(Director.outro_hold, 0.01),
		"opening": Director.opening}


## ...and back, through the sliders - so the card shows the holds and the Director saves them. A
## hold the block does not name is left as it is, and so is the opening (none, as a note opens:
## [method Director.reset_show]).
func apply(block: Dictionary) -> void:
	for pair in [["intro", _intro], ["outro", _outro]]:
		var sl: HSlider = pair[1]
		if block.has(String(pair[0])):
			sl.value = clampf(float(block[String(pair[0])]), sl.min_value, sl.max_value)
	if block.has("opening"):
		Director.set_opening(String(block["opening"]))
	_show_opening()
