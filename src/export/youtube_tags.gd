extends EpisodeStep
class_name YouTubeTags

## YouTubeTags - each episode's tags, written from what it says (the user, 2026-10-18: "I want to be
## able to enable/disable the management of tags applied to the video, based upon the script/content of
## the video. Today, we have just a static list. I would like to allow the 'Generate' button to
## override/rewrite those tags, to be something more appropriate to the upload").
##
## A STEP OF THE EPISODE ([EpisodeStep]), offered by the YouTube card while its "Write each episode's
## tags" box is ticked: the card that makes episodes lists it under its own steps, Generate writes it
## with them and its ⟳ writes it again. The writer is the show's own; it reads the episode - its words,
## title and description - and the note's tags, keeps those that fit and leaves out the rest
## (rules/youtube/tags.yaml).
##
## THE ANSWER REPLACES THE NOTE'S TAGS (the user, 2026-10-19: "it's confusing, because I never know which
## tags are truly going to be applied ... I'd prefer to see just one, unified list"): written over the
## note's `tags:` line as it lands ([method EpisodeFeed.replace_tags]), the one list the YouTube card
## shows and every upload takes - edited there by hand like any other. What landed is also kept in the
## episode's folder (`youtube_tags.json`) with the fingerprint of the words it was written from, which is
## all that says the step is made: words written again make it stale, and Generate writes new ones.

const YouTube := preload("res://src/export/youtube.gd")
## The fewest usable tags an answer must hold to be kept.
const FEWEST := 3

var _wanted: Callable


## [param wanted_by]: () -> bool, the card's box.
func _init(wanted_by := Callable()) -> void:
	key = "youtube_tags"
	label = "Tags"
	again = "Write this episode's tags again"
	first = "Write this episode's tags now"
	waits = "written once the episode's words are"
	unmade = "not written for this episode yet"
	tier = "fast"
	_wanted = wanted_by


func wanted() -> bool:
	return _wanted.is_valid() and bool(_wanted.call())


func _prompt(feed: EpisodeFeed) -> Dictionary:
	return prompt(feed.show_title(), feed.episode_title(), feed.description(), feed.tags(), feed.words())


## What the writer is told, from the show's name, the episode's [param title] and [param description],
## the tags the note gives every video ([param given]) and the episode's [param words]. Static and pure
## for the gate.
static func prompt(show: String, title: String, description: String, given: PackedStringArray,
		words: String) -> Dictionary:
	return {"system": Rules.say("youtube/tags.system", {}),
		"prompt": Rules.say("youtube/tags.prompt", {"show": show.strip_edges(), "title": title.strip_edges(),
			"description": description.strip_edges(), "given": ", ".join(given), "words": words.strip_edges(),
			"most": str(YouTube.TAGS_MAX)})}


## The writer's answer, landed, and written over the note's tags; why not, when it cannot be.
func _land(text: String, feed: EpisodeFeed) -> Variant:
	var got: Variant = land(TextGen.extract_json(text))
	if got is Dictionary:
		var err := feed.replace_tags(DataPath.strings((got as Dictionary)["tags"]))
		if not err.is_empty():
			return err
	return got


## The writer's answer [param d] as kept: `{tags}`, each cleaned (a hashtag sign dropped), each once -
## or why it cannot be kept. Static and pure for the gate.
static func land(d: Variant) -> Variant:
	var raw: Variant = (d as Dictionary).get("tags") if d is Dictionary else d
	if not (raw is Array):
		return "the answer held no list of tags"
	var clean: Array = []
	var seen := {}
	for t in DataPath.strings(raw):
		var c := YouTube.clean_tag(String(t).trim_prefix("#"))
		if not c.is_empty() and not seen.has(c.to_lower()):
			seen[c.to_lower()] = true
			clean.append(c)
	if clean.size() < FEWEST:
		return "the answer held %d usable tag%s" % [clean.size(), "" if clean.size() == 1 else "s"]
	return {"tags": clean}


func summary(m: Dictionary) -> String:
	var t := DataPath.strings(m.get("tags", []))
	return "%d tag%s: %s" % [t.size(), "" if t.size() == 1 else "s", ", ".join(t)]
