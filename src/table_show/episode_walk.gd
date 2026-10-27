extends TextWalk
class_name EpisodeWalk

## EpisodeWalk - a show of cards reads its EPISODE, never the note: the note is the brief agents
## work from, and what the reader says is the script they wrote, step by step, for the episode up
## now. A [TextWalk] Cards hands its reading.

## The episode up now, asked each time: `() -> TableEpisode`, null while there is none.
var episode: Callable


func _init(current: Callable) -> void:
	episode = current


func body(_pulled: String) -> String:
	return _script()


func spoken(text: String, _title: String) -> Dictionary:
	return {"body": CardReading.speakable(text), "title": ""}


func cast_text(_written: String) -> String:
	return _script()


## A reader's minute (2026-10-25, the user: "make the test audio a bit longer"): the greeting, the
## shuffle's one-word sentences ("Oh. Oh, wow." - the shortest a voice is ever asked for), three cards,
## one of them reversed, a question to the viewer and the sign-off.
func test_passage(_fallback: String) -> String:
	return ("Hello, my loves, and welcome back to the channel. This is a timeless reading, so "
		+ "whenever you find it is exactly when you were meant to. Let's shuffle. Oh. Oh, wow. "
		+ "Okay, I'm getting chills - the cards are really insisting on this one tonight. "
		+ "The first card is the Three of Cups, and it came out upside down. Reversed, this is a "
		+ "gathering that has gone quiet: a friendship that needs a phone call more than a grand "
		+ "gesture. Who have you been meaning to reach? Next, the Tower. I know, I know - nobody "
		+ "likes to see it. But the Tower is not the end of the house; it is the end of the crack "
		+ "you have been painting over. And the last one is the Star. Breathe. After the storm "
		+ "there is a clear night, and you are allowed to rest in it. Take what resonates, leave "
		+ "the rest, and I'll see you in the next one.")


## An edit to the brief changes the NEXT episode, never the reading of this one.
func reads_source() -> bool:
	return false


func _script() -> String:
	var ep: TableEpisode = episode.call() if episode.is_valid() else null
	return ep.script() if ep != null else ""
