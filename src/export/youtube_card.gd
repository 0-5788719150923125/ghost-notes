extends VBoxContainer
class_name YouTubeCard

## YouTubeCard - the YouTube component's card (2026-10-07, the user: "add a little '+' button near
## those labels... 'youtube' should be an option. When we add it, a new card is created"): whether
## an export goes up, what it is called, who may see it and the playlist it joins - and the Google
## client and the sign-in an upload needs, which used to live in the export button's menu. Its block
## in a document is `youtube:`.
##
## THE TITLE IS A TEMPLATE ([method YouTube.expand_title]) of the macros in [constant YouTube.MACROS] - so
## one note makes many videos, each named as it goes up. ITS NAMES ARE THE SCRIPT CARD'S (2026-10-25, the
## user: "nowhere is an episode title actually an option here ... it shouldn't even be possible to keep
## missing details like this"): every panel that shows this card binds it to its Script card ([method
## name_from]), which shows Title, Episode, Author and Book from then on, and the card reads %title%,
## %episode%, %author% and %book% from there itself - no panel fills them its own way. A panel adds only
## what it alone knows ([member values]: a show's own name, its episode's seed), and what it hands with an
## export (the episode rendered) is laid over the note's names, never in place of them. WHAT IT CLAIMS IS
## WHAT THE NOTE FILLS: the title box's tooltip
## names only those macros, and a title naming one the note does not fill (%seed% on an actor's note) is
## said under it and does not go up - the export refuses before it renders ([method why_not]). The rest of
## an upload only the panel knows (a show's description and tags, its thumbnail's moment) comes through
## [member extra], a slot under the card's own rows, and [method meta].
##
## THE CATEGORY is the card's too ([constant YouTube.CATEGORIES]): People & Blogs until it is changed,
## so a math channel's note can go up as Education.
##
## THE CHANNEL IS THE NOTE'S (the user, 2026-10-17: "target different channels for different kinds of
## project ... the list of available clients should be a toggle, such that switching is easy"): a
## toggle per channel signed in here, named as YouTube names it ([method YouTube.channels]), the note's
## own pressed, and "+" to sign in to another. The block keeps the channel's id and its name, so a
## note whose channel is not signed in here still shows it, dimmed, to sign in to; a block that names
## none takes the first channel kept. A playlist is a channel's, so another channel clears it. The
## account rows below speak for the channel picked.
##
## ONE LIST OF TAGS (the user, 2026-10-19: "I never know which tags are truly going to be applied ...
## I'd prefer to see just one, unified list"): the note's `tags:` line, which the panel shows in
## [member extra] and every upload takes. With "Write each episode's tags" ticked (2026-10-18: "allow
## the 'Generate' button to override/rewrite those tags"), the card adds a step to the episodes the note
## makes ([YouTubeTags], an [EpisodeStep] - offered by [method episode_steps], never handed to a card by
## name): the card that makes them lists it, writes it with the episode and again on its ⟳, and what it
## writes REPLACES that list. The box stands at the top, beside "Upload after export" (the user: "where
## it belongs"); a line under the list says what the writer is doing to it.
##
## THE THUMBNAIL IS CHOSEN HERE, AND ONLY HERE (the user, 2026-10-28: "I'm not a fan of this implicit,
## undocumented behavior"): a show's card had handed every upload a frame of its title screen. Now the
## card's Thumbnail says ([constant YouTube.THUMBNAILS]): YouTube's own choice (a new card's), a frame of
## the title screen - asked of the take, which says whether it opened on its title ([method
## Openings.of_take]) - or one PAINTED for the episode by the writer and the painter picked under it, a
## step this card offers the card that makes the episode ([YouTubeThumbnail]), shown here once it is
## painted. What cannot be had is said under it, and the video goes up with YouTube's. EVERY ONE PAINTED IS
## KEPT (2026-10-30, the user: "there is no way to cycle backward/forward through generated thumbnails, as
## the generated in-episode pictures can be cycled through"): ‹ › under it picks the one that goes up, as a
## book's pictures are stepped through, and ✕, pressed twice, deletes the one shown. A CLICK ON IT OPENS IT
## FULL SIZE (2026-10-30: "like we do elsewhere"), in a window of its own as a book's pictures open
## ([method open_thumbnail]), with what the writer asked of it and the same steps through its versions. "MATCH
## THE VIDEO'S PICTURES" (2026-10-30: "akin to the full-screen images' 'match earlier' option"), ticked on a new
## card, paints it in the look of the episode's own pictures, as a book's picture is matched to the ones before it.
##
## A NOTE READ AS IT IS WRITTEN IS DESCRIBED HERE (2026-10-23, the user, of an actor's note: "I don't see
## anywhere it would be possible to write a description for videos uploaded in this way"): its panel shows
## the box ([method describe]) when nothing on the note writes its episodes' descriptions - a show's card
## keeps its own - and the block keeps what is written; an upload takes it first, then what the panel adds
## (an actor's likeness, said by the code).
##
## TICKING "UPLOAD AFTER EXPORT" SETS UPLOADS UP as far as they need, visibly: the Google client file
## the first time, then the sign-in - and the box ticks once both are done (a cancel leaves it clear).
## A PLAYLIST takes more of the account than an upload, so the wider sign-in is asked for only when
## the list is first loaded ([constant YouTube.PLAYLIST_SCOPE]). The dialogs are the exporter's,
## beside the upload that waits on them (see [method Exporter.youtube_sign_in]).
##
## THE PLAYLIST IS NAMED AS YOUTUBE NAMES IT NOW (2026-10-26, the user: "every time I restart, it keeps
## reverting to 'Tarot' ... I shouldn't have to reload"): the block kept the title it was picked under, ↻
## showed the new one and never kept it, so a playlist renamed since came back by its old name at every
## opening, and the description named it so. A loaded list's title is the block's, and a card opening on
## a playlist loads the list itself when its sign-in may already see them, asking and saying nothing
## ([method _look_quietly]).

const YouTube := preload("res://src/export/youtube.gd")

## The block this card keeps under a document's `ghost:` key.
const KEY := "youtube"
## A new card's block: nothing goes up until the box is ticked, and then privately.
const DEFAULTS := {"upload": false, "title": YouTube.TITLE_TEMPLATE, "privacy": YouTube.PRIVACY,
	"category": YouTube.CATEGORY, "playlist": "", "playlist_title": "", "channel": "", "channel_name": "",
	"write_tags": false, "description": "", "thumbnail": YouTube.THUMBNAIL,
	"thumbnail_writer": "claude", "thumbnail_writer_model": "", "thumbnail_writer_effort": "",
	"thumbnail_painter": "codex", "thumbnail_painter_model": "", "thumbnail_painter_effort": "", "thumbnail_match": true}
## The Script card's rows the title's macros are read from ([method name_from]): [constant YouTube.MACROS]'
## keys of the same names.
const NAMES := ["title", "episode", "author", "book"]

signal noted(msg: String)

