extends CanvasLayer
class_name NotePanel

## NotePanel - a note's own panel, for every note no specialized panel runs: a note with nothing
## attached (next/notes.md step 8: "with nothing attached, it is a text editor"), and a note with a
## song - Auto and Manual, rebuilt 2026-10-06 ("if we load an audio file, allow it to be played. Do
## not hide the left-hand panel, ever. Then, if we want a scene for that audio file - attach a
## 'picture' component").
##
## ITS CARDS ARE THE NOTE'S COMPONENTS, read off the note's blocks: the Script (the note's words,
## always), the Song, the Picture (with Auto first among its media - the seeded show, nothing to
## set), the Look, the Intro & outro and the Storyboards. Each keeps its block in the note through
## the autosave every panel's frontmatter goes through ([DocSource]); the song's block is written
## only when another song is chosen.
##
## "+" OFFERS WHAT THE NOTE COULD HAVE NEXT ([method Components.attach_menu]): with nothing attached,
## what decides what it becomes (a Voice, a Voice lab, Cards, a song, a clip); with a song, a Picture
## for it, what a picture carries and where its video goes (YouTube) - each grayed with its reason
## when it cannot be had yet ("Needs a Picture"). ATTACHING WRITES THE COMPONENT'S BLOCK into the
## note and opens the note again, as whatever its blocks now say it is.
##
## THE SONG IS THE NOTE'S CLOCK, and main runs it ([member begin_song]): loaded as the panel comes
## up, after its cards have applied the note's picture, holds and look - and waiting at its start,
## because a note opens stopped. With no Picture there is no stage; with one, the Director cuts its
## scenes on the song in the medium the Picture card names, and a medium picked while the note is up
## is shown at once ([member restage]).

## The Settings section the script's source lives in (its remembered document).
const SECTION := "note"
## What "+" offers a note with nothing attached: the components that decide what it becomes.
const DECIDES := ["voice", "voice_lab", "cards", "song", "clip"]
## What "+" offers a note with a song: a picture for it, what a picture carries, and where its video goes.
const WITH_SONG := ["picture", "look", "bookends", "storyboard", "youtube"]

## Set by main: the note this panel shows, and how to open it again once a component is attached.
var path := ""
var reopen: Callable
## Set by main: (song: String, picture: bool, storyboard: String) -> void - load the note's song,
## waiting at its start, with a show for it when the note has a picture.
var begin_song: Callable
## Set by main: (storyboard: String) -> void - show the picture again in the medium chosen now.
var restage: Callable

var _panel: SidePanel
var _writer: ScriptWriter
var _status: Label
var _blocks := {}             # the note's blocks, as it opened
var _attached: Array = []     # the components it has (Components.attached_of)
var _cards := {}              # block key -> a card with capture() / apply()
var _song: SongCard
var _picture: PictureCard
var _boards: StoryboardsCard
var _youtube: YouTubeCard


func _ready() -> void:
	layer = 10
	_blocks = NoteStore.blocks_of(path) if not path.is_empty() else {}
	_attached = Components.attached_of(_blocks)
	var has_song := _attached.has("song")
	# NOTHING TO RENDER without a show: a plain note, or a song with no picture yet, has no ⤓
	# (released on the way out, keyed - see Chrome._export_claims)
	var ch := Chrome.of(self)
	if ch != null and not _attached.has("picture"):
		ch.suppress_export(&"note_panel")
	_panel = preload("res://src/side_panel.gd").new(380.0)
	_panel.title = "Note"
	add_child(_panel)
	var box: VBoxContainer = _panel.body
	box.add_theme_constant_override("separation", 8)
	_build_header(box)
	_build_component_row(box)
	_panel.card_prefix = SECTION
	var script_card: VBoxContainer = _panel.add_card("script", "Script", &"paper")
	# THE NOTE'S OWN FILE, from the first frame: the source is pointed at it before it is bound
	Settings.write(SECTION, "doc_path", path)
	Settings.write(SECTION, "sync", not path.is_empty())
	_writer = preload("res://src/script_writer.gd").new()
	_writer.setup(SECTION, PackedStringArray(_doc_blocks()), SECTION)
	_writer.bind_note()
	script_card.add_child(_writer)
	if has_song:
		_song = SongCard.new(_song_path())
		_song.chosen.connect(_choose_song)
		_panel.add_card("song", "Song", &"sound").add_child(_song)
	if _attached.has("picture"):
		_picture = PictureCard.new(false)
		_add_card("Picture", &"picture", _picture)
	if _attached.has("storyboard"):
		_boards = StoryboardsCard.new()
		_add_card("Storyboards", &"picture", _boards)
	if _attached.has("look"):
		_add_card("Look", &"look", LookCard.new())
	if _attached.has("bookends"):
		_add_card("Intro & outro", &"paper", BookendsCard.new(
			"Seconds held before the song starts, the picture fading up through them.",
			"Seconds held after the song ends, picture and sound fading out together."))
	if _attached.has("youtube"):
		_youtube = YouTubeCard.new()
		_youtube.values = func() -> Dictionary: return {"title": _title()}
		_add_card("YouTube", &"publish", _youtube)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 11)
	_status.add_theme_color_override("font_color", Color(0.55, 0.95, 0.75, 0.85))
	box.add_child(_status)
	# THE NOTE'S BLOCKS REACH THE CARDS as the source binds - the picture, the holds and the look are
	# set before the song is loaded, because the lead-in is decided as playback starts
	_writer.doc.capture = _doc_capture
	_writer.doc.apply = _doc_apply
	_writer.doc.bind_text(_writer.text_edit)
	if _picture != null:
		Director.medium_changed.connect(_on_medium)
	if has_song and _song.ready_to_play() and begin_song.is_valid():
		begin_song.call(_song.path(), _picture != null, _boards.active() if _boards != null else "")


