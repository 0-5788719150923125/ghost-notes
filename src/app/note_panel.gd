extends CanvasLayer
class_name NotePanel

## NotePanel - a note's own panel: where every new note opens, and what runs every note whose components
## need no editor of their own ([method Components.workspace_of]) - a note of words alone, and a note with
## a sound.
##
## Its cards are the note's components, read off the note's blocks: the Script (the words, always), the
## Sound, and whatever else is attached, built the one way every panel builds them ([method
## NoteCards.build]). Each keeps its block in the note through the autosave every panel's frontmatter goes
## through ([DocSource]). What a card makes is one list on the Pipeline card ([PipelineCard]), there while
## any card offers a section (a composed Sound's: its reference read, its lines sung, its mix).
##
## "+" offers what the note could have next ([method Components.attach_menu]), each grayed with its reason
## when it cannot be had yet. Attaching writes the component's block into the note and opens the note again
## as whatever its blocks now say ([method NoteCards.attach]); a card's × takes it off the same way
## ([method NoteCards.detach]).
##
## The sound is the note's clock, and main runs it ([member begin_song]): the file the Sound card plays
## ([method SoundCard.playable]: a chosen file, or the composed song's mix) loaded as the panel comes up,
## after the cards have applied the note's medium, holds and look, and waiting at its start. A new mix made
## opens the note again around it ([method _sound_made]). With no Medium
## there is no stage; with one, the Director cuts scenes on the song in the format the Medium card names
## (the seed's choice, or the note's storyboard - [NoteStoryboard], [method show_plan]), and a format picked
## while the note is up is shown at once ([member restage]).

## The Settings section the script's source lives in (its remembered document).
const SECTION := "note"
## Seconds the typing pauses before the cards that follow the words are handed them.
const WORDS_SETTLE := 0.6

## Set by main: the note this panel shows, and how to open it again once a component is attached.
var path := ""
var reopen: Callable
## Set by main: (from: String, to: String) -> String - the note was saved into another file (its Script
## card's Save…); returns what became of the file it left.
var note_moved: Callable
## Set by main: (song: String, show: Dictionary) -> void - load the note's song, waiting at its start, with
## the show [method show_plan] describes.
var begin_song: Callable
## Set by main: (show: Dictionary) -> void - put the picture up again in the format chosen now.
var restage: Callable
## Set by main: (fp, sr, words) -> {playback, subtitles} and () -> void - a composed song's stream opened with the show
## on it, and closed ([SongStream]).
var begin_stream: Callable
var end_stream: Callable
## Set by main: a session a person plays (a composed song is heard as it is made), not an export's render (which plays
## the song's mix, made whole).
var live := true

var _panel: SidePanel
var _writer: ScriptWriter
var _status: Label
var _blocks := {}             # the note's blocks, as it opened
var _attached: Array = []     # the components it has (Components.attached_of)
var _cards := {}              # block key -> a card with capture() / apply()
var _sound: SoundCard
var _cartoon: Object = null                  # the Cartoon card, by what it answers (its class named here would compile it with every note)
var _pipeline: PipelineCard
var _medium: MediumCard
var _story: NoteStoryboard
var _youtube: YouTubeCard