## Set by a panel that adds to the title's macros: () -> Dictionary, laid over the Script card's names - a
## show's own name (never the note's file name), its picked episode's title and seed. Unset, the names alone.
var values: Callable
## Where the panel puts rows of its own (a show's description and tags), under the card's.
var extra: VBoxContainer
## The exporter whose sign-in and upload this card drives: Chrome's, unless a gate hands it one.
var exporter: Node

var _upload: CheckBox
var _chips: HFlowContainer
var _chip_group: ButtonGroup
var _add: Button
var _title: LineEdit
var _preview: Label
var _privacy: OptionButton
var _category: OptionButton
var _playlist: OptionButton
var _reload: Button
var _account: Label
var _sign: Button
var _remove: Button
var _client: Button
var _resume: Button
var _state: Label
var _write_tags: CheckBox
var _desc: TextEdit
var _tags_note: Label
## The step that writes each episode's tags, while the box is ticked.
var _tags: YouTubeTags
var _thumbnail: OptionButton
var _thumb_writer: AgentPick
var _thumb_painter: AgentPick
var _thumb_match: CheckBox
var _thumb_note: Label
var _thumb_view: TextureRect
var _thumb_steps: HBoxContainer   # ‹ v2/3 › ✕ under the painted one
var _thumb_back: Button
var _thumb_at: Label
var _thumb_on: Button
var _thumb_del: Button
var _thumb_window: Window = null  # the thumbnail at full size, opened by a click on it
## The step that paints each episode's thumbnail, while the Thumbnail is Painted.
var _thumb: YouTubeThumbnail
var _thumb_seen := []           # what the thumbnail's rows were last drawn for
var _thumb_shown := ""          # the picture the preview holds, with its time
var _tags_seen := []            # what the tag rows were last drawn for
## The Script card the note's names are read from ([method name_from]); null until a panel binds it.
var _names: ScriptWriter
## The channel the note's uploads go to, kept whole even when it is not signed in here: `{id, name}`.
var _chan := {"id": "", "name": ""}
## The playlist the block names, kept whole even before the list is loaded: `{id, title}`.
var _list := {"id": "", "title": ""}
var _lists: Array = []          # the channel's playlists, as last loaded
var _looked := ""               # the channel they were last asked for, by ↻ or as the card opened
var _loading := false
var _poll := 0.0
var _seen := []                 # what the account rows were last drawn for
var _tip := ""                  # the title's tooltip as last set, before Boot.wrap_tip folded it on hover


## This card for a note's panel, from what the panel says of itself ([method NoteCards.make]):
## it asks nothing of it.
static func for_note(_ctx: Dictionary) -> YouTubeCard:
	return YouTubeCard.new()


func _init() -> void:
	add_theme_constant_override("separation", 8)
	_upload = CheckBox.new()
	_upload.text = "Upload after export"
	_upload.add_theme_font_size_override("font_size", 12)
	_upload.tooltip_text = ("Once an export of this note is saved, upload it to the YouTube channel picked below. "
		+ "Ticking it the first time asks for your Google OAuth client file (the JSON from Google Cloud), "
		+ "then opens your browser to sign in.")
	_upload.toggled.connect(_on_tick)
	var boxes := HFlowContainer.new()
	boxes.add_theme_constant_override("h_separation", 12)
	add_child(boxes)
	boxes.add_child(_upload)
	_write_tags = CheckBox.new()
	_write_tags.text = "Write each episode's tags"
	_write_tags.add_theme_font_size_override("font_size", 12)
	_write_tags.tooltip_text = ("The show's writer writes tags for each episode from what it says - its words, "
		+ "title and description - and they REPLACE the note's tags below (the writer is shown those, and keeps "
		+ "the ones that fit). The card that makes the episode lists them as a step: they are written along "
		+ "with the episode, and ⟳ on their row writes them again. A note read as it is written is its own "
		+ "episode: an export that goes up writes its tags from its words once they have changed, and ⟳ on "
		+ "their row writes them now.")
	_write_tags.toggled.connect(func(_on: bool) -> void: refresh())
	boxes.add_child(_write_tags)
	# WITH THE CARD'S OTHER BOXES (the user, 2026-10-30: "at the top, near the other options"), shown while the
	# Thumbnail is Painted
	_thumb_match = CheckBox.new()
	_thumb_match.text = "Match the video's pictures"
	_thumb_match.add_theme_font_size_override("font_size", 12)
	_thumb_match.button_pressed = true
	_thumb_match.tooltip_text = ("Paint each episode's thumbnail (Thumbnail: Painted, below) in the look of the video's own "
		+ "pictures - a show's paintings, a letter's or a book's pictures - as each picture of a book is matched to the "
		+ "ones before it: the writer is shown them, and the painter is handed a few to paint after. Clear, it is "
		+ "designed and painted free of them.")
	_thumb_match.toggled.connect(func(_on: bool) -> void: refresh())
	boxes.add_child(_thumb_match)
	_chips = HFlowContainer.new()
	_chips.add_theme_constant_override("h_separation", 4)
	_chips.add_theme_constant_override("v_separation", 4)
	_chip_group = ButtonGroup.new()
	_add = Button.new()
	_add.text = "+"
	_add.focus_mode = Control.FOCUS_NONE
	_add.add_theme_font_size_override("font_size", 12)
	_add.tooltip_text = ("Sign in to another channel: your browser opens, and you choose the Google account - "
		+ "and the channel, when Google asks which. It is named here as YouTube names it.")
	_add.pressed.connect(_on_add)
	_chips.add_child(_add)
	_row("Channel", _chips)
	_chan = _first_channel()
	_title = LineEdit.new()
	_title.placeholder_text = YouTube.TITLE_TEMPLATE
	_title.tooltip_text = _title_tip({})
	_title.text = YouTube.TITLE_TEMPLATE
	_title.text_changed.connect(func(_t: String) -> void: refresh())
	_row("Title", _title)
	_preview = _small("")
	add_child(_preview)
	_privacy = OptionButton.new()
	_privacy.fit_to_longest_item = false
	_privacy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for k in YouTube.PRIVACIES:
		_privacy.add_item(String(YouTube.PRIVACIES[k]))
		_privacy.set_item_metadata(_privacy.item_count - 1, k)
	_privacy.tooltip_text = ("Who may see the video: only you (Private), anyone with the link (Unlisted), "
		+ "or everyone (Public). A Google Cloud project YouTube has not audited keeps every upload "
		+ "private whatever this says.")
	_privacy.item_selected.connect(func(_i: int) -> void: refresh())
	_row("Visibility", _privacy)
	_category = OptionButton.new()
	_category.fit_to_longest_item = false
	_category.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for k in YouTube.CATEGORIES:
		_category.add_item(String(YouTube.CATEGORIES[k]))
		_category.set_item_metadata(_category.item_count - 1, k)
	_category.tooltip_text = "The category YouTube files the video under, as YouTube Studio lists them."
	_select(_category, YouTube.CATEGORY)
	_row("Category", _category)
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 6)
	_playlist = OptionButton.new()
	_playlist.fit_to_longest_item = false
	_playlist.clip_text = true
	_playlist.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_playlist.tooltip_text = ("The playlist the video is added to once it is up. ↻ loads your channel's "
		+ "playlists - the first time, that signs in again, asking to see and manage them.")
	_playlist.item_selected.connect(_on_playlist)
	prow.add_child(_playlist)
	_reload = Button.new()
	_reload.text = "↻"
	_reload.tooltip_text = "Load the picked channel's playlists."
	_reload.focus_mode = Control.FOCUS_NONE
	_reload.pressed.connect(load_playlists)
	prow.add_child(_reload)
	_row("Playlist", prow)
	_fill_playlists()
	_build_thumbnail()
	_desc = TextEdit.new()
	_desc.placeholder_text = "Description"
	_desc.tooltip_text = ("The video's description, as it goes up. The playlist it joins is named and linked "
		+ "under it, and what the note's cards add (an actor's likeness, said) between the two.")
	_desc.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_desc.custom_minimum_size = Vector2(0, 120)
	_desc.visible = false
	add_child(_desc)
	extra = VBoxContainer.new()
	extra.add_theme_constant_override("separation", 8)
	add_child(extra)
	_build_tags()
	add_child(HSeparator.new())
	_account = _small("")
	add_child(_account)
	var arow := HBoxContainer.new()
	arow.add_theme_constant_override("separation", 6)
	add_child(arow)
	_sign = Button.new()
	_sign.focus_mode = Control.FOCUS_NONE
	_sign.add_theme_font_size_override("font_size", 12)
	_sign.pressed.connect(_on_sign)
	arow.add_child(_sign)
	_remove = Button.new()
	_remove.text = "Remove"
	_remove.focus_mode = Control.FOCUS_NONE
	_remove.add_theme_font_size_override("font_size", 12)
	_remove.pressed.connect(_on_remove)
	arow.add_child(_remove)
	_client = Button.new()
	_client.focus_mode = Control.FOCUS_NONE
	_client.add_theme_font_size_override("font_size", 12)
	_client.pressed.connect(_on_client)
	arow.add_child(_client)
	_resume = Button.new()
	_resume.focus_mode = Control.FOCUS_NONE
	_resume.add_theme_font_size_override("font_size", 12)
	_resume.clip_text = true
	_resume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_resume.tooltip_text = ("An export's upload was cut off - by a quit, a lapsed sign-in or a dropped "
		+ "connection. It carries on from where YouTube says it stopped.")
	_resume.pressed.connect(_on_resume)
	add_child(_resume)
	_state = _small("")
	add_child(_state)


