extends CanvasLayer
class_name ReadingPanel

## ReadingPanel - a reading of a document in the neural voice: the script, the cast, the voice, the stream, the
## transport's hooks and the export. It runs two workspaces, a note read aloud and a show at a table, and is the
## same panel for both: what differs is the note's components, each a card ([method _note_cards]) keeping its
## block in the document ([method _doc_blocks]).
##
## Not a backend swap inside [SynthEditor]: the fishing game's economy is defined over the procedural engine's
## parameter space (a 25-dimensional trait-plus-genome vector), while a neural backend exposes a speaker id and
## three global scalars. Everything downstream is shared, because a take is a WAV: [Spectrum], the scenes, the
## exporter, the subtitles and the feedback console work unchanged. The panel mirrors [SynthEditor]'s corner,
## width and title/hide/text shape.
##
## Made of (next/structure.md, steps 17-23): the voices and the Voice card's rows are [ReadingCast] (the `voice`
## block); the reading on the stream is [ReadingStream] (the sliding window: a chapter is too long to synthesize
## up front, so only a sentence or two is in flight); Test is [ReadingAudition]; what a reading will say is
## [ReadingPlan] (pure: the words in, the chunks out); every take - live, exported, auditioned - is joined by one
## [ReadingJoin]. What is left here is the panel: its rows and the note's cards, the document's blocks, the
## host, the transport's hooks and the export's render.

## A reading of a document, whoever wrote it: what is read comes from the document a [ScriptWriter] holds, and
## what it is seen in is the cards of the note's components. Nothing extends it (next/structure.md, step 12): the
## workspace it runs is a row ([member workspace]: its section, title and the cards a panel without a note has),
## and a component that changes the reading hands it the part - what is read ([member walk]), where it is heard
## ([member bed]) and how it goes out ([member publish]). A table show's [EpisodeCard] hands all three, so the
## voice pipeline, the cast, the export and the scrubbing exist once.

## Set by main: open one generator session for the whole chapter.
var begin_stream: Callable     # begin_stream.call(fp, sample_rate, words) -> playback

## The other half of begin_stream: closes the stream, detaches the Director from the stage and
## frees the subtitle overlay. Optional - an owner that does not set it simply cannot Stop.
var end_stream: Callable

## Set by main: play a take kept whole as the session's audio, as a render plays it - `begin_take.call(path) ->
## bool`, false when it would not load ([method kept_take]; next/editing.md step 3). Optional: without it a reading
## is always said live.
var begin_take: Callable

var _marks_dock: TimelineDock = null
var _marks_btn: Button = null
var _kept: NoteKept = null

const TAKE_DIR := "user://generative"
## Where an export's take is written, [constant TAKE_DIR] (a gate's seam: a test writes nothing of the author's).
var take_dir := TAKE_DIR

# Persisted through [Settings], which owns the one file the whole app shares.
const AUTOSAVE_DELAY_MS := 800


## The voice a new tab reads in, and the one picked when a tab names none: 904 readers under one checkpoint, so
## a cast can be voiced from one model.
const DEFAULT_VOICE := "en_US-libritts-high"

## One tab's worth of settings, and the schema: [method ReadingCast.slot_cfg] merges a stored slot onto this, so
## a slot saved by an older build is missing keys rather than broken.
const SLOT_DEFAULTS := {
	"voice": DEFAULT_VOICE, "speaker": 0, "tone": 0, "pace": 1.0, "pause": 1.0,
	# a new voice made of the voice's readers (VoiceBlend: "mix: af_heart 2, bf_emma 1"); "" is the Speaker alone
	"blend": "",
	"dynamics": 0.5, "arc": 0.4, "effort": 0.35,
	"echo": 0.0, "room": 0.0, "resonance": 0.0, "presence": 1.0, "ambience": 0.0,
	"lean": 0.0, "near": 0.0, "seat": 0.0,
		# the pen this voice writes in, in a medium that writes by hand - a name from NotebookLayout.INKS or a hex
		# color; "" is the default black
	"ink": "",
}

var _host: VoiceHost
var _panel: PanelContainer
var _writer: ScriptWriter
var _doc: DocSource
var _text: TextEdit

## The panel's play and stop are the transport's (next/notes.md step 3): this panel conducts the clock (see
## [method transport_hooks]) and the bar along the stage plays, pauses, stops and seeks the reading. True once a
## voice has loaded, so Play can do something.
var _can_play := false

## The cast ([ReadingCast]): the voices the script names, and the Voice card's rows - its `voice` block.
var _cast := ReadingCast.new(self)

## The reading on the stream ([ReadingStream]): the sliding window, the ring, the take being joined.
var _stream := ReadingStream.new(self)

## The audition ([ReadingAudition]): Test's voice heard on its own, with its own state.
var _audition := ReadingAudition.new(self)
var _status: Label

## The voice's sample rate, as the host last reported it: the stream's, the audition's and the export's.
var _sr := 22050
var subtitles: Node            # set by main; its clock is re-based by the stream

# What the last plan noticed about the script (a speaker cue with no tab, a macro with no default). Not written
# straight to the status line, which is overwritten by "Planned N chunk(s)..." a moment later and would keep a
# warning after the text is fixed. Rebuilt by every plan ([method _plan_of]), and read by whoever reports it.
var _plan_note := ""

## This panel's own rows that belong to a medium feature (the Ink): tag -> the Controls to show
## or hide together, by [method _sync_medium_rows]. A card keeps its own (see [MediumCard]).
var _medium_rows := {}

## The note this panel is (set by main before it is added), "" when started without one.
var note_path := ""

## Set by main: (from: String, to: String) -> String - the note was saved into another file (its
## Script card's Save…), which is the note from here on; returns what became of the file it left.
var note_moved: Callable

## Set by main: (path: String) -> void - open the note again, as what a component attached to it
## or taken off it made it.
var reopen: Callable

## The components the note has ([method Components.attached_of]), read as the panel is built: the cards it shows
## and what "+" offers follow them. [] when started without a note (the command line, a gate), which is every
## card the workspace has.
var _attached: Array = []
var _blocks := {}             # the note's blocks, as it opened
## The cards that keep a block of the document's frontmatter, by block (see [method _add_block_card]): each
## answers `capture() -> Dictionary` and `apply(block)`. The voice is this panel's own.
var _block_cards := {}
var _youtube: YouTubeCard
## The note as its own episode on the YouTube card ([NoteUpload]): its description, tags and the steps made from
## its words, when [member publish] says it is one; null otherwise.
var _note_upload: NoteUpload

## Everything agents and tools make for the note, one list ([PipelineCard]): every card built here that has
## anything to make hands it a section ([method _offer_pipeline]). No card names another.
var _pipeline: PipelineCard
var _dirty := false
var _last_edit_ms := 0

## The [Settings] section this panel's own state lives in (its draft, remembered document, an unsynced script's
## cast): the workspace's (its row's `section`). A synced document's settings are not per mode: its blocks are
## the components' ([method _doc_blocks]), so two panels reading one chapter share its voice.
var _section := "generative"
## The mode its Script card works in - its rows, wording and marks ([method Components.script_mode]): a table's
## is "table", though its settings keep the section "cards".
var _mode := "generative"