func _ready() -> void:
	layer = 10
	_blocks = NoteStore.blocks_of(path) if not path.is_empty() else {}
	var words := String(FrontMatter.split(FileAccess.get_file_as_string(path)).get("body", "")) if not path.is_empty() and FileAccess.file_exists(path) else ""
	_attached = Components.attached_of(_blocks, words)
	var has_song := _attached.has("sound")
	var has_show := _attached.has("medium") or _attached.has("cartoon")
	#Nothing to render without a show: a plain note, or a song with no medium yet, has no ⤓ (released on the
	#way out, keyed - see Chrome._export_claims)
	var ch := Chrome.of(self)
	if ch != null and not has_show:
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
	var script_card: VBoxContainer = _panel.add_card("body", "Body", &"paper")
	#The note's own file, from the first frame: the source is pointed at it before it is bound
	Settings.write(SECTION, "doc_path", path)
	Settings.write(SECTION, "sync", not path.is_empty())
	_writer = preload("res://src/ui/script_writer.gd").new()
	# a note with a Sound is written as a song: its editor offers a song's marks (ScriptMarks, "song")
	_writer.setup(SECTION, PackedStringArray(_doc_blocks()), "song" if _attached.has("sound") else SECTION)
	_writer.refine_folder = func() -> String: return NoteUpload.folder_of(path)
	_writer.refine_parts = func() -> Array: return _attached
	_writer.bind_note()
	_writer.doc.moved.connect(_on_note_moved)
	script_card.add_child(_writer)
	#...and what is kept of the note ([NoteKept]): its cache and every state to go back to
	var kept := NoteKept.new()
	kept.doc = _writer.doc
	kept.cache_dir = func() -> String: return NoteUpload.folder_of(path)
	kept.history_dir = func() -> String: return NoteUpload.folder_of(path).path_join("history") if not path.is_empty() else ""
	script_card.add_child(kept)
	_cards = NoteCards.build(_panel, _attached, {"blocks": _blocks, "reshape": _reshape, "path": path, "brought": Components.brought_by(words),
		"folder": NoteUpload.folder_of(path) if not path.is_empty() else "", "video": _attached.has("medium"),
		"begin_stream": begin_stream, "end_stream": end_stream, "live": live,
		"intro_tip": "Seconds held before the song starts, the picture fading up through them and up a few seconds before it.",
		"outro_tip": "Seconds held after the song ends, picture and sound fading out together."})
	#...the timeline open, as a list ([TimelineList]): a card shown only while a timeline editor is open
	_panel.add_card("timeline", "Timeline", &"picture", "", TimelineList.BLURB).add_child(TimelineList.new())
	_medium = _cards.get("medium") as MediumCard
	#...the storyboard, kept in the note's folder and opened from beside Play: on a note shown in a Medium, and on a cartoon
	_cartoon = _cards.get("cartoon")
	if _medium != null or _cartoon != null:
		_story = NoteStoryboard.new()
		_story.folder = func() -> String: return NoteUpload.folder_of(path)
		_story.noted.connect(_note)
		add_child(_story)
		kept.board_history = func() -> String: return NoteUpload.folder_of(path).path_join(NoteStoryboard.HISTORY) if not path.is_empty() else ""
		kept.board_restore = _story.restore
	_youtube = _cards.get("youtube") as YouTubeCard
	if _youtube != null:
		_youtube.name_from(_writer)
	_sound = _cards.get("sound") as SoundCard
	if _sound != null:
		_sound.chosen.connect(_choose_song)
		_sound.baked.connect(_sound_made)
	# a cartoon's storyboard written anew opens the note again around it, its silent track as long as it now is
	if _cartoon != null and _cartoon.has_signal("made"):
		_cartoon.connect("made", _sound_made)
	#...and everything the cards make, one list, last in the deck: there while a card has something to make
	for key in _cards:
		if (_cards[key] as Object).has_method("pipeline"):
			if _pipeline == null:
				_pipeline = PipelineCard.new(SECTION)
				_pipeline.put_on(_panel)
			var section: PipelineSection = (_cards[key] as Object).call("pipeline")
			if section != null:
				_pipeline.add(section)
	for key in _cards:
		if (_cards[key] as Object).has_signal("noted"):
			(_cards[key] as Object).connect("noted", _note)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 11)
	_status.add_theme_color_override("font_color", Color(0.55, 0.95, 0.75, 0.85))
	box.add_child(_status)
	#The note's blocks reach the cards as the source binds: the medium, holds and look are set before the
	#song is loaded, because the lead-in is decided as playback starts
	_writer.doc.capture = _doc_capture
	_writer.doc.apply = _doc_apply
	_writer.doc.bind_text(_writer.text_edit)
	# the cards that follow the words follow them as they are typed, once the typing pauses (`set_script_text`, as the reading's do)
	var pause := Timer.new()
	pause.one_shot = true
	pause.wait_time = WORDS_SETTLE
	pause.timeout.connect(func() -> void:
		var body := String(FrontMatter.split(_writer.text_edit.text).get("body", _writer.text_edit.text))
		for key in _cards:
			if (_cards[key] as Object).has_method("set_script_text"):
				(_cards[key] as Object).call("set_script_text", body))
	add_child(pause)
	_writer.text_edit.text_changed.connect(pause.start)
	if _medium != null:
		Director.medium_changed.connect(_on_medium)
	# a composed song conducts itself, heard as it is made ([SongStream]); a file, or a render's mix, plays as a song does
	if has_song and _sound != null and not _sound.streams() and _sound.ready_to_play() and begin_song.is_valid():
		begin_song.call(_sound.playable(), show_plan())
	# a silent cartoon is timed by its storyboard: a silent track as long as it ([CartoonCard], next/cartoon.md)
	elif not has_song and _cartoon != null and bool(_cartoon.call("ready_to_play")) and begin_song.is_valid():
		begin_song.call(String(_cartoon.call("playable")), show_plan())


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
	#pinned over the scrolling body, so "⋯" and "‹" never scroll away (SidePanel.pin_title_row)
	_panel.pin_title_row(self)