func _ready() -> void:
	refresh()


## THE THUMBNAIL'S ROWS: the choice, the writer and the painter of a painted one (shown only then), the
## line that says what goes up, and the painted one itself.
func _build_thumbnail() -> void:
	_thumbnail = OptionButton.new()
	_thumbnail.fit_to_longest_item = false
	_thumbnail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tips := PackedStringArray(["The picture the video is shown by before it is watched."])
	for k in YouTube.THUMBNAILS:
		_thumbnail.add_item(Registry.label(YouTube.THUMBNAILS, k))
		_thumbnail.set_item_metadata(_thumbnail.item_count - 1, k)
		tips.append("%s: %s" % [Registry.label(YouTube.THUMBNAILS, k), Registry.blurb(YouTube.THUMBNAILS, k)])
	_thumbnail.tooltip_text = "\n\n".join(tips) + ("\n\nA channel YouTube has not verified (youtube.com/verify) "
		+ "cannot set one of its own: YouTube's stays.")
	_select(_thumbnail, YouTube.THUMBNAIL)
	_thumbnail.item_selected.connect(func(_i: int) -> void: refresh())
	_row("Thumbnail", _thumbnail)
	_thumb_writer = AgentPick.writer("Reads the episode and writes what its thumbnail shows - the subject, the "
		+ "light, the colors, a few words on it or none - and which of the episode's own pictures the painter follows.")
	_thumb_writer.changed.connect(refresh)
	add_child(_thumb_writer)
	_thumb_painter = AgentPick.painter("Paints the thumbnail the writer describes, cut to YouTube's 16:9.")
	_thumb_painter.changed.connect(refresh)
	add_child(_thumb_painter)
	_thumb = YouTubeThumbnail.new(func() -> bool: return thumbnail() == "painted", _thumb_writer.choice,
		_thumb_painter.choice, func() -> bool: return _thumb_match.button_pressed)
	_thumb_note = _small("")
	add_child(_thumb_note)
	_thumb_view = TextureRect.new()
	_thumb_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_thumb_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_thumb_view.custom_minimum_size = Vector2(0, 126)
	_thumb_view.visible = false
	_thumb_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_thumb_view.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_thumb_view.tooltip_text = "Click to see it full size."
	_thumb_view.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed \
				and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			open_thumbnail())
	add_child(_thumb_view)
	_thumb_steps = HBoxContainer.new()
	_thumb_steps.alignment = BoxContainer.ALIGNMENT_CENTER
	_thumb_steps.add_theme_constant_override("separation", 4)
	_thumb_steps.visible = false
	add_child(_thumb_steps)
	_thumb_back = _thumb_button("‹", "Show the thumbnail painted before this one: it goes up instead.")
	_thumb_back.pressed.connect(func() -> void: _choose_thumb(-1))
	_thumb_at = Label.new()
	_thumb_at.add_theme_font_size_override("font_size", 11)
	_thumb_at.modulate = Color(1, 1, 1, 0.7)
	_thumb_steps.add_child(_thumb_at)
	_thumb_on = _thumb_button("›", "Show the thumbnail painted after this one: it goes up instead.")
	_thumb_on.pressed.connect(func() -> void: _choose_thumb(1))
	_thumb_del = _armed_delete("✕", _delete_thumb)
	_thumb_steps.add_child(_thumb_del)


## The step that writes each episode's tags, and the line that says where it stands (the box that turns
## it on is at the top, beside "Upload after export"; the list it writes is the panel's, above).
func _build_tags() -> void:
	_tags = YouTubeTags.new(func() -> bool: return _write_tags.button_pressed)
	_tags_note = _small("")
	add_child(_tags_note)


func _row(label: String, field: Control) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(72, 0)
	l.add_theme_font_size_override("font_size", 12)
	row.add_child(l)
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(field)


func _small(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 11)
	l.modulate = Color(1, 1, 1, 0.7)
	return l


## THE ACCOUNT ROWS FOLLOW THE FILES BY LOOKING, twice a second: a sign-in finishes in the exporter's
## dialog, an upload waits or goes up from any note, and none of it signals this card.
func _process(dt: float) -> void:
	_poll -= dt
	if _poll > 0.0:
		return
	_poll = 0.5
	refresh()


