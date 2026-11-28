extends RefCounted
class_name ShowSounds

## ShowSounds - the sounds a show makes for the note on its own, as the Sound card lists them beside the sound effects the words ask
## for ([MadeSounds]): a show hands one to the panel it stands on (the reading's `sound_sections`) and says its sounds here, so the
## card names no show. Making one again is its row's, on the Pipeline card (docs.py "one pipeline").


## The sounds made and to be made, in the order they are heard: `[{key, name, line, tip, path}]` - `line` what it is now (made and
## how long, being made, why it failed), `tip` what it is in words, `path` its sound file (absolute; "" while it is not made).
func sounds() -> Array:
	return []


## The conversation that changes sound [param key] ([WriterChat], opened by its Refine… on the card), null where it has none.
func chat_of(_key: String) -> WriterChat:
	return null


## How loud and how muffled sound [param key] is heard (`""`: all of them): `{db, muffle}` - `db` its level (0 as made), `muffle` 0
## (as made) to 1 (through thick cloth); {} where the show sets no level.
func level_of(_key: String) -> Dictionary:
	return {}


## Sound [param key] (`""`: all of them) heard [param db] louder and [param muffle] muffled from now, at once.
func set_level(_key: String, _db: float, _muffle: float) -> void:
	pass


## What its sounds are called on the card.
func heading() -> String:
	return "Made by the show"
