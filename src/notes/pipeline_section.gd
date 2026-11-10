extends RefCounted
class_name PipelineSection

## PipelineSection - what one card hands a note's Pipeline card ([PipelineCard]; next/pipeline.md): its rows
## ([PipelineRow]), what Generate asks of it, and whether it is busy.
##
## THE ONE WAY IN (the user, 2026-11-02: "the pipeline is not a unified, generic card - it is multiple branching paths,
## and we are forced to build logic that pushes steps into different lists, at different times, depending upon the
## context"). A card answers `pipeline() -> PipelineSection` and the panel adds it ([method ReadingPanel._offer_pipeline]):
## no card names another, none is told where it stands, and none lists anyone else's steps.
##
## A CARD SUBCLASSES IT, usually as a small inner class over its own methods. The card keeps its own producer, and how it
## ticks it; a section is only what the Pipeline card asks of that.

## Its heading.
var title := ""
## THE CARD IT IS OF: gone with it, so a card freed under the Pipeline card takes its section along ([method alive]). None for
## a section of nobody's.
var owner: Object = null:
	set(by):
		owner = by
		_owned = by != null
## THE EPISODE A STEP MADE FROM ONE READS, `() -> EpisodeFeed`: the panel hands it to every section ([EpisodeSteps] reads
## it). Whoever makes the note's episode says which is shown, and no section need know who.
var episode := Callable()
## WHAT IT WAS LAST TOLD TO SAY: a refusal or a note from the card, said over [method line] until the next press.
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


## WHETHER GENERATE WOULD START MORE HERE WHILE IT IS BUSY (the user, 2026-11-09: "Can we perhaps make that "Generate" button available
## for clicking immediately after steps become tainted ... That way, I could click both buttons at the same time - and come back to the
## full pipeline finished later"): making only some of what it is missing - a row made again, what was made from it waiting - so Generate
## widens it to the rest, and what is under way carries on. False by default: a busy section is left to finish.
func widens() -> bool:
	return false


## Whether [method make] has anything to do. Asked at its turn in Generate's walk, so a step made from the words of the
## section before it answers once they are written.
func missing() -> bool:
	return true


## THE PANEL IS GOING: stop what must not outlive it. A card's own producer is the card's to stop.
func leave() -> void:
	pass


## THE EPISODE IN [param feed] IS BEING LEFT OR THROWN AWAY: stop what is being made of it.
func episode_left(_feed: EpisodeFeed) -> void:
	pass