## The block for a document.
func capture() -> Dictionary:
	var w := _thumb_writer.choice()
	var p := _thumb_painter.choice()
	return {"upload": _upload.button_pressed, "title": _title.text, "privacy": _privacy_key(),
		"category": _category_key(), "playlist": String(_list["id"]), "playlist_title": String(_list["title"]),
		"channel": String(_chan["id"]), "channel_name": _channel_name(), "write_tags": writes_tags(),
		"description": _desc.text, "thumbnail": thumbnail(),
		"thumbnail_writer": w["agent"], "thumbnail_writer_model": w["model"], "thumbnail_writer_effort": w["effort"],
		"thumbnail_painter": p["agent"], "thumbnail_painter_model": p["model"], "thumbnail_painter_effort": p["effort"],
		"thumbnail_match": _thumb_match.button_pressed}


## ...and back. A key the block does not name keeps the card's default; a privacy YouTube does not
## know is Private, a category it does not offer is People & Blogs, a thumbnail it does not know is
## YouTube's choice, and no channel is the first one kept here.
func apply(block: Dictionary) -> void:
	var b := DEFAULTS.duplicate()
	b.merge(block, true)
	_upload.set_pressed_no_signal(bool(b["upload"]))
	_write_tags.set_pressed_no_signal(bool(b["write_tags"]))
	_tags_seen = []
	if _title.text != str(b["title"]):
		_title.text = str(b["title"])
	if _desc.text != str(b["description"]):
		_desc.text = str(b["description"])
	var p := str(b["privacy"])
	for i in _privacy.item_count:
		if String(_privacy.get_item_metadata(i)) == p:
			_privacy.select(i)
	if not YouTube.PRIVACIES.has(p):
		_privacy.select(0)
	var cat := str(b["category"])
	_select(_category, cat if YouTube.CATEGORIES.has(cat) else YouTube.CATEGORY)
	var th := str(b["thumbnail"])
	_select(_thumbnail, th if YouTube.THUMBNAILS.has(th) else YouTube.THUMBNAIL)
	_thumb_writer.set_choice(str(b["thumbnail_writer"]), str(b["thumbnail_writer_model"]), str(b["thumbnail_writer_effort"]))
	_thumb_painter.set_choice(str(b["thumbnail_painter"]), str(b["thumbnail_painter_model"]), str(b["thumbnail_painter_effort"]))
	_thumb_match.set_pressed_no_signal(bool(b["thumbnail_match"]))
	_thumb_seen = []
	_chan = {"id": str(b["channel"]), "name": str(b["channel_name"])}
	if String(_chan["id"]).is_empty():
		_chan = _first_channel()
	if String(_chan["id"]) != _looked:      # another channel's playlists are not this one's
		_lists = []
		_looked = ""
	_list = {"id": str(b["playlist"]), "title": str(b["playlist_title"])}
	_fill_playlists()
	_seen = []
	refresh()


func _privacy_key() -> String:
	return String(_privacy.get_item_metadata(maxi(0, _privacy.selected))) if _privacy.item_count > 0 else YouTube.PRIVACY


func _category_key() -> String:
	return String(_category.get_item_metadata(_category.selected)) if _category.selected >= 0 else YouTube.CATEGORY


## The thumbnail picked ([constant YouTube.THUMBNAILS]).
func thumbnail() -> String:
	return String(_thumbnail.get_item_metadata(_thumbnail.selected)) if _thumbnail.selected >= 0 else YouTube.THUMBNAIL


## Select the item of [param box] whose metadata is [param key].
static func _select(box: OptionButton, key: String) -> void:
	for i in box.item_count:
		if String(box.get_item_metadata(i)) == key:
			box.select(i)


## Is an export of this note to go up?
func ticked() -> bool:
	return _upload.button_pressed


## Does the writer write each episode's tags over the note's?
func writes_tags() -> bool:
	return _write_tags.button_pressed


## THE NOTE IS DESCRIBED HERE from now on: the box shows, and its words go up first. It is its own
## episode, so the tags written are the note's.
func describe() -> void:
	_desc.visible = true
	_write_tags.text = "Write the note's tags"


## The description written here, "" when the box is not shown.
func description() -> String:
	return _desc.text.strip_edges() if _desc.visible else ""


## THE STEPS THIS CARD ADDS TO THE NOTE'S EPISODES ([EpisodeStep]), for whatever card makes them: each
## episode's tags, listed only while [method writes_tags] (see [method YouTubeTags.wanted]), and its
## thumbnail, only while it is Painted.
func episode_steps() -> Array:
	return [_tags, _thumb]


## THE NOTE'S NAMES ARE [param writer]'S - its Script card's - from now on: %title% its Title (else the
## note's file name), %episode% its Episode, %author% its Author, %book% its Book, every row shown there,
## so whatever the title can say has a place on the note to be written. Every panel that shows this card
## calls it.
func name_from(writer: ScriptWriter) -> void:
	_names = writer
	for k in NAMES:
		writer.show_field(k)
	refresh()


## WHAT THE TITLE'S MACROS ARE WORTH NOW - and so which this note fills: the Script card's Title, Episode,
## Author and Book, under what the panel adds ([member values]). {} while no panel has bound the card: it
## fills nothing, and nothing goes up.
func values_now() -> Dictionary:
	if _names == null:
		return {}
	var v := {}
	for k in NAMES:
		v[k] = _names.field_value(k)
	v["title"] = _names.title_or_name()
	var more: Variant = values.call() if values.is_valid() else {}
	if more is Dictionary:
		v.merge(more, true)
	return v


## The macros' values: [param given] (an export's own - the episode it rendered) laid over the note's now.
func _values(given: Dictionary) -> Dictionary:
	var v := values_now()
	v.merge(given, true)
	return v


## WHY THE TITLE CANNOT GO UP AS IT STANDS ("" when it can), with the macros' [param given] values laid
## over the note's now: it names a macro the note does not fill ([method YouTube.unfilled]), or no panel
## ever said what the note is called.
func why_not(given := {}) -> String:
	var v := _values(given)
	if v.is_empty():
		return "This panel never says what the note is called, so the title cannot be made here."
	var out := YouTube.unfilled(template(), v)
	if out.is_empty():
		return ""
	var said := PackedStringArray()
	for k in out:
		said.append("%s (%s)" % [String(YouTube.MACROS[k]["label"]), String(YouTube.MACROS[k]["blurb"])])
	return "The title names %s, which this note does not have: take %s out of the title, or nothing goes up." % [
		" and ".join(said), "it" if out.size() == 1 else "them"]


## The title box's tooltip: what each macro the note fills stands for - only those.
static func _title_tip(v: Dictionary) -> String:
	return ("The video's title, made of the words written here and these macros: %s What a missing one leaves "
		% YouTube.macros_said(v) + "(a dangling \": \") goes, and a name is never said twice. YouTube takes 100 characters.")


## The title as it goes up: the template, its macros filled from [param given] laid over
## [method values_now], the note as it stands now.
func title_now(given := {}) -> String:
	var v := _values(given)
	return YouTube.fit_title(YouTube.expand_title(template(), v))