## The workspace this panel runs, a key of [constant Components.WORKSPACES] - `reading` (a note read aloud),
## `table` (a show at a table) or `proof` - set by main before the panel is added. Its row says the panel's section
## and title, which of a note's cards it can show (`hosts`) and every card a panel started without a note has
## (`classic`).
var workspace := "reading":
	set(key):
		workspace = key
		_section = String(Registry.field(Components.WORKSPACES, key, "section", "generative"))
		_mode = Components.script_mode(key)

## Where the reading is heard ([ReadingBed]): no place, unless a component hands one (a table show hands the
## episode's table).
var bed: ReadingBed = ReadingBed.new()

## How the reading goes out ([ReadingPublish]): what its export is called, what is held while the take renders,
## what an upload says. A note's own, unless a component's card hands another.
var publish: ReadingPublish = ReadingPublish.new()

## What the show may be paced by ([TuneSection]): each component whose parts read such numbers hands one; the
## Pacing card shows the rows they offer, and none when none do ([PacingCard]).
var tune_sections: Array = []

## The author changed the script by hand (never a document arriving): for a component that keeps count of what
## an edit changes (a table show's brief changes the next episode, not this one).
signal source_edited

## The panel's own state was written to [Settings] ([method _persist]): a component that keeps
## some there writes its own beside it.
signal persisted

## The scrub's settle: a drag on the transport's rail restarts the reading once it stops.
var _seek_timer: Timer

## A drag restarts the reading once, when it settles - not once per pixel.
const SEEK_SETTLE := 0.4


func _ready() -> void:
	layer = 10
	DirAccess.make_dir_recursive_absolute(TAKE_DIR)
	_build_panel()
		# Nothing to render without something to be seen in: a voice alone has no export button, as a song alone has
		# none (released on the way out, keyed - see Chrome._export_claims)
	var ch := Shell.of(self)
	if ch != null and not bool(show_plan()["picture"]):
		ch.suppress_export(&"reading")
	_host = VoiceHost.new()
	add_child(_host)
	_host.host_ready.connect(_on_host_ready)
	_host.failed.connect(_on_failed)
	_host.progress.connect(func(_s: String, m: String) -> void: _set_status(m))
	_host.synthesized.connect(_on_synthesized)
	_load_persisted()
	_set_status("Starting the voice host…")
	_host.start()
		# The reading conducts: registered while the panel is up, so the transport shows a Play before anything has
		# been read, and released in _exit_tree.
	Spectrum.conduct(self, transport_hooks())


## Every frame: the autosave, the audition, and the reading's ring ([method ReadingStream.tick]).
func _process(delta: float) -> void:
	_process_persist()
		# the audition whether or not a reading plays: it is not part of one, and would otherwise never be noticed to
		# have finished
	_audition.tick()
	_stream.tick(delta)


func _exit_tree() -> void:
	Spectrum.release_conductor(self)
	var ch := Shell.of(self)
	if ch != null:
		ch.release_export(&"reading")
	if _dirty:
		_persist()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and _dirty:
		_persist()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F2:
		_panel.visible = not _panel.visible


## What the transport drives (see Spectrum's `_conductor`). Space is the transport's too, taken before a focused
## button could.
func transport_hooks() -> Dictionary:
	return {
		"play": _transport_play,
		"pause": _transport_pause,
		"stop": _stream.stop,
		"playing": func() -> bool: return _stream.live() and not Spectrum.paused,
		"can_play": func() -> bool: return _can_play,
		"can_stop": func() -> bool: return _stream.has_reading() or _stream.playback != null,
				# A stopped reading has nothing on the rail: the sentence scale is the last plan's, and a seek there would
				# start a reading.
		"position": func() -> float: return _stream.position() if _stream.has_reading() else 0.0,
		"length": func() -> float: return _stream.length() if _stream.has_reading() else 0.0,
		"seek": _transport_seek,
		"stale": func() -> bool: return _stream.stale and _stream.has_reading(),
		# ...and how far ahead of the playhead the voice is made ([method ReadingStream.ahead]): the transport's buffered stretch
		"ahead": func() -> float: return _stream.ahead() if _stream.live() else -1.0,
	}


## Play: carry on a paused reading, or read the script from the top.
func _transport_play() -> void:
	if _stream.live():
		if Spectrum.paused:
			Spectrum.set_paused(false)
			_set_status("Resumed.")
		return
	_stream.play()


func _transport_pause() -> void:
	if _stream.live() and not Spectrum.paused:
		Spectrum.set_paused(true)
		_set_status("Paused. Space or ▶ carries on; ■ ends the reading.")


func _transport_seek(t: float) -> void:
	if _stream.has_reading():
		_stream.seek(t)


# --- the panel: its rows and the note's cards -----------------------------------------------------


func _build_panel() -> void:
		# A [SidePanel] rather than a bare PanelContainer, so rows past the bottom edge are reachable (see side_panel.gd).
	_panel = preload("res://src/ui/side_panel.gd").new(380.0)
	_panel.title = _row("label")
	if not note_path.is_empty():
		_blocks = NoteStore.blocks_of(note_path)
		_attached = Components.attached_of(_blocks)
		# a note's components come off again: each card's × (see SidePanel.add_card)
		_panel.detach = _detach
		_panel.detach_blocker = func(key: String) -> String: return Components.detach_blocker(key, _has())
	add_child(_panel)
	var box: VBoxContainer = _panel.body
	box.add_theme_constant_override("separation", 8)
	_build_header(box)
	# made before the cards, which hand it what they make; pinned once they are, its chip after theirs
	_pipeline = PipelineCard.new(_section)
		# The cards (next/notes.md, step 2): each section a colored card that folds, its chip in the row under the
		# heading, in the families' order: the text, what produces it, the voice, the picture, the Look.
	_panel.card_prefix = _section
	_panel.add_component_row(_has, _attach)
	_build_source(_panel.add_card("body", "Body", &"paper"))
	# the transport's rail seeks by sentence, once a drag settles (see ReadingStream.seek)
	_seek_timer = Timer.new()
	_seek_timer.one_shot = true
	_seek_timer.wait_time = SEEK_SETTLE
	_seek_timer.timeout.connect(_stream.seek_now)
	add_child(_seek_timer)
		# what produces the text comes before the voice that reads it (a table show's episode)
	_note_cards(true)
		# a show that names its episodes keeps the Script card's Episode: the picked one's title
	if not publish.note_is_episode():
		_writer.hand_field("episode", func() -> Variant: return publish.episode_title(),
			func(t: String) -> String: return publish.name_episode(t))
		# the rest are the note's: the Voice ([VoiceCard], the cast this panel reads), the Medium, the Storyboard, the
		# Look, the bookends...
	_note_cards(false)
	# ...and where the video goes, when the note says so
	if _attached.has("youtube"):
		_add_youtube()
		# ...what the show may be paced by ([PacingCard]): a card only while some component offers a row
	_panel.add_card("pacing", "Pacing", &"producer", "", PacingCard.BLURB).add_child(PacingCard.new(func() -> Array: return tune_sections))
		# ...the timeline open, as a list ([TimelineList]): a card shown only while a timeline editor is open
	_panel.add_card("timeline", "Timeline", &"picture", "", TimelineList.BLURB).add_child(TimelineList.new())
	# ...and what is made for all of it, last of them: found in one place on every note (next/pipeline.md)
	_pipeline.put_on(_panel)
	# rows only some media use (the Ink) follow the medium the moment it changes
	_sync_medium_rows()
	Director.medium_changed.connect(_sync_medium_rows)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 11)
	_status.add_theme_color_override("font_color", Color(0.55, 0.95, 0.75, 0.85))
	box.add_child(_status)


