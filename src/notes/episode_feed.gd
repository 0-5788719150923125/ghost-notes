extends RefCounted
class_name EpisodeFeed

## EpisodeFeed - one episode a card makes, as the steps the note's other cards add to it read it
## ([EpisodeStep]).
##
## Where the cards on a note meet. A card that makes episodes (a table's [EpisodeCard]) says which it shows and names
## no card that makes a step from it; a card that makes one (the YouTube card's tags, [YouTubeTags]) reads the episode
## through this and names no card that makes it. The panel puts the two together ([method ReadingPanel.episode_feed]).
##
## One episode, not whichever is picked: a step started on one writes into it after another is picked. A maker hands a
## feed of its own (`EpisodeCard.Feed`); these defaults are an episode with nothing in it.


## The folder the episode is kept in, absolute: a step keeps what it makes here, so deleting the episode takes it
## along.
func folder() -> String:
	return ""


## The show's name: the note's title, "" for none.
func show_title() -> String:
	return ""


## The episode's own title, "" before it has one.
func episode_title() -> String:
	return ""


## The episode's number, what its show is drawn from: 0 for none.
func seed() -> int:
	return 0


## The description it goes up with, "" for none.
func description() -> String:
	return ""


## The tags the note gives every episode (its `tags:` line), and any its maker wrote for this one.
func tags() -> PackedStringArray:
	return PackedStringArray()


## The note's tags are [param tags] from now on: its `tags:` line (the one list its uploads take) replaced whole
## ([YouTubeTags]). "" once written, else why not.
func replace_tags(_tags: PackedStringArray) -> String:
	return "nothing keeps this episode's note's tags"


## The episode's words, as the voice says them, the marks taken out: "" until they are written, which is when a step
## made from them can be made.
func words() -> String:
	return ""


## What makes what is made from its words, as a row and the YouTube card say it ("Generate"; a note read as it is
## written, "Generate, or an export that goes up").
func made_by() -> String:
	return "Generate"


## The episode's voice, kept whole (next/editing.md step 3): its take's wav, absolute, where it was said from the
## episode's words as they stand - "" for none, and then the reading is said live. Whether it was said in the voices
## as they stand is the reading's to judge ([method ReadingPanel.kept_take]).
func take() -> String:
	return ""


## The episode's steps as they stood before, to be put back (the Body card's Restore): newest first,
## `[{at (unix seconds), said, key}]` - none for an episode that keeps no versions.
func versions() -> Array:
	return []


## Version [param key] (from [method versions]) put back: what stands now goes a version back in its place. "" done, else why not.
func put_back(_key: Variant) -> String:
	return "nothing here keeps versions"


## The episode's own pictures, absolute paths (a show's paintings), for a step that may be shown them; none for an
## episode painted nothing.
func pictures() -> PackedStringArray:
	return PackedStringArray()


## The pictures the episode's agents made, as a card shows them: `[{path (absolute), label, row (the Pipeline row that
## makes it again, "" none), group}]`, in the order they are made; none for an episode that painted nothing. Every
## maker says its own here - the Pictures card names none.
func made_pictures() -> Array:
	return []


## Who writes for the episode, `{agent, model, effort}`: the maker's own writer, so a step's words are written by
## whoever the show's are.
func writer() -> Dictionary:
	return {"agent": "claude", "model": "", "effort": ""}


## The words' fingerprint, "" while there are none. A step keeps the fingerprint of the words it was
## made from: once they are written again, it is no longer this episode's ([method EpisodeStep.fresh]).
func stamp() -> String:
	var w := words()
	return w.md5_text() if not w.is_empty() else ""