## The title's template as it stands: the field's, else the one a new card starts with.
func template() -> String:
	return _title.text if not _title.text.strip_edges().is_empty() else YouTube.TITLE_TEMPLATE


## WHAT AN UPLOAD OF [param take] SAYS (see [member Exporter.upload_provider]): [param base] - the
## panel's own part, its description, tags (the note's one list), the episode's folder and record, and the
## macros' `values` when they are not the panel's as it stands now (an episode an export rendered) - with
## this card's title, privacy, category, playlist (its id and title, which the description names), channel
## and thumbnail ([method thumbnail_of]) laid over it, and the description written here ([method describe])
## before the panel's. {} when nothing is to go up: the box is clear, or the panel has nothing ({});
## `{refused: why}` when its title cannot be made ([method why_not]) - the exporter says so, and nothing
## renders for it.
func meta(base: Dictionary, take := "") -> Dictionary:
	if not ticked() or base.is_empty():
		return {}
	var held: Variant = base.get("values", {})
	var why := why_not(held if held is Dictionary else {})
	if not why.is_empty():
		return {"refused": why}
	var out := base.duplicate()
	var own := description()
	if not own.is_empty():
		var theirs := str(out.get("description", "")).strip_edges()
		out["description"] = own + ("\n\n" + theirs if not theirs.is_empty() else "")
	var given: Variant = out.get("values", {})
	out.erase("values")
	out["title"] = title_now(given if given is Dictionary else {})
	out["privacy"] = _privacy_key()
	out["category"] = _category_key()
	out["playlist"] = String(_list["id"])
	out["playlist_title"] = String(_list["title"])
	out["channel"] = String(_chan["id"])
	out["channel_name"] = _channel_name()
	out.merge(thumbnail_of(take, String(out.get("folder", ""))), true)
	out.erase("folder")
	return out


## THE THUMBNAIL AN UPLOAD OF [param take] TAKES, as the card's Thumbnail says - a painted one the episode's
## in [param folder]: `{thumbnail}` (an image), `{thumbnail_at}` (a moment of the take, its frame taken
## there), or neither - with `thumbnail_why` when the choice cannot be had, and YouTube's goes up.
func thumbnail_of(take: String, folder: String) -> Dictionary:
	match thumbnail():
		"title":
			var o := Openings.of_take(take, {"opening": Director.opening_shown(), "intro": Director.intro_hold})
			if not Openings.titled(String(o["opening"])):
				return {"thumbnail_why": "the video does not open on its title (Opening, on the Intro & outro card)"}
			return {"thumbnail_at": Openings.title_moment(float(o["intro"]))}
		"painted":
			if folder.is_empty():
				return {"thumbnail_why": "nothing on this note makes an episode to paint one for"}
			var img := YouTubeThumbnail.image_in(folder)
			if img.is_empty():
				return {"thumbnail_why": "no thumbnail is painted for this episode yet"}
			return {"thumbnail": img}
	return {}


## The line under the title: how it goes up, and where this note's episode already is.
func refresh() -> void:
	if _preview == null:
		return
	var v := values_now()
	# ONLY WHEN IT CHANGES: Boot.wrap_tip rewrites a tooltip as it is hovered, so the field's own text is
	# never the tip as made - compared with it, the tip went back unwrapped twice a second, under the
	# tooltip's own delay, and ran off the screen in one line
	var tip := _title_tip(v)
	if tip != _tip:
		_tip = tip
		_title.tooltip_text = tip
	var why := why_not(v)
	var t := title_now(v) if not v.is_empty() else ""
	if not why.is_empty():
		_preview.text = "⚠  " + why
	else:
		_preview.text = ("Goes up as \"%s\"" % t) if not t.is_empty() else "The title is empty: the export's file name is used."
	if _preview.has_theme_color_override("font_color") == why.is_empty():
		if why.is_empty():
			_preview.remove_theme_color_override("font_color")
		else:
			_preview.add_theme_color_override("font_color", Color(1.0, 0.85, 0.6))
	_refresh_account()
	_refresh_tags()
	_refresh_thumbnail()
	_look_quietly()


func _refresh_account() -> void:
	var ex := _exporter()
	var has_client := YouTube.has_client()
	var all := YouTube.channels()
	var id := String(_chan["id"])
	var kept := YouTube.channel(id)
	var signed := YouTube.signed_in(id)
	var lists := YouTube.granted(YouTube.PLAYLIST_SCOPE, id)
	var p := YouTube.pending()
	var busy := ex != null and bool(ex.youtube_busy())
	var yt: Node = ex.youtube() if ex != null else null
	var phase := String(yt.phase) if yt != null else ""
	var pct := int(round(float(yt.progress) * 100.0)) if yt != null else 0
	var now := [has_client, all, _chan, signed, lists, p.get("file", ""), p.get("channel", ""), busy, phase, pct,
		ex != null, _loading]
	if now == _seen:
		return
	_seen = now
	_fill_channels(all)
	var named := _channel_name()
	var no_client := ("No Google client yet: uploads go through your own Google Cloud project's "
		+ "\"Desktop app\" OAuth client. Import its JSON file once; Ghost Notes keeps it.")
	if ex == null:
		_account.text = "Uploads are made by the export, which this window does not have."
	elif id.is_empty():
		_account.text = no_client if not has_client else "No channel yet: + signs in to one. Your browser opens, and you choose the channel there."
	elif not signed:
		_account.text = ("%s is not signed in here%s. Signing in opens your browser: choose that channel there."
			% [named, " (its sign-in lapsed)" if not kept.is_empty() else ""])
	else:
		var title := String(kept.get("title", ""))
		_account.text = "Uploads go to %s%s - signed in%s." % [named, (" (%s)" % title) if not title.is_empty() and title != named else "",
			", playlists too" if lists else ", uploads only"]
	_sign.visible = ex != null and not id.is_empty() and not signed
	_sign.text = "Sign in"
	_sign.tooltip_text = "Open your browser to sign in to %s. Choose that channel there." % named
	_remove.visible = ex != null and not kept.is_empty()
	_remove.tooltip_text = ("Sign out of %s - Google is asked to revoke the sign-in - and take it off the list. "
		% named + "Notes that upload to it keep its name, to sign in again.")
	_client.visible = ex != null
	_client.text = "Replace client…" if has_client else "Import client…"
	_client.tooltip_text = ("Import another Google OAuth client file (a \"Desktop app\" client's JSON) - another "
		+ "Cloud project's, for its own quota. New sign-ins use it; a channel already signed in keeps the "
		+ "client it signed in with." if has_client else "Import your Google OAuth client file (a \"Desktop "
		+ "app\" client's JSON from Google Cloud). It stays on this machine, readable only by you, and one "
		+ "client signs in to every channel.")
	var waiting := not p.is_empty() and FileAccess.file_exists(str(p.get("file", "")))
	_resume.visible = ex != null and waiting and not busy
	var to := YouTube.name_of(YouTube.channel(str(p.get("channel", ""))))
	_resume.text = "Resume the upload of %s%s" % [str(p.get("file", "")).get_file(), (" to " + to) if not to.is_empty() else ""]
	_reload.disabled = _loading or ex == null or id.is_empty()
	if busy and phase == "uploading":
		_state.text = "Uploading … %d%%" % pct
	elif busy:
		_state.text = "An upload waits for its sign-in."
	elif _loading:
		_state.text = "Loading your playlists…"
	else:
		_state.text = ""
	_state.visible = not _state.text.is_empty()


