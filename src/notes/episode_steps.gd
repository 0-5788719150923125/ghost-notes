extends RefCounted
class_name EpisodeSteps

## EpisodeSteps - THE STEPS THE NOTE'S OTHER CARDS ADD ([EpisodeStep]), as the one card that lists them runs
## them: each refresh what their jobs ended with is landed and the episode the card shows is said to each,
## Generate makes them once the card's own steps are done, Stop stops them, and the card's buttons ask
## whether they are being made or still to make.
##
## ONCE, FOR EVERY CARD THAT LISTS THEM (the user, 2026-10-28, of a Letter's note whose tags waited at the
## bottom of its YouTube card: "keeping this tagging updated is going to be a game of whack-a-mole"). Cards',
## Proof's and the Actor's cards each kept a copy of this, and so did the note's own upload ([NoteUpload]);
## a card that made what goes out with no copy of its own - the Letter's - left the steps on the YouTube
## card, out of reach of its Generate.
##
## WHICH CARD LISTS THEM IS NOT THE CARD'S CHOICE: the one that hands the reading how it goes out does
## ([method ReadingPanel.hand_publish]); with none - a Voice alone - the YouTube card does ([NoteUpload]).
## Their rows are [EpisodeStepRows], or the card's own where its steps are one list (Cards').

## The card listing them, as their rows say where they are ("the Proof card").
var host := ""
## What makes the episode there, as their rows say it ("making the episode"; a note read as it is written,
## "Generate, or an export that goes up").
var makes := "making the episode"
## GENERATE ASKED FOR THEM: made once the card's own steps are done ([method tick]).
var asked := false

var _offered: Callable


## Listed by [param by], from what [param offered] () -> Array hands - the panel's steps ([method
## ReadingPanel.episode_steps]), never a card's - their episode made by [param makes_it].
func _init(by: String, offered: Callable, makes_it := "making the episode") -> void:
	host = by
	_offered = offered
	makes = makes_it


## Every step the note's cards add, as the panel holds them - listed or not, each is landed.
func offered() -> Array:
	return _offered.call() if _offered.is_valid() else []


## The ones listed now for [param feed]'s episode ([method EpisodeStep.wanted]): none without an episode
## kept anywhere.
func listed(feed: EpisodeFeed) -> Array:
	if feed == null or feed.folder().is_empty():
		return []
	return EpisodeStep.listed_of(offered())


## What a card's rows were built for: the listed steps' keys.
func key(feed: EpisodeFeed) -> String:
	return ",".join(PackedStringArray(listed(feed).map(func(s: EpisodeStep) -> String: return s.key)))


## The listed steps' names, lower-cased, for a card's line - only the ones not made yet with [param unmade].
func names(feed: EpisodeFeed, unmade := false) -> PackedStringArray:
	var out := PackedStringArray()
	for s in listed(feed):
		if not unmade or (s as EpisodeStep).to_make(feed):
			out.append((s as EpisodeStep).label.to_lower())
	return out


## EACH REFRESH: what every step's jobs ended with, landed; [param feed]'s episode said to the steps listed;
## and once Generate asked and the card's own steps are done ([param busy] false), each listed step made -
## from the episode's words, so only once they are written.
func tick(feed: EpisodeFeed, busy := false) -> void:
	for s in offered():
		(s as EpisodeStep).tick()
	var now := listed(feed)
	for s in now:
		(s as EpisodeStep).listed(host, feed, makes)
	if asked and not busy:
		asked = false
		for s in now:
			(s as EpisodeStep).generate(feed)


## Each listed step not made from [param feed]'s words as they are, made now (an export that goes up).
func generate(feed: EpisodeFeed) -> void:
	for s in listed(feed):
		(s as EpisodeStep).generate(feed)


## STOP what they are making of [param feed]'s episode - and, unless it is another than the one the card
## shows ([param shown]), what Generate asked of them.
func stop(feed: EpisodeFeed, shown: EpisodeFeed = null) -> void:
	if feed == null or shown == null or feed.folder() == shown.folder():
		asked = false
	if feed == null:
		return
	for s in offered():
		(s as EpisodeStep).stop(feed)


## Is a listed step being made for [param feed]'s episode?
func busy(feed: EpisodeFeed) -> bool:
	for s in listed(feed):
		if (s as EpisodeStep).busy(feed):
			return true
	return false


## Is a listed step still to make for [param feed]'s episode ([method EpisodeStep.to_make])?
func missing(feed: EpisodeFeed) -> bool:
	for s in listed(feed):
		if (s as EpisodeStep).to_make(feed):
			return true
	return false
