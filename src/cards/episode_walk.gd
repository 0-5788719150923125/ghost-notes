extends TextWalk
class_name EpisodeWalk

## EpisodeWalk - a show of cards reads its EPISODE, never the note: the note is the brief agents
## work from, and what the reader says is the script they wrote, step by step, for the episode up
## now. A [TextWalk] Cards hands its reading.

## The episode up now, asked each time: `() -> CardEpisode`, null while there is none.
var episode: Callable


func _init(current: Callable) -> void:
	episode = current


func body(_pulled: String) -> String:
	return _script()


func spoken(text: String, _title: String) -> Dictionary:
	return {"body": CardReading.speakable(text), "title": ""}


func cast_text(_written: String) -> String:
	return _script()


func test_passage(_fallback: String) -> String:
	return ("Hello, my loves, and welcome back to the channel. This is a timeless reading, so "
		+ "whenever you find it is exactly when you were meant to. Let's shuffle. Oh. Oh, wow. "
		+ "Okay, I'm getting chills - the cards are really insisting on this one tonight.")


## An edit to the brief changes the NEXT episode, never the reading of this one.
func reads_source() -> bool:
	return false


func _script() -> String:
	var ep: CardEpisode = episode.call() if episode.is_valid() else null
	return ep.script() if ep != null else ""