func _exporter() -> Node:
	if exporter != null:
		return exporter
	return Exporter.of(self)


## TICKED: set uploads up first - the box shows ticked only once the note's channel is signed in and
## may do what this card asks (a playlist chosen asks for more); a note with no channel yet signs in
## to one, and takes it. Cleared: simply cleared.
func _on_tick(on: bool) -> void:
	if not on:
		refresh()
		return
	var id := String(_chan["id"])
	var scopes := _scopes()
	if YouTube.signed_in(id) and YouTube.missing_scopes(scopes, id).is_empty():
		refresh()
		return
	_upload.set_pressed_no_signal(false)
	var ex := _exporter()
	if ex == null:
		noted.emit("Uploads are made by the export, which this window does not have.")
		return
	var done := func(landed: String) -> void:
		if is_instance_valid(self):
			pick_channel(landed)
			_upload.set_pressed_no_signal(true)
			refresh()
	ex.youtube_sign_in(done, scopes, id, String(_chan["name"]))


func _scopes() -> Array:
	return [YouTube.SCOPE, YouTube.PLAYLIST_SCOPE] if not String(_list["id"]).is_empty() else [YouTube.SCOPE]


func _on_sign() -> void:
	var ex := _exporter()
	if ex == null:
		return
	ex.youtube_sign_in(Callable(), _scopes(), String(_chan["id"]), String(_chan["name"]))
	_seen = []


func _on_remove() -> void:
	var ex := _exporter()
	if ex != null and not String(_chan["id"]).is_empty():
		ex.youtube_sign_out(String(_chan["id"]))
	_seen = []


# --- the episode's tags --------------------------------------------------------------------------

## UNDER THE LIST, while the box is ticked: what the writer is doing to it for the episode the card
## that makes it shows - or that nothing on the note makes an episode, when nothing does. Drawn again
## only when something it says has changed.
func _refresh_tags() -> void:
	var on := writes_tags()
	var feed: EpisodeFeed = _tags.shown if on and not _tags.host.is_empty() else null
	var st := _tags.state(feed) if feed != null else ""
	var words := feed != null and not feed.words().is_empty()
	var stale := feed != null and not _tags.made(feed).is_empty() and not _tags.fresh(feed)
	var now := [on, _tags.host, feed.folder() if feed != null else "", st, words, stale,
		_tags.said(feed) if st == "failed" else ""]
	if now == _tags_seen:
		return
	_tags_seen = now
	var row := "⟳ on its Tags row on %s" % _tags.host
	var t := ""
	if not on:
		t = ""
	elif feed == null:
		t = "Nothing on this note makes episodes, so nothing writes their tags: the tags above go up as they are."
	elif st == "running" or st == "queued":
		t = "Writing this episode's tags… They replace the tags above when they are in."
	elif st == "failed":
		t = "⚠  This episode's tags could not be written: %s. The tags above go up as they are; %s tries again." % [
			_tags.said(feed), row]
	elif st == "ready":
		t = "This episode's tags are written: they replaced the tags above, which are what goes up. %s writes them again." % row
	elif not words:
		t = "This episode's tags are written once its words are, along with it, replacing the tags above."
	elif stale:
		t = "This episode's words were written again after its tags: %s writes new ones over the tags above, and so does %s." % [
			row, _tags.host_makes]
	else:
		t = "No tags are written for this episode yet: %s writes them over the tags above, and so does %s." % [
			row, _tags.host_makes]
	_tags_note.text = t
	_tags_note.visible = not t.is_empty()


# --- the thumbnail -------------------------------------------------------------------------------

## UNDER THE THUMBNAIL: the writer and painter rows of a painted one, what goes up as it stands - a frame
## of the title screen and when, or what the painter is doing for the episode the card that makes it shows
## - and the painted one itself. Drawn again only when something it says has changed.
func _refresh_thumbnail() -> void:
	var th := thumbnail()
	var feed := _thumb_feed()
	var st := _thumb.state(feed) if feed != null else ""
	var img := _thumb.image(feed) if feed != null else ""
	var words := feed != null and not feed.words().is_empty()
	var stale := feed != null and not _thumb.made(feed).is_empty() and not _thumb.fresh(feed)
	var n := _thumb.versions(feed).size() if feed != null else 0
	var at := _thumb.chosen(feed) if feed != null else -1
	var none_to_match := feed != null and _thumb.matching() and feed.pictures().is_empty()
	var now := [th, Director.opening_shown(), Director.intro_hold, _thumb.host, feed.folder() if feed != null else "",
		st, img, FileAccess.get_modified_time(img) if not img.is_empty() else 0, words, stale, n, at, none_to_match,
		_thumb.said(feed) if st in ["failed", "running", "queued"] else ""]
	if now == _thumb_seen:
		return
	_thumb_seen = now
	_thumb_steps.visible = th == "painted" and n > 0
	_thumb_back.visible = n > 1
	_thumb_on.visible = n > 1
	_thumb_at.visible = n > 1
	_thumb_at.text = "v%d/%d" % [at + 1, n]
	_thumb_back.disabled = at <= 0
	_thumb_on.disabled = at >= n - 1
	if _thumb_window != null and _thumb_window.visible:
		_fill_thumb_window()
	_thumb_writer.visible = th == "painted"
	_thumb_painter.visible = th == "painted"
	_thumb_match.visible = th == "painted"
	var row := "⟳ on its Thumbnail row on %s" % _thumb.host
	var t := ""
	match th:
		"title":
			if Openings.titled(Director.opening_shown()):
				t = "A frame of the title screen, %.1f s in, goes up as the thumbnail." % Openings.title_moment(Director.intro_hold)
			elif Medium.uses(Director.resolved_medium(), "opening"):
				t = "⚠  This note does not open on its title (Opening, on the Intro & outro card): YouTube chooses the thumbnail."
			else:
				t = "⚠  This note's picture has no title screen: YouTube chooses the thumbnail."
		"painted":
			if feed == null:
				t = "⚠  Nothing on this note makes episodes, so nothing paints their thumbnails: YouTube chooses."
			elif st == "running" or st == "queued":
				t = "Painting this episode's thumbnail: %s…" % _thumb.said(feed)
			elif st == "failed":
				t = "⚠  This episode's thumbnail could not be painted: %s. YouTube chooses one until %s tries again." % [
					_thumb.said(feed), row]
			elif not img.is_empty() and stale:
				t = ("This thumbnail was painted before the episode's words were written again: it goes up as it is until "
					+ "%s paints another.") % row
			elif not img.is_empty() and n > 1:
				t = "The thumbnail shown goes up with this episode - ‹ › picks another of the %d painted. %s paints one more." % [n, row]
			elif not img.is_empty():
				t = "This episode's thumbnail goes up with it. %s paints another, and this one is kept." % row
			elif not words:
				t = "This episode's thumbnail is painted once its words are written, along with it."
			else:
				t = "No thumbnail is painted for this episode yet: %s paints one, and so does %s. Until then YouTube chooses." % [
					row, _thumb.host_makes]
	if th == "painted" and none_to_match and not t.begins_with("⚠"):
		t += " This episode has no pictures of its own yet, so there is no look to match: it is painted free of one."
	_thumb_note.text = t
	_thumb_note.visible = not t.is_empty()
	_show_painted(img if th == "painted" else "")


