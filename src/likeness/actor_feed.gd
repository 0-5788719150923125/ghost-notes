extends RefCounted
class_name ActorFeed

## ActorFeed - an actor as the card that plays them reads it (next/likeness.md, "The cards never name
## each other"): the Actor card answers `feeds()` with `{"actor": ActorFeed}`, the panel collects it as
## it collects the steps a card adds ([method ReadingPanel.feed]), and the Likeness card asks the panel
## for it. A small typed contract, so neither card names the other.
##
## This one is the feed of no actor: nothing to play, nothing to make.


## The actor, or null.
func actor() -> ActorFolder:
	return null


## The actor's folder, absolute; "" for none.
func folder() -> String:
	var a := actor()
	return a.dir if a != null else ""


## The set the likeness plays, "" before there are sets.
func chosen_set() -> String:
	var a := actor()
	return a.chosen_set() if a != null else ""


## `{ready, busy, said}`: whether the chosen set can be played, whether anything is being made, and a
## line saying what is missing or under way.
func status() -> Dictionary:
	return {"ready": false, "busy": false, "said": "Pick or make an actor on the Actor card."}
