extends VBoxContainer
class_name NoteUpload

## NoteUpload - A NOTE READ AS IT IS WRITTEN IS ITS OWN EPISODE (2026-10-23, the user, of an actor's
## note: "I don't see anywhere it would be possible to write a description for videos uploaded in this
## way ... be sure that the auto-tagging mechanism should work as well"). Nothing on such a note makes
## episodes - its words are the author's, read by a Voice or an Actor - so its YouTube card holds what a
## show's card holds for its episodes: the description its uploads take (the card's own box, [method
## YouTubeCard.describe]), the note's tags as one list (its `tags:` line, as a show's), and THE STEPS THE
## NOTE'S OTHER CARDS ADD ([EpisodeStep] - the YouTube card's tags and painted thumbnail), listed here with the note as their
## episode ([Feed]): a row each with its ⟳ - UNLESS A CARD ON THE NOTE LISTS THEM UNDER ITS OWN, beside its
## Generate: the card that handed the reading how it goes out (the Actor's, the Letter's - handed this
## note's [method feed]; the user, 2026-10-23: "push the generate/regenerate step into the Actor card. Right
## now, it's buried at the bottom of the YouTube card"; [method ReadingPanel.hand_publish]). With no such
## card - a Voice alone - the rows are here ([EpisodeSteps], [EpisodeStepRows]).
##
## AN EXPORT THAT GOES UP MAKES THEM, when they are not made from the words as they are (a painted thumbnail only
## while none is - [method YouTubeThumbnail.owed]): started as the
## take starts rendering ([method start]) and waited for once it is rendered ([method settled], at most
## [constant SETTLE_MOST]), so the upload takes the tags and the thumbnail they made. What a step makes is kept in the note's
## own folder ([method folder_of]).
##
## Built by the [ReadingPanel] on its YouTube card when its publish says the note is its own episode
## ([method ReadingPublish.note_is_episode]); a show's card (Cards', Proof's) does all of this for its
## episodes itself.

const YouTube := preload("res://src/export/youtube.gd")
const TagField := preload("res://src/ui/tag_field.gd")

## How long an export waits for the steps an upload takes, in seconds: a painted thumbnail is a writer's
## brief and then a painting, minutes of both.
const SETTLE_MOST := 360.0
## Where the steps' rows say they are, and what makes the note's episode, when they are listed here.
const HOST := "this card"
const MAKES := "an export that goes up"

## Where each note's folder is: what the steps made from its words. A gate points it at its own.
const ROOT := "user://readings"
static var root := ROOT

var reading: ReadingPanel
var youtube: YouTubeCard
var _feed: Feed
var _tags_field: TagField
var _added: EpisodeSteps          # the steps the note's other cards add, the note their episode
var _added_rows: EpisodeStepRows  # ...and their rows, while no card on the note lists them
var _words := ""
var _pictures := PackedStringArray()
var _pictures_of := []            # what they were found for: the words' hash and the library's revision
var _t := 0.0


## THE NOTE AS THE STEPS READ IT: its folder, the video's title as it goes up, the description written on
## the YouTube card, the note's tags (and a step's to write over them), its words with the marks taken out,
## and who writes for its uploads.
class Feed extends EpisodeFeed:
	var upload: NoteUpload

	func _init(u: NoteUpload) -> void:
		upload = u

	func folder() -> String:
		return NoteUpload.folder_of(upload.reading.note_path)

	func episode_title() -> String:
		return upload.youtube.title_now()

	func description() -> String:
		return upload.youtube.description()

	func tags() -> PackedStringArray:
		return upload.note_tags()

	func replace_tags(tags: PackedStringArray) -> String:
		return upload.write_tags(tags)

	func words() -> String:
		return upload._words

	func pictures() -> PackedStringArray:
		return upload.pictures()

	func writer() -> Dictionary:
		var w := upload.reading.publish.writer()
		return w if not w.is_empty() else super.writer()


func _init(panel: ReadingPanel, card: YouTubeCard) -> void:
	reading = panel
	youtube = card
	_feed = Feed.new(self)
	add_theme_constant_override("separation", 8)
	youtube.describe()
	_tags_field = TagField.new()
	_tags_field.tooltip_text = ("The note's tags - its `tags:` line - the one list its videos go up with. With "
		+ "\"Write the note's tags\" ticked above, the writer replaces it with tags written from the note's "
		+ "words. × removes one; type in the box and a comma (or Enter) makes it a tag. YouTube takes 500 "
		+ "characters of tags in all; a dimmed tag is past that.")
	_tags_field.changed.connect(_save_tags)
	add_child(_tags_field)
	_added = EpisodeSteps.new(HOST, reading.episode_steps, MAKES)
	_added_rows = EpisodeStepRows.new(_added, " - once the note has words")
	_added_rows.redo.connect(_redo)
	add_child(_added_rows)


## The note as the steps read it, for a card that lists them under its own.
func feed() -> EpisodeFeed:
	return _feed


## Whether the steps are listed here: no card on the note lists them under its own.
func hosting() -> bool:
	return reading.steps_by.is_empty()


func _ready() -> void:
	refresh()


func _process(dt: float) -> void:
	_t -= dt
	if _t > 0.0:
		return
	_t = 0.25
	refresh()