func _thumb_button(text: String, tip: String) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 12)
	_thumb_steps.add_child(b)
	return b


## The episode the card that makes them shows, while its thumbnail is Painted; null otherwise.
func _thumb_feed() -> EpisodeFeed:
	return _thumb.shown if thumbnail() == "painted" and not _thumb.host.is_empty() else null


## ‹ or › ([param step] -1 or 1): the thumbnail painted before or after the one shown goes up instead.
func _choose_thumb(step: int) -> void:
	var feed := _thumb_feed()
	if feed == null:
		return
	var err := _thumb.choose(feed, _thumb.chosen(feed) + step)
	if not err.is_empty():
		noted.emit("The thumbnail could not be chosen: %s." % err)
	_refresh_thumbnail()


## ✕, pressed twice: the thumbnail shown is deleted, its painting too.
func _delete_thumb() -> void:
	var feed := _thumb_feed()
	if feed == null:
		return
	var err := _thumb.delete(feed, _thumb.chosen(feed))
	if not err.is_empty():
		noted.emit("The thumbnail could not be deleted: %s." % err)
	_refresh_thumbnail()


## A DELETE PRESSED TWICE, as a book's picture is deleted ([IllustrationPanel]): the first press arms it for
## 3 s ("Delete?"), the second calls [param act].
func _armed_delete(text: String, act: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = "Delete this thumbnail - its painting too. The one before it goes up instead, or none."
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 12)
	var disarm := Timer.new()
	disarm.one_shot = true
	disarm.wait_time = 3.0
	var calm := func() -> void:
		b.set_meta("armed", false)
		b.text = text
		b.remove_theme_color_override("font_color")
	disarm.timeout.connect(calm)
	b.add_child(disarm)
	b.pressed.connect(func() -> void:
		if not bool(b.get_meta("armed", false)):
			b.set_meta("armed", true)
			b.text = "Delete?"
			b.add_theme_color_override("font_color", Color(1.0, 0.55, 0.5))
			if disarm.is_inside_tree():
				disarm.start()
			return
		disarm.stop()
		calm.call()
		act.call())
	return b


## THE THUMBNAIL AT FULL SIZE, in a window of its own as a book's pictures open ([IllustrationPanel]): the
## one chosen, what the writer asked of it, and its versions to step through or delete there. Escape or
## the window's close hides it.
func open_thumbnail() -> void:
	if _thumb_feed() == null or not is_inside_tree():
		return
	_fill_thumb_window()
	var vp := get_viewport().get_visible_rect().size
	_thumb_window.size = Vector2i(int(vp.x * 0.8), int(vp.y * 0.85))
	_thumb_window.popup_centered()


## What the full-size window holds for the thumbnail chosen now - drawn again whenever the card's is
## ([method _refresh_thumbnail]) - and hidden once there is none.
func _fill_thumb_window() -> void:
	if _thumb_window == null:
		_thumb_window = Window.new()
		_thumb_window.visible = false
		_thumb_window.close_requested.connect(_thumb_window.hide)
		_thumb_window.window_input.connect(func(e: InputEvent) -> void:
			if e is InputEventKey and (e as InputEventKey).pressed and (e as InputEventKey).keycode == KEY_ESCAPE:
				_thumb_window.hide())
		add_child(_thumb_window)
	for c in _thumb_window.get_children():
		_thumb_window.remove_child(c)
		c.queue_free()
	var feed := _thumb_feed()
	var vs := _thumb.versions(feed) if feed != null else []
	if vs.is_empty():
		_thumb_window.hide()
		return
	var at := _thumb.chosen(feed)
	var v: Dictionary = vs[at]
	_thumb_window.title = "Thumbnail  ·  %s" % (feed.episode_title() if not feed.episode_title().is_empty() else "this episode")
	var bg := PanelContainer.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_thumb_window.add_child(bg)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	bg.add_child(col)
	var pic := TextureRect.new()
	pic.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var path := _thumb.image(feed)
	var img := Image.load_from_file(path) if not path.is_empty() else null
	if img != null and not img.is_empty():
		pic.texture = ImageTexture.create_from_image(img)
	col.add_child(pic)
	var words := String(v.get("words", ""))
	var desc := Label.new()
	desc.text = ("Its words: \"%s\"\n\n" % words if not words.is_empty() else "No words on it.\n\n") + String(v.get("picture", ""))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 12)
	col.add_child(desc)
	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 8)
	col.add_child(bar)
	for step in [-1, 1]:
		var b := Button.new()
		b.text = "‹ previous" if step < 0 else "next ›"
		b.focus_mode = Control.FOCUS_NONE
		b.disabled = at + step < 0 or at + step >= vs.size()
		b.pressed.connect(_choose_thumb.bind(step))
		bar.add_child(b)
		if step < 0:
			var n := Label.new()
			n.text = "version %d of %d%s" % [at + 1, vs.size(), "  (painted before the words were written again)"
				if not _thumb.fresh(feed) else ""]
			bar.add_child(n)
	bar.add_child(_armed_delete("Delete this version", _delete_thumb))


## The painted thumbnail at [param path] on the card, read again only when it changes; none for "".
func _show_painted(path: String) -> void:
	var key := ("%s|%d" % [path, FileAccess.get_modified_time(path)]) if not path.is_empty() else ""
	if key == _thumb_shown:
		return
	_thumb_shown = key
	var img := Image.load_from_file(path) if not path.is_empty() else null
	_thumb_view.texture = ImageTexture.create_from_image(img) if img != null and not img.is_empty() else null
	_thumb_view.visible = _thumb_view.texture != null


# --- the channel ---------------------------------------------------------------------------------

## The channel a note with none takes: the first one kept here, else none.
static func _first_channel() -> Dictionary:
	var all := YouTube.channels()
	return {"id": String(all[0]["id"]), "name": String(all[0]["name"])} if not all.is_empty() else {"id": "", "name": ""}


## What the note's channel is called: as kept here, else as the block remembers it, else its id.
func _channel_name() -> String:
	var kept := YouTube.channel(String(_chan["id"]))
	if not kept.is_empty():
		return String(kept["name"])
	return String(_chan["name"]) if not String(_chan["name"]).is_empty() else String(_chan["id"])