## What the workspace's row says ([member workspace]): its `label`.
func _row(field: String) -> String:
	return String(Registry.field(Components.WORKSPACES, workspace, field, ""))


## The note's cards ([method NoteCards.build]): one for each component it has - or, started without a note, each
## the workspace has ([method _components]). [param producers]: the cards of what produces the text, which stand
## above the voice that reads it; otherwise the rest, the Voice first. YouTube is this panel's own to build
## ([method _add_youtube]: a component adds rows of its own to it). Each card is handed what it may need of this
## panel in `ctx`: `workspace` (this panel), `cast` (the voices the reading plays), `reading` (a voice is
## attached, so every format of the Medium is offered), `provides` (what the note's components give: a table show's
## Medium offers Table's formats, [method Medium.offered]), `blocks` and `reshape` (the Medium's format, and the note
## written and opened again when it picks one with rows of its own) and the bookends' tooltips in the words of
## what the show is presented on (its row's `intro_tip` / `outro_tip`, or its Medium format's).
func _note_cards(producers: bool) -> void:
	var have := _voiced()
	var with := {"reading": true, "workspace": self, "cast": _cast, "blocks": _blocks, "reshape": _reshape,
		"provides": Components.provided(have)}
	var fmt: Variant = _blocks.get("medium")
	var rows: Array = []
	for key in have:
		rows.append(Components.REGISTRY.get(key, {}))
	if have.has("medium") and fmt is Dictionary:
		rows.append(Medium.REGISTRY.get(String((fmt as Dictionary).get("format", "")), {}))
	for row in rows:
		for tip in ["intro_tip", "outro_tip"]:
			var said := String((row as Dictionary).get(tip, ""))
			if not said.is_empty():
				with[tip] = said
	var only: Array = []
	for key in _hosted():
		if (StringName(Registry.field(Components.REGISTRY, key, "family", &"")) == &"producer") == producers:
			only.append(key)
	with["only"] = only
	var built := NoteCards.build(_panel, have, with)
	for key in built:
		_add_block(built[key])


## Which of a note's component cards this workspace shows, of [constant NoteCards.KEYS]: its row's
## `hosts`. (YouTube is this panel's own to build.)
func _hosted() -> Array:
	return Registry.field(Components.WORKSPACES, workspace, "hosts", []) as Array


## The components this panel is made of: the note's, or, started without one, every one its workspace has (the
## row's `classic`).
func _components() -> Array:
	if not note_path.is_empty():
		return _attached
	return Registry.field(Components.WORKSPACES, workspace, "classic", ["text", "voice"]) as Array


## ...and its voice, always, for the cards and the blocks they keep: a reading is the voice's workspace, and a
## table show requires one before its note carries the block. And what its components bring
## ([method Components.with_required]): a Likeness brings an Actor, whose card stands beside it from the first
## open. And what comes with them ([method Components.with_parts]): the Pictures card beside the Medium.
func _voiced() -> Array:
	var have: Array = Components.with_parts(Components.with_required(_components()))
	if not have.has("voice"):
		have.append("voice")
	return have


## Put [param card] - a node with `KEY`, `capture()` and `apply(block)` - on a card of its own,
## and keep its block in the document. A card with a `noted` signal speaks on the status line.
func _add_block_card(title: String, family: StringName, card: Control) -> Control:
	var body: VBoxContainer = _panel.add_card(String(card.KEY), title, family)
	body.add_child(card)
	_add_block(card)
	return card


## The components this note has, for "+" and for what may be detached: what its blocks say, and what has been
## attached since the panel came up. Without a note, the workspace's own.
func _has() -> Array:
	var have: Array = _components().duplicate()
	if _youtube != null and not have.has("youtube"):
		have.append("youtube")
	return have


## What the note's show is, for main ([method main._attach_show]): whether it has something to be seen in (a
## Medium, a table; a voice alone is heard, its words over an empty frame) and the storyboard it walks. Without a
## note, the workspace's show.
func show_plan() -> Dictionary:
	if note_path.is_empty():
		return {"picture": true}
	var plan := {"picture": not Components.holder("presentation", _attached).is_empty(), "board": {}, "source": ""}
	var story: Object = _block_cards.get("scenes")
	if story != null and story.has_method("plan"):
		plan.merge(story.call("plan"), true)
	return plan


## What the cards hold, written into the note, and the note opened again around it: a format with rows of its own
## picked on the Medium card, or one left ([member MediumCard._reshape]).
func _reshape() -> void:
	_rewrite(func(held: Dictionary) -> String:
		var ghost := NoteStore.blocks_of(note_path)
		ghost.merge(held, true)
		return FrontMatter.write_block(note_path, ghost))


## A component picked from "+". YouTube's card is added at once (the autosave writes its block into the note).
## Anything else changes what the note is made of: its block is written and the note opened again
## ([method NoteCards.attach]).
func _attach(key: String) -> void:
	if key == "youtube" and _youtube == null:
		_add_youtube()
		_set_status("YouTube attached: tick \"Upload after export\" to send this note's exports to your channel.")
		return
	_rewrite(func(held: Dictionary) -> String: return NoteCards.attach(note_path, key, held))


## A card's ×, once asked: its blocks out of the note, and the note opened again without it.
func _detach(key: String) -> void:
	_rewrite(func(held: Dictionary) -> String: return NoteCards.detach(note_path, key, held))


## Change what the note is made of, then open it again (see [method NotePanel._rewrite]): what is waiting to be
## saved goes into the file first, [param write] makes the change, and this panel stops saving before the next
## one is built.
func _rewrite(write: Callable) -> void:
	if note_path.is_empty() or not reopen.is_valid():
		_set_status("⚠  That needs a note - this panel was opened without one.")
		return
	if not _doc.settle():
		return
	var err := String(write.call(_doc_capture()))
	if not err.is_empty():
		push_warning("ghost: could not change what %s is made of - %s" % [note_path.get_file(), err])
		_set_status("⚠  " + err)
		return
	_doc.set_process(false)
	_doc.capture = Callable()
	reopen.call(note_path)


## The YouTube card, last of the note's cards. One attached while the panel is up is moved above the Pipeline
## card, where a card built with the panel stands.
func _add_youtube() -> void:
	_youtube = YouTubeCard.new()
	_youtube.values = func() -> Dictionary: return publish.upload_values()
	_youtube.name_from(_writer)
	_panel.add_card(YouTubeCard.KEY, "YouTube", &"publish", "youtube").add_child(_youtube)
	_block_cards[YouTubeCard.KEY] = _youtube
	_youtube.noted.connect(_set_status)
	_offer_pipeline(_youtube)
	var card: Node = _youtube.get_parent()
	while card != null and not (card is Card):
		card = card.get_parent()
	if card != null and _pipeline.card != null and _pipeline.card.get_parent() == card.get_parent():
		card.get_parent().move_child(card, _pipeline.card.get_index())
	publish.youtube_built(_youtube)
	if publish.note_is_episode():
		_note_upload = NoteUpload.new(self, _youtube)
		_youtube.extra.add_child(_note_upload)


