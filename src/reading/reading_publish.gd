extends RefCounted
class_name ReadingPublish

## ReadingPublish - how a reading goes out: what its export is called, what is held while the take
## renders, and what an upload of it says.
##
## HANDED, NOT OVERRIDDEN (next/structure.md, step 12). A [ReadingPanel] renders the take, writes
## its sidecar and holds the YouTube card; the component whose show it is says the rest. This one
## is a note read aloud: the exporter's own name, the note's title on the upload, nothing more.
## Cards hands an [EpisodePublish]: an episode's title for a name, the episode pinned through the
## minutes of a render, upload notes and a chapter per card.


## What an export is called, without an extension; "" keeps the exporter's own name (see
## [member Exporter.name_provider]).
func name() -> String:
	return ""


## Before the take renders: hold what it is of, for as long as it renders (the panel stays live
## through minutes of synthesis). False when there is nothing to export, and nothing renders.
func before_take() -> bool:
	return true


## After it renders - [param path] is the take, or "" when it did not: let go of what
## [method before_take] held, and write what goes with the take. Returns a line for the panel's
## status, or "" to leave it.
func after_take(_path: String) -> String:
	return ""


## The component's part of an upload of [param take] - a description, tags, a thumbnail's moment,
## a record - or {} when it has nothing to upload yet (see [method YouTubeCard.meta]).
func upload_base(_take: String) -> Dictionary:
	return {"tags": []}


## What the YouTube title's macros are worth now ([method YouTube.expand_title]), given the
## reading's own [param own] (the note's title).
func upload_values(own: Dictionary) -> Dictionary:
	return own


## The document a book or a table is drawn from ([method ReadingPanel.book_document]), given the
## reading's [param d] for [param body]: what the component adds to it.
func book(d: Dictionary, _body: String) -> Dictionary:
	return d


## The YouTube card is built: the component's own rows on it ([member YouTubeCard.extra]).
func youtube_built(_card: YouTubeCard) -> void:
	pass
