extends TextWalk
class_name ProofWalk

## ProofWalk - a Proof note reads its EPISODE's lesson, never the note: the note is the problem the
## agents work from, and what the voice says is the lesson they wrote. A [TextWalk] the Proof card
## hands its reading, as Cards hands [EpisodeWalk].
##
## THE VOICE'S RESTS ARE THE PEN'S: [method DeskScript.speakable] gives the pen a moment to come down
## before each dictation, a page's turn where the pad fills, and a rest after a dictation the pen would
## trail - each sized from the episode's ink exactly as the desk writes and lays it out
## ([method ProofEpisode.lengths], [method ProofEpisode.sizes]) - so the voice and the pen keep time.

## The episode up now, asked each time: `() -> ProofEpisode`, null while there is none.
var episode: Callable


func _init(current: Callable) -> void:
	episode = current


func body(_pulled: String) -> String:
	return _script()


func spoken(text: String, _title: String) -> Dictionary:
	var ep: ProofEpisode = episode.call() if episode.is_valid() else null
	return {"body": DeskScript.speakable(text, ep.lengths() if ep != null else {},
		ep.sizes() if ep != null else {}), "title": ""}


func cast_text(_written: String) -> String:
	return _script()


## A teacher's minute at the desk (2026-10-25, the user: "make the test audio a bit longer"): a
## question, a definition with its examples, an argument a step at a time, and the end of it.
func test_passage(_fallback: String) -> String:
	return ("Here's a question that sounds too simple to be hard. Take the numbers that can't be split "
		+ "into smaller equal groups - two, three, five, seven. Do they ever run out? Let's find out "
		+ "together, one line at a time. Suppose they do, and that we have written every one of them "
		+ "down. Now multiply them all together: two times three times five times seven, and so on, "
		+ "to the end of the list. Then add one. Divide that new number by two, and one is left over. "
		+ "Divide it by three: one again. In fact, every number on our list leaves exactly one behind. "
		+ "So either the new number can't be split at all, or it is built from one we never wrote "
		+ "down. Either way, the list was missing something. There is no last one. That's the whole "
		+ "proof, and it is more than two thousand years old.")


## An edit to the note changes the NEXT episode, never the lesson of this one.
func reads_source() -> bool:
	return false


func _script() -> String:
	var ep: ProofEpisode = episode.call() if episode.is_valid() else null
	return ep.script() if ep != null else ""
