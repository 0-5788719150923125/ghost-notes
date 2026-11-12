extends RefCounted
class_name PipelineSection

## PipelineSection - what one card hands a note's Pipeline card ([PipelineCard]; next/pipeline.md): its rows
## ([PipelineRow]), what Generate asks of it, and whether it is busy.
##
## The one way in: a card answers `pipeline() -> PipelineSection` and the panel adds it ([method
## ReadingPanel._offer_pipeline]); no card names another, none is told where it stands, and none lists anyone else's
## steps.
##
## A card subclasses it, usually as a small inner class over its own methods. The card keeps its own producer and how it
## ticks it; a section is only what the Pipeline card asks of that.

## Its heading.
var title := ""
## The card it is of: gone with it, so a card freed under the Pipeline card takes its section along ([method alive]).
## None for a section of nobody's.
var owner: Object = null:
	set(by):
		owner = by
		_owned = by != null
## The episode a step made from one reads, `() -> EpisodeFeed`: the panel hands it to every section ([EpisodeSteps]
## reads it). Whoever makes the note's episode says which is shown.
var episode := Callable()
## What it was last told to say: a refusal or a note from the card, said over [method line] until the next press.
var told := ""

var _owned := false


## Whether the card it is of is still here. (A freed object compares equal to null, so whether it had one is kept apart.)
func alive() -> bool:
	return not _owned or is_instance_valid(owner)


## Whether it is listed now: a section with nothing to make is no heading, and with none listed there is no card.
func shown() -> bool:
	return true


## ITS ROWS, in the order they are made: built new each refresh, four times a second, so what is slow to read is kept by
## the card ([PipelineRow]).
func rows() -> Array:
	return []


## What the group [param group] says of itself, beside its name ("The Tower, reversed"); "" for nothing.
func group_said(_group: String) -> String:
	return ""


## A line under the card's title, "" for none: what is being done, or what is ready.
func line() -> String:
	return ""


## Says [param text] over [method line], until the next press. A card's refusal: "Write a problem in the note first."
func tell(text: String) -> void:
	told = text


## EACH REFRESH, before its rows are read: what ended, landed.
func tick() -> void:
	pass


## GENERATE: everything it is missing. Generate's walk waits while [method busy] says so after this.
func make() -> void:
	pass


## What the ▶ on its heading says, "" for no ▶: making this section alone.
func make_tip() -> String:
	return ""


## Stops what it is making. What is finished is kept.
func stop() -> void:
	pass


## Whether it is making anything.
func busy() -> bool:
	return false


## Whether Generate would start more here while it is busy: making only some of what it is missing (a row made again,
## what was made from it waiting), so Generate widens it to the rest and what is under way carries on. False by
## default: a busy section is left to finish.
func widens() -> bool:
	return false


## Whether [method make] has anything to do. Asked at its turn in Generate's walk, so a step made from the words of the
## section before it answers once they are written.
func missing() -> bool:
	return true


## The panel is going: stop what must not outlive it. A card's own producer is the card's to stop.
func leave() -> void:
	pass


## The episode in [param feed] is being left or thrown away: stop what is being made of it.
func episode_left(_feed: EpisodeFeed) -> void:
	pass