## THE NOTE'S FOLDER, absolute, for the note at [param note]: named after its file, and told apart from
## another of that name by its path. "" for a note with no file.
static func folder_of(note: String) -> String:
	if note.is_empty():
		return ""
	var abs := ProjectSettings.globalize_path(note)
	var base := abs.get_file().get_basename().strip_edges().to_lower().replace(" ", "-").validate_filename()
	return ProjectSettings.globalize_path(root.path_join("%s-%s" % [base, abs.md5_text().substr(0, 8)]))


## A NOTE MOVED TAKES WHAT ITS STEPS MADE WITH IT, as [method LetterSketches.carry] its sketches: the folder of the note
## at [param from] renamed to the one at [param to]'s, never over one already there, and the author's only where the
## caller [param may] write them (a gate's own root always). "" once moved or with nothing to move, else why not.
static func carry(from: String, to: String, may: bool) -> String:
	var was := folder_of(from)
	var now := folder_of(to)
	if was.is_empty() or now.is_empty() or was == now or not DirAccess.dir_exists_absolute(was) or (not may and root == ROOT):
		return ""
	if DirAccess.dir_exists_absolute(now):
		return "%s has its own steps' work already, so that of %s is left in %s." % [to.get_file(), from.get_file(), was]
	return "" if DirAccess.rename_absolute(was, now) == OK else "What its steps made could not be moved from %s to %s." % [was, now]


## The note's `tags:` line, as a list.
func note_tags() -> PackedStringArray:
	var doc := reading.doc_source()
	return YouTube.split_tags(doc.field("tags")) if doc != null else PackedStringArray()


## THE NOTE'S TAGS ARE [param tags] from now on: its `tags:` line, and the chips. "" once written, else why
## not.
func write_tags(tags: PackedStringArray) -> String:
	var doc := reading.doc_source()
	if doc == null or not doc.set_field("tags", ", ".join(tags)):
		return "the tags could not be written into the note"
	_refresh_tags()
	return ""


## What an upload of the note says, over the panel's part [param base]: the note's tags, and any the panel
## gives that they do not hold - and the note's folder, where the steps keep what they made of it.
func upload_of(base: Dictionary) -> Dictionary:
	var out := base.duplicate()
	out["folder"] = _feed.folder()
	var tags := note_tags()
	for t in DataPath.strings(base.get("tags", [])):
		if not tags.has(t):
			tags.append(t)
	out["tags"] = Array(tags)
	return out


## THE NOTE'S OWN PICTURES, absolute, in the order it shows them: each its words call for that is painted
## ([Illustrations]) - a letter's pictures over the screen, a book's. A note read as it is written had handed
## its steps none, and its thumbnail was painted blind to them (2026-10-30, the user: "just random weird
## pictures, completely different from the video"). Found again only when the words or the library change.
func pictures() -> PackedStringArray:
	var box := reading.source_box()
	var body := box.text if box != null else ""
	var key := [body.hash(), Illustrations.revision]
	if key != _pictures_of:
		_pictures_of = key
		_pictures = PackedStringArray()
		for im in Manuscript.images(body):
			var path := Illustrations.path_for(String((im as Dictionary)["key"]))
			var abs := ProjectSettings.globalize_path(path) if not path.is_empty() else ""
			if not abs.is_empty() and not _pictures.has(abs):
				_pictures.append(abs)
	return _pictures


## EACH REFRESH: the note's words as the steps read them; while they are listed here, what the steps' jobs
## ended with, landed, the note said to the steps listed, and their rows; and the chips.
func refresh() -> void:
	var box := reading.source_box()
	_words = Manuscript.unspoken(reading.walk.body(box.text if box != null else "")).strip_edges()
	if hosting():
		_added.tick(_feed)
	_added_rows.refresh(_feed if hosting() else null)
	_refresh_tags()


## An export starts: each listed step not made from the note's words as they are, made now - only when it
## goes up.
func start() -> void:
	if not youtube.ticked():
		return
	refresh()
	_added.generate(_feed)


## A COROUTINE: the take is rendered, and the upload waits for the steps making what it takes (its tags,
## its painted thumbnail) - at most [constant SETTLE_MOST] - saying so on the panel's line.
func settled() -> void:
	if not youtube.ticked() or not _added.busy(_feed):
		return
	reading.status("Making the note's %s for the upload…" % ", ".join(_added.names(_feed, true)))
	var t0 := Time.get_ticks_msec()
	while _added.busy(_feed) and float(Time.get_ticks_msec() - t0) < SETTLE_MOST * 1000.0:
		await get_tree().create_timer(0.25).timeout
	if _added.busy(_feed):
		reading.status("The note's %s were still being made: this upload takes them as they were." % ", ".join(_added.names(_feed, true)))


## ⟳ on a step's row: made again now, from the note's words - which must be written first.
func _redo(step: EpisodeStep) -> void:
	if not step.redo(_feed):
		reading.status("%s waits for the note's words: write them on the Script card." % step.label)
	refresh()


## The chips follow the note's line, unless they are being typed in.
func _refresh_tags() -> void:
	if _tags_field.typing():
		return
	var tags := note_tags()
	if _tags_field.get_tags() != tags:
		_tags_field.set_tags(tags)
	_tags_field.mark(YouTube.left_out(tags))


## A chip added or removed: the note's `tags:` line, written at once.
func _save_tags() -> void:
	var doc := reading.doc_source()
	if doc == null or not doc.set_field("tags", ", ".join(_tags_field.get_tags())):
		reading.status("The tags could not be saved into the note.")
	_tags_field.mark(YouTube.left_out(_tags_field.get_tags()))