## Keep [param card]'s block in the document without a card of its own (one shown inside another).
func _add_block(card: Object) -> void:
	_block_cards[String(card.KEY)] = card
	if card.has_signal("noted"):
		card.noted.connect(_note)
	_offer_pipeline(card)


## What [param card] makes for the note, if it makes anything (`pipeline()`), on the one list. A card attached
## while the panel is up adds its own at once.
func _offer_pipeline(card: Object) -> void:
	if not card.has_method("pipeline") or _pipeline == null:
		return
	var section: PipelineSection = card.call("pipeline")
	if section != null:
		section.episode = episode_feed
		_pipeline.add(section)


## The note's Pipeline card.
func pipeline() -> PipelineCard:
	return _pipeline


## The episode what is made from one reads ([EpisodeFeed]): the one the note's show picked, else the note itself,
## which is then its own ([NoteUpload]); null while the note has neither.
func episode_feed() -> EpisodeFeed:
	var shown := publish.feed()
	if shown != null:
		return shown
	return _note_upload.feed() if _note_upload != null else null


## The episode in [param feed] is being left or thrown away: what is being made of it stops.
func episode_left(feed: EpisodeFeed) -> void:
	if _pipeline != null:
		_pipeline.episode_left(feed, episode_feed())


func _build_header(_box: VBoxContainer) -> void:
		# pinned over the scrolling body, so "⋯" and "–" never scroll away (SidePanel.pin_title_row)
	(_panel as SidePanel).pin_title_row(self)


## The script: a card here, the writing in the editor window it opens. Where the words come from (a draft, or a
## file on disk re-read at every Play) is the DocSource inside it. The card's section, blocks and mode are this
## panel's own (see [member _section], [member _mode]).
func _build_source(box: VBoxContainer) -> void:
	_writer = preload("res://src/ui/script_writer.gd").new()
	_writer.setup(_section, _doc_blocks(), _mode)
	if not note_path.is_empty():
		_writer.bind_note()
		_writer.doc.moved.connect(_on_note_moved)
	_doc = _writer.doc
	_doc.capture = _doc_capture
	_doc.apply = _doc_apply
	_text = _writer.text_edit
	_text.text_changed.connect(func() -> void:
				# The cast follows the text whoever changed it: a document arriving brings a whole new set of names.
		_cast.follow_text()
		if _doc.is_quiet():
			return          # the document being shown, not the author typing
		touch()
		_on_source_edited())
	box.add_child(_writer)
	_writer.doc.default_text = _starter()
		# ...and its marks on the voice's clock (next/editing.md step 12: [ReadingTimeline]): docked under the show, read-only
	var tl := Button.new()
	tl.text = "Timeline…"
	tl.toggle_mode = true
	tl.focus_mode = Control.FOCUS_NONE
	tl.tooltip_text = ("The words' marks as a timeline, under the show: each mark - a pause, a voice heard through a phone, a strike, "
		+ "a sketch - a flag where it comes in the words as the reader says them, each heading a group. Move a mark in the words.")
	tl.toggled.connect(func(on: bool) -> void:
		if on:
			if open_marks() == null:
				tl.set_pressed_no_signal(false)
		else:
			close_marks())
	box.add_child(tl)
	_marks_btn = tl
		# ...opened from beside Play, as every note's timeline is ([method Transport.offer_timeline]), below a show's own
	tl.visible = false
	tree_entered.connect(_offer_marks)
	tree_exiting.connect(func() -> void: Transport.withdraw_timeline(self))
	# (the panel builds its cards from its _ready, already in the tree: offered now)
	if is_inside_tree():
		_offer_marks()
		# ...and what is kept of the note ([NoteKept]): its cache (the picked episode's folder, else its own) and every state to go back to
	var kept := NoteKept.new()
	kept.doc = _doc
	kept.cache_dir = func() -> String:
		var f := episode_feed()
		return f.folder() if f != null and not f.folder().is_empty() else NoteUpload.folder_of(note_path)
	kept.history_dir = func() -> String: return NoteUpload.folder_of(note_path).path_join("history") if not note_path.is_empty() else ""
	kept.feed = episode_feed
	kept.after = func() -> void: _stream.mark_stale()
	box.add_child(kept)
	_kept = kept


func _offer_marks() -> void:
	Transport.offer_timeline(self, 1, func() -> void:
		if _marks_dock != null and is_instance_valid(_marks_dock):
			close_marks()
		else:
			open_marks(), func() -> bool: return _marks_dock != null and is_instance_valid(_marks_dock),
		"The words' timeline: each mark - a pause, a voice heard through a phone, a strike, a sketch - where the reader comes to it.")


## The words' marks, docked ([ReadingTimeline]): each where the reader comes to it, a mark picked shown as
## written and found in the words. The dock, null for words with no marks.
func open_marks() -> TimelineDock:
	if _marks_dock != null and is_instance_valid(_marks_dock):
		return _marks_dock
	var body := walk.body(_doc.shown() if _doc != null else "")
	var tl := ReadingTimeline.of(body, ReadingCast.said_word(_cast.cfg_of(_cast.reader())))
	if tl.is_empty():
		_set_status("There are no marks in the words yet: the timeline is where each comes as the reader says them.")
		return null
	_marks_dock = TimelineDock.new()
	_marks_dock.open(tl, "The words' marks")
	_marks_dock.closed.connect(close_marks)
	_marks_dock.inspector = func(what: Dictionary, box: VBoxContainer) -> void:
		var it: Dictionary = what.get("item", {}) if what.get("item") is Dictionary else {}
		var key := String((it.get("text", "") as String)).trim_prefix("<!--").strip_edges().get_slice(":", 0).strip_edges().get_slice(" ", 0)
		var head := Label.new()
		head.text = String(it.get("text", ""))
		head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(head)
		var about := Label.new()
		about.text = "%s\nAt %s as the reader says it." % [ScriptMarks.blurb(key) if ScriptMarks.REGISTRY.has(key) else "", Clock.text(float(it.get("at", 0.0)))]
		about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		about.add_theme_font_size_override("font_size", 12)
		about.modulate = Color(1, 1, 1, 0.7)
		box.add_child(about)
		var src: Array = it.get("source", []) if it.get("source") is Array else []
		var find := Button.new()
		find.text = "Find it in the words"
		find.focus_mode = Control.FOCUS_NONE
		find.pressed.connect(func() -> void:
			var at := _text.text.find(String(it.get("text", "")), maxi(0, int(src[2]) - 64) if src.size() == 3 else 0)
			if at < 0:
				return
			var line := _text.text.substr(0, at).count("\n")
			var col := at - (_text.text.rfind("\n", at - 1) + 1) if at > 0 else 0
			_text.select(line, col, line, col + String(it.get("text", "")).length())
			_text.set_caret_line(line)
			_text.center_viewport_to_caret()
			_text.grab_focus())
		box.add_child(find)
	add_child(_marks_dock)
	if _marks_btn != null:
		_marks_btn.set_pressed_no_signal(true)
	return _marks_dock


