extends CanvasLayer
class_name NotePanel

## NotePanel - a note's own panel: where every new note opens, and what runs every note whose
## components need no editor of their own ([method Components.workspace_of]) - a note that is its
## words alone, and a note with a song.
##
## ITS CARDS ARE THE NOTE'S COMPONENTS, read off the note's blocks: the Script (the note's words,
## always), the Song, and whatever else is attached, built the one way every panel builds them
## ([method NoteCards.build]) - the Picture (with Auto first among its media: the seeded show,
## nothing to set), the Storyboard, the Look, the Intro & outro, YouTube. Each keeps its block in
## the note through the autosave every panel's frontmatter goes through ([DocSource]); the song's
## block is written only when another song is chosen.
##
## "+" OFFERS WHAT THE NOTE COULD HAVE NEXT ([method Components.attach_menu]): everything that can
## be attached, each grayed with its reason when it cannot be had yet ("Needs a Picture - attach it
## first", "This note's clock is its Song"). ATTACHING WRITES THE COMPONENT'S BLOCK into the note
## and opens the note again, as whatever its blocks now say it is ([method NoteCards.attach]) - and
## the × on a card takes it off the same way ([method NoteCards.detach]).
##
## THE SONG IS THE NOTE'S CLOCK, and main runs it ([member begin_song]): loaded as the panel comes
## up, after its cards have applied the note's picture, holds and look - and waiting at its start,
## because a note opens stopped. With no Picture there is no stage; with one, the Director cuts its
## scenes on the song in the medium the Picture card names - the seed's choice, or the note's
## Storyboard where one is written ([method show_plan]) - and a medium picked while the note is up
## is shown at once ([member restage]).

## The Settings section the script's source lives in (its remembered document).
const SECTION := "note"

## Set by main: the note this panel shows, and how to open it again once a component is attached.
var path := ""
var reopen: Callable
## Set by main: (from: String, to: String) -> String - the note was saved into another file (its
## Script card's Save…), which is the note from here on; returns what became of the file it left.
var note_moved: Callable
## Set by main: (song: String, show: Dictionary) -> void - load the note's song, waiting at its
## start, with the show [method show_plan] describes.
var begin_song: Callable
## Set by main: (show: Dictionary) -> void - put the picture up again in the medium chosen now.
var restage: Callable