## THE NOTE'S CHANNEL IS [param id] from now on: its uploads go there. Another channel's playlists are
## not this one's, so the playlist is cleared.
func pick_channel(id: String) -> void:
	if id == String(_chan["id"]):
		return
	var kept := YouTube.channel(id)
	_chan = {"id": id, "name": String(kept.get("name", ""))}
	_list = {"id": "", "title": ""}
	_lists = []
	_fill_playlists()
	_seen = []
	refresh()


## The toggles: a channel each, the order they were signed in to, the note's pressed - its own, dimmed,
## when it is not signed in here - and "+" last.
func _fill_channels(all: Array) -> void:
	for c in _chips.get_children():
		if c != _add:
			_chips.remove_child(c)
			c.queue_free()
	var listed := false
	for ch in all:
		var d: Dictionary = ch
		_chip(String(d["id"]), String(d["name"]), String(d["title"]), bool(d["signed_in"]))
		listed = listed or String(d["id"]) == String(_chan["id"])
	if not String(_chan["id"]).is_empty() and not listed:
		_chip(String(_chan["id"]), _channel_name(), "", false)
	_chips.move_child(_add, _chips.get_child_count() - 1)


func _chip(id: String, name: String, title: String, signed: bool) -> void:
	var b := Button.new()
	b.text = name
	b.toggle_mode = true
	b.button_group = _chip_group
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 12)
	b.set_pressed_no_signal(id == String(_chan["id"]))
	b.modulate = Color(1, 1, 1, 1.0 if signed else 0.55)
	b.tooltip_text = ("%s%s\nThis note's uploads go to the channel pressed." % [title if not title.is_empty() and title != name else name,
		"" if signed else " - not signed in here"])
	b.pressed.connect(_on_channel.bind(id))
	_chips.add_child(b)


## A toggle pressed: the note's uploads go there. With the box ticked, a channel not signed in (or
## whose sign-in may not do what this card asks) is signed in to at once, while the person is here.
func _on_channel(id: String) -> void:
	pick_channel(id)
	var ex := _exporter()
	if ticked() and ex != null and not YouTube.missing_scopes(_scopes(), id).is_empty():
		ex.youtube_sign_in(Callable(), _scopes(), id, _channel_name())


## "+": sign in to another channel, whichever the person picks, and make it the note's.
func _on_add() -> void:
	var ex := _exporter()
	if ex == null:
		noted.emit("Uploads are made by the export, which this window does not have.")
		return
	var then := func(landed: String) -> void:
		if is_instance_valid(self):
			pick_channel(landed)
			noted.emit("Signed in to %s: this note's uploads go there." % YouTube.name_of(YouTube.channel(landed)))
	ex.youtube_sign_in(then, [YouTube.SCOPE], "")


func _on_client() -> void:
	var ex := _exporter()
	if ex != null:
		ex.youtube_import_client(func() -> void: _seen = [])


func _on_resume() -> void:
	var ex := _exporter()
	if ex != null:
		ex.youtube_resume()
	_seen = []


# --- the playlist --------------------------------------------------------------------------------

## THE CHANNEL'S PLAYLISTS, loaded on ↻: a sign-in that may see them first, when the kept one may
## only upload. The one the block names stays picked; one that has gone from the channel stays
## listed, marked, until another is picked. [param quiet]: as the card opens - no sign-in, and nothing
## said, either way.
func load_playlists(quiet := false) -> void:
	var ex := _exporter()
	var id := String(_chan["id"])
	if ex == null or _loading:
		return
	if id.is_empty():
		if not quiet:
			noted.emit("No channel yet: + signs in to one.")
		return
	if not YouTube.granted(YouTube.PLAYLIST_SCOPE, id):
		if quiet:
			return
		var again := func(_landed: String) -> void:
			if is_instance_valid(self):
				load_playlists()
		ex.youtube_sign_in(again, [YouTube.SCOPE, YouTube.PLAYLIST_SCOPE], id, _channel_name())
		return
	_loading = true
	_looked = id
	_seen = []
	var got: Dictionary = await ex.youtube().playlists(id)
	if not is_instance_valid(self):
		return
	_loading = false
	_seen = []
	if id != String(_chan["id"]):
		return                      # another channel was picked meanwhile: these are not its playlists
	if got.has("error"):
		if not quiet:
			noted.emit("⚠  The playlists could not be loaded: %s" % got["error"])
		return
	_lists = got["playlists"]
	_fill_playlists()
	if not quiet:
		noted.emit("%d playlist%s on the channel." % [_lists.size(), "" if _lists.size() == 1 else "s"])


## A CARD OPENING ON A PLAYLIST LOADS THE LIST, so the playlist shows by its name now: once a channel,
## when its sign-in may already see them and the card is where the exporter is. A sign-in that may only
## upload waits for ↻, which asks for more.
func _look_quietly() -> void:
	var id := String(_chan["id"])
	if _loading or id.is_empty() or _looked == id or String(_list["id"]).is_empty():
		return
	if _exporter() != null and YouTube.granted(YouTube.PLAYLIST_SCOPE, id):
		load_playlists(true)


## The dropdown: None, the loaded playlists, and the block's own when it is not among them - among them,
## it takes the title YouTube gives it now, which the block keeps and the description names.
func _fill_playlists() -> void:
	_playlist.clear()
	_playlist.add_item("None")
	_playlist.set_item_metadata(0, {"id": "", "title": ""})
	var at := 0
	var listed := false
	for pl in _lists:
		var d: Dictionary = pl
		var extra_words := " (%s)" % String(d.get("privacy", "")) if String(d.get("privacy", "")) not in ["", "public"] else ""
		_playlist.add_item(String(d.get("title", "")) + extra_words)
		_playlist.set_item_metadata(_playlist.item_count - 1, {"id": String(d["id"]), "title": String(d.get("title", ""))})
		if String(d["id"]) == String(_list["id"]):
			at = _playlist.item_count - 1
			listed = true
			_list["title"] = String(d.get("title", ""))
	if not String(_list["id"]).is_empty() and not listed:
		var name := String(_list["title"]) if not String(_list["title"]).is_empty() else String(_list["id"])
		_playlist.add_item(name + ("  (not on the channel)" if not _lists.is_empty() else ""))
		_playlist.set_item_metadata(_playlist.item_count - 1, _list.duplicate())
		at = _playlist.item_count - 1
	_playlist.select(at)


func _on_playlist(i: int) -> void:
	var d: Variant = _playlist.get_item_metadata(i)
	_list = (d as Dictionary).duplicate() if d is Dictionary else {"id": "", "title": ""}
	# a playlist needs the wider sign-in at upload time: ask for it now, while the person is here
	var id := String(_chan["id"])
	if ticked() and not YouTube.missing_scopes(_scopes(), id).is_empty():
		var ex := _exporter()
		if ex != null:
			ex.youtube_sign_in(Callable(), _scopes(), id, _channel_name())
	refresh()