func close_marks() -> void:
	if _marks_dock != null and is_instance_valid(_marks_dock):
		_marks_dock.queue_free()
	_marks_dock = null
	if _marks_btn != null:
		_marks_btn.set_pressed_no_signal(false)


## The note was saved into another file ([signal DocSource.moved]): this panel is that file's now, and main
## makes it the note everywhere else (or the next open would read the file it was opened from).
func _on_note_moved(from: String, to: String) -> void:
	note_path = to
	var said := String(note_moved.call(from, to)) if note_moved.is_valid() else ""
	_doc.tell("✓  This note is %s now - every change is saved there. %s" % [to.get_file(), said])


## The first draft of a panel with no draft of its own yet: the starter of a component it has (a table show's
## bundled brief - the row's `starter`), an editable unsynced draft; "" for none.
func _starter() -> String:
	for key in _components():
		var path := String((Components.REGISTRY.get(key, {}) as Dictionary).get("starter", ""))
		if not path.is_empty():
			return FileAccess.get_file_as_string(path)
	return ""


## The author changed the document by hand. Where the document is the reading ([method TextWalk.reads_source]),
## what is on the stream no longer matches it.
func _on_source_edited() -> void:
	if walk.reads_source() and _stream.has_reading():
		_stream.stale = true            # the reading no longer matches the box
	source_edited.emit()


## Show only what the medium can use - the panel's own rows (the Ink); a card keeps its own. Asked
## of the Director, so a run launched with `--medium` shows what that medium uses.
func _sync_medium_rows() -> void:
	Medium.show_rows(_medium_rows, Director.resolved_medium())


func _set_status(msg: String) -> void:
	if _status != null:
		_status.text = msg


## One finding about the script, for the line that reports the plan.
func _note(msg: String) -> void:
	_plan_note += ("  " if _plan_note.is_empty() else "; ") + msg


# --- what a component's card asks of the reading --------------------------------------------------
# A card that changes the reading ([EpisodeCard]) hands it a walk, a bed and a publish, and asks it
# these few things by name - never its own members.


## A block as it stands now, for a card that reads another component's without naming its card (the Episode card
## reads the Direction, [method Direction.text_of]): the card's own as it is (what [method _doc_capture] would
## write) where that card is up, else the note's as it was opened, else {}.
func block_now(key: String) -> Dictionary:
	var got: Variant = _capture_block(key)
	if got is Dictionary:
		return got
	var stored: Variant = _blocks.get(key)
	return stored if stored is Dictionary else {}


## The document the script card holds (the note, or a draft).
func doc_source() -> DocSource:
	return _doc


## The script's box: the text as it is being written.
func source_box() -> TextEdit:
	return _text


## The [Settings] section this panel keeps its own state in.
func section() -> String:
	return _section


## The mode its Script card works in ([member _mode]): what marks its words may carry.
func script_mode() -> String:
	return _mode


## A line on the panel's status row.
func status(text: String) -> void:
	_set_status(text)


## What is on the stream no longer matches what would be read now: the next Play reads it again.
func mark_stale() -> void:
	_stream.mark_stale()


## Something of the panel's changed: it is written to [Settings] once the typing stops.
func touch() -> void:
	_dirty = true
	_last_edit_ms = Time.get_ticks_msec()


## Whether a reading is on the stream now.
func reading_live() -> bool:
	return _stream.live()


## End the reading on the stream.
func stop_speaking() -> void:
	_stream.stop()


## Every voice the cast has, by the name the script cues it with - the reader's first.
func cast_names() -> Array:
	return _cast.cast_dict().keys()


## How long a word takes the reader's voice to say, seconds ([method ReadingCast.said_word]).
func reader_said_word() -> float:
	return ReadingCast.said_word(_cast.cfg_of(_cast.reader()))


## Where each voice sits, by name, in degrees round a table ([member VoiceFX.seat]).
func cast_seats() -> Dictionary:
	var out := {}
	for who in cast_names():
		out[who] = float(_cast.cfg_of(String(who)).get("seat", 0.0))
	return out


# --- what is handed: what the reading reads -------------------------------------------------------

## What this reading reads ([TextWalk]): the note's own words, unless the mode hands another (a table show hands
## the episode it produced, [EpisodeWalk]). Handed, not overridden; the methods below only ask the walk.
var walk: TextWalk = TextWalk.new()


## The words to read, fresh: what Play, a scrub and an export read. Here the document's own body - in sync mode
## the file as it is on disk right now (see [method DocSource.pull]).
func _reading_body() -> String:
	return walk.body(_doc.pull())


## What the voice reads of [param body] and the title it announces first: `{body, title}`. A tablet chapter is
## read off the screen and nothing else.
func _reading_of(body: String) -> Dictionary:
	return walk.spoken(body, _doc_field(body, "title").strip_edges())


## The text the cast is derived from - the speaker cues in it are the tabs.
func _cast_text() -> String:
	return walk.cast_text(_text.text)


## The text the live session is fingerprinted by (its scenes' seed, the pad's notes).
func _fingerprint_text() -> String:
	return walk.cast_text(_text.text)


## Whether there is anything to read (and so to export).
func _has_reading() -> bool:
	return not _cast_text().strip_edges().is_empty()


## The passage every voice is auditioned with by Test.
func _test_passage() -> String:
	return walk.test_passage(ReadingAudition.PASSAGE)


# --- persistence (mirrors SynthEditor._persist / _load_persisted) ---------------------------------


## Debounced: a keystroke marks the draft dirty, and the write happens once the typing stops.
func _process_persist() -> void:
	if _dirty and Time.get_ticks_msec() - _last_edit_ms >= AUTOSAVE_DELAY_MS:
		_persist()


func _persist() -> void:
	_dirty = false
	Settings.write(_section, "text", _doc.draft())
	_cast.persist()
	persisted.emit()


func _load_persisted() -> void:
	_cast.load_stored()
		# Last, and once: every dial the chain reads is now in the slot, so this is where the loaded session's room is
		# applied.
	Delivery.apply_fx(_stream.fx, _cast.slot_cfg(_cast.slot))
		# ...and now the box is filled, after the cast is loaded, because an open document overrules what was loaded
		# above: in sync mode the file is the source of truth for both the words and the voice (see
		# DocSource.bind_text). The text arriving re-derives the tabs.
	_doc.bind_text(_text)
	_cast.refresh(_cast_text())


# --- the document's own settings ------------------------------------------------------------------


