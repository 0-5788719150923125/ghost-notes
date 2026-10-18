extends RefCounted
class_name EpisodeFeed

## EpisodeFeed - one episode a card makes, as the steps the note's other cards add to it read it
## ([EpisodeStep]).
##
## WHERE THE CARDS ON A NOTE MEET (the user, 2026-10-18: "dependency inversion. It's okay to hook into
## an interface that populates that list of steps, but it would not be okay to tightly-couple the two
## cards"). A card that makes episodes - Cards' [EpisodeCard], Proof's [ProofCard] - hands one of these
## to each step it lists, and names no card that adds one; a card that adds a step - the YouTube card's
## tags ([YouTubeTags]) - reads the episode through it, and names no card that makes one. The panel puts
## the two together ([method ReadingPanel.episode_steps]).
##
## ONE EPISODE, not whichever is picked: a step started on one writes into it after another is picked.
## A maker hands a feed of its own (`EpisodeCard.Feed`, `ProofCard.Feed`); these defaults are an
## episode with nothing in it.


## The folder the episode is kept in, absolute: a step keeps what it makes here, so deleting the episode
## takes it along and another episode starts without it.
func folder() -> String:
	return ""


## The show's name: the note's title, "" for none.
func show_title() -> String:
	return ""


## The episode's own title, "" before it has one.
func episode_title() -> String:
	return ""


## The description it goes up with, "" for none.
func description() -> String:
	return ""


## The tags the note gives every episode (its `tags:` line), and any its maker wrote for this one.
func tags() -> PackedStringArray:
	return PackedStringArray()


## THE EPISODE'S WORDS, as the voice says them, the marks taken out - "" until they are written, which is
## when a step made from them can be made.
func words() -> String:
	return ""


## Who writes for the episode, `{agent, model, effort}`: the maker's own writer, so a step's words are
## written by whoever the show's are.
func writer() -> Dictionary:
	return {"agent": "claude", "model": "", "effort": ""}


## The words' fingerprint, "" while there are none. A step keeps the fingerprint of the words it was
## made from: once they are written again, it is no longer this episode's ([method EpisodeStep.fresh]).
func stamp() -> String:
	var w := words()
	return w.md5_text() if not w.is_empty() else ""
