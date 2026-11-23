extends TextWalk
class_name EpisodeWalk

## EpisodeWalk - a show of cards reads its episode, never the note: the note is the brief agents work from, and what the reader
## says is the script written for the episode up now. A [TextWalk] Cards hands its reading. An episode shown in a Medium whose
## row's script rests the voice for its own work (a static `voiced(text, episode's document)`: the desk's pen) is read with
## those rests ([method _voiced]). A person renamed on the Voice card is renamed in the brief and in every episode
## ([method rename_read]).

## The episode up now, asked each time: `() -> TableEpisode`, null while there is none.
var episode: Callable
## Called once a person is renamed in the episodes, for the card to show them as they now are.
var renamed := Callable()


func _init(current: Callable) -> void:
	episode = current


func body(_pulled: String) -> String:
	return _script()


func spoken(text: String, _title: String) -> Dictionary:
	return {"body": CardReading.speakable(_voiced(text)), "title": ""}


## [param text] as the Medium the episode up now is shown in has its voice read it: the row's script's `voiced` where it has
## one, named by the row's path ([constant Medium.REGISTRY] `script`), else the text as it is.
func _voiced(text: String) -> String:
	var ep: TableEpisode = episode.call() if episode.is_valid() else null
	if ep == null:
		return text
	var path := String(Registry.field(Medium.REGISTRY, ep.medium(), "script", ""))
	var script: GDScript = load(path) as GDScript if not path.is_empty() else null
	if script == null or not script.has_method("voiced"):
		return text
	return String(script.call("voiced", text, ep.document()))


func cast_text(_written: String) -> String:
	return _script()


## An edit to the brief changes the next episode, never the reading of this one.
func reads_source() -> bool:
	return false


## A person is renamed where the show's people come from: the brief's words, every episode made from it ([EpisodeRename]), and
## the voice. Refused while there is no episode to say which show.
func rename_refused(old: String, new: String, words: String) -> String:
	var ep: TableEpisode = episode.call() if episode.is_valid() else null
	return EpisodeRename.refused(EpisodeRename.episodes_of(ep), old, new, words) if ep != null else ""


func rename_read(old: String, new: String) -> String:
	var ep: TableEpisode = episode.call() if episode.is_valid() else null
	if ep == null:
		return ""
	var err := EpisodeRename.rename(EpisodeRename.episodes_of(ep), old, new)
	if renamed.is_valid():
		renamed.call()
	return err


## The brief describes its people in its prose: the name is rewritten wherever it stands whole.
func renamed_words(words: String, old: String, new: String) -> String:
	return EpisodeRename.replaced(words, old, new)


func _script() -> String:
	var ep: TableEpisode = episode.call() if episode.is_valid() else null
	return ep.script() if ep != null else ""
