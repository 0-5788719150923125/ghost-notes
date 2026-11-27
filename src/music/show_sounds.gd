extends RefCounted
class_name ShowSounds

## ShowSounds - the sounds a show makes for the note on its own, as the Sound card lists them beside the sound effects the words ask
## for ([MadeSounds]): a show hands one to the panel it stands on (the reading's `sound_sections`) and says its sounds here, so the
## card names no show. Making one again is its row's, on the Pipeline card (docs.py "one pipeline").


## The sounds made and to be made, in the order they are heard: `[{key, name, line, tip, path}]` - `line` what it is now (made and
## how long, being made, why it failed), `tip` what it is in words, `path` its sound file (absolute; "" while it is not made).
func sounds() -> Array:
	return []


## What its sounds are called on the card.
func heading() -> String:
	return "Made by the show"