func _note(msg: String) -> void:
	StatusLog.say("status", msg)
	if _status != null:
		_status.text = msg


## What the note's show is, for main ([method main._attach_show]): whether it has a Medium (`picture`) and
## the storyboard it walks - {} where the note has none or has written nothing in it.
func show_plan() -> Dictionary:
	var plan := {"picture": _medium != null or _cartoon != null, "board": {}, "source": ""}
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
		# a card with nothing to keep yet (one the note's marks bring, never changed) writes no block
		var block: Variant = (_cards[key] as Object).call("capture")
		if block is Dictionary:
			out[key] = block
	return out


func _doc_apply(blocks: Dictionary) -> void:
	for key in _cards:
		if blocks.get(key) is Dictionary:
			(_cards[key] as Object).call("apply", blocks[key] as Dictionary)


## The note was saved into another file ([signal DocSource.moved]): this panel is that file's now, and main
## makes it the note everywhere else (see [method ReadingPanel._on_note_moved]).
func _on_note_moved(from: String, to: String) -> void:
	path = to
	var said := String(note_moved.call(from, to)) if note_moved.is_valid() else ""
	_writer.doc.tell("✓  This note is %s now - every change is saved there. %s" % [to.get_file(), said])


## The Medium's format changed: shown at once while a song is loaded (a reading's waits for the next reading).
func _on_medium() -> void:
	if restage.is_valid():
		restage.call(show_plan())


## Another song file for the note: its block written, and the note opened again around it.
func _choose_song(song: String) -> void:
	_rewrite(func(held: Dictionary) -> String:
		var ghost := NoteStore.blocks_of(path)
		ghost.merge(held, true)
		var sound: Dictionary = (held.get("sound", {}) as Dictionary).duplicate()
		sound["source"] = "file"
		sound["path"] = song
		ghost["sound"] = sound
		ghost.erase("song")
		return FrontMatter.write_block(path, ghost))


## The composed song was made: the note opened again, its new mix the song it plays.
func _sound_made(_mix: String) -> void:
	# a song heard as it is made has nothing to open again around: its stream reads the takes the bake sang
	if _sound != null and _sound.streams():
		return
	_rewrite(func(held: Dictionary) -> String:
		var ghost := NoteStore.blocks_of(path)
		ghost.merge(held, true)
		ghost.erase("song")
		return FrontMatter.write_block(path, ghost))


## The song this note's export renders, and whether there is one ([SoundCard.export_song]; [member
## Exporter.take_provider]).
func export_song() -> String:
	return String(await _sound.export_song()) if _sound != null and is_instance_valid(_sound) else ""


func can_export_song() -> bool:
	return _sound != null and is_instance_valid(_sound) and _sound.can_export_song()


## Whether the note has a Sound, whose song an export takes.
func has_sound() -> bool:
	return _sound != null


## What an upload of this note's export says (see [member Exporter.upload_provider]): the YouTube
## card's title, visibility and playlist; {} without a card, or with its box clear.
func upload_meta(take: String) -> Dictionary:
	return _youtube.meta({"tags": []}, take) if _youtube != null else {}


## What the cards hold, written into the note, and the note opened again around it: a format with rows of its
## own picked on the Medium card, or one left ([member MediumCard._reshape]).
func _reshape() -> void:
	_rewrite(func(held: Dictionary) -> String:
		var ghost := NoteStore.blocks_of(path)
		ghost.merge(held, true)
		return FrontMatter.write_block(path, ghost))


## A component picked from "+": its block into the note, and the note opened again as what it now is.
func _attach(key: String) -> void:
	_rewrite(func(held: Dictionary) -> String: return NoteCards.attach(path, key, held))


## A card's ×, once asked: its blocks out of the note, and the note opened again without it.
func _detach(key: String) -> void:
	_rewrite(func(held: Dictionary) -> String: return NoteCards.detach(path, key, held))


## Change what the note is made of, then open it again. The words and settings waiting to be saved go into
## the file first; [param write] - `(held) -> String`, handed what the cards hold now - makes the change,
## and this panel stops saving before the next one is built, since a write of its own would put back the
## block just taken out.
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
