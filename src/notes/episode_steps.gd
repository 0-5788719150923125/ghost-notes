extends PipelineSection
class_name EpisodeSteps

## EpisodeSteps - the steps one card makes from the episode another card makes ([EpisodeStep], [EpisodeFeed]), as a
## section of the note's Pipeline card ([PipelineSection]): each refresh what their jobs ended with is landed and the
## episode shown is said to each, Generate makes them at their turn (after the section that writes the words) and Stop
## stops them.
##
## The card that offers them hands this (the YouTube card's "YouTube" section: its tags and thumbnail), so where they
## are listed is never a question. Which episode they are of is the panel's to say ([member PipelineSection.episode],
## [method ReadingPanel.episode_feed]).

var _offered: Callable


## A section called [param named], of what [param offered] () -> Array hands - the card's steps.
func _init(named := "", offered := Callable(), by: Object = null) -> void:
	title = named
	_offered = offered
	owner = by


## The episode shown, null with none.
func current() -> EpisodeFeed:
	return episode.call() if episode.is_valid() else null


## Every step offered - listed or not, each is landed.
func offered() -> Array:
	return _offered.call() if _offered.is_valid() else []


## The ones listed now for [param feed]'s episode ([method EpisodeStep.wanted]): none without an episode kept anywhere.
func listed(feed: EpisodeFeed) -> Array:
	if feed == null or feed.folder().is_empty():
		return []
	return EpisodeStep.listed_of(offered())


## The listed steps' names, lower-cased, for a line - only the ones not made yet with [param unmade].
func names(feed: EpisodeFeed, unmade := false) -> PackedStringArray:
	var out := PackedStringArray()
	for s in listed(feed):
		if not unmade or (s as EpisodeStep).to_make(feed):
			out.append((s as EpisodeStep).label.to_lower())
	return out


## Each listed step not made from [param feed]'s words as they are, made now.
func generate(feed: EpisodeFeed) -> void:
	for s in listed(feed):
		(s as EpisodeStep).generate(feed)


## Is a listed step being made for [param feed]'s episode?
func busy_on(feed: EpisodeFeed) -> bool:
	for s in listed(feed):
		if (s as EpisodeStep).busy(feed):
			return true
	return false


## Is a listed step still to make for [param feed]'s episode ([method EpisodeStep.to_make])?
func missing_on(feed: EpisodeFeed) -> bool:
	for s in listed(feed):
		if (s as EpisodeStep).to_make(feed):
			return true
	return false


# --- as a section of the Pipeline card ---------------------------------------------------------------------------------

func shown() -> bool:
	return not listed(current()).is_empty()


func tick() -> void:
	for s in offered():
		(s as EpisodeStep).tick()
	var feed := current()
	for s in listed(feed):
		(s as EpisodeStep).listed(feed)


func rows() -> Array:
	var feed := current()
	var words := feed != null and not feed.words().is_empty()
	var out: Array = []
	for s in listed(feed):
		var step: EpisodeStep = s
		var made := not step.made(feed).is_empty()
		var r := PipelineRow.new(step.key, step.label)
		var st := step.state(feed)
		r.state = String({"ready": "made", "running": "running", "queued": "queued", "failed": "failed"}.get(st,
			"stale" if made else "missing"))
		r.said = step.said(feed)
		r.wraps = st == "running" or st == "queued"
		r.again = (step.again if made else step.first) + ("" if words else " - once there are words to make it from")
		r.open = words and not step.busy(feed)
		r.redo = func() -> void: step.redo(feed)
		out.append(r)
	return out


func make() -> void:
	generate(current())


func make_tip() -> String:
	return "Make what is missing of these, from the words as they are."


func stop() -> void:
	var feed := current()
	if feed == null:
		return
	for s in offered():
		(s as EpisodeStep).stop(feed)


func busy() -> bool:
	return busy_on(current())


func missing() -> bool:
	return missing_on(current())


func leave() -> void:
	stop()


func episode_left(feed: EpisodeFeed) -> void:
	if feed == null:
		return
	for s in offered():
		(s as EpisodeStep).stop(feed)
