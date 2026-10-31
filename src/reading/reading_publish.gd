extends RefCounted
class_name ReadingPublish

## ReadingPublish - how a reading goes out: what its export is called, what is held while the take
## renders, and what an upload of it says.
##
## HANDED, NOT OVERRIDDEN (next/structure.md, step 12). A [ReadingPanel] renders the take, writes
## its sidecar and holds the YouTube card; the component whose show it is says the rest. This one
## is a note read aloud: named after the note ([method ReadingPanel.export_name]), the note's title on the
## upload, and the note as its own episode - its description and tags on the YouTube card ([NoteUpload]).
## Cards hands an [EpisodePublish]: an episode's title for a name, the episode pinned through the
## minutes of a render, upload notes and a chapter per card.


## What an export is called, without an extension; "" names it after the note when the note is its own episode
## ([method ReadingPanel.export_name]), else keeps the exporter's own name (see [member Exporter.name_provider]).
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


## What the component adds to the YouTube title's macros ([constant YouTube.MACROS]), laid over the
## note's Title and Episode, which the YouTube card reads from the Script card itself ([method
## YouTubeCard.name_from]): a show's own name (never the note's file name) and its episode's title and
## seed. {} adds nothing.
func upload_values() -> Dictionary:
	return {}


## WHAT THE PICKED EPISODE IS CALLED, for a component that names its episodes (Cards' producer, Proof's
## framer): what the Script card's Episode shows and edits ([method ScriptWriter.hand_field]) - null while
## it has none to edit. A note that is its own episode ([method note_is_episode]) keeps its own Episode
## (its `episode:` line), and this is never asked.
func episode_title() -> Variant:
	return null


## ...and [param title] names it from now on: "" once written, else why not.
func name_episode(_title: String) -> String:
	return "nothing here names an episode"


## The document a book or a table is drawn from ([method ReadingPanel.book_document]), given the
## reading's [param d] for [param body]: what the component adds to it.
func book(d: Dictionary, _body: String) -> Dictionary:
	return d


## The YouTube card is built: the component's own rows on it ([member YouTubeCard.extra]).
func youtube_built(_card: YouTubeCard) -> void:
	pass


## WHETHER THE NOTE IS ITS OWN EPISODE: read as it is written, it goes up with the description written
## on its YouTube card and its own tags, and the steps the note's other cards add are made from its words
## ([NoteUpload] - listed by the card that handed this, [method ReadingPanel.hand_publish]). False for a
## component that makes episodes and says what each goes up with.
func note_is_episode() -> bool:
	return true


## Who writes for the note's uploads (its tags), `{agent, model, effort}` - {} for the default writer.
func writer() -> Dictionary:
	return {}
