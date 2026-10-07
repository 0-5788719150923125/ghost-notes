extends VBoxContainer
class_name BookendsCard

## BookendsCard - the intro and the outro: seconds held before the first word and after the last
## (next/notes.md step 5: one card per section, in every panel that has it - the tarot panel used
## to declare both sliders a second time). Its block in a document is `bookends:`.
##
## Like the Look they are the DIRECTOR'S, so they hold in every session a picture is made in. What
## the picture DOES during them is the presentation's, so a panel may say it in its own words:
## [method _init] takes the two tooltips, and the defaults are a written chapter's.

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


func _init(intro_tip := INTRO_TIP, outro_tip := OUTRO_TIP) -> void:
	add_theme_constant_override("separation", 8)
	_intro = Card.slider_row(self, "Intro", Director.INTRO_MIN, Director.INTRO_MAX, 0.5,
		Director.intro_hold, intro_tip, func(v: float) -> void: Director.set_intro_hold(v))
	_outro = Card.slider_row(self, "Outro", Director.OUTRO_MIN, Director.OUTRO_MAX, 0.5,
		Director.outro_hold, outro_tip, func(v: float) -> void: Director.set_outro_hold(v))


## The block for a document.
func capture() -> Dictionary:
	return {"intro": snappedf(Director.intro_hold, 0.01), "outro": snappedf(Director.outro_hold, 0.01)}


## ...and back, through the sliders - so the card shows the holds and the Director saves them. A
## hold the block does not name is left as it is.
func apply(block: Dictionary) -> void:
	for pair in [["intro", _intro], ["outro", _outro]]:
		var sl: HSlider = pair[1]
		if block.has(String(pair[0])):
			sl.value = clampf(float(block[String(pair[0])]), sl.min_value, sl.max_value)