var _panel: SidePanel
var _writer: ScriptWriter
var _status: Label
var _heading: Label
var _blocks := {}             # the note's blocks, as it opened
var _attached: Array = []     # the components it has (Components.attached_of)
var _cards := {}              # block key -> a card with capture() / apply()
var _song: SongCard
var _picture: PictureCard
var _story: StoryboardCard
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
	_panel = preload("res://src/ui/side_panel.gd").new(380.0)
	_panel.title = "Note"
	_panel.detach = _detach
	_panel.detach_blocker = func(key: String) -> String: return Components.detach_blocker(key, _attached)
	add_child(_panel)
	var box: VBoxContainer = _panel.body
	box.add_theme_constant_override("separation", 8)
	_build_header(box)
	_panel.add_component_row(func() -> Array: return _attached, _attach)
	_panel.card_prefix = SECTION
	var script_card: VBoxContainer = _panel.add_card("script", "Script", &"paper")
	# THE NOTE'S OWN FILE, from the first frame: the source is pointed at it before it is bound
	Settings.write(SECTION, "doc_path", path)
	Settings.write(SECTION, "sync", not path.is_empty())
	_writer = preload("res://src/ui/script_writer.gd").new()
	_writer.setup(SECTION, PackedStringArray(_doc_blocks()), SECTION)
	_writer.bind_note()
	_writer.doc.moved.connect(_on_note_moved)
	script_card.add_child(_writer)
	if has_song:
		_song = SongCard.new(_song_path())
		_song.chosen.connect(_choose_song)
		_panel.add_card("song", "Song", &"sound", "song").add_child(_song)
	_cards = NoteCards.build(_panel, _attached, {
		"intro_tip": "Seconds held before the song starts, the picture fading up through them.",
		"outro_tip": "Seconds held after the song ends, picture and sound fading out together."})
	_picture = _cards.get("picture") as PictureCard
	_story = _cards.get("scenes") as StoryboardCard
	_youtube = _cards.get("youtube") as YouTubeCard
	if _youtube != null:
		_youtube.name_from(_writer)
	for key in _cards:
		if (_cards[key] as Object).has_signal("noted"):
			(_cards[key] as Object).connect("noted", _note)
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
		begin_song.call(_song.path(), show_plan())


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
	head.add_child(Shell.back_button(self))
	var title := Label.new()
	_heading = title
	title.text = _title()
	title.add_theme_font_size_override("font_size", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(title)
	head.add_child(Shell.note_menu(self))
	var hide := Button.new()
	hide.text = "–"
	hide.tooltip_text = "Hide panel (F2)"
	hide.focus_mode = Control.FOCUS_NONE
	hide.custom_minimum_size = Vector2(28, 28)
	hide.pressed.connect(func() -> void: _panel.visible = false)
	head.add_child(hide)


func _title() -> String:
	return NoteStore.title_of(path) if not path.is_empty() else "Note"


func _note(msg: String) -> void:
	if _status != null:
		_status.text = msg


## WHAT THE NOTE'S SHOW IS, for main ([method main._attach_show]): whether it has a Picture, and
## the storyboard it walks - {} where the note has none, or has written nothing in it.
func show_plan() -> Dictionary:
	var plan := {"picture": _picture != null, "board": {}, "source": ""}
	if _story != null:
		plan.merge(_story.plan(), true)
	return plan


## The blocks this panel keeps in the note: one per card with settings, in the panel's order.
func _doc_blocks() -> Array:
	var out: Array = []
	for key in NoteCards.KEYS:
		if _attached.has(key):
			out.append(String((Components.REGISTRY[key] as Dictionary)["block"]))
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


## THE NOTE WAS SAVED INTO ANOTHER FILE ([signal DocSource.moved]): this panel is that file's now,
## and main makes it the note everywhere else (see [method ReadingPanel._on_note_moved]).
func _on_note_moved(from: String, to: String) -> void:
	path = to
	_heading.text = _title()
	var said := String(note_moved.call(from, to)) if note_moved.is_valid() else ""
	_writer.doc.tell("✓  This note is %s now - every change is saved there. %s" % [to.get_file(), said])


func _song_path() -> String:
	var song: Variant = _blocks.get("song", {})
	return String((song as Dictionary).get("path", "")) if song is Dictionary else ""


## The picture's medium changed: shown at once while a song is loaded (a reading's waits for the
## next reading; a song's has nothing to wait for).
func _on_medium() -> void:
	if restage.is_valid():
		restage.call(show_plan())


## Another song for the note: its block written, and the note opened again around it.
func _choose_song(song: String) -> void:
	_rewrite(func(held: Dictionary) -> String:
		var ghost := NoteStore.blocks_of(path)
		ghost.merge(held, true)
		ghost["song"] = {"path": song}
		return FrontMatter.write_block(path, ghost))


## What an upload of this note's export says (see [member Exporter.upload_provider]): the YouTube
## card's title, visibility and playlist; {} without a card, or with its box clear.
func upload_meta(_take: String) -> Dictionary:
	return _youtube.meta({"tags": []}) if _youtube != null else {}


## A component picked from "+": its block into the note, and the note opened again as what it now is.
func _attach(key: String) -> void:
	_rewrite(func(held: Dictionary) -> String: return NoteCards.attach(path, key, held))


## A card's ×, once asked: its blocks out of the note, and the note opened again without it.
func _detach(key: String) -> void:
	_rewrite(func(held: Dictionary) -> String: return NoteCards.detach(path, key, held))


## CHANGE WHAT THE NOTE IS MADE OF, then open it again. The words and the settings waiting to be
## saved go into the file first, [param write] - `(held) -> String`, handed what the cards hold now -
## makes the change, and this panel stops saving before the next one is built: a write of its own
## landing afterward would put back the very block that was just taken out.
func _rewrite(write: Callable) -> void:
	if path.is_empty() or not _writer.doc.settle():
		return
	var err := String(write.call(_doc_capture()))
	if not err.is_empty():
		push_warning("ghost: could not change what %s is made of - %s" % [path.get_file(), err])
		_note("⚠  " + err)
		return
	_writer.doc.set_process(false)
	_writer.doc.capture = Callable()
	if reopen.is_valid():
		reopen.call(path)