func _exit_tree() -> void:
	var ch := Chrome.of(self)
	if ch != null:
		ch.release_export(&"note_panel")
	if Director.medium_changed.is_connected(_on_medium):
		Director.medium_changed.disconnect(_on_medium)


## F2 hides and shows the panel, as every note's panel does.
func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F2:
		_panel.visible = not _panel.visible


func _build_header(_box: VBoxContainer) -> void:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	# pinned over the scrolling body, so "⋯" and "–" never scroll away (SidePanel.pin_header)
	_panel.pin_header(head)
	head.add_child(Chrome.back_button(self))
	var title := Label.new()
	title.text = _title()
	title.add_theme_font_size_override("font_size", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(title)
	head.add_child(Chrome.note_menu(self))
	var hide := Button.new()
	hide.text = "–"
	hide.tooltip_text = "Hide panel (F2)"
	hide.focus_mode = Control.FOCUS_NONE
	hide.custom_minimum_size = Vector2(28, 28)
	hide.pressed.connect(func() -> void: _panel.visible = false)
	head.add_child(hide)


## THE COMPONENT ROW: "+", then a chip per card ([method SidePanel.add_component_row]).
func _build_component_row(_box: VBoxContainer) -> void:
	_panel.add_component_row(func() -> Array:
		return [_attached, WITH_SONG if _attached.has("song") else DECIDES], _attach)


func _title() -> String:
	return NoteStore.title_of(path) if not path.is_empty() else "Note"


## [param card] - a node with `KEY`, `capture()` and `apply(block)` - on a card of its own, its block
## kept in the note. A card with a `noted` signal speaks on the status line.
func _add_card(title: String, family: StringName, card: Control) -> void:
	_panel.add_card(String(card.KEY), title, family).add_child(card)
	_cards[String(card.KEY)] = card
	if card.has_signal("noted"):
		card.noted.connect(_note)


func _note(msg: String) -> void:
	if _status != null:
		_status.text = msg


## The blocks this panel keeps in the note: one per card with settings, in the panel's order.
func _doc_blocks() -> Array:
	var out: Array = []
	for k in ["picture", "scenes", "look", "bookends", "youtube"]:
		if _attached.has({"picture": "picture", "scenes": "storyboard", "look": "look", "bookends": "bookends",
				"youtube": "youtube"}[k]):
			out.append(k)
	return out


func _doc_capture() -> Dictionary:
	var out := {}
	for key in _cards:
		out[key] = (_cards[key] as Object).call("capture")
	return out


func _doc_apply(blocks: Dictionary) -> void:
	for key in _cards:
		if blocks.get(key) is Dictionary:
			(_cards[key] as Object).call("apply", blocks[key] as Dictionary)


func _song_path() -> String:
	var song: Variant = _blocks.get("song", {})
	return String((song as Dictionary).get("path", "")) if song is Dictionary else ""


## The picture's medium changed: shown at once while a song is loaded (a reading's waits for the
## next reading; a song's has nothing to wait for).
func _on_medium() -> void:
	if restage.is_valid():
		restage.call(_boards.active() if _boards != null else "")


## Another song for the note: its block written, and the note opened again around it.
func _choose_song(song: String) -> void:
	_write_blocks({"song": {"path": song}})


## What an upload of this note's export says (see [member Exporter.upload_provider]): the YouTube
## card's title, visibility and playlist; {} without a card, or with its box clear.
func upload_meta(_take: String) -> Dictionary:
	return _youtube.meta({"tags": []}) if _youtube != null else {}


func _attach(key: String) -> void:
	var add := Components.attach_blocks(key)
	if not add.is_empty():
		_write_blocks(add)


## Lay [param add] over the note's blocks, write them, and open the note again as what it now is.
func _write_blocks(add: Dictionary) -> void:
	if path.is_empty():
		return
	# what the cards hold now goes in too, so a dial moved a moment ago is not lost to the reopen
	var ghost := NoteStore.blocks_of(path)
	ghost.merge(_doc_capture(), true)
	ghost.merge(add, true)
	var err := FrontMatter.write_block(path, ghost)
	if not err.is_empty():
		push_warning("ghost: could not write %s into %s - %s" % [str(add.keys()), path.get_file(), err])
		_note("⚠  " + err)
		return
	if reopen.is_valid():
		reopen.call(path)