## The blocks this panel keeps under the document's `ghost:` key, one per card with settings, in the panel's
## order (the order a fresh document gets them in; see [DocSource]). A block is the component's, not the panel's:
## every panel reads and writes the same `voice:`, `look:` and `bookends:`, so a chapter's voices are there
## whichever panel opens it.
func _doc_blocks() -> PackedStringArray:
		# asked before the cards are built (the script's source is set up first), so read off what the note has
		# attached, never off the cards - in the order the cards stand: what produces the text, the voice, the rest
	var have := _voiced()
	var out := PackedStringArray()
	for producers in [true, false]:
		for key in _hosted():
			var producer := StringName(Registry.field(Components.REGISTRY, key, "family", &"")) == &"producer"
			if producer != producers or not have.has(key):
				continue
			for b in Components.blocks_of(key):
				if not out.has(String(b)):
					out.append(String(b))
	if not out.has("youtube"):
		out.append("youtube")
	return out


## Every block this panel keeps, for [DocSource] to store in a document's frontmatter.
func _doc_capture() -> Dictionary:
	var out := {}
	for key in _doc_blocks():
		var block: Variant = _capture_block(key)
		if block is Dictionary:
			out[key] = block
	return out


## One block as it is now, or null for one this panel does not keep: each is a card's.
func _capture_block(key: String) -> Variant:
	var card: Object = _block_cards.get(key)
	return card.capture() if card != null else null


## ...and back the other way: the blocks a document carries, each to its card. A block the
## document does not carry changes nothing.
func _doc_apply(blocks: Dictionary) -> void:
		# The other cards first, on their own: a document may carry a look and no cast yet; then the voice, whose cast
		# reads the script's speakers as the rest stand
	for key in _doc_blocks():
		var card: Object = _block_cards.get(key)
		if key != VoiceCard.KEY and card != null and blocks.get(key) is Dictionary:
			card.apply(blocks[key] as Dictionary)
	var voice: Object = _block_cards.get(VoiceCard.KEY)
	if voice != null and blocks.get(VoiceCard.KEY) is Dictionary:
		voice.apply(blocks[VoiceCard.KEY] as Dictionary)


## The script's text, whenever the cast is read from it: the cards that follow the words follow it.
func _script_text_changed(body: String) -> void:
	for key in _block_cards:
		var card: Object = _block_cards[key]
		if card != null and card.has_method("set_script_text"):
			card.call("set_script_text", body)


## What [method export_take] hands the book medium, and what main gives a live one: the chapter as the author
## wrote it, so pages can be typeset from the same words being read. The title, the book's name and its author are
## carried separately because in sync mode the body arrives without its frontmatter.
func book_document(body := "") -> Dictionary:
	var src := body if not body.is_empty() else _reading_body()
		# Each voice's pen, beside the text for the reason the title is: in sync mode the voices live in the frontmatter.
	var inks := {}
	var cast := _cast.cast_dict()
	for who in cast:
		var v := String((cast[who] as Dictionary).get("ink", ""))
		if not v.is_empty():
			inks[who] = v
	return publish.book({"source": src, "title": _doc_field(src, "title"), "book": _doc_field(src, "book"),
		"author": _doc_field(src, "author"), "inks": inks, "start_words": _stream.start_words(),
		"start_index": _stream.start_index(), "start_time": _stream.start_time()}, body)


## A top-level frontmatter field (`title:`, `book:`): what the source says (the synced file,
## or the panel's own fields for an unsynced script), else [param src]'s own frontmatter.
func _doc_field(src: String, key: String) -> String:
	var v := _doc.field(key) if _doc != null else ""
	return v if not v.is_empty() else FrontMatter.field_of(src, key)


# --- what a reading asks of the host: its plan and its requests -----------------------------------


## What the plan is asked ([method ReadingPlan.make]): whose voice the reader's cue is (the cast's first), the
## Hesitate row as it stands, and the Outro's length.
func _plan_ask() -> Dictionary:
	var ask := _cast.hesitation()
	ask["reader"] = _cast.reader()
	ask["outro"] = Director.outro_hold
	return ask


## [param body] planned ([method ReadingPlan.make]) as the walk reads it (the title announced first, a tablet
## chapter off its screen, [method _reading_of]). What the plan noticed goes on the line that reports it
## ([member _plan_note]).
func _plan_of(body: String) -> Dictionary:
	var read := _reading_of(body)
	var plan := ReadingPlan.make(String(read["body"]), String(read["title"]), _plan_ask())
	_plan_note = ""
	if not String(plan["note"]).is_empty():
		_note(String(plan["note"]))
	return plan


## The chunks of [param body] ([method _plan_of]): what playback, the scrub and the export read.
func _build_chunks(body: String) -> Array:
	return _plan_of(body)["chunks"]


## [param body]'s passages by speaker, as the walk reads it ([method ReadingPlan.passages]).
func _split_speakers(body: String) -> Array:
	var read := _reading_of(body)
	return ReadingPlan.passages(String(read["body"]), String(read["title"]), _plan_ask())


## Where the reader is, sentence by sentence, in [param chunks] from [param from] on
## ([method ReadingPlan.near]), from each voice's Near dial as it is now.
func _plan_near(chunks: Array, from: int, voice := "") -> void:
	ReadingPlan.near(chunks, from, func(name: String) -> float: return float(_cast.cfg_of(name)["near"]), voice)


## [method Delivery.request_args] for slot [param s], with the reader this install's voice holds - and how the host
## may look up a word eSpeak would guess at (lexicon.py): from Wiktionary, kept in its cache; never in a process
## that must not write the user's things, so a test is the same on every machine.
## The key a sentence is kept under ([TakeCache]): voice config [param s]'s voice, that voice's own record, and
## the request's [param args].
func take_key(s: Dictionary, args: Dictionary) -> String:
	var id := _cast.voice_id_of(s)
	var record := {}
	for v in _cast.voice_meta:
		if String((v as Dictionary).get("id", "")) == id:
			record = v
	return TakeCache.key_of(id, record, args)


func _request_args(s: Dictionary, ch: Dictionary) -> Dictionary:
	var a := Delivery.request_args(s, ch, _cast.speaker_of(s), _cast.blend_of(s))
	a["lexicon"] = "off" if Settings.is_read_only() else "fetch"
	return a


## [method Delivery.gap_before], with the Turn dial as it stands.
func _gap_before(chunks: Array, idx: int, s: Dictionary) -> float:
	return Delivery.gap_before(chunks, idx, s, _cast.turn_scale())


# --- the audition ---------------------------------------------------------------------------------


## Test: the selected tab's voice on its own ([ReadingAudition]), or stop the one playing. One sound at a time.
func _on_test() -> void:
	if _test_busy():
		_stop_test()
		return
	if _host == null or not _host.is_up() or _cast.voice_meta.is_empty():
		return
	if _stream.has_reading():
		_stream.stop()
	_cast.capture_slot()
	_audition.start(_test_passage(), _cast.tab_name())
	_show_testing(true)
	_set_status("Testing %s…" % _cast.tab_name())


func _test_busy() -> bool:
	return _audition.busy()


func _stop_test() -> void:
	_audition.stop()
	_show_testing(false)


## The Test button says what pressing it does now.
func _show_testing(on: bool) -> void:
	_cast.show_testing(on)


# --- the host -------------------------------------------------------------------------------------


func _on_host_ready(backends: PackedStringArray) -> void:
	_set_status("Voice host up (%s). Loading voices…" % ", ".join(backends))
	_host.capabilities()
	_host.list_voices()


## A voice made while this note is open (an actor's own, from the Actor card): the voices asked for again, and
## the reader reads in it ([method ReadingCast.voice_made]).
func voice_made(id: String) -> void:
	_cast.voice_made(id)
	if _host != null and _host.is_up():
		_host.list_voices()


func _on_failed(stage: String, message: String) -> void:
	_set_status("%s failed: %s" % [stage, message])
	if stage != "synthesize":
		return
	_can_play = true
	_stream.failed()


## Have the host prepare [param voice] before it is asked to read in it ([method VoiceHost.ensure]):
## the voice the list opens on and every voice picked after.
func warm_voice(voice: String) -> void:
	if not voice.is_empty() and _host != null and _host.is_up():
		_host.ensure(voice)


func _on_synthesized(id: int, result: Dictionary) -> void:
	if result.has("backends"):
		var caps: Dictionary = result["backends"]
		for name in caps:
			if bool((caps[name] as Dictionary).get("duration_control", false)):
				_cast.show_pace()
			if bool((caps[name] as Dictionary).get("blend", false)):
				_cast.offer_blends(String(name))
		return
	if result.has("voices"):
		_cast.fill_voices(result["voices"])
		return
	if _audition.owns(id):
		_audition.take(id, result)
		return
	if _stream.owns(id):
		_stream.arrived(id, result)


# --- export ---------------------------------------------------------------------------------------


## What an export of this reading is called, without an extension; "" keeps the exporter's own name (see
## [member Exporter.name_provider]). The reading's [member publish] says; a note read as it is written is named
## after itself: its Episode, else its Title, else the file it is kept in.
func export_name() -> String:
	var named := publish.name()
	if named.is_empty() and publish.note_is_episode() and _writer != null:
		named = _writer.field_value("episode")
		if named.is_empty():
			named = _writer.title_or_name()
	return named


## What an upload of the take at [param take] says (see [member Exporter.upload_provider]): the YouTube card's
## title, visibility, playlist and thumbnail over what [member publish] adds, and for a note that is its own
## episode its tags and the description written on the card; {} without a card, or with its box clear.
func upload_meta(take: String) -> Dictionary:
	if _youtube == null:
		return {}
	var base := publish.upload_base(take)
	if _note_upload != null and not base.is_empty():
		base = _note_upload.upload_of(base)
	return _youtube.meta(base, take)


## Gate for the export button: text and a loaded voice.
func can_export_take() -> bool:
	return _has_reading() \
		and not _cast.voice_meta.is_empty() and _host != null and _host.is_up()


## Render the whole text to one WAV, independent of whatever is playing, with what the take is of held by
## [member publish] while it renders and what goes with it written after. A note that is its own episode has what
## its upload takes made from its words meanwhile, and waits for it ([NoteUpload]).
func export_take() -> String:
	if not publish.before_take():
		return ""
	if _note_upload != null:
		_note_upload.start()
		# A take kept for these words in these voices is the export's, nothing said again
	var body := _reading_body().strip_edges()
	var kept := kept_take(body)
	var path: String = _kept_copy(kept, body) if not kept.is_empty() else ""
	if path.is_empty():
		path = await _render_take()
	if _note_upload != null and not path.is_empty():
		await _note_upload.settled()
	var said := publish.after_take(path)
	if not said.is_empty():
		_set_status(said)
	return path


## The take kept at [param kept], as an export's own: copied beside the takes an export renders, its sidecar's
## book and opening as they stand now ([method _render_take] writes both at render time). The copy's absolute path,
## "" when it could not be made (and then the take is rendered).
func _kept_copy(kept: String, body: String) -> String:
	var side: Variant = JSON.parse_string(FileAccess.get_file_as_string(kept.get_basename() + ".json"))
	if not (side is Dictionary):
		return ""
	var path := ProjectSettings.globalize_path(take_dir + "/take_%d.wav" % Time.get_ticks_msec())
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if DirAccess.copy_absolute(kept, path) != OK:
		return ""
	(side as Dictionary)["opening"] = Director.opening_shown()
	(side as Dictionary)["book"] = book_document(body)
	var f := FileAccess.open(path.get_basename() + ".json", FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(JSON.stringify(side))
	f.close()
	_set_status("The take kept is the export's: nothing is said again.")
	return path


## What a take of [param body] (the words to read, by default) is said from, as a digest: the words, every voice's
## settings and the record of the voice each is said in, the bookend and the place under it - everything
## [method _render_take] reads. Written in every take's sidecar (`sig`): a take kept whose `sig` is this one is the
## reading as it would be said now.
func take_sig(body := "") -> String:
		# ...the words as they stand, never pulled: a pull reads the file and lays its blocks over every card, and a row
		# asks this at every refresh (panel_fit_check)
	var b := (walk.body(_doc.shown() if _doc != null else "") if body.is_empty() else body).strip_edges()
	var cast := _cast.capture()
	var records := {}
	var voices: Dictionary = cast.get("voices", {}) if cast.get("voices") is Dictionary else {}
	for name in voices:
		var id := _cast.voice_id_of(voices[name])
		for v in _cast.voice_meta:
			if String((v as Dictionary).get("id", "")) == id:
				records[id] = v
	var place := bed.of(true)
	return JSON.stringify([b, cast, records, Director.intro_hold, Director.outro_hold, String(place.get("key", "")),
		bed.level()]).sha256_text()


## The take kept for [param body]: the episode's ([method EpisodeFeed.take]) where it was said from these words in
## the voices as they stand ([method take_sig]); "" for none, and then the reading is said live.
func kept_take(body: String) -> String:
	var feed := episode_feed()
	var path := feed.take() if feed != null else ""
	if path.is_empty() or not FileAccess.file_exists(path):
		return ""
	var side: Variant = JSON.parse_string(FileAccess.get_file_as_string(path.get_basename() + ".json"))
	return path if side is Dictionary and String((side as Dictionary).get("sig", "")) == take_sig(body) else ""


## Whether the reading heard now is a take kept, playing as a file ([method kept_take]).
func take_playing() -> bool:
	return not _stream.take_path.is_empty()


## The take kept has played to its end ([signal Spectrum.song_finished]): the reading is over, as a reading said
## live ends, and Play plays it again from the top.
func take_ended() -> void:
	_stream.take_done = true


## The whole take, rendered as an export renders it and nothing else done (no upload notes, no publish): what a
## show's "Voice" row keeps (next/editing.md step 3). Every sentence said before comes from the [TakeCache]. The
## take's path, "" for none.
func render_take() -> String:
	return await _render_take()


## A coroutine, because the host answers asynchronously and the exporter awaits this. It does not reuse the
## playback queue: an export captures the entire reading and must not disturb a reading in progress.
func _render_take() -> String:
	var body := _reading_body().strip_edges()
	if body.is_empty() or _cast.voice_pick.selected < 0:
		return ""
	_cast.refresh(body)
		# A plan of its own, fade and all: an export made while a reading plays must not change what that one fades by
	var plan := _plan_of(body)
	var chunks: Array = plan["chunks"]
	var fade_len := float(plan["fade"])
	if chunks.is_empty():
		return ""
	var stamp := Time.get_ticks_msec()
		# The bookend, written into the take itself: held silence at the head and tail, so the video opens and closes
		# on something. It goes in before the effects chain: VoiceFX is a filter, so given real samples the ambience
		# pad (an independent instrument on its own clock) swells through the intro and decays through the outro;
		# padding the PCM afterwards would leave both ends digital silence.
	var intro := maxf(0.0, Director.intro_hold)
	var outro := maxf(0.0, Director.outro_hold)
	var head := int(intro * float(_sr))
	var pcm := PackedFloat32Array()
	pcm.resize(head)
	var words: Array = []
		# One join, the live reading's too ([ReadingJoin]): the seams, the hesitations, where the room changes voice and
		# distance and every word, in frames and seconds of the take, the intro included
	var join := ReadingJoin.new(_sr, words, head)
	var phones: Array = []
	join.phones = phones
	join.label = "export chunk"
	_plan_near(chunks, 0)

	for i in chunks.size():
		_set_status("Rendering for export: %d of %d…" % [i + 1, chunks.size()])
				# The same arguments the preview used, from the same builder: an export that re-derived its own would be
				# a different performance from the one auditioned.
		var who := String((chunks[i] as Dictionary).get("speaker", ""))
		var s := _cast.cfg_of(who)
		var args := _request_args(s, chunks[i])
				# A sentence said before is not said again ([TakeCache]): the same request is the same performance
		var key := take_key(s, args)
		var hit := TakeCache.find(key)
		var out: Dictionary
		var part := PackedFloat32Array()
		if not hit.is_empty():
			out = hit["out"]
			part = Splice.read_wav(String(hit["wav"]))
		else:
			var id := _host.request("", _cast.voice_id_of(s), TAKE_DIR + "/export_%d_%d.wav" % [stamp, i], args, null)
			var res: Array = []
			while true:
				res = await _host.synthesized
				if int(res[0]) == id:
					break
			out = res[1]
			var wav := String(out.get("wav", ""))
			if wav.is_empty():
				continue
			if not Settings.is_read_only():
				TakeCache.put(key, wav, out)
			part = Splice.read_wav(wav)
			DirAccess.remove_absolute(ProjectSettings.globalize_path(wav))
		if part.is_empty():
			continue
		pcm.append_array(join.add(chunks, i, part, out.get("tokens", []), s, _cast.turn_scale(), out.get("phones", [])))

	if join.frames <= head:
		return ""
	var spoken := float(join.frames - head) / float(_sr)
		# The outro mark: the reading ends where its fade does (cut there, or filled out with silence if the text ran
		# out first); the fade is the outro, so none is added after
	var fade_end := join.fade_end(fade_len)
	if fade_end >= 0:
		join.end_at(fade_end)
		pcm.resize(join.frames)
		outro = fade_len
	else:
		pcm.append_array(join.pad(int(outro * float(_sr))))

		# the ambience belongs in the render, so the export matches the audition - a fresh chain, since the live one is
		# mid-reading and carries its own tails
	var fx := VoiceFX.new()
	fx.pad_seed = hash(body)
	fx.setup(_sr)
		# Seed the key, or the intro is silent anyway: the pad picks its tonic from the voice's tracked pitch, which is 0
		# on silence, so during a leading pad of zeros `_start_tone` refuses to schedule anything and the bed would only
		# begin after the narration. Measuring the voice first and handing the chain its key up front lets the bed play
		# before the first word.
	if intro > 0.0:
		fx.prime_key(pcm)
		# One chain, re-dialed per passage, never one per voice: the effects are stateful, so a second chain would start
		# each speaker in a dead room and cut the previous tail off. The first voice's mark is at 0: it owns the intro.
	var marks: Array = join.marks
		# Stereo only when somebody leans: a take where nobody moves is the same mono file, at half the size.
	var leans := false
	var wet := PackedVector2Array()
	var cfg: Dictionary = _cast.cfg_of(String((marks[0] as Dictionary)["speaker"]))
	for k in marks.size():
		var m: Dictionary = marks[k]
				# every mark is applied, even one with no audio before the next: a distance and a voice can change at the
				# same frame
		if m.has("speaker"):
			cfg = _cast.cfg_of(String(m["speaker"]))
			leans = leans or float(cfg["lean"]) > 0.0 or absf(float(cfg.get("seat", 0.0))) > 0.5
			Delivery.apply_fx(fx, cfg)
			fx.heard = String(m.get("heard", ""))
		if m.has("near"):
			Delivery.near_to(fx, m["near"])
		var a := int(m["at"])
		var b := pcm.size() if k == marks.size() - 1 else int((marks[k + 1] as Dictionary)["at"])
		if b > a:
			# ...the voices over this line, each where it sits ([ReadingJoin])
			fx.side = join.side_between(a, b, _cast.pan_of)
			leans = leans or not fx.side.is_empty()
			wet.append_array(fx.process_stereo(pcm.slice(a, b)))
		# The place, under the whole take (its first sample at show time 0, since the take carries its own bookend), so
		# the export hears the gusts the render shows. Rendered on a worker: minutes of take are a long while of GDScript.
	var place := bed.of(true)
	if place.has("make"):
		var env: SoundBed = (place["make"] as Callable).call(_sr, 0.0)
		if env != null and env.active():
			env.set_level(bed.level())
			_set_status("Mixing in the place's sound...")
			var box := [wet]
			var task := WorkerThreadPool.add_task(func() -> void: box[0] = env.mix(box[0]), false, "soundscape export")
			while not WorkerThreadPool.is_task_completed(task):
				await get_tree().process_frame
			WorkerThreadPool.wait_for_task_completion(task)
			wet = box[0]
			leans = true          # the place is stereo
		# ...faded after the effects, so the room and the ambience bed go down with the voice
	if fade_end >= 0:
		var f0 := join.fade_at
		var fade_n := fade_end - f0
		for i in range(f0, wet.size()):
			var u := float(i - f0) / maxf(1.0, float(fade_n))
			wet[i] *= 0.0 if u >= 1.0 else 0.5 + 0.5 * cos(PI * u)

	var path := take_dir + "/take_%d.wav" % stamp
	var abs_path := Splice.write_wav(path, wet, 2 if leans else 1, _sr)
		# Always written, words or not: the book medium reads the chapter from it.
	var side := FileAccess.open(path.get_basename() + ".json", FileAccess.WRITE)
	if side != null:
				# Word timings are in the take's seconds, the bookend included (the join started on it), so the karaoke
				# overlay, the live session and the export render all read this file without knowing a bookend exists.
				# The book rides along: a medium that typesets pages needs the chapter those words came from (see BookMedium).
				# ...and the phones, each sound timed as the words are, for a medium whose mouth says them
				# ...and the opening it was rendered with ([Openings]): a thumbnail of its title screen asks the take
		side.store_string(JSON.stringify({
			"words": words, "phones": phones, "bookend": {"in": intro, "out": outro}, "sig": take_sig(body),
			"opening": Director.opening_shown(), "book": book_document(body)}))
		side.close()
	_set_status("Rendered %.1fs for export (%.0fs intro, %.0fs outro)." % [spoken, intro, outro])
	return abs_path
