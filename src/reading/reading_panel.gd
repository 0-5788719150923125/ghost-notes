extends CanvasLayer
class_name ReadingPanel

## ReadingPanel - a reading of a document in the neural voice: the script, the cast, the voice,
## the stream, the transport's hooks, the export (VOICE_PLAN.md P4). It runs two workspaces - a
## note read aloud, and a show of cards - and is the same panel for both: what differs is the
## note's components, each a card ([method _note_cards]) keeping its block in the document
## ([method _doc_blocks]).
##
## Deliberately NOT a backend swap inside [SynthEditor]. The fishing game's
## economy is defined over the procedural engine's parameter space - difficulty
## is nearest-neighbor distance in a 25-dimensional trait-plus-genome vector,
## the toll anneals a genome toward the belt's forces - and a neural backend
## exposes a speaker id and three global scalars. One UI serving both would be
## built for the intersection of their capabilities, which is nearly empty.
##
## Everything DOWNSTREAM is shared, because a take is just a WAV: [Spectrum],
## the scenes, the exporter, the subtitles and the ` feedback console all work
## unchanged. The panel deliberately mirrors [SynthEditor]'s - same corner, same
## width, same title/hide/hint/text shape - so this reads as another ghost mode
## rather than a bolted-on window.
##
## THE SLIDING WINDOW. A chapter is far too long to synthesize up front: at
## roughly 4x real time, twenty minutes of narration is five minutes of silence
## before anything plays. So the text is cut into chunks at sentence boundaries
## and only [constant LOOKAHEAD] of them are ever in flight. The first chunk
## plays while the second is still being made, and each finished session pulls
## the next one in. First audio arrives in seconds however long the chapter is,
## and memory stays bounded.

## A READING OF A DOCUMENT, WHOEVER WROTE IT. This panel is the voice and the room a reading is
## heard in; what is read comes from the document a [ScriptWriter] holds, and what it is SEEN in is
## the cards of the note's components. NOTHING EXTENDS IT (next/structure.md, step 12): the
## workspace it runs is a row ([member workspace]: its section, title, hint and the cards a panel
## without a note has), and a component that changes the reading HANDS it the part - what is read
## ([member walk]), where it is heard ([member bed]) and how it goes out ([member publish]). Cards'
## [EpisodeCard] hands all three, so the voice pipeline, the cast, the export and the scrubbing
## exist once, for a chapter and for a reading agents write at a table alike.

## Set by main: open ONE generator session for the whole chapter.
var begin_stream: Callable     # begin_stream.call(fp, sample_rate, words) -> playback

## The other half of begin_stream: closes the stream, detaches the Director from the stage and
## frees the subtitle overlay. Optional - an owner that does not set it simply cannot Stop.
var end_stream: Callable

const TAKE_DIR := "user://generative"
# Persisted through [Settings], which owns the one file the whole app shares - one save
# for ghost, not one per mode.
const AUTOSAVE_DELAY_MS := 800
const LOOKAHEAD := 2           # chunks in flight; 1 would stall at every seam
# ...and a bound on how much finished audio may sit AHEAD of the playhead.
#
# LOOKAHEAD alone throttles concurrency, not depth: chunks were requested as
# fast as they arrived, so at ~4x real time the whole chapter ended up decoded
# and queued within a minute. Nothing was wrong with the audio, but a tone or
# pace change then had nothing left to affect - every remaining chunk was
# already made - so the switch appeared to take "ages". Keeping only a few
# seconds buffered is what makes the window actually slide.
# Must comfortably EXCEED the generator's own ring (measured 131071 frames,
# 5.94 s at 22050) - otherwise the ring drains while the next chunk is still
# being synthesized and playback stalls, which is heard as a pause every few
# chunks and seen as the visualizer freezing with it. 3.0 was below the ring and
# did exactly that. The cost is switch latency, which is why chunks are single
# sentences: small chunks keep the window shallow in TIME while still deep
# enough in SECONDS to never starve.
const LOOKAHEAD_SECONDS := 9.0
# The punctuation marks the host is allowed to receive.
#
# A mark is phonemized as part of its word, so whatever is sent here has to have
# an entry in the selected voice's phoneme_id_map - piper.py raises loudly on a
# symbol that does not, and rightly so. This list is the contract: anything else
# a text might end a word with (a bare newline, an em dash, a stray glyph the
# normalizer let through) falls back to the coarse pause_after mapping instead of
# being forwarded verbatim.
const PUNCT_ALLOWED := [".", ",", "!", "?", ":", ";"]
# One sentence per chunk. Two made every tone or pace change wait for the larger
# buffer to drain; one halves that latency, and costs nothing now that the
# inter-sentence gap is inserted at chunk boundaries too (see _drain_ready).
const CHUNK_SENTENCES := 1

# VOICES, plural, and NAMED. One tab per reader, and the tabs are whoever the script says
# is speaking - a line of its own hands the text after it to that name:
#
#     <!-- speaker: Emily White -->     (what a chapter file carries)
#     [speaker: Emily White]            (the same thing, typeable)
#
# THE SCRIPT IS THE CAST LIST. There is no + and no ×: the tabs are derived from the cues
# ([method _refresh_cast]) every time the text changes or a document is read, so a name
# written into the prose is a tab the moment it exists. A name was chosen over a number
# because the author reads the prose, and "speaker 2" says nothing to a reader of it. Text
# before the first cue is [constant Manuscript.NARRATOR]'s.
#
# A tab is a WHOLE settings page, not just a checkpoint id: the voice, the reader within
# it, the tone, the pace, the pauses, the delivery dials and the room are all per-tab. Two
# speakers in one reading are rarely the same person recorded twice.
#
# A NAME THAT LEAVES THE SCRIPT KEEPS ITS VOICE ([member _stash]). Deleting a scene to
# rewrite it must not cost the character their settings, so a name no longer cued is
# hidden, not forgotten, and comes back exactly as it was.
#
# The cue must own its line (see [constant Manuscript.SPEAKER]): a mis-parsed cue does not
# error, it just reads the rest of the chapter in the wrong voice.
#
# HESITATIONS. `<!-- hesitation -->` anywhere in the text - mid-sentence included - is a
# longer rest at exactly that point, for effect; `<!-- hesitation: 2.5 -->` names its own
# length in seconds. The Hesitate row sets the length of a bare one and switches them all.
# The rest is spliced into the take where the host reports the gap after a word, so it lands
# between two words and never inside one (see [method Splice.chunk]).
const HESITATE_DEFAULT := 1.5
const HESITATE_MAX := 6.0
## The voice a new tab reads in, and the one picked when a tab names none: 904 readers under one
## checkpoint, so a cast can be voiced from one model (the user, 2026-10-08: "make 'libritts high' the
## default voice option"). Before, the default was whatever the host listed first.
const DEFAULT_VOICE := "en_US-libritts-high"
## One tab's worth of settings. Also the schema: [method _cfg] merges a stored
## slot onto this, so a slot saved by an older build is missing keys rather than
## broken, and a key added later arrives with a sane value everywhere at once.
const SLOT_DEFAULTS := {
	"voice": DEFAULT_VOICE, "speaker": 0, "tone": 0, "pace": 1.0, "pause": 1.0,
	"dynamics": 0.5, "arc": 0.4, "effort": 0.35,
	"echo": 0.0, "room": 0.0, "resonance": 0.0, "presence": 1.0, "ambience": 0.0,
	"lean": 0.0, "near": 0.0,
	# the pen this voice writes in, in a medium that writes by hand - a name from
	# NotebookLayout.INKS or a hex color; "" is the default black
	"ink": "",
}
## Seconds of audio that must be queued before the first sample is heard, when there is
## no intro to serve as the lead. Chunks are one sentence, and a short opening sentence
## (1.13 s, measured) cannot cover the synthesis of a long second one (14.49 s), so
## playback starves without a floor here. It is a LOWER bound on latency-to-first-word,
## which is why it is not larger.
const LIVE_PREROLL := 2.5

var _last_leans: Array = []     # the delivery marks of the passage being resolved: [at, lean]

var _host: VoiceHost
var _panel: PanelContainer
var _writer: ScriptWriter
var _doc: DocSource
var _text: TextEdit
var _voices: OptionButton
var _test: Button
## THE PANEL'S PLAY AND STOP ARE THE TRANSPORT'S (next/notes.md step 3): this panel conducts the
## clock - see [method transport_hooks] - and the bar along the stage plays, pauses, stops and
## seeks the reading. True once a voice has loaded, so Play can do something.
var _can_play := false
var _test_player: AudioStreamPlayer
var _test_req := {}            # host request id -> chunk index, for the audition
var _test_parts := {}          # chunk index -> wav path, as they arrive
var _test_chunks: Array = []
var _test_name := ""           # the voice being auditioned, fixed when it was pressed
var _test_next := 0            # the next sentence to join onto the audition's stream
var _test_hold := PackedVector2Array()   # wet frames not yet pushed (before playback starts)
var _test_pushed := 0
var _test_read := 0            # cursor into _test_hold: what has been pushed
var _test_tasks := {}          # chunk index -> {box, task}: decoding on a worker
var _test_dry := PackedFloat32Array()   # joined audio waiting for the room (see _pump_test_fx)
var _test_fx_task := {}        # the one piece going through the room right now: {box, task}
var _test_cap := 0             # the generator's ring, measured empty
var _test_fx: VoiceFX = null
var _test_marks: Array = []    # [{at, near}] in frames of the audition's dry audio (see _near_mark)
var _test_near := {}           # the last distance marked
var _test_dry_at := 0          # the frame _test_dry[0] is
var _test_dry_end := 0         # frames joined so far
var _status: Label
var _rate: HSlider
var _rate_row: HBoxContainer
var _pause: HSlider
var _voice_meta: Array = []
var _want_voice := ""          # remembered selection, applied once voices load

# the window
var _chunks: Array = []        # [{tokens, words}] planned up front, cheap
var _ready_takes: Array = []   # [{pcm, index}] synthesized, awaiting the push
var _next_to_request := 0
var _next_to_play := 0
var _in_flight := 0
var _req_chunk := {}           # request id -> chunk index

# the one continuous stream
var _playback: AudioStreamGeneratorPlayback
var _pending := PackedFloat32Array()   # decoded samples not yet handed to the ring
var _read := 0                 # cursor into _pending; slicing it per frame was
                               # an O(n) copy of the whole queue 60 times a
                               # second, which is its own source of hitching
var _sr := 22050
var _elapsed := 0.0            # seconds pushed so far: the offset for chunk N's timings
var _sub_words: Array = []     # shared BY REFERENCE with the Subtitles overlay
var subtitles: Node            # set by main; its clock is re-based here
var _pushed := 0               # frames handed to the ring, for the played-time clock
var _ring_capacity := 0        # measured, never computed - see _drain_ready
var _fx := VoiceFX.new()
## THE PLACE UNDER THE VOICE (a [SoundBed]): the wind, the sea, the rain of where the reading is, mixed
## in after the voice's own effects - live here, and into the exported take by [method export_take]. A
## component that knows where its reading is says so through [member bed]; null when none does.
var _env: SoundBed = null
var _env_key := ""             # the place it was made from, to notice the place changing mid-reading
var _env_poll := 0.0
var _fx_echo: HSlider
var _dynamics: HSlider
var _arc: HSlider
var _effort: HSlider

var _fx_res: HSlider
var _fx_room: HSlider
var _fx_presence: HSlider
var _fx_lean: HSlider
var _fx_near: HSlider
var _fx_pad: HSlider
var _tone: OptionButton
var _speaker: SpinBox
var _speaker_about: Label        # who that speaker number is (VoiceReaders)
var _speaker_browse: PopupPanel
var _speaker_row: HBoxContainer
var _turn: HSlider
var _hesitate: HSlider
var _hesitate_on: CheckBox
var _tabs: VBoxContainer      # one row per speaker the script names
var _cast_head: Label
var _tab_group: ButtonGroup
var _names := PackedStringArray()  # the tabs, in order of first appearance in the script
var _slots: Array = []         # [SLOT_DEFAULTS-shaped Dictionary], one per tab, beside _names
var _stash := {}               # name -> settings, for voices the script no longer cues
var _order := PackedStringArray()  # every voice's name in the order the document lists them - the first is the reader's
var _slot := 0                 # which tab the controls are currently showing
var _cast_timer: Timer         # re-derives the tabs once typing pauses
# The lengths of the hesitations in the passage being cut, in text order; [method _cut]
# consumes them as the phonemizer hands back the sentinels that mark their places.
var _holds: Array = []
var _hold_i := 0
var _syncing := false          # writing controls from a slot must not re-plan
# WHEN THE ROOM CHANGES, in frames of the one continuous stream. The effects
# chain is stateful across chunk boundaries - that is the whole reason it runs
# here rather than in the host - so a second speaker cannot get their own chain
# without cutting the first one's tail off mid-decay. What they get instead is
# the same chain re-dialed at the exact frame their first sample is heard,
# which is what a live slider move already does, just scheduled.
var _fx_marks: Array = []      # [{at: int, speaker: String} or {at, near}], ascending, absolute
var _fx_queued_near := {}      # the last distance a mark was written for (see _near_mark)
# Whether this reading has written its first mark. NOT `_fx_marks.is_empty()`: the push
# consumes the list, so mid-reading it is empty again, and a handover written then at 0 was
# dialed at once - the next voice's room seconds before the next voice.
var _fx_marked := false
var _fx_live_name := ""        # which voice the live chain is currently dialed to
var _fx_queued_name := ""      # ...and the last one a mark was written for
# WHAT THE LAST PLAN NOTICED about the script - a speaker cue with no tab, a
# macro with no default. Not written straight to the status line, for two
# reasons that are both bugs it had: the line is overwritten by "Planned N
# chunk(s)…" a moment later, and a warning written only when there is something
# to warn about STAYS on screen after the text has been fixed. Rebuilt from
# scratch by every _build_chunks, and read by whoever reports the plan.
var _plan_note := ""
var _stream_open := false      # explicit: a null playback must not retry forever
var _epoch := 0                # bumped on a pace change; stale replies are dropped
# THE PREDICTED TIMELINE. The scrub bar used to be scaled by how much audio had been
# DECODED, which grows as the reading is synthesized - so the bar's own length changed
# under the pointer and dragging to "near the end" meant near the end of the first thirty
# seconds. A timeline has to know how long the thing is before it plays it.
var _repace_timer: Timer
## This panel's own rows that belong to a medium feature (the Ink): tag -> the Controls to show
## or hide together, by [method _sync_medium_rows]. A card keeps its own (see [PictureCard]).
var _medium_rows := {}
## THE CARDS THAT KEEP A BLOCK of the document's frontmatter, by block (see [method _add_block_card]):
## each answers `capture() -> Dictionary` and `apply(block)`. The voice is this panel's own.
## The note this panel is (set by main before it is added), "" when started without one.
var note_path := ""
## Set by main: (from: String, to: String) -> String - the note was saved into another file (its
## Script card's Save…), which is the note from here on; returns what became of the file it left.
var note_moved: Callable
## Set by main: (path: String) -> void - open the note again, as what a component attached to it
## or taken off it made it.
var reopen: Callable
## THE COMPONENTS THE NOTE HAS ([method Components.attached_of]), read as the panel is built: the
## cards it shows and what "+" offers follow them. [] when the panel was started without a note
## (the command line, a gate), which is every card the workspace has.
var _attached: Array = []
var _block_cards := {}
var _youtube: YouTubeCard
var _lead_in := 0.0        # the intro seeded into _pending by _plan, in seconds
var _dirty := false
var _last_edit_ms := 0
## The [Settings] section this panel's own state lives in (its draft, its remembered document, an
## unsynced script's cast), and the mode its script's marks are offered for (see [ScriptMarks]):
## the workspace's (its row's `section`). A SYNCED document's settings are not per mode: its blocks
## are the components' ([method _doc_blocks]), so two panels reading one chapter share its voice.
var _section := "generative"

## THE WORKSPACE THIS PANEL RUNS, a key of [constant Components.WORKSPACES] - `reading` (a note read
## aloud) or `cards` (a show of cards) - set by main before the panel is added. Its row says the
## panel's section, title and hint, which of a note's cards it can show (`hosts`) and every card a
## panel started without a note has (`classic`).
var workspace := "reading":
	set(key):
		workspace = key
		_section = String(Registry.field(Components.WORKSPACES, key, "section", "generative"))

## WHERE THE READING IS HEARD ([ReadingBed]): no place, unless a component hands one - Cards hands
## the episode's table, heard.
var bed: ReadingBed = ReadingBed.new()
## HOW THE READING GOES OUT ([ReadingPublish]): what its export is called, what is held while the
## take renders, what an upload says. A note's own, unless a component hands another.
var publish: ReadingPublish = ReadingPublish.new()

## THE AUTHOR CHANGED THE SCRIPT by hand (never a document arriving): for a component that keeps
## count of what an edit changes - Cards' brief changes the NEXT episode, not this one.
signal source_edited
## The panel's own state was written to [Settings] ([method _persist]): a component that keeps
## some there writes its own beside it.
signal persisted


func _ready() -> void:
	layer = 10
	DirAccess.make_dir_recursive_absolute(TAKE_DIR)
	_build_panel()
	# NOTHING TO RENDER without something to be seen in: a voice alone has no ⤓, as a song alone
	# has none (released on the way out, keyed - see Chrome._export_claims)
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
	# THE READING CONDUCTS: registered for as long as the panel is up, so the transport shows a
	# Play before anything has been read, and released when it leaves (_exit_tree).
	Spectrum.conduct(self, transport_hooks())


## Feed the ring. The generator is the only thing keeping the session alive, so
## this must never fall behind; it is a few array copies a frame.
func _process(_delta: float) -> void:
	_process_persist()
	_tick_test()
	# BEFORE the playback guard: a window cut is not part of a reading, and one started
	# with nothing playing would otherwise never be noticed to have finished.
	if _playback == null:
		return
	_tick_environment(_delta)
	# THE PICTURE FADES WITH THE VOICE: the gain of the sample being heard right now, so the
	# outro mark's fade is one fade, in sound and picture, whatever the buffer holds ahead
	if _fade_at >= 0 and _ring_capacity > 0:
		var heard := _pushed - maxi(0, _ring_capacity - int(_playback.get_frames_available()))
		Director.live_fade = _fade_gain(heard)

	# RE-BASE THE SUBTITLE CLOCK FIRST, and unconditionally.
	#
	# This used to sit at the BOTTOM of the push block, after an early return on
	# an empty queue - so the moment synthesis got ahead of playback and there
	# was nothing left to push, the re-base stopped running and time_base froze.
	# Spectrum's clock kept advancing against a stale base, _now() ran past the
	# last word, and the overlay drew nothing from then on. Reported as: the
	# subtitles worked briefly, then disappeared and never came back.
	#
	# It belongs here because it describes PLAYBACK, which continues whether or
	# not there is new audio to hand over.
	if subtitles != null and is_instance_valid(subtitles) and _ring_capacity > 0:
		var queued := _ring_capacity - int(_playback.get_frames_available())
		var played := float(maxi(0, _pushed - maxi(queued, 0))) / float(_sr)
		subtitles.time_base = Spectrum.current.time - played

	# The window has to be topped up as it drains. Requests used to be driven
	# only by chunk ARRIVAL, which stops the moment the buffer bound is hit.
	if not _chunks.is_empty() and _next_to_request < _chunks.size():
		_pump()

	if _pending.size() - _read <= 0:
		return
	var room := int(_playback.get_frames_available())
	if room <= 0:
		return
	var avail := _fx_admit(_pending.size() - _read)
	var n := mini(room, avail)
	# the place is rendered ahead on a worker ([method Soundscape.prefetch]); a frame takes at most half
	# a second of it, so filling the ring at the start is spread over frames rather than one long one
	if _env != null:
		n = mini(n, _sr / 2)
	if n <= 0:
		return
	# the ambience runs HERE rather than in the host: it is stateful across
	# chunk boundaries, so a seam must not reset the echo tail or the ring
	var buf: PackedVector2Array = _fx.process_stereo(_pending.slice(_read, _read + n))
	# ...and the place after it, so the room and the bed are the voice's and the wind is not
	if _env != null:
		buf = _env.mix(buf)
	if _fade_at >= 0:
		for i in n:
			buf[i] *= _fade_gain(_pushed + i)
	_playback.push_buffer(buf)
	_pushed += n
	_read += n
	# compact only when the consumed head is worth reclaiming, not every frame
	if _read > 0 and (_read == _pending.size() or _read > 4 * _sr):
		_pending = _pending.slice(_read)
		_read = 0


## THE ROOM CHANGES AT A FRAME, not at a chunk. Dial in every scheduled change the
## push has reached, and report how many frames may go out before the next one.
##
## The coordinate is ABSOLUTE FRAMES PUSHED, which is the only clock these marks
## can use. It is not what is being heard - the ring runs seconds ahead - and it
## does not need to be: the chain transforms the samples at exactly these
## positions on their way out, so aligning to the push aligns to the audio. Cut
## short at the next mark rather than crossing it, or a whole buffer of one
## speaker is read in the other's room.
##
## Split out of [method _process] because it is the arithmetic here that can be
## wrong by a buffer, and a room that arrives a moment early is audible without
## being attributable.
func _fx_admit(avail: int) -> int:
	while not _fx_marks.is_empty() and int((_fx_marks[0] as Dictionary)["at"]) <= _pushed:
		var m: Dictionary = _fx_marks.pop_front()
		if m.has("speaker"):
			_fx_live_name = String(m["speaker"])
			Delivery.apply_fx(_fx, _cfg_of(_fx_live_name))
		if m.has("near"):
			Delivery.near_to(_fx, m["near"])
	if _fx_marks.is_empty():
		return avail
	return mini(avail, maxi(0, int((_fx_marks[0] as Dictionary)["at"]) - _pushed))


## WHAT THE TRANSPORT DRIVES (see Spectrum's `_conductor`). Space is the transport's too - it
## was this panel's own, taken before a focused button could, and the transport keeps that rule.
func transport_hooks() -> Dictionary:
	return {
		"play": _transport_play,
		"pause": _transport_pause,
		"stop": _stop_speaking,
		"playing": func() -> bool: return _reading_live() and not Spectrum.paused,
		"can_play": func() -> bool: return _can_play,
		"can_stop": func() -> bool: return not _chunks.is_empty() or _playback != null,
		# A stopped reading has nothing on the rail: the sentence scale is the last plan's until
		# the next one, and a seek there would start a reading.
		"position": func() -> float: return _scrub_pos() if not _chunks.is_empty() else 0.0,
		"length": func() -> float: return _scrub_len() if not _chunks.is_empty() else 0.0,
		"seek": _transport_seek,
		"stale": func() -> bool: return _stale and not _chunks.is_empty(),
	}


## Play: carry on a paused reading, or read the script from the top.
func _transport_play() -> void:
	if _reading_live():
		if Spectrum.paused:
			Spectrum.set_paused(false)
			_set_status("Resumed.")
		return
	_on_speak()


func _transport_pause() -> void:
	if _reading_live() and not Spectrum.paused:
		Spectrum.set_paused(true)
		_set_status("Paused. Space or ▶ carries on; ■ ends the reading.")


func _transport_seek(t: float) -> void:
	if not _chunks.is_empty():
		_scrub_seek(t)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F2:
		_panel.visible = not _panel.visible


# --- panel (mirrors SynthEditor._build_panel) --------------------------------


func _build_panel() -> void:
	# A [SidePanel] rather than a bare PanelContainer: this panel has outgrown the window,
	# and a Control outside a container is never asked to fit anything - the rows past the
	# bottom edge were unreachable rather than clipped. See side_panel.gd.
	_panel = preload("res://src/ui/side_panel.gd").new(380.0)
	_panel.title = _row("title")
	if not note_path.is_empty():
		_attached = Components.attached_of(NoteStore.blocks_of(note_path))
		# a note's components come off again: each card's × (see SidePanel.add_card)
		_panel.detach = _detach
		_panel.detach_blocker = func(key: String) -> String: return Components.detach_blocker(key, _has())
	add_child(_panel)
	var box: VBoxContainer = _panel.body
	box.add_theme_constant_override("separation", 8)
	_build_header(box)
	# THE CARDS (next/notes.md, step 2): each section a colored card that folds, its chip in the
	# row under the heading. The order is the families': the text, what produces it, the voice,
	# the picture, the Look - read top to bottom, the panel says what happens to the note.
	_panel.card_prefix = _section
	_panel.add_component_row(_has, _attach)
	_build_source(_panel.add_card("script", "Script", &"paper"))
	# WHAT PRODUCES THE TEXT comes before the voice that reads it (a show of cards' episode)
	_note_cards(true)
	# The voice card: the cast rows (Turn, Hesitate, the list of speakers) are global; every row
	# below the list belongs to the speaker that is selected in it.
	var voice: VBoxContainer = _panel.add_card("voice", "Voice", &"voice", "voice")
	_build_cast(voice)
	_build_voice(voice)
	# THE REST ARE THE NOTE'S (the Picture, the Storyboard, the Look, the bookends...)
	_note_cards(false)
	# ...and where the video goes, when the note says so
	if _attached.has("youtube"):
		_add_youtube()
	# rows only some media use (the Ink) follow the medium the moment it changes
	_sync_medium_rows()
	Director.medium_changed.connect(_sync_medium_rows)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 11)
	_status.add_theme_color_override("font_color", Color(0.55, 0.95, 0.75, 0.85))
	box.add_child(_status)


## What the workspace's row says ([member workspace]): `title`, `hint`.
func _row(field: String) -> String:
	return String(Registry.field(Components.WORKSPACES, workspace, field, ""))


## THE NOTE'S CARDS ([method NoteCards.build]): one for each component it has - or, started without
## a note, each the workspace has ([method _components]) - built the way every panel builds them.
## [param producers]: the cards of what produces the text, which stand above the voice that reads
## it (a show of cards' episode); otherwise the rest, below it. YouTube is this panel's own to build
## ([method _add_youtube]: a component adds rows of its own to it). Each card is handed what it may
## need of this panel in `ctx`: `workspace` (this panel - a producer hands it what the reading reads),
## `reading` (a voice is attached, so every medium is offered) and the bookends' tooltips in the
## words of what the show is presented on (its row's `intro_tip` / `outro_tip`).
func _note_cards(producers: bool) -> void:
	var have := _components()
	var with := {"reading": true, "workspace": self}
	for key in have:
		for tip in ["intro_tip", "outro_tip"]:
			var said := String((Components.REGISTRY.get(key, {}) as Dictionary).get(tip, ""))
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
	# THE BOOK'S PICTURES are set inside the Picture's card and keep a block of their own
	var picture := built.get("picture") as PictureCard
	if picture != null:
		_add_block(picture.illustrations())


## Which of a note's component cards this workspace shows, of [constant NoteCards.KEYS]: its row's
## `hosts`. (YouTube is this panel's own to build.)
func _hosted() -> Array:
	return Registry.field(Components.WORKSPACES, workspace, "hosts", []) as Array


## THE COMPONENTS THIS PANEL IS MADE OF: the note's, or - started without one (the command line, a
## gate) - every one its workspace has (the row's `classic`).
func _components() -> Array:
	if not note_path.is_empty():
		return _attached
	return Registry.field(Components.WORKSPACES, workspace, "classic", ["text", "voice"]) as Array


## Put [param card] - a node with `KEY`, `capture()` and `apply(block)` - on a card of its own,
## and keep its block in the document. A card with a `noted` signal speaks on the status line.
func _add_block_card(title: String, family: StringName, card: Control) -> Control:
	var body: VBoxContainer = _panel.add_card(String(card.KEY), title, family)
	body.add_child(card)
	_add_block(card)
	return card


## THE COMPONENTS THIS NOTE HAS, for "+" and for what may be detached: what its blocks say, and
## what has been attached since the panel came up. Without a note, the workspace's own.
func _has() -> Array:
	var have: Array = _components().duplicate()
	if _youtube != null and not have.has("youtube"):
		have.append("youtube")
	return have


## WHAT THE NOTE'S SHOW IS, for main ([method main._attach_show]): whether it has something to be
## seen in - a Picture, a card table; a voice alone is heard, its words over an empty frame - and
## the storyboard it walks. Without a note, the workspace's show as it always was.
func show_plan() -> Dictionary:
	if note_path.is_empty():
		return {"picture": true}
	var plan := {"picture": not Components.holder("presentation", _attached).is_empty(), "board": {}, "source": ""}
	var story: Object = _block_cards.get("scenes")
	if story != null and story.has_method("plan"):
		plan.merge(story.call("plan"), true)
	return plan


## A component picked from "+". YouTube's card is added at once - the autosave writes its block
## into the note, and nothing of the reading changes. Anything else changes what the note is made
## of: its block is written and the note opened again ([method NoteCards.attach]).
func _attach(key: String) -> void:
	if key == "youtube" and _youtube == null:
		_add_youtube()
		_set_status("YouTube attached: tick \"Upload after export\" to send this note's exports to your channel.")
		return
	_rewrite(func(held: Dictionary) -> String: return NoteCards.attach(note_path, key, held))


## A card's ×, once asked: its blocks out of the note, and the note opened again without it.
func _detach(key: String) -> void:
	_rewrite(func(held: Dictionary) -> String: return NoteCards.detach(note_path, key, held))


## CHANGE WHAT THE NOTE IS MADE OF, then open it again (see [method NotePanel._rewrite]): what is
## waiting to be saved goes into the file first, [param write] makes the change, and this panel
## stops saving before the next one is built.
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


## THE YOUTUBE CARD, last of the cards (the families' order ends where the video goes). One attached
## while the panel is up is moved above the status line, where a card built with the panel stands.
func _add_youtube() -> void:
	_youtube = YouTubeCard.new()
	_youtube.values = _upload_values
	_panel.add_card(YouTubeCard.KEY, "YouTube", &"publish", "youtube").add_child(_youtube)
	_block_cards[YouTubeCard.KEY] = _youtube
	_youtube.noted.connect(_set_status)
	var card: Node = _youtube.get_parent()
	while card != null and not (card is Card):
		card = card.get_parent()
	if card != null and _status != null and _status.get_parent() == card.get_parent():
		card.get_parent().move_child(card, _status.get_index())
	publish.youtube_built(_youtube)


## What the YouTube title's macros are worth now (see [method YouTube.expand_title]): the note's
## title, and what the reading's [member publish] makes of it.
func _upload_values() -> Dictionary:
	var t := _doc.field("title").strip_edges() if _doc != null else ""
	if t.is_empty() and not note_path.is_empty():
		t = NoteStore.title_of(note_path)
	return publish.upload_values({"title": t, "episode": ""})


## Keep [param card]'s block in the document without a card of its own (one shown inside another).
func _add_block(card: Object) -> void:
	_block_cards[String(card.KEY)] = card
	if card.has_signal("noted"):
		card.noted.connect(_note)


func _build_header(box: VBoxContainer) -> void:
	var title_row := HBoxContainer.new()
	# pinned over the scrolling body, so "⋯" and "–" never scroll away (SidePanel.pin_header)
	(_panel as SidePanel).pin_header(title_row)
	title_row.add_child(Shell.back_button(self))
	var title := Label.new()
	title.text = _row("title")
	title.add_theme_font_size_override("font_size", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	title_row.add_child(Shell.note_menu(self))
	var hide := Button.new()
	hide.text = "–"
	hide.tooltip_text = "Hide panel (F2)"
	hide.custom_minimum_size = Vector2(28, 28)
	hide.pressed.connect(func() -> void: _panel.visible = false)
	title_row.add_child(hide)

	var hint := Label.new()
	hint.text = _row("hint")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 12)
	hint.modulate = Color(1, 1, 1, 0.6)
	box.add_child(hint)


## THE SCRIPT: a card here, the writing in the editor window it opens. Where the words
## come from (a draft, or a file on disk re-read at every Play) is the DocSource inside it.
## The card's section, block and marks are this panel's own (see [member _section]).
func _build_source(box: VBoxContainer) -> void:
	_writer = preload("res://src/ui/script_writer.gd").new()
	_writer.setup(_section, _doc_blocks(), _section)
	if not note_path.is_empty():
		_writer.bind_note()
		_writer.doc.moved.connect(_on_note_moved)
	_doc = _writer.doc
	_doc.capture = _doc_capture
	_doc.apply = _doc_apply
	_text = _writer.text_edit
	_text.text_changed.connect(func() -> void:
		# The cast follows the text whoever changed it - a document arriving is exactly
		# when a whole new set of names appears.
		_cast_timer.start()
		if _doc.is_quiet():
			return          # the document being shown, not the author typing
		_dirty = true
		_last_edit_ms = Time.get_ticks_msec()
		_on_source_edited())
	box.add_child(_writer)
	_writer.doc.default_text = _starter()


## THE NOTE WAS SAVED INTO ANOTHER FILE ([signal DocSource.moved]): this panel is that file's now,
## and main makes it the note everywhere else - or the next time the note opened it would read the
## file it was opened from, and every edit since would be in a file nothing reads (2026-10-12, the
## user: "That selection keeps getting reverted back to the untitled cards label").
func _on_note_moved(from: String, to: String) -> void:
	note_path = to
	var said := String(note_moved.call(from, to)) if note_moved.is_valid() else ""
	_doc.tell("✓  This note is %s now - every change is saved there. %s" % [to.get_file(), said])


## THE FIRST DRAFT of a panel with no draft of its own yet: the starter of a component it has (a
## show of cards' bundled brief - the row's `starter`), an editable unsynced draft; "" for none.
func _starter() -> String:
	for key in _components():
		var path := String((Components.REGISTRY.get(key, {}) as Dictionary).get("starter", ""))
		if not path.is_empty():
			return FileAccess.get_file_as_string(path)
	return ""


## The author changed the document by hand. Where the document IS the reading ([method
## TextWalk.reads_source]), what is on the stream no longer matches it.
func _on_source_edited() -> void:
	if walk.reads_source() and not _chunks.is_empty():
		_stale = true            # the reading no longer matches the box
	source_edited.emit()


func _build_cast(box: VBoxContainer) -> void:
	# THE HANDOVER REST, above the tabs because it belongs to no tab: it is the
	# silence BETWEEN two of them. Unlike Pause it needs no re-synthesis - the
	# gap is spliced in as the chunks are joined, not asked of the model - so it
	# takes effect at the next handover rather than at the next chunk.
	var turow := HBoxContainer.new()
	turow.add_theme_constant_override("separation", 8)
	box.add_child(turow)
	var tul := Label.new()
	tul.text = "Turn"
	tul.custom_minimum_size = Vector2(72, 0)
	tul.add_theme_font_size_override("font_size", 12)
	turow.add_child(tul)
	_turn = HSlider.new()
	_turn.min_value = 0.0
	_turn.max_value = Delivery.MAX_TURN_SCALE
	_turn.step = 0.05
	_turn.value = 1.0
	_turn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_turn.tooltip_text = ("EXTRA rest when the script CHANGES SPEAKER, shown in seconds beside it, on top of "
		+ "the ordinary rest between sentences. 1 is a little over half a second - enough to "
		+ "hear one reader stop and another begin; 0 hands over on the same beat as any other "
		+ "sentence, which reads as one person changing their mind rather than as two people. "
		+ "The whole rest is capped at four seconds however far this is pushed. It applies to "
		+ "every tab, because the pause belongs to the boundary and not to either voice, and it "
		+ "takes effect at the next handover - nothing has to be generated again.")
	_turn.value_changed.connect(func(_v: float) -> void:
		if _syncing:
			return
		_dirty = true
		_last_edit_ms = Time.get_ticks_msec())
	turow.add_child(_turn)
	# THE READOUT IS IN SECONDS, not the dial's multiplier: what matters is how long the gap
	# is. There was no readout at all, and a stored 5.1 was a hidden 2.8 s at every handover -
	# "an invisible, forced pause between speakers... killing the pacing".
	var tur := Label.new()
	tur.custom_minimum_size = Vector2(42, 0)
	tur.add_theme_font_size_override("font_size", 12)
	tur.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var show_turn := func(v: float) -> void:
		tur.text = "+%.1fs" % (Delivery.TURN_GAP * v)
	show_turn.call(_turn.value)
	_turn.value_changed.connect(show_turn)
	turow.add_child(tur)

	# HESITATIONS, global for the same reason Turn is: a `<!-- hesitation -->` belongs to a
	# moment in the text, not to whichever voice happens to be reading it. The checkbox
	# switches every marker off at once (an author auditioning the plain reading); the dial
	# is the length of a bare marker, and a marker that names its own length keeps it.
	var hrow := HBoxContainer.new()
	hrow.add_theme_constant_override("separation", 8)
	box.add_child(hrow)
	_hesitate_on = CheckBox.new()
	_hesitate_on.text = "Hesitate"
	_hesitate_on.button_pressed = true
	_hesitate_on.custom_minimum_size = Vector2(72, 0)
	_hesitate_on.add_theme_font_size_override("font_size", 12)
	_hesitate_on.tooltip_text = ("Honor the script's <!-- hesitation --> markers: a longer rest "
		+ "at exactly that point, mid-sentence or between paragraphs, for dramatic effect. Off "
		+ "reads straight through them as if they were not there.")
	hrow.add_child(_hesitate_on)
	_hesitate = HSlider.new()
	_hesitate.min_value = 0.2
	_hesitate.max_value = HESITATE_MAX
	_hesitate.step = 0.05
	_hesitate.value = HESITATE_DEFAULT
	_hesitate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hesitate.tooltip_text = ("How long a bare <!-- hesitation --> rests, in seconds, on top of "
		+ "whatever pause the text already has there. A marker that names its own length - "
		+ "<!-- hesitation: 2.5 --> - keeps it whatever this says. Takes effect from the next "
		+ "chunk; nothing already made is regenerated, because the rest is spliced in rather "
		+ "than asked of the voice.")
	hrow.add_child(_hesitate)
	Card.readout(hrow, _hesitate, "s")
	var on_hesitate := func(_v: Variant) -> void:
		if _syncing:
			return
		_hesitate.editable = _hesitate_on.button_pressed
		_dirty = true
		_last_edit_ms = Time.get_ticks_msec()
	_hesitate.value_changed.connect(on_hesitate)
	_hesitate_on.toggled.connect(on_hesitate)
	# SHOWN WHERE THE SCRIPT CAN CARRY THE MARK: a panel whose palette has no hesitation mark
	# (the Cards panel's - its agents write none) keeps the values in the voice block and shows no row.
	hrow.visible = ScriptMarks.for_mode(_section).has("hesitation")

	# THE TABS - one per name the script cues, derived rather than managed (see the note on
	# the speaker cues above). Everything below this row belongs to the selected tab; the
	# Play button beside the voice picker does not - it reads the whole script, in every
	# voice it asks for. A FLOW, not a TabBar, so a chapter with eight speakers shows all
	# eight names at once instead of hiding half of them behind scroll arrows.
	# A LIST WITH A HEADING, one row per person, each saying what voice they have now - a
	# first cut drew the names as a flow of flat buttons and it read as a line of text: no
	# heading, no visible selection, nothing saying these were the speakers or what they
	# sounded like.
	_cast_head = Label.new()
	_cast_head.add_theme_font_size_override("font_size", 12)
	_cast_head.mouse_filter = Control.MOUSE_FILTER_STOP
	_cast_head.tooltip_text = ("The voices are the speakers the script names - a line of its "
		+ "own reading <!-- speaker: Emily --> hands the text after it to Emily - and the "
		+ "list follows the script as it changes. Pick a person to edit their voice below; "
		+ "Test hears it on its own. A name that drops out of the script keeps its settings "
		+ "for when it comes back. Play still reads the whole script.")
	box.add_child(_cast_head)
	_tabs = VBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 2)
	_tabs.tooltip_text = _cast_head.tooltip_text
	box.add_child(_tabs)
	_tab_group = ButtonGroup.new()
	_cast_timer = Timer.new()
	_cast_timer.one_shot = true
	_cast_timer.wait_time = 0.4
	_cast_timer.timeout.connect(func() -> void: _refresh_cast(_cast_text()))
	add_child(_cast_timer)
	_seek_timer = Timer.new()
	_seek_timer.one_shot = true
	_seek_timer.wait_time = SEEK_SETTLE
	_seek_timer.timeout.connect(_seek_now)
	add_child(_seek_timer)


## THE VOICE: the model, Play / Stop / Test, the reader, the tone, the pace and pauses, the
## delivery dials and the room - every control below belongs to the tab that is showing.
func _build_voice(box: VBoxContainer) -> void:
	var vrow := HBoxContainer.new()
	vrow.add_theme_constant_override("separation", 8)
	box.add_child(vrow)
	_voices = OptionButton.new()
	_voices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# SIZED BY THE ROW, NOT BY ITS LONGEST VOICE: Play becomes "Resume ●" beside it, and a picker
	# as wide as "libritts high (downloads)" pushed the whole panel out (see SidePanel._check_width)
	_voices.fit_to_longest_item = false
	_voices.clip_text = true
	_voices.tooltip_text = "Which Piper model reads. Each is a different person with its own accent, recording and license - the license appears under the panel when you pick one. Changing this regenerates whatever has not been played yet."
	_voices.item_selected.connect(func(_i: int) -> void:
		if _syncing:
			return
		_show_voice_license()
		_capture_slot()
		# A voice change is not a re-pace. _repace keeps the stream and appends
		# at the new setting, which for a VOICE would splice a second speaker
		# mid-narration; and leaving the old requests in flight keeps both
		# models loaded and chunking, halving the throughput of each. So: kill
		# the session and read again in the new voice.
		if not _chunks.is_empty():
			_restart_speaking()
		_dirty = true
		_last_edit_ms = Time.get_ticks_msec())
	vrow.add_child(_voices)
	# PLAY AND STOP ARE THE TRANSPORT'S, along the bottom of the stage (Space plays and pauses).

	# AUDITION ONE VOICE, without the chapter. In a script with seven speakers the last one
	# first speaks forty minutes in, so tuning that voice by reading the whole script is not
	# a loop anyone can iterate in. This reads a fixed passage (TEST_PASSAGE) in the voice on
	# the selected tab - its tone, pace, pauses, delivery and room - and plays it straight
	# out: no stage, no subtitles, no Director.
	_test = Button.new()
	_test.text = "Test"
	_test.tooltip_text = ("Hear the selected tab's voice on its own: a short fixed passage, "
		+ "read with every setting on this tab and played without any visuals. The same "
		+ "words every time, so two voices - or two settings of one - can be compared by "
		+ "ear. Press again to stop. Starting a test ends a reading in progress.")
	_test.disabled = true
	_test.pressed.connect(_on_test)
	vrow.add_child(_test)

	# Multi-speaker checkpoints carry hundreds of readers under one model -
	# libritts-high has 904 - and they are the only way to change WHO is
	# reading without changing the model. Hidden entirely for single-speaker
	# voices, like every other capability-driven control here.
	_speaker_row = HBoxContainer.new()
	_speaker_row.add_theme_constant_override("separation", 8)
	_speaker_row.visible = false
	box.add_child(_speaker_row)
	var sl2 := Label.new()
	sl2.text = "Speaker"
	sl2.custom_minimum_size = Vector2(72, 0)
	sl2.add_theme_font_size_override("font_size", 12)
	_speaker_row.add_child(sl2)
	_speaker = SpinBox.new()
	_speaker.min_value = 0
	# NO CEILING UNTIL THE MODEL IS KNOWN. A Range's default max is 100, and a document or a stored
	# cast is applied at boot, before the host has listed its voices - so reader 692 of
	# libritts-high (904 readers) was clamped to 100 and then saved that way. The real ceiling is
	# set by _show_voice_license once the voice's reader count is known.
	_speaker.max_value = 100000
	_speaker.step = 1
	_speaker.tooltip_text = "Which reader, on a model that holds more than one (libritts carries 904). Same model and same accent, a different person - so it changes WHO is reading, not how. Grayed out on single-speaker voices. Regenerates the un-played chunks."
	_speaker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_speaker.value_changed.connect(func(_v: float) -> void:
		if _syncing:
			return
		_capture_slot()
		# same model, different reader: only the un-played chunks need redoing
		if not _chunks.is_empty():
			_repace()
		_dirty = true
		_last_edit_ms = Time.get_ticks_msec())
	_speaker_row.add_child(_speaker)
	_speaker.value_changed.connect(func(_v: float) -> void: _describe_speaker())
	# BROWSE: every reader of the voice, with who they are - so a voice is chosen by
	# description rather than by stepping through numbers and listening to each
	var browse := Button.new()
	browse.text = "Browse…"
	browse.focus_mode = Control.FOCUS_NONE
	browse.tooltip_text = "Every reader on this voice, with their gender and a description of how they sound (LibriTTS-P annotations). Filter, search, and pick one."
	browse.pressed.connect(_open_speaker_browser)
	_speaker_row.add_child(browse)

	_speaker_about = Label.new()
	_speaker_about.add_theme_font_size_override("font_size", 11)
	_speaker_about.modulate = Color(1, 1, 1, 0.75)
	_speaker_about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_speaker_about.tooltip_text = "Who this speaker number is: perceived gender and how the voice sounds, from LibriTTS-P (LINE Corporation, CC BY 4.0)."
	_speaker_row.add_sibling(_speaker_about)

	var trow := HBoxContainer.new()
	trow.add_theme_constant_override("separation", 8)
	box.add_child(trow)
	var tl := Label.new()
	tl.text = "Tone"
	tl.custom_minimum_size = Vector2(72, 0)
	tl.add_theme_font_size_override("font_size", 12)
	trow.add_child(tl)
	_tone = OptionButton.new()
	_tone.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tone.tooltip_text = "The reading's overall manner: pace, pitch, how much the model varies itself, how evenly it divides the words, and whether it is whispered or muffled - all of it the VOICE, and none of it the dials below, which stay yours. The pitch shift moves the formants with it, so the reader reads as a different SIZE - which is what makes Spooky larger and lower, Excited smaller and higher. Regenerates the un-played chunks."
	for k in Delivery.TONE_PRESETS:
		_tone.add_item(String(k))
	_tone.item_selected.connect(func(_i: int) -> void:
		if _syncing:
			return
		_capture_slot()
		# a tone changes the model's own parameters, so un-played chunks have
		# to be regenerated - the same path a pace change takes
		if not _chunks.is_empty():
			_repace()
		_dirty = true
		_last_edit_ms = Time.get_ticks_msec())
	trow.add_child(_tone)

	# Shown only if the backend reports duration_control - the surface is built
	# from capabilities(), never from assumptions about what a model can do.
	_rate_row = HBoxContainer.new()
	_rate_row.add_theme_constant_override("separation", 8)
	_rate_row.visible = false
	box.add_child(_rate_row)
	var rl := Label.new()
	rl.text = "Pace"
	rl.add_theme_font_size_override("font_size", 12)
	_rate_row.add_child(rl)
	_rate = HSlider.new()
	# 0.7 was arbitrary. VITS length_scale is stable well past it, and an
	# audiobook read often wants slower than "slightly slow".
	_rate.min_value = 0.4
	_rate.max_value = 1.6
	_rate.step = 0.05
	_rate.value = 1.0
	_rate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rate.tooltip_text = "Speaking rate. Takes effect from the next chunk - already-generated audio keeps its pace."
	_rate.value_changed.connect(func(_v: float) -> void:
		if _syncing:
			return
		_repace_timer.start())
	_rate_row.add_child(_rate)
	Card.readout(_rate_row, _rate, "x")

	# PAUSE. How long the reading rests on punctuation, as a multiple of the
	# host's default rests (roughly: a tenth of a second on a comma, a quarter on
	# a colon, a third at a sentence end). VITS runs straight through a comma and
	# especially through a colon, so the silence is spliced in around the mark by
	# the host rather than asked of the model.
	#
	# Always visible, unlike Pace: this needs no duration_control, because the
	# host is inserting silence rather than asking the model for a different
	# length. And it is NOT a live buffer effect like Echo/Ambience - it changes
	# what gets synthesized, so it takes the debounced re-plan path below, the
	# same one a pace change takes.
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 8)
	box.add_child(prow)
	var pl := Label.new()
	pl.text = "Pause"
	pl.custom_minimum_size = Vector2(72, 0)
	pl.add_theme_font_size_override("font_size", 12)
	prow.add_child(pl)
	_pause = HSlider.new()
	_pause.min_value = 0.0
	_pause.max_value = 10.0
	_pause.step = 0.05
	_pause.value = 1.0
	_pause.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pause.tooltip_text = "How long to rest on punctuation - commas, semicolons, colons and sentence ends. It scales the WHOLE rest, the model's own included, so every mark keeps its share of the reading at every setting rather than the long ones running away from the short ones. 1 is the natural rest; 0 runs straight through; 10 is five times natural, a two-and-a-half second full stop, and deliberately too much for most material. A quicker Tone rests proportionally less at the same setting - that is what quicker means - so a fast reading wants a higher number here than a slow one. Takes effect from the next chunk; already-generated audio keeps its pauses."
	_pause.value_changed.connect(func(_v: float) -> void:
		if _syncing:
			return
		_repace_timer.start())
	prow.add_child(_pause)
	Card.readout(prow, _pause, "x")

	# Debounced rather than immediate: a slider drag emits a value per pixel,
	# and each change throws away work in flight. One re-plan per gesture.
	_repace_timer = Timer.new()
	_repace_timer.wait_time = 0.3
	_repace_timer.one_shot = true
	_repace_timer.timeout.connect(func() -> void:
		# CAPTURE FIRST. _repace re-requests from the slot store, not from the
		# controls, so a pace the slider knows about and the slot does not is a
		# pace the regenerated chunks are read at the OLD value.
		_capture_slot()
		_repace()
		_persist())
	add_child(_repace_timer)

	# Ambience: the same effects Synthesis has, over any PCM. Off by default -
	# a narration take should sound like a reading unless asked otherwise.
	# DELIVERY, not effect. These two are the discourse layer Piper structurally
	# cannot supply: it never sees the paragraph, so every sentence starts from the
	# same register at the same rate. See piper._discourse_plan for the rules.
	_dynamics = _fx_slider(box, "Dynamics", 0.5,
		"How much the READING's timing follows its own structure: a sentence at the end of a "
		+ "paragraph is drawn out, a short one after a long one lands harder, a question runs a "
		+ "little quicker. 0 reads every sentence at the same rate. At the top a closing sentence "
		+ "runs about a third longer than an opening one, which is deliberately more than any "
		+ "reader would do - if a chapter seems to be getting slower and slower as it goes, this "
		+ "is the dial, not Arc.")
	_effort = _fx_slider(box, "Effort", 0.35,
		"Vocal effort across a paragraph - which is not the same as volume. A louder voice has a "
		+ "brighter source spectrum, not just a higher level, so this moves the two together: "
		+ "opening a paragraph with a little more push and easing off toward the end. Level "
		+ "alone reads as the reader standing further away; the brightness is what makes it read "
		+ "as them easing off instead. 0 is off, 1 is about 6dB and a firm tilt top to bottom.")
	_arc = _fx_slider(box, "Arc", 0.4,
		"Pitch shape ACROSS a paragraph, in semitones. A speaker opens a new paragraph in a higher "
		+ "register and settles as it goes, then resets on the next - it is what makes a paragraph "
		+ "land rather than just stop. 0 is off, 0.15 is half a semitone top to bottom, 0.4 is "
		+ "one and a half, and 1 is four. The whole travel is usable now: the shift holds the "
		+ "reader's own formants, so the register moves without the speaker changing SIZE, and "
		+ "the ceiling is set by what a speaker would actually do rather than by the DSP.")
	_fx_echo = _fx_slider(box, "Echo", 0.0,
		"The room the voice is in. Low settings are a small close room - the repeat is short enough "
		+ "to fuse with the voice rather than be heard as a separate sound. It opens out into a "
		+ "distinct slapback with a long tail as you raise it, so this changes the SIZE of the "
		+ "space, not just how loud it is.")
	# THE ROOM, the same one Masking has - see [RoomFX], which owns the dial and
	# leaves each mode only its engine. It is a separate control from Echo above
	# and has to be: Echo is discrete repeats, which the ear counts, and this is
	# the diffuse tail behind them, which it cannot. A voice with only the first
	# sounds like a voice in a corridor; with only the second, like a voice in a
	# hall. Most rooms are both.
	_fx_room = _fx_slider(box, "Room", 0.0,
		"The size of the space around the reader. Where Echo is a repeat you can hear arrive, "
		+ "this is the diffuse tail behind it - no countable events, just the room answering. "
		+ "Low is a small studio whose tail is gone before the next word; the top is a hall that "
		+ "rings for seconds. Resonance sets its color, exactly as it does in Masking: dark and "
		+ "swallowed at 0, bright and ringing at 1. It is baked into the exported take, so what "
		+ "you hear here is what renders.")
	_fx_res = _fx_slider(box, "Resonance", 0.0,
		"Sympathetic tones tuned to the reader's own pitch, ringing when the voice rings and dying "
		+ "when it stops - the room answering, rather than a chord played over the top. It follows "
		+ "the speaking register, so it moves with the voice instead of fighting it.")
	_fx_presence = _fx_slider(box, "Presence", 1.0,
		"How close the reader is. 1 is right here; lower moves them away, dulling the high end "
		+ "first the way air does and only then dropping the level. Distance is a filter before it "
		+ "is a volume, which is why this is not a master gain.")
	_fx_lean = _fx_slider(box, "Lean", 0.0,
		"The reader leaning toward one side of a microphone in the middle and back, the way an "
		+ "ASMR recording moves between your ears. Only the voice moves; the room and the bed stay "
		+ "put. 0 is still. Low settings rest at center and lean now and then, holding a side for "
		+ "a while; higher, the rests and holds get shorter and the reader crosses straight to the "
		+ "other side more often, until at 1 it is a slow, constant sway. The far ear always keeps "
		+ "at least 30% of the voice. It is in the exported take as well.")
	_fx_near = _fx_slider(box, "Near", 0.0,
		"The reader coming in close to the microphone, or backing off, a sentence at a time. Closer, "
		+ "the voice gains warmth and the room falls away; backed off, the reverse. Often the reader "
		+ "drops their voice to come in, softer and quieter, so closer is not always louder. "
		+ "0 is still. Low settings make occasional, subtle moves; higher settings move farther "
		+ "and more often, with shorter rests, until at 1 the reader is always moving in or out. "
		+ "With Lean up too, an approach often goes toward one side, and a lean reaches furthest "
		+ "up close. The softer voice is chosen when a sentence is made, so a move takes effect "
		+ "from the sentences not yet made.")
	_fx_pad = _fx_slider(box, "Ambience", 0.0,
		"A sustained ambient bed underneath, in the reader's own key - long tones that keep "
		+ "sounding through the pauses, rather than reverb of the voice. It ducks under speech and "
		+ "swells in the gaps, and it is what plays alone through the Intro hold. Any setting plays "
		+ "the bed at full level; the dial is SEVERITY - how often a low bass swell answers the "
		+ "reader's pitch moving. Low is the bed alone; higher, the bass comes more often.")
	_build_ink_row(box)


# --- what a component's card asks of the reading ------------------------------------------------
# A card that changes the reading ([EpisodeCard]) hands it a walk, a bed and a publish, and asks it
# these few things by name - never its own members.

## The document the script card holds (the note, or a draft).
func doc_source() -> DocSource:
	return _doc


## The script's box: the text as it is being written.
func source_box() -> TextEdit:
	return _text


## The [Settings] section this panel keeps its own state in.
func section() -> String:
	return _section


## A line on the panel's status row.
func status(text: String) -> void:
	_set_status(text)


## What is on the stream no longer matches what would be read now: the next Play reads it again.
func mark_stale() -> void:
	_mark_stale()


## Something of the panel's changed: it is written to [Settings] once the typing stops.
func touch() -> void:
	_dirty = true
	_last_edit_ms = Time.get_ticks_msec()


## Whether a reading is on the stream now.
func reading_live() -> bool:
	return _reading_live()


## End the reading on the stream.
func stop_speaking() -> void:
	_stop_speaking()


## Every voice the cast has, by the name the script cues it with - the reader's first.
func cast_names() -> Array:
	return _cast_dict().keys()


# --- what is handed: what the reading reads, and where it is heard ---------------

## WHAT THIS READING READS ([TextWalk]): the note's own words, unless the mode hands another - Cards
## hands the episode it produced ([EpisodeWalk]). Handed, not overridden: the words a reading speaks
## are a thing of their own, and the methods below only ask the walk.
var walk: TextWalk = TextWalk.new()


func _open_environment(t0: float) -> void:
	_close_environment()
	var place := bed.of()
	_env_key = String(place.get("key", ""))
	_env_poll = 0.0
	if not place.has("make"):
		return
	var env: SoundBed = (place["make"] as Callable).call(_sr, t0)
	if env == null or not env.active():
		return
	env.set_level(bed.level())
	env.prefetch()
	_env = env


func _close_environment() -> void:
	if _env != null:
		_env.finish()
	_env = null


## Every frame of a reading: keep the place rendered ahead, follow the dial, and every couple of
## seconds see whether the place itself changed (live, the set dresser can hand a table in mid-reading),
## and if so carry on from here with the new one.
func _tick_environment(delta: float) -> void:
	if _env != null:
		_env.set_level(bed.level())
		_env.prefetch()
	if not _stream_open:
		return
	_env_poll += delta
	if _env_poll < 2.0:
		return
	_env_poll = 0.0
	var place := bed.of()
	if String(place.get("key", "")) != _env_key:
		_open_environment(Spectrum.stream_origin() + float(_pushed) / float(_sr))


## THE WORDS TO READ, fresh: what Play, a scrub and an export read. Here the document's own
## body - in sync mode the file as it is on disk RIGHT NOW (see [method DocSource.pull]).
func _reading_body() -> String:
	return walk.body(_doc.pull())


## What the VOICE reads of [param body] and the title it announces first: `{body, title}`. A
## tablet chapter is read off the screen and nothing else - no title announced, skipped text
## out, link targets out, a rest for every run of taps.
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
	return walk.test_passage(TEST_PASSAGE)


# --- persistence (mirrors SynthEditor._persist / _load_persisted) ------------


## Debounced: a keystroke marks the draft dirty, and the write happens once the
## typing stops. Saving per keystroke would hit the disk on every character.
func _process_persist() -> void:
	if _dirty and Time.get_ticks_msec() - _last_edit_ms >= AUTOSAVE_DELAY_MS:
		_persist()


func _persist() -> void:
	_dirty = false
	# The controls are the truth for the tab on screen; every other tab's truth
	# is already in _slots. Capture before writing or the tab being edited saves
	# whatever it held when it was last switched away from.
	_capture_slot()
	Settings.write(_section, "text", _doc.draft())
	Settings.write(_section, "cast", _cast_dict())
	Settings.write(_section, "turn", _turn.value)
	# A NEW KEY, not "tab": that one held an int index, and Settings' no-op guard compares
	# the stored value with the new one - an int against a String is a script error.
	Settings.write(_section, "tab_name", _tab_name())
	Settings.write(_section, "hesitate", _hesitate.value)
	Settings.write(_section, "hesitate_on", _hesitate_on.button_pressed)
	persisted.emit()


func _load_persisted() -> void:
	_syncing = true
	_turn.value = clampf(float(Settings.read(_section, "turn", 1.0)), 0.0, Delivery.MAX_TURN_SCALE)
	_hesitate.value = clampf(float(Settings.read(_section, "hesitate", HESITATE_DEFAULT)),
		_hesitate.min_value, HESITATE_MAX)
	_hesitate_on.button_pressed = bool(Settings.read(_section, "hesitate_on", true))
	_hesitate.editable = _hesitate_on.button_pressed
	_syncing = false
	var cast: Variant = Settings.read(_section, "cast", {})
	if cast is Dictionary and not (cast as Dictionary).is_empty():
		_stash = _merge_cast(cast as Dictionary)
	else:
		# MIGRATION, from the numbered tabs. Tab N was cued `<!-- speaker: N -->`, and tab 1
		# also read everything before the first cue - so it becomes both "1" and the narrator.
		var rows: Variant = Settings.read(_section, "slots", [])
		_stash = _cast_from_rows(rows if rows is Array else [],
			str(Settings.read(_section, "text", "")))
		if _stash.is_empty():
			# ...and from the single-voice file before that, read exactly once.
			_stash[Manuscript.NARRATOR] = _merge({
				"voice": str(Settings.read(_section, "voice", "")),
				"speaker": int(Settings.read(_section, "speaker", 0)),
				"tone": int(Settings.read(_section, "tone", 0)),
				"pace": float(Settings.read(_section, "pace", 1.0)),
				"pause": float(Settings.read(_section, "pause", 1.0)),
			})
	_order = PackedStringArray(_stash.keys())
	var tab: Variant = Settings.read(_section, "tab_name", "")
	_names = PackedStringArray()
	_slots = []
	# From the stored draft first, so the tabs exist before the box is bound below.
	_refresh_cast(str(Settings.read(_section, "text", "")), str(tab) if tab is String else "")
	# Last, and once: every dial the chain reads is now in the slot, so this is the one
	# place the loaded session's room is applied.
	Delivery.apply_fx(_fx, _cfg(_slot))
	# ...and NOW the box is filled, after the cast is loaded, because a document that is open
	# OVERRULES what was loaded above: in sync mode the file is the source of truth for both
	# the words and the voice, which is what makes it safe for the panel to write back to it
	# on its own. See DocSource.bind_text. The text arriving re-derives the tabs.
	_doc.bind_text(_text)
	_refresh_cast(_cast_text())


# --- the document's own settings ---------------------------------------------


## THE BLOCKS THIS PANEL KEEPS under the document's `ghost:` key, one per card with settings, in
## the panel's order - the order a fresh document gets them in (see [DocSource]). A block is the
## COMPONENT'S, not the panel's: the Generative and Cards panels read and write the same `voice:`,
## `look:` and `bookends:`, so a chapter's voices are there whichever panel opens it.
func _doc_blocks() -> PackedStringArray:
	# asked before the cards are built (the script's source is set up first), so read off what
	# the note has attached, never off the cards - in the order the cards stand: what produces the
	# text, the voice (this panel's own), then the rest
	var have := _components()
	var out := PackedStringArray()
	for producers in [true, false]:
		if not producers:
			out.append("voice")
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


## One block as it is now, or null for one this panel does not keep. The voice is the panel's
## own; every other block is a card's ([method _add_block_card]).
func _capture_block(key: String) -> Variant:
	if key == "voice":
		return _voice_capture()
	var card: Object = _block_cards.get(key)
	return card.capture() if card != null else null


## THE WHOLE CAST: every voice, keyed by the name the script cues it with - including names the
## text no longer uses, so rewriting a scene and restoring it does not lose a character's voice
## from the document either - the reader's first ([method _reader]). The controls are captured
## first, because they - not [member _slots] - are the truth for the tab on screen. WHICH VOICE
## IS ON SCREEN IS NOT THE DOCUMENT'S: it had been kept as `tab`, and every change wrote it back.
func _voice_capture() -> Dictionary:
	_capture_slot()
	return {"turn": _turn.value, "voices": _cast_dict(),
		"hesitate": _hesitate.value, "hesitate_on": _hesitate_on.button_pressed}


## ...and back the other way: the blocks a document carries, each to its card. A block the
## document does not carry changes nothing.
func _doc_apply(blocks: Dictionary) -> void:
	# THE CARDS first, and on their own: a document may carry a look and no cast yet.
	for key in _doc_blocks():
		var card: Object = _block_cards.get(key)
		if card != null and blocks.get(key) is Dictionary:
			card.apply(blocks[key] as Dictionary)
	if blocks.get("voice") is Dictionary:
		_voice_apply(blocks["voice"] as Dictionary)


## The script's text, whenever the cast is read from it: the book's pictures follow it.
func _script_text_changed(body: String) -> void:
	var picture := _block_cards.get("picture") as PictureCard
	if picture != null:
		picture.set_script_text(body)


## THE VOICE BLOCK, to the cast.
##
## A BLOCK WITH NO CAST CHANGES NOTHING. `_merge` gives every row every key, so a voice
## written by an older build arrives with sane defaults rather than half-applied - but a
## block with no `voices` at all is a document that has never been given a voice, and
## silently blanking the panel's cast for it would be the opposite of the feature. A LIST
## of voices is the numbered tabs this replaced, and is read the way the settings are.
func _voice_apply(cfg: Dictionary) -> void:
	var rows: Variant = cfg.get("voices", {})
	var cast: Dictionary = _merge_cast(rows as Dictionary) if rows is Dictionary \
		else _cast_from_rows(rows if rows is Array else [], _cast_text())
	if cast.is_empty():
		return
	# THE READER IS THE FIRST VOICE LISTED, whatever its name. A voice named for the reader's cue
	# ([constant Manuscript.NARRATOR]) listed after it can never be spoken - that name is the
	# reader's - and is what the panel had written in as a copy of the reader: it goes.
	var first := String(cast.keys()[0])
	if first != Manuscript.NARRATOR:
		cast.erase(Manuscript.NARRATOR)
	_stash = cast
	_order = PackedStringArray(cast.keys())
	_names = PackedStringArray()
	_slots = []
	_syncing = true
	_turn.value = clampf(float(cfg.get("turn", _turn.value)), 0.0, Delivery.MAX_TURN_SCALE)
	_hesitate.value = clampf(float(cfg.get("hesitate", _hesitate.value)),
		_hesitate.min_value, HESITATE_MAX)
	_hesitate_on.button_pressed = bool(cfg.get("hesitate_on", _hesitate_on.button_pressed))
	_hesitate.editable = _hesitate_on.button_pressed
	_syncing = false
	_refresh_cast(_cast_text())
	# The room, once, exactly as [method _load_persisted] does it: the chain is stateful
	# and a tab switch alone does not re-dial it.
	Delivery.apply_fx(_fx, _cfg(_slot))
	# Whatever is on the stream was cut against the PREVIOUS cast.
	_mark_stale()
	_dirty = true
	_last_edit_ms = Time.get_ticks_msec()


## What [method export_take] hands the book medium, and what main gives a live one: the
## chapter as the author wrote it, so pages can be typeset from the same words being read.
##
## The TITLE, the BOOK's name and its AUTHOR are carried separately because in sync mode the body arrives without its
## frontmatter, which is where a chapter's title lives.
func book_document(body := "") -> Dictionary:
	var src := body if not body.is_empty() else _reading_body()
	# Each voice's pen, beside the text for the reason the title is: in sync mode the text has
	# no frontmatter, and the voices live there.
	var inks := {}
	var cast := _cast_dict()
	for who in cast:
		var v := String((cast[who] as Dictionary).get("ink", ""))
		if not v.is_empty():
			inks[who] = v
	return publish.book({"source": src, "title": _doc_field(src, "title"), "book": _doc_field(src, "book"),
		"author": _doc_field(src, "author"), "inks": inks, "start_words": _start_words(),
		"start_index": _start_index()}, body)


## A top-level frontmatter field (`title:`, `book:`): what the source says (the synced file,
## or the panel's own fields for an unsynced script), else [param src]'s own frontmatter.
func _doc_field(src: String, key: String) -> String:
	var v := _doc.field(key) if _doc != null else ""
	return v if not v.is_empty() else FrontMatter.field_of(src, key)


# --- voices, plural and named --------------------------------------------------


## Every voice the panel knows, shown or not: name -> settings, in the order the document lists
## them (a new one last) - so the reader stays first ([method _reader]).
func _cast_dict() -> Dictionary:
	var out := {}
	for k in _order:
		var i := _names.find(k)
		if i >= 0:
			out[k] = _cfg(i)
		elif _stash.has(k):
			out[k] = _merge(_stash[k] as Dictionary)
	for k in _stash:
		if not out.has(k):
			out[k] = _merge(_stash[k] as Dictionary)
	for i in _names.size():
		if not out.has(_names[i]):
			out[_names[i]] = _cfg(i)
	return out


## THE READER'S VOICE: the first one the document lists, whatever it is called (the user,
## 2026-10-15: a show whose one voice was "Ryan" had a copy of it written in as "Narrator" at any
## change, because only a voice of that name could read the words before the first cue). Those
## words, and a cue naming [constant Manuscript.NARRATOR] - as a Cards reading hands a line back to
## its reader - are the reader's; a cast with no voice yet starts with one of that name.
func _reader() -> String:
	return _order[0] if not _order.is_empty() else Manuscript.NARRATOR


## The voice a script's [param name] is: the reader's for [constant Manuscript.NARRATOR], else its own.
func _who(name: String) -> String:
	return _reader() if name == Manuscript.NARRATOR else name


func _merge_cast(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		if d[k] is Dictionary and not str(k).strip_edges().is_empty():
			out[str(k).strip_edges()] = _merge(d[k] as Dictionary)
	return out


## The numbered tabs this replaced, as names: row i was cued `<!-- speaker: i+1 -->`, and
## the first row read everything before the first cue - so it becomes the NARRATOR, and also
## "1" only when the script actually cues `1` (otherwise every migrated document would carry
## a phantom voice named "1" from then on).
func _cast_from_rows(rows: Array, body := "") -> Dictionary:
	var cued := Manuscript.speakers(body)
	var out := {}
	for i in rows.size():
		if not (rows[i] is Dictionary):
			continue
		if i == 0:
			out[Manuscript.NARRATOR] = _merge(rows[i] as Dictionary)
			if cued.has("1"):
				out["1"] = _merge(rows[i] as Dictionary)
		else:
			out[str(i + 1)] = _merge(rows[i] as Dictionary)
	return out


## THE TABS FOLLOW THE SCRIPT. Re-derive them from [param body]: every name it cues, in order
## of first appearance, each with its own settings - kept if it had a tab, restored if it was
## stashed, and otherwise a COPY of the first voice (a new character is reached by changing
## one thing about the reader you already have, not by re-dialing a room from nothing).
## Names that left the script go to [member _stash]. The tab on screen stays on the same
## NAME when it survives, since its index means nothing once names come and go.
##
## Cheap and idempotent - it runs on every pause in typing - and it touches nothing when the
## cast is unchanged, so a reading in progress is only marked stale by a real change.
func _refresh_cast(body: String, want := "") -> void:
	# The cards that follow the text (the book's pictures) follow it on the same beat.
	_script_text_changed(body)
	if _rate != null:
		_capture_slot()
	var names := PackedStringArray()
	for n in Manuscript.speakers(body):
		if not names.has(_who(n)):
			names.append(_who(n))
	if names.is_empty():
		names = PackedStringArray([_reader()])
	for n in names:
		if not _order.has(n):
			_order.append(n)
	var showing := want if not want.is_empty() else _tab_name()
	if names == _names and not _slots.is_empty():
		if not want.is_empty() and names.has(want) and names.find(want) != _slot:
			_select_tab(names.find(want))
		return
	var old := {}
	for i in _names.size():
		old[_names[i]] = _slots[i]
	for k in old:
		_stash[k] = old[k]
	var seed_row: Dictionary = SLOT_DEFAULTS.duplicate()
	if not _slots.is_empty():
		seed_row = _cfg(0)
	elif not _stash.is_empty():
		seed_row = _merge(_stash[_stash.keys()[0]] as Dictionary)
	var slots: Array = []
	for n in names:
		if _stash.has(n):
			slots.append(_merge(_stash[n] as Dictionary))
			_stash.erase(n)
		else:
			slots.append(seed_row.duplicate())
	var changed := _names.size() > 0 and names != _names
	_names = names
	_slots = slots
	_slot = maxi(0, _names.find(showing))
	_rebuild_tabs()
	_apply_slot(_slot)
	if changed:
		_mark_stale()
		_dirty = true
		_last_edit_ms = Time.get_ticks_msec()


func _tab_name() -> String:
	return _names[_slot] if _slot >= 0 and _slot < _names.size() else ""


## A stored slot merged onto [constant SLOT_DEFAULTS]: every key present, every
## value the right type, and an index that cannot be out of range. Everything
## downstream reads settings through here, so a tab that vanished while its passages
## are still queued degrades to the first voice rather than to a null.
func _cfg(i: int) -> Dictionary:
	if _slots.is_empty():
		return SLOT_DEFAULTS.duplicate()
	return _merge(_slots[clampi(i, 0, _slots.size() - 1)] as Dictionary)


## The settings of the voice NAMED [param who] - which is how a chunk asks, because a tab's
## index moves whenever the script gains or loses a speaker, and a reading in flight must
## not change voice because someone typed a new name further down.
func _cfg_of(who: String) -> Dictionary:
	who = _who(who)
	var i := _names.find(who)
	if i >= 0:
		return _cfg(i)
	if _stash.has(who):
		return _merge(_stash[who] as Dictionary)
	return _cfg(0)


func _merge(row: Dictionary) -> Dictionary:
	var out := SLOT_DEFAULTS.duplicate()
	for k in out:
		if not row.has(k):
			continue
		# The defaults double as the schema: an int key stays an int through a
		# ConfigFile round trip, which stores every number as a float.
		match typeof(out[k]):
			TYPE_INT: out[k] = int(row[k])
			TYPE_FLOAT: out[k] = float(row[k])
			_: out[k] = str(row[k])
	return out


## The controls -> the selected slot.
func _capture_slot() -> void:
	if _slot < 0 or _slot >= _slots.size() or _rate == null:
		return
	_slots[_slot] = {
		"voice": _selected_voice_id(), "speaker": int(_speaker.value),
		"tone": _tone.selected, "pace": _rate.value, "pause": _pause.value,
		"dynamics": _dynamics.value, "arc": _arc.value, "effort": _effort.value,
		"echo": _fx_echo.value, "room": _fx_room.value, "resonance": _fx_res.value,
		"presence": _fx_presence.value, "ambience": _fx_pad.value, "lean": _fx_lean.value,
		"near": _fx_near.value,
		"ink": _ink_value(),
	}
	_refresh_tab_labels()


## A slot -> the controls. Every write is inside `_syncing`, because each of
## these controls answers a change by throwing away work in flight: without the
## guard, showing a tab would restart the reading and re-request every chunk at
## the settings of the tab that was just left.
func _apply_slot(i: int) -> void:
	var s := _cfg(i)
	_syncing = true
	_want_voice = String(s["voice"])
	for k in _voice_meta.size():
		if String((_voice_meta[k] as Dictionary).get("id", "")) == _want_voice:
			_voices.select(k)
			break
	_tone.select(clampi(int(s["tone"]), 0, Delivery.TONE_PRESETS.size() - 1))
	_rate.value = float(s["pace"])
	_pause.value = float(s["pause"])
	_dynamics.value = float(s["dynamics"])
	_arc.value = float(s["arc"])
	_effort.value = float(s["effort"])
	_fx_echo.value = float(s["echo"])
	_fx_room.value = float(s["room"])
	_fx_res.value = float(s["resonance"])
	_fx_presence.value = float(s["presence"])
	_fx_pad.value = float(s["ambience"])
	_fx_lean.value = float(s["lean"])
	_fx_near.value = float(s["near"])
	_show_ink(String(s["ink"]))
	# After the voice, because it is what sets the Speaker row's range - and a
	# speaker id is only meaningful against the model that holds it.
	_show_voice_license()
	_speaker.value = clampf(float(int(s["speaker"])), _speaker.min_value, _speaker.max_value)
	_syncing = false


func _rebuild_tabs() -> void:
	if _tabs == null:
		return
	for c in _tabs.get_children():
		_tabs.remove_child(c)
		c.queue_free()
	var on := StyleBoxFlat.new()
	on.bg_color = Color(0.30, 0.55, 0.75, 0.45)
	on.border_color = Color(0.55, 0.85, 1.0, 0.9)
	on.border_width_left = 3
	on.set_content_margin_all(4)
	var off := StyleBoxFlat.new()
	off.bg_color = Color(1, 1, 1, 0.04)
	off.set_content_margin_all(4)
	off.content_margin_left = 7
	var hover := off.duplicate() as StyleBoxFlat
	hover.bg_color = Color(1, 1, 1, 0.10)
	for i in _names.size():
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = _tab_group
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.add_theme_font_size_override("font_size", 12)
		b.add_theme_stylebox_override("normal", off)
		b.add_theme_stylebox_override("hover", hover)
		b.add_theme_stylebox_override("pressed", on)
		b.add_theme_stylebox_override("hover_pressed", on)
		b.set_pressed_no_signal(i == _slot)
		var at := i
		b.pressed.connect(func() -> void: _on_tab_selected(at))
		_tabs.add_child(b)
	_refresh_tab_labels()


## Each row: the name, then the voice it has NOW - model, reader, tone - so the whole cast can
## be read at a glance, and two people accidentally left on the same voice are obvious.
func _refresh_tab_labels() -> void:
	if _tabs == null:
		return
	if _cast_head != null:
		_cast_head.text = "Voices (%d)  -  from the script's speaker cues" % _names.size()
	var tones := Delivery.TONE_PRESETS.keys()
	for i in mini(_tabs.get_child_count(), _names.size()):
		var s := _cfg(i)
		var model := String(s["voice"])
		var multi := false
		for v in _voice_meta:
			if String((v as Dictionary).get("id", "")) == model:
				model = String((v as Dictionary).get("name", model))
				multi = int((v as Dictionary).get("speakers", 1)) > 1
				break
		if model.is_empty():
			model = "default voice"
		var desc := model + ((" #%d" % int(s["speaker"])) if multi else "")
		desc += "  ·  " + String(tones[clampi(int(s["tone"]), 0, tones.size() - 1)])
		var b := _tabs.get_child(i) as Button
		b.text = "%s    %s" % [_names[i], desc]
		b.tooltip_text = "%s - %s. Pick to edit this voice." % [_names[i], desc]


func _select_tab(i: int) -> void:
	_on_tab_selected(i)
	for c in _tabs.get_children():
		(c as Button).set_pressed_no_signal(c.get_index() == _slot)


func _on_tab_selected(i: int) -> void:
	if _syncing or i == _slot:
		return
	_capture_slot()
	_slot = clampi(i, 0, _slots.size() - 1)
	_apply_slot(_slot)


## The reading on the stream no longer matches the panel. The same dot the text
## box raises, and for the same reason: the cast changed under what is playing.
func _mark_stale() -> void:
	if not _chunks.is_empty():
		_stale = true


## SPEAK IS A TOGGLE while a reading plays: Pause, then Resume, from where it was. It restarted
## the reading from the top every time, and "there are times when I need to pause the
## visualization and come back to it later". Reading again from the top is Stop, then Play.
var _stale := false
var _outro_queued := false       # the outro's silence is on the stream (see the drain)
## THE OUTRO MARK, live: how long the fade is (0 = no mark), the stream sample it starts at
## (-1 until the first fading chunk is drained), and whether the reading has been cut.
var _fade_len := 0.0
var _fade_at := -1
## LIVE SCRUBBING, BY SENTENCE. A live reading is synthesized a sentence or two ahead, so there
## is no audio behind or ahead of the playhead to seek within. The transport's rail (through this
## panel's conductor hooks, [method transport_hooks]) therefore seeks by SENTENCE: its positions are estimated
## sentence starts, and a seek is Stop + Play from that sentence - a fresh reading that is only
## synthesized from there on. The media start in the state they would be in at that point
## (book_document()["start_words"]). The in-place generator seek recorded above _repace stays
## withdrawn; this never seeks a stream, it ends one and starts another, as Stop then Play does.
var _start_chunk := 0
var _chunk_at := {}                      # chunk -> the stream sample its audio starts at
var _chunk_t := PackedFloat32Array()     # chunk -> its estimated start along the reading, s (n + 1)
var _seek_k := -1                        # a seek waiting for the bar to settle
var _seek_timer: Timer
## The estimate the bar is laid out by: a reading pace, plus every rest at its own length.
const SCRUB_SECONDS_PER_WORD := 0.38
## A drag restarts the reading once, when it settles - not once per pixel.
const SEEK_SETTLE := 0.4
var _fade_done := false
const OUTRO_MIN_FADE := 0.5
## Enough words to fill a fade - a brisk pace, so the fade never runs out of voice early.
const OUTRO_WORDS_PER_SECOND := 3.5

## A reading that is still going: planned, and not yet played out to the end. A generated
## stream never announces its end, so "every chunk played and the buffer drained" is the end -
## and then Play reads again from the top rather than pausing silence.
func _reading_live() -> bool:
	if _chunks.is_empty():
		return false
	if _next_to_play < _chunks.size() or not _pending.is_empty() or _playback == null:
		return true
	return _ring_capacity - int(_playback.get_frames_available()) > 256


## What Play does now, in a word - for the status line and the gates. The transport draws its
## own button from the conductor's `playing`.
func _play_label() -> String:
	var label := "Play"
	if _reading_live():
		label = "Resume" if Spectrum.paused else "Pause"
	return label + (" ●" if _stale and not _chunks.is_empty() else "")


## Split a script into passages by speaker: `[{speaker, text, lead}]`. Text before the
## first cue - and a script with no cues at all - is the narrator's.
##
## Also where the HESITATIONS are resolved, because it is the last place that still sees the
## markers in their text: each becomes a [constant TextNorm.HOLD_MARK] welded to the word it
## follows (or leads, when nothing comes before it in the passage), and its length goes on
## [member _holds] in the same order, for [method _cut] to hand back out. With the Hesitate
## box off they are simply removed. Every other comment is an authoring note and goes too.
func _split_speakers(body: String) -> Array:
	var kept: Array = []
	var on := _hesitate_on == null or _hesitate_on.button_pressed
	var bare := _hesitate.value if _hesitate != null else HESITATE_DEFAULT
	_holds = []
	# THE TITLE IS READ FIRST, as a heading of its own, by the voice that opens the chapter.
	# The frontmatter as metadata is still never spoken - only the title's value, the way a
	# reader announces a chapter before its first word. Not twice: a chapter that already
	# opens on its title as a heading keeps that one. A chapter read off a screen announces
	# nothing (see [method _reading_of]).
	var read := _reading_of(body)
	var title := String(read["title"])
	body = String(read["body"])
	var first := true
	var fading := false
	for p in Manuscript.passages(body):
		var raw := String((p as Dictionary)["text"])
		# the first passage with anything in it: a chapter opening on a cue has an empty one
		# before it, and a title put there would invent a narrator to read it
		if first and not title.is_empty() and not raw.strip_edges().is_empty():
			var lead := raw.strip_edges().get_slice("\n", 0).lstrip("#").strip_edges()
			if lead.to_lower() != title.to_lower():
				raw = "# %s\n\n%s" % [title, raw]
		if not raw.strip_edges().is_empty():
			first = false
		# a log entry's time gets its pause before the markers are read, so it IS a marker
		var t := Manuscript.mark_timestamp_pauses(raw)
		# THE OUTRO MARK splits its passage: what comes after it is read FADING (see
		# [method _build_chunks]), and so is every passage after that. The first mark counts.
		var parts := [t]
		var om: RegExMatch = null
		if not fading:
			om = Manuscript._rx(Manuscript.OUTRO).search(t)
		if om != null:
			parts = [t.substr(0, om.get_start()), t.substr(om.get_end())]
		for k in parts.size():
			if k == 1:
				fading = true
			var out := _resolve_marks(String(parts[k]), on, bare)
			if not out.replace(TextNorm.HOLD_MARK, "").strip_edges().is_empty():
				kept.append({"speaker": _who(String((p as Dictionary)["speaker"])), "text": out,
					"fade": fading, "leans": _last_leans})
			else:
				# A passage of nothing but hesitations: its rests would have no word to sit on.
				for _i in out.count(TextNorm.HOLD_MARK):
					_holds.pop_back()
	# A TABLET'S OPENING RUN (wake, open the browser, type) comes AFTER the intro, end to end:
	# the intro is the tablet lying dark on the desk, and its rest is the run's own, whole
	return kept


## A passage's marks resolved: every hesitation (and the tablet's action rests) becomes a
## [constant TextNorm.HOLD_MARK] welded to the word before it - or leading the next, when
## nothing precedes it - with its length queued on [member _holds]; a DELIVERY mark is noted where
## it falls ([member _last_leans], see [method Delivery.leans_of]); every other comment goes.
func _resolve_marks(t: String, on: bool, bare: float) -> String:
	var out := ""
	var at := 0
	var re := Manuscript._rx(Manuscript.COMMENT)
	var hes := Manuscript._rx(Manuscript.HESITATION)
	var lean_re := Manuscript._rx(Manuscript.DELIVERY)
	_last_leans = []
	for m in re.search_all(t):
		out += t.substr(at, m.get_start() - at)
		at = m.get_end()
		# THE TABLET'S HAND IS NOT A HESITATION: its rest is the time a tap or a typed
		# address takes, so it stays when the Hesitate box is off
		var secs := TabletScript.hold_of(m.get_string())
		if secs < 0.0:
			var lm := lean_re.search(m.get_string())
			if lm != null:
				_last_leans.append([out.length(), Delivery.lean_of(lm.get_string(1))])
				continue
			if not on:
				continue
			var hm := hes.search(m.get_string())
			if hm == null:
				continue             # an authoring note
			var v := hm.get_string(1) if not hm.get_string(1).is_empty() else hm.get_string(2)
			secs = clampf(float(v), 0.0, 30.0) if not v.is_empty() else bare
		# WELDED, never left standing: a sentinel alone between two spaces is a token of
		# its own, and a token that is not a word confuses the sentence splitter around
		# it. Trailing whitespace is stepped over so it lands directly after the last
		# character of the previous word.
		var head := out.rstrip(" \t\n")
		out = head + TextNorm.HOLD_MARK + out.substr(head.length())
		_holds.append(secs)
	out += t.substr(at)
	_last_leans = Delivery.leans_of(out, _last_leans)
	# Sentinels with nothing before them in the passage LEAD the next word instead:
	# close the gap after them so they weld on to it.
	var body_t := out.strip_edges()
	var n := 0
	while body_t.begins_with(TextNorm.HOLD_MARK):
		n += 1
		body_t = body_t.substr(1).strip_edges(true, false)
	# ...AFTER a heading's `#`s, never before them: `#` is only markup at the start of a
	# line, and a sentinel in front of it left "##" to be read as a word (a hesitation
	# standing alone above a dated entry did exactly that).
	var marks := ""
	if n > 0 and body_t.begins_with("#"):
		var k := 0
		while k < body_t.length() and body_t[k] == "#":
			k += 1
		marks = body_t.substr(0, k) + " "
		body_t = body_t.substr(k).strip_edges(true, false)
	var said := marks + TextNorm.HOLD_MARK.repeat(n) + body_t
	# A DELIVERY MARK IS WHERE IT FALLS IN WHAT IS RETURNED: it was noted in `out`, before the
	# passage's leading whitespace went, so a passage opening on a stripped comment and a blank
	# line had every mark two characters late - past the first word of the sentence under it,
	# which then read in the delivery before (tests/reading/multi_voice_check.gd).
	var gone := out.strip_edges(false, true).length() - said.length()
	if gone != 0:
		for lean in _last_leans:
			(lean as Array)[0] = maxi(0, int((lean as Array)[0]) - gone)
	return said


func _selected_voice_id() -> String:
	var i := _voices.selected
	if i < 0 or i >= _voice_meta.size():
		return _want_voice
	return String(_voice_meta[i].get("id", ""))


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


# --- the audition -------------------------------------------------------------

## The words every voice is auditioned with. The SAME passage for every speaker, so two
## voices are compared on identical material; chosen to exercise what a chapter will ask of
## them - a long sentence with commas, a colon, a question, an exclamation, a number, a line
## of dialogue in quotes and a short sentence landing after a long one. It OPENS on a short
## sentence on purpose: the first sound waits for the first sentence to be made.
const TEST_PASSAGE := """The rain had not stopped. Since morning it had kept on, and the lamps along the river were already lit by four o'clock. I counted them from the window: twelve on this side, eleven on the other, one of them out.

"Are you coming, or not?" she asked from the doorway. I told her I would be a minute. It was closer to twenty.

Some evenings are like that. You mean to leave, and the room keeps you, and by the time you notice it is dark. Still, I went. I am glad I did!"""


## Speak the passage in the selected tab's voice, or stop the one playing.
##
## STREAMED, like a reading: every sentence is requested at once (the host answers them in
## order), each is joined onto the stream the moment it and everything before it has
## arrived, and playback starts with the first sentence. The
## first cut waited for the whole passage and was reported as "a solid 15 seconds of
## silence" - longer than a chapter takes to start.
func _on_test() -> void:
	if _test_busy():
		_stop_test()
		return
	if _host == null or not _host.is_up() or _voice_meta.is_empty():
		return
	# One sound at a time: a test over a reading is two voices at once and neither is heard.
	if not _chunks.is_empty():
		_stop_speaking()
	_capture_slot()
	_test_name = _tab_name()
	_holds = []
	_hold_i = 0
	var passage := _test_passage()
	_test_chunks = _cut(passage, 0)["chunks"]
	_place_chunks(_test_chunks, passage)
	_plan_near(_test_chunks, 0, _test_name)
	_test_marks = []
	_test_near = {}
	_test_dry_at = 0
	_test_dry_end = 0
	_test_parts = {}
	_test_req = {}
	_test_tasks = {}
	_test_dry = PackedFloat32Array()
	_test_fx_task = {}
	_test_next = 0
	_test_hold = PackedVector2Array()
	_test_read = 0
	_test_pushed = 0
	_test_fx = null
	var s := _cfg_of(_test_name)
	for i in _test_chunks.size():
		var id := _host.request("", _voice_id_of(s), TAKE_DIR + "/test_%d.wav" % i,
			_request_args(s, _test_chunks[i]), null)
		_test_req[id] = i
	_test.text = "Test ■"
	_set_status("Testing %s…" % _test_name)


func _test_busy() -> bool:
	return not _test_req.is_empty() or (_test_player != null and _test_player.playing)


func _stop_test() -> void:
	# A worker still decoding is waited for rather than abandoned - it is a fraction of a second.
	for k in _test_tasks:
		WorkerThreadPool.wait_for_task_completion(int((_test_tasks[k] as Dictionary)["task"]))
	_test_tasks = {}
	if not _test_fx_task.is_empty():
		WorkerThreadPool.wait_for_task_completion(int(_test_fx_task["task"]))
	_test_fx_task = {}
	_test_dry = PackedFloat32Array()
	_test_marks = []
	_test_req = {}          # replies still in flight are dropped on arrival
	_test_parts = {}
	_test_hold = PackedVector2Array()
	_test_read = 0
	if _test_player != null:
		_test_player.stop()
	_test.text = "Test"


## One sentence of the audition arrived. Join everything that is now contiguous from the
## front - resample, sentence seam, the voice's room, through ONE effects chain so the room
## carries across the joins - and hand it to the stream.
func _on_test_part(id: int, result: Dictionary) -> void:
	var i := int(_test_req[id])
	_test_req.erase(id)
	_test_parts[i] = String(result.get("wav", ""))
	_sr = int(result.get("sample_rate", _sr))
	var s := _cfg_of(_test_name)
	if _test_fx == null:
		_test_fx = VoiceFX.new()
		_test_fx.pad_seed = hash(_test_passage())
		_test_fx.setup(_sr)
		Delivery.apply_fx(_test_fx, s)
	# DECODE OFF THE MAIN THREAD. It is a per-sample GDScript loop, and a long sentence is
	# several hundred thousand samples - measured at a 0.3 s frame on arrival. A pure function
	# of the file, so a worker can do it; the join below waits for it.
	var box := [PackedFloat32Array()]
	var path := String(_test_parts[i])
	_test_tasks[i] = {"box": box, "task": WorkerThreadPool.add_task(func() -> void:
		box[0] = Splice.decode_wav(path))}
	_join_test_parts()


## Join every prepared sentence that is now contiguous from the front onto the audition.
## Polled from [method _tick_test] too, because a worker can finish between replies.
func _join_test_parts() -> void:
	var s := _cfg_of(_test_name)
	while _test_tasks.has(_test_next):
		var t: Dictionary = _test_tasks[_test_next]
		if not WorkerThreadPool.is_task_completed(int(t["task"])):
			return
		WorkerThreadPool.wait_for_task_completion(int(t["task"]))
		_test_tasks.erase(_test_next)
		var wav := String(_test_parts.get(_test_next, ""))
		_test_parts.erase(_test_next)
		if not wav.is_empty():
			DirAccess.remove_absolute(ProjectSettings.globalize_path(wav))
		var part: PackedFloat32Array = (t["box"] as Array)[0]
		if not part.is_empty():
			Delivery.near_mark(_test_marks, (_test_chunks[_test_next] as Dictionary).get("near", {}),
				_test_dry_end, _test_near)
		if _test_next > 0 and not part.is_empty():
			var gap := PackedFloat32Array()
			gap.resize(int(Delivery.seam_gap_of(s) * float(_sr)))
			gap.append_array(part)
			part = gap
		_test_next += 1
		if _test_next >= _test_chunks.size():
			# a second of silence so the room rings out rather than being cut
			var tail := PackedFloat32Array()
			tail.resize(_sr)
			part.append_array(tail)
		if not part.is_empty():
			_test_dry.append_array(part)
			_test_dry_end += part.size()
	_pump_test_fx()


## THE ROOM RUNS ON A WORKER. VoiceFX is GDScript DSP at about 15 microseconds a sample -
## measured, a third of the main thread for every second of audio, and 0.36 s in ONE frame
## when a sentence was processed whole: the reported "the entire UI keeps freezing, then
## releasing". So the dry audio goes through the chain on a worker, half a second at a time
## and ONE piece at a time (the chain is stateful, so pieces must run in order), and the main
## thread only moves finished samples into the ring. A dial moved mid-test reaches the next
## piece - the settings are taken when a piece starts, never changed under a running one.
const TEST_FX_PIECE := 0.5

func _pump_test_fx() -> void:
	if not _test_fx_task.is_empty():
		if not WorkerThreadPool.is_task_completed(int(_test_fx_task["task"])):
			return
		WorkerThreadPool.wait_for_task_completion(int(_test_fx_task["task"]))
		_test_hold.append_array((_test_fx_task["box"] as Array)[0])
		_test_fx_task = {}
	if _test_dry.is_empty() or _test_fx == null:
		_start_test_playback()
		return
	var n := mini(_test_dry.size(), int(TEST_FX_PIECE * float(_sr)))
	# a distance the piece has reached goes in before it; a piece stops at the next one
	var near := {}
	while not _test_marks.is_empty() and int((_test_marks[0] as Dictionary)["at"]) <= _test_dry_at:
		near = (_test_marks.pop_front() as Dictionary)["near"]
	if not _test_marks.is_empty():
		n = mini(n, int((_test_marks[0] as Dictionary)["at"]) - _test_dry_at)
	var piece := _test_dry.slice(0, n)
	_test_dry = _test_dry.slice(n)
	_test_dry_at += n
	var fx := _test_fx
	var cfg := _cfg_of(_test_name)
	var box := [PackedVector2Array()]
	_test_fx_task = {"box": box, "task": WorkerThreadPool.add_task(func() -> void:
		Delivery.apply_fx(fx, cfg)
		if not near.is_empty():
			Delivery.near_to(fx, near)
		box[0] = fx.process_stereo(piece))}
	_start_test_playback()


func _start_test_playback() -> void:
	var done := _test_next >= _test_chunks.size() and _test_dry.is_empty() and _test_fx_task.is_empty()
	_set_status("Testing %s… %d of %d" % [_test_name, _test_next, _test_chunks.size()])
	# Unlike a reading, the audition starts on its FIRST sentence (a short one, see
	# TEST_PASSAGE): a test is pressed to hear a voice now, and a brief gap at one seam costs
	# less here than seconds of silence up front.
	var playing := _test_player != null and _test_player.playing
	if playing or (_test_hold.size() - _test_read <= 0 and not done):
		return
	if _test_player == null:
		_test_player = AudioStreamPlayer.new()
		add_child(_test_player)
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = _sr
	# A short ring: the room is already applied (on a worker), so a frame only copies samples.
	gen.buffer_length = 1.0
	_test_player.stream = gen
	_test_player.play()
	var pb := _test_player.get_stream_playback() as AudioStreamGeneratorPlayback
	# MEASURED, not computed: Godot rounds a generator's ring to a power of two, so "empty"
	# is whatever it reports before the first push (see _drain_ready).
	_test_cap = pb.get_frames_available() if pb != null else 0


## Feed the audition's ring with finished (wet) samples, a frame's worth at a time; and end it
## once everything has been pushed and has played out (a generator never finishes by itself).
func _tick_test() -> void:
	if not _test_tasks.is_empty():
		_join_test_parts()
	if not _test_fx_task.is_empty() or not _test_dry.is_empty():
		_pump_test_fx()
	if _test_player == null or not _test_player.playing:
		return
	var pb := _test_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if pb == null:
		return
	var n := mini(_test_hold.size() - _test_read, pb.get_frames_available())
	if n > 0:
		pb.push_buffer(_test_hold.slice(_test_read, _test_read + n))
		_test_pushed += n
		_test_read += n
		# reclaim the consumed head only when it is worth it, not every frame
		if _test_read > 4 * _sr:
			_test_hold = _test_hold.slice(_test_read)
			_test_read = 0
		return
	if _test_req.is_empty() and _test_next >= _test_chunks.size() and _test_dry.is_empty() \
			and _test_fx_task.is_empty() \
			and pb.get_frames_available() >= _test_cap - 64:
		_test_player.stop()
		_test.text = "Test"
		_set_status("Tested %s - %.1fs." % [_test_name, float(_test_pushed) / float(_sr)])


## Show only what the medium can use - the panel's own rows (the Ink); a card keeps its own. Asked
## of the Director, so a run launched with `--medium` shows what that medium uses.
func _sync_medium_rows() -> void:
	Medium.show_rows(_medium_rows, Director.resolved_medium())


## A voice/delivery slider. `tip` is not optional in practice: an unlabeled dial
## is a dial nobody touches, and every other slider in this panel carries one.
## Give every chunk its place in the reading, so the delivery plan can be a plan.
##
## THE BUG THIS FIXES. `_discourse_plan` shapes a sentence by where it sits in the unit
## it was handed - and the unit it is handed is one REQUEST, which is one sentence
## (CHUNK_SENTENCES = 1). So every sentence was simultaneously the first and last of its
## own unit: position 0 of 1, every time. Final lengthening never once fired, and the
## "arc" resolved to the same constant offset on every sentence in the chapter - a
## transposition wearing an arc's name. It measured correctly when I tested it, because I
## tested it by handing the whole paragraph over in one call, which is a path the editor
## never takes. The audible difference between Arc 0 and Arc 1 was real; it just was not
## an arc.
##
## TWO NESTED LEVELS, because discourse structure is nested and so are its pitch resets -
## the size of a reset scales with the depth of the boundary it follows (Grosz & Sidner;
## Hirschberg & Nakatani). `u` is the sentence's place in its paragraph and `v` its
## paragraph's place in a run of them. That second level is what a chapter of one-sentence
## paragraphs needs: at `u` the paragraph collapses to a point and every one of them would
## otherwise be handed the identical contour, which is exactly the flatness reported.
## Sections are runs of SECTION_PARAS paragraphs, so the slow movement is phase-locked to
## the prose the same way the fast one is.
const SECTION_PARAS := 5
## ...and the longest run of sentences that may be called one paragraph. Nothing to
## do with style: a paragraph is where the pitch arc RESETS, so an unbroken block is
## an arc with no reset in it, and the register just falls for as long as the block
## does. Eight is a long paragraph; past that the text is not telling us where its
## paragraphs are, and reading it as consecutive ones of this length is the same
## guard SECTION_PARAS is a level up.
const PARA_CEILING := 8

func _place_chunks(out: Array, body: String) -> void:
	# Paragraph boundaries come from the SOURCE text (a blank line), which is the only place
	# they exist - Phonemes.parse hands back a flat run of sentences and knows nothing about
	# them. Counting sentence-final marks per paragraph maps one onto the other without
	# parsing the body twice.
	var per_para: Array = []
	# A BLANK LINE IS THE MARKER, BUT ONLY IF THE WRITER USED ANY. A script typed
	# with one newline between paragraphs - which is most of them, in a plain text
	# box with no formatting to lose - has no blank line anywhere in it, so this
	# found exactly one paragraph and handed the entire chapter a single arc that
	# descends from the first sentence to the last and never resets. That is half
	# of the "lower and lower and lower" report ([method Delivery.arc_semis] is the other
	# half); measured on one, the register fell monotonically across all sixteen
	# sentences instead of resetting six times.
	var para_mark := "\n\n"
	if body.find("\n\n") < 0:
		# ...but a line break is only a PARAGRAPH break if the lines are paragraphs.
		# Hard-wrapped prose breaks in the middle of sentences, and reading each of
		# those lines as a paragraph would reset the arc mid-sentence. The test is
		# whether the lines END the way sentences do - within a character or two of
		# the last one, so a closing quote or bracket still counts. Text that fails
		# it keeps the blank-line marker, finds no paragraphs, and is bounded by
		# PARA_CEILING instead, which is the right answer for prose that genuinely
		# carries no structure.
		var lines := 0
		var ended := 0
		for ln in body.split("\n", false):
			var t := String(ln).strip_edges()
			if t.is_empty():
				continue
			lines += 1
			var tail := t.substr(maxi(0, t.length() - 2))
			if tail.contains(".") or tail.contains("!") or tail.contains("?"):
				ended += 1
		if lines > 0 and float(ended) / float(lines) >= 0.6:
			para_mark = "\n"
	for para in body.split(para_mark, false):
		var t := String(para).strip_edges()
		if t.is_empty():
			continue
		var c := 0
		for ch in t:
			if ch == "." or ch == "!" or ch == "?":
				c += 1
		per_para.append(maxi(1, c))
	if per_para.is_empty():
		per_para = [maxi(1, out.size())]
	# ...and prose pasted as one unbroken block has no marker of either kind, so the
	# length of a paragraph is bounded whether the text says where they end or not.
	var capped: Array = []
	for n in per_para:
		var left := int(n)
		while left > PARA_CEILING:
			capped.append(PARA_CEILING)
			left -= PARA_CEILING
		capped.append(maxi(1, left))
	per_para = capped
	# sentence index -> (paragraph index, position within it)
	var pi := 0
	var within := 0
	for i in out.size():
		if within >= int(per_para[mini(pi, per_para.size() - 1)]) and pi < per_para.size() - 1:
			pi += 1
			within = 0
		var n := int(per_para[mini(pi, per_para.size() - 1)])
		# A ONE-SENTENCE PARAGRAPH SITS IN THE MIDDLE OF ITS OWN ARC, not at the start
		# of it. Placing it at 0 hands it the opening register of a paragraph it also
		# ends, so a run of them takes a constant lift - measured +2.3 semitones at Arc 1,
		# which is a transposition again, just a subtler one. The midpoint makes the
		# paragraph term neutral where the paragraph has no extent, and leaves the section
		# to supply all of the movement, which is the whole point of having one.
		out[i]["plan_u"] = 0.5 if n <= 1 else float(within) / float(n - 1)
		# ...and the paragraph's place in its section. A one-paragraph section would put
		# every paragraph at 0 again, which is the same trap one level up.
		var sp := pi % SECTION_PARAS
		out[i]["plan_v"] = float(sp) / float(maxi(1, SECTION_PARAS - 1))
		within += 1


## THE INK: which pen this voice writes in, where the medium writes by hand (the Notebook).
## Not a sound, so changing it restarts nothing; it reaches the page at the next Play.
var _ink_pick: OptionButton
var _ink_raw := ""               # the slot's ink as stored, kept when it is a hex the list lacks

func _build_ink_row(box: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	var l := Label.new()
	l.text = "Ink"
	l.custom_minimum_size = Vector2(72, 0)
	l.add_theme_font_size_override("font_size", 12)
	row.add_child(l)
	_ink_pick = OptionButton.new()
	_ink_pick.focus_mode = Control.FOCUS_NONE
	_ink_pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for k in NotebookLayout.INKS:
		_ink_pick.add_item(String(k).capitalize())
	_ink_pick.tooltip_text = ("The pen this voice writes in, in the Notebook: a color per speaker "
		+ "tells the voices apart on the page without naming them. Black unless set. Saved on "
		+ "the voice as `ink:` - a hex color written there works too.")
	_ink_pick.item_selected.connect(func(i: int) -> void:
		if _syncing:
			return
		_ink_raw = "" if i == 0 else String(NotebookLayout.INKS.keys()[i])
		_capture_slot())
	row.add_child(_ink_pick)
	# ONLY WHERE THE MEDIUM WRITES BY HAND: it showed on the card table, which writes nothing
	(_medium_rows.get_or_add("handwriting", []) as Array).append(row)


func _ink_value() -> String:
	return _ink_raw


func _show_ink(v: String) -> void:
	_ink_raw = v
	if _ink_pick == null:
		return
	var k := v.strip_edges().to_lower()
	var i := NotebookLayout.INKS.keys().find("black" if k.is_empty() else k)
	_ink_pick.select(i)            # -1 (nothing shown) for a hex: it is kept, not replaced
	_ink_pick.tooltip_text = _ink_pick.tooltip_text.get_slice("\n\nNow: ", 0) \
		+ ("\n\nNow: " + v if i < 0 and not v.is_empty() else "")


func _fx_slider(box: VBoxContainer, name: String, initial: float, tip := "") -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.tooltip_text = tip          # the gap between the label and the slider
	box.add_child(row)
	var l := Label.new()
	l.text = name
	l.custom_minimum_size = Vector2(72, 0)
	l.add_theme_font_size_override("font_size", 12)
	# A Label ignores the mouse by default, so pointing at the NAME - which is
	# what anyone actually does - would otherwise show nothing.
	l.mouse_filter = Control.MOUSE_FILTER_STOP
	l.tooltip_text = tip
	row.add_child(l)
	var sl := HSlider.new()
	sl.tooltip_text = tip
	sl.min_value = 0.0
	sl.max_value = 1.0
	sl.step = 0.01
	sl.value = initial
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.value_changed.connect(func(_v: float) -> void:
		if _syncing:
			return
		_capture_slot()
		_live_fx()
		_dirty = true
		_last_edit_ms = Time.get_ticks_msec())
	row.add_child(sl)
	Card.readout(row, sl)
	return sl




## WHERE THE READER IS, sentence by sentence ([method VoiceFX.near_plan]), written into
## each chunk from [param from] on as `near` - read by [method _request_args] (the softer
## voice) and by the marks that ease the chain there. Taken when a chunk is
## REQUESTED, from the dials as they are then, and never rewritten behind a request: a
## sentence already made has its softer voice in it, and its distance has to match.
## [param voice] reads every chunk as that voice (the audition's chunks carry none).
func _plan_near(chunks: Array, from: int, voice := "") -> void:
	var ks := PackedFloat32Array()
	var who := PackedStringArray()
	var text := ""
	for c in chunks:
		var name := voice if not voice.is_empty() else String((c as Dictionary).get("speaker", ""))
		ks.append(float(_cfg_of(name)["near"]))
		who.append(name)
		for w in (c as Dictionary).get("words", []):
			text += String((w as Dictionary).get("text", "")) + " "
	# same words, same moves - in the reading, the audition of it and the export alike
	var plan := VoiceFX.near_plan(ks, who, hash("near " + text))
	for i in range(maxi(from, 0), chunks.size()):
		(chunks[i] as Dictionary)["near"] = plan[i]




## A dial moved on the panel, applied to the LIVE chain - but only if the tab
## being edited is the voice currently sounding. Turning up the reverb on a
## character who has not spoken yet must not put the narrator in a cathedral;
## the setting is stored either way, and arrives at that character's first word
## through [member _fx_marks].
func _live_fx() -> void:
	if not _fx_live_name.is_empty() and _fx_live_name != _tab_name():
		return
	_fx_live_name = _tab_name()
	Delivery.apply_fx(_fx, _cfg(_slot))


func _set_status(msg: String) -> void:
	if _status != null:
		_status.text = msg


# --- host --------------------------------------------------------------------


func _on_host_ready(backends: PackedStringArray) -> void:
	_set_status("Voice host up (%s). Loading voices…" % ", ".join(backends))
	_host.capabilities()
	_host.list_voices()


func _on_failed(stage: String, message: String) -> void:
	_can_play = true
	_in_flight = maxi(0, _in_flight - 1)
	_set_status("%s failed: %s" % [stage, message])


func _on_synthesized(id: int, result: Dictionary) -> void:
	if result.has("backends"):
		var caps: Dictionary = result["backends"]
		for name in caps:
			if bool((caps[name] as Dictionary).get("duration_control", false)):
				_rate_row.visible = true
		return
	if result.has("voices"):
		_fill_voices(result["voices"])
		return
	if _test_req.has(id):
		_on_test_part(id, result)
		return
	if not _req_chunk.has(id):
		return
	var meta: Dictionary = _req_chunk[id]
	_req_chunk.erase(id)
	# THE SLOT IS FREED WHETHER OR NOT THE RESULT IS WANTED, and this has to happen BEFORE
	# the epoch check. It did not, and that is what made seeking slower than a cold start:
	# an abandoned request still occupies the host - the protocol has no cancel - so a jump
	# that zeroed the counter let _pump send a full lookahead on top of work already
	# queued, and the chunk actually being waited for ended up third or fourth in line.
	# Counting abandoned work as in-flight means the new request enters the queue exactly
	# when a slot frees, which without a cancel is the best available.
	_in_flight = maxi(0, _in_flight - 1)
	if int(meta["epoch"]) != _epoch:
		# Superseded by a pace change or a jump. Nothing to keep, but the pump may now
		# have room it did not have a moment ago.
		_pump()
		return
	var idx: int = int(meta["idx"])

	var wav := String(result.get("wav", ""))
	if wav.is_empty():
		_set_status("The host returned no audio.")
		return
	_sr = int(result.get("sample_rate", _sr))
	_ready_takes.append({"wav": wav, "index": idx,
		"words": _words_for(idx, result.get("tokens", [])),
		"spans": result.get("tokens", [])})
	_drain_ready()
	_pump()


func _fill_voices(voices: Array) -> void:
	_voice_meta = voices
	_voices.clear()
	for v in voices:
		var mark := "" if bool(v.get("installed", false)) else "  (downloads)"
		_voices.add_item("%s%s" % [String(v.get("name", v.get("id", "?"))), mark])
	if voices.is_empty():
		_set_status("No voices available - see the >_ log.")
		return
	var want := _want_voice if not _want_voice.is_empty() else DEFAULT_VOICE
	for i in voices.size():
		if String((voices[i] as Dictionary).get("id", "")) == want:
			_voices.select(i)
			break
	_test.disabled = false
	_refresh_tab_labels()           # model names are known now, not just ids
	_can_play = true            # from here on Play is always live
	_show_voice_license()


## Under the speaker number: who that reader is. Hidden on a single-speaker voice, or when nothing
## is known about the reader.
func _describe_speaker() -> void:
	if _speaker_about == null:
		return
	var d := VoiceReaders.describe(_selected_voice_id(), int(_speaker.value))
	_speaker_about.text = VoiceReaders.line(d, 8)
	_speaker_about.visible = _speaker_row.visible and not d.is_empty()


## The reader browser: a filter by gender, a search over the descriptions, and the list.
## Picking one sets the speaker number (which regenerates what has not played, as a step does).
func _open_speaker_browser() -> void:
	var all := VoiceReaders.all(_selected_voice_id())
	if all.is_empty():
		_set_status("Nothing is known about this voice's readers (is it installed, and multi-speaker?).")
		return
	if _speaker_browse != null and is_instance_valid(_speaker_browse):
		_speaker_browse.queue_free()
	_speaker_browse = PopupPanel.new()
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(560, 460)
	_speaker_browse.add_child(box)
	var bar := HBoxContainer.new()
	box.add_child(bar)
	var which := OptionButton.new()
	for label in ["All", "♀ Female", "♂ Male"]:
		which.add_item(label)
	bar.add_child(which)
	var find := LineEdit.new()
	find.placeholder_text = "Search: soft, deep, calm, raspy…"
	find.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	find.clear_button_enabled = true
	bar.add_child(find)
	var list := ItemList.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(list)
	var note := Label.new()
	note.text = "Descriptions: LibriTTS-P, LINE Corporation (CC BY 4.0)."
	note.add_theme_font_size_override("font_size", 10)
	note.modulate = Color(1, 1, 1, 0.55)
	box.add_child(note)
	var fill := func() -> void:
		list.clear()
		var want: String = ["", "F", "M"][which.selected]
		var words := find.text.strip_edges().to_lower().split(" ", false)
		for r in all:
			var d: Dictionary = r
			if not want.is_empty() and String(d["g"]) != want:
				continue
			var hay := String(d["d"]).to_lower()
			var ok := true
			for w in words:
				ok = ok and hay.contains(w)
			if not ok:
				continue
			var at := list.add_item("%d   %s" % [int(d["i"]), VoiceReaders.line(d, 10)])
			list.set_item_metadata(at, int(d["i"]))
			if int(d["i"]) == int(_speaker.value):
				list.select(at)
	which.item_selected.connect(func(_i: int) -> void: fill.call())
	find.text_changed.connect(func(_t: String) -> void: fill.call())
	list.item_selected.connect(func(at: int) -> void:
		_speaker.value = float(int(list.get_item_metadata(at))))
	add_child(_speaker_browse)
	fill.call()
	_speaker_browse.popup_centered()
	list.ensure_current_is_visible()


## Always shown: these checkpoints are licensed individually and the terms are
## inherited through fine-tuning in a way nothing machine-readable records.
func _show_voice_license() -> void:
	var i := _voices.selected
	if i < 0 or i >= _voice_meta.size():
		return
	var v: Dictionary = _voice_meta[i]
	var n := int(v.get("speakers", 1))
	_speaker_row.visible = n > 1
	if n > 1:
		_speaker.max_value = n - 1
		_speaker.value = clampf(_speaker.value, 0, n - 1)
	_describe_speaker()
	_set_status("%s - %s%s" % [String(v.get("id", "")), String(v.get("license", "unknown")),
		("  (%d speakers)" % n) if n > 1 else ""])


# --- the window ---------------------------------------------------------------


func _on_speak() -> void:
	if _reading_live():
		Spectrum.set_paused(not Spectrum.paused)
		_set_status("Paused. Space or ▶ carries on; ■ ends the reading."
			if Spectrum.paused else "Resumed.")
		return
	if _host == null or not _host.is_up() or _voices.selected < 0:
		return
	# THE REAL-TIME READ. In sync mode this is the file as it is on disk RIGHT NOW, not as
	# it was when the document was opened - which is what lets the author keep writing in
	# their own editor with ghost open beside it.
	var body := _reading_body().strip_edges()
	if body.is_empty():
		_set_status("Nothing to speak yet.")
		return
	# The cast NOW, not at the next pause in typing: a name written a moment ago must read in
	# its own voice from the first Play.
	_refresh_cast(body)
	if _test_busy():
		_stop_test()
	# _plan is a full teardown - stream closed, queues emptied, pending request
	# ids dropped so replies for the OLD text are discarded on arrival rather
	# than spliced into the new reading.
	_plan(body)
	if _chunks.is_empty():
		_set_status("Nothing speakable in that text.")
		return
	_stale = false
	Spectrum.set_stream_paused(false)
	_sync_speak_buttons()
	_set_status("Planned %d chunk(s). Synthesizing the first…%s" % [_chunks.size(), _plan_note])
	_pump()


## Tear the stream down and read again from the top. _plan clears the pending
## request map, so replies still in flight for the old voice are dropped on
## arrival rather than spliced in.
func _restart_speaking() -> void:
	var body := _reading_body().strip_edges()
	if body.is_empty():
		return
	_refresh_cast(body)
	_plan(body)
	if _chunks.is_empty():
		return
	_stale = false
	Spectrum.set_stream_paused(false)
	_sync_speak_buttons()
	_set_status("Voice changed - reading again from the start…%s" % _plan_note)
	_pump()


## Cut the text into chunks at sentence boundaries, recording per chunk the
## phone stream and the word spans within it. Planning is pure front end - no
## synthesis - so it stays cheap even for a whole chapter.
## EVERY PIECE OF STATE A READING OWNS, put back. Split out of [method _plan] so that
## stopping and re-planning cannot drift apart: they were one block, and a Stop button that
## reset "most of" it is the kind that leaves a stream half open.
##
## The pending request map is the important one. Replies for chunks already asked for are still
## in flight on the host, and dropping their ids here is what makes them discarded on arrival
## instead of spliced into a reading that no longer exists.
func _reset_playback() -> void:
	_chunks = []
	_ready_takes = []
	_req_chunk = {}
	_next_to_request = 0
	_next_to_play = 0
	_in_flight = 0
	_stream_open = false
	_playback = null
	_pushed = 0
	_ring_capacity = 0
	_pending = PackedFloat32Array()
	_read = 0
	_elapsed = 0.0
	_fx_marks = []
	_fx_live_name = ""
	_fx_queued_name = ""
	_fx_queued_near.clear()
	_fx_marked = false
	# The intro silence belongs to a reading that is STARTING, so it is seeded in _plan and
	# only cleared here. `_elapsed` is the clock every word span and every seam is measured
	# against, so starting it at the end of that silence offsets the whole reading, subtitles
	# included, with nothing else needing to know. Inserting it later would put it AFTER the
	# first sentence - the audition spoke its opening line, went quiet for five seconds, then
	# carried on.
	_lead_in = 0.0
	_close_environment()
	_outro_queued = false
	_fade_at = -1
	_fade_done = false
	Director.live_fade = 1.0
	_sub_words.clear()          # cleared in place: Subtitles holds this by reference


## Play and Stop, from one place. Two buttons whose enabled state is set at each of the
## several points a reading starts or ends is two buttons that will eventually disagree.
func _sync_speak_buttons() -> void:
	if _chunks.is_empty():
		_stale = false


## THE OUTRO MARK, in chunks: the reading goes on past it only as far as the fade can carry
## it. Enough fading chunks are kept to fill the Outro's length at a brisk reading pace (and
## one more, since the fade is cut on the clock, not on a word), and the rest are dropped
## BEFORE synthesis - text that would be cut is never made. Sets [member _fade_len] when there
## is a mark, 0 when there is none.
func _trim_to_outro(chunks: Array) -> Array:
	_fade_len = 0.0
	var first := -1
	for i in chunks.size():
		if bool((chunks[i] as Dictionary).get("fade", false)):
			first = i
			break
	if first < 0:
		return chunks
	_fade_len = maxf(OUTRO_MIN_FADE, Director.outro_hold)
	var budget := _fade_len * OUTRO_WORDS_PER_SECOND
	var words := 0.0
	var keep := first
	while keep < chunks.size() and words < budget:
		words += float(((chunks[keep] as Dictionary).get("words", []) as Array).size())
		keep += 1
	return chunks.slice(0, mini(keep + 1, chunks.size()))


## The scrub bar's length: the whole reading, estimated.
func _scrub_len() -> float:
	return _chunk_t[_chunk_t.size() - 1] if not _chunk_t.is_empty() else 0.0


## The scrub bar's position: where a waiting seek is going, else the sentence being heard and
## how far through it, on the estimated scale.
func _scrub_pos() -> float:
	var n := _chunk_t.size() - 1
	if n <= 0:
		return 0.0
	if _seek_k >= 0:
		return _chunk_t[clampi(_seek_k, 0, n)]
	var i := _start_chunk
	var f := 0.0
	if _playback != null and _ring_capacity > 0 and not _chunk_at.is_empty():
		var heard := _pushed - maxi(0, _ring_capacity - int(_playback.get_frames_available()))
		var best := -1
		for c in _chunk_at:
			if int(_chunk_at[c]) <= heard and int(c) > best:
				best = int(c)
		if best >= 0:
			i = best
			var est := maxf(0.2, _chunk_t[mini(i + 1, n)] - _chunk_t[mini(i, n)])
			f = clampf(float(heard - int(_chunk_at[best])) / float(_sr) / est, 0.0, 0.99)
	i = clampi(i, 0, n - 1)
	return lerpf(_chunk_t[i], _chunk_t[i + 1], f)


## The scrub bar asks to go to [param t] (estimated seconds): remember the sentence there and
## restart from it once the bar settles.
func _scrub_seek(t: float) -> void:
	var k := 0
	for i in _chunk_t.size() - 1:
		if _chunk_t[i] <= t:
			k = i
	_seek_k = k
	if _seek_timer != null and _seek_timer.is_inside_tree():
		_seek_timer.start()


func _seek_now() -> void:
	var k := _seek_k
	if k >= 0:
		_speak_from(k)


## Read from sentence [param k]: Stop, then Play from there. The old stream is ENDED (the voice
## stops at once and the stage is handed back), then a fresh reading is planned and requested
## from [param k] on, with no intro. The media start where it starts ([method _start_words]).
func _speak_from(k: int) -> void:
	_seek_k = -1
	if _host == null or not _host.is_up() or _voices.selected < 0:
		_set_status("The voice is not ready yet - wait for it, then scrub.")
		return
	var body := _reading_body().strip_edges()
	if body.is_empty():
		return
	if not _chunks.is_empty() or _playback != null:
		Spectrum.set_stream_paused(false)
		_reset_playback()
		if end_stream.is_valid():
			end_stream.call()
	_refresh_cast(body)
	if _test_busy():
		_stop_test()
	_plan(body)
	if _chunks.is_empty():
		_set_status("Nothing speakable in that text.")
		return
	k = _start_at(k)
	_stale = false
	Spectrum.set_stream_paused(false)
	_sync_speak_buttons()
	_set_status("Reading from sentence %d of %d…%s" % [k + 1, _chunks.size(), _plan_note])
	_pump()


## A planned reading made to start at chunk [param k]: requested and played from there, with no
## intro. Returns the chunk it will start at.
func _start_at(k: int) -> int:
	k = clampi(k, 0, maxi(0, _chunks.size() - 1))
	_start_chunk = k
	if k > 0:
		_pending = PackedFloat32Array()
		_read = 0
		_lead_in = 0.0
		_elapsed = 0.0
		_next_to_request = k
		_next_to_play = k
	return k


## About where those words are: how many words with letters come before the chunk a reading
## starts at (-1 for a reading from the top). A medium breaks ties between equally good matches
## of [method _start_words] with it - see [method TabletScript.find_run].
func _start_index() -> int:
	if _start_chunk <= 0 or _start_chunk >= _chunks.size():
		return -1
	var n := 0
	for ci in _start_chunk:
		for w in (_chunks[ci] as Dictionary).get("words", []):
			if not TabletScript.norm(String((w as Dictionary).get("text", ""))).is_empty():
				n += 1
	return n


## The first words of the chunk a reading starts at, normalized - how a medium finds its place.
## Empty for a reading from the top.
func _start_words() -> PackedStringArray:
	var out := PackedStringArray()
	if _start_chunk <= 0 or _start_chunk >= _chunks.size():
		return out
	for ci in range(_start_chunk, mini(_start_chunk + 2, _chunks.size())):
		for w in (_chunks[ci] as Dictionary).get("words", []):
			var n := TabletScript.norm(String((w as Dictionary).get("text", "")))
			if not n.is_empty():
				out.append(n)
			if out.size() >= 6:
				return out
	return out


## The outro mark's fade at stream sample [param sample]: 1 before it starts, easing to 0 over
## [member _fade_len], 0 after.
func _fade_gain(sample: int) -> float:
	if _fade_at < 0 or sample < _fade_at:
		return 1.0
	var u := float(sample - _fade_at) / maxf(1.0, _fade_len * float(_sr))
	return 0.0 if u >= 1.0 else 0.5 + 0.5 * cos(PI * u)


## Plan a reading: tear the old one down, then cut the text into chunks.
func _plan(body: String) -> void:
	_reset_playback()
	# THE INTRO, seeded HERE rather than at the moment the stream opens - see the note in
	# _reset_playback's lead-in block, which this replaces for a reading that is starting.
	_lead_in = maxf(0.0, Director.intro_hold)
	if _lead_in > 0.0:
		_pending.resize(int(_lead_in * float(_sr)))
		_elapsed = _lead_in
	_chunks = _build_chunks(body)
	_start_chunk = 0
	_chunk_at = {}
	_seek_k = -1
	_chunk_t = PackedFloat32Array()
	var at := 0.0
	for c in _chunks:
		_chunk_t.append(at)
		var rest := 0.0
		for h in (c as Dictionary).get("holds", []):
			if h is Dictionary:
				rest += float((h as Dictionary).get("sec", 0.0))
		at += maxf(0.2, float(((c as Dictionary).get("words", []) as Array).size())
			* SCRUB_SECONDS_PER_WORD + rest)
	_chunk_t.append(at)


## STOP: end the reading and hand the stage back.
##
## There was no way to do this. The Speak button's tooltip claimed "press again while it is
## running to stop" and that was simply untrue - _on_speak re-plans and reads again from the
## top, whatever is playing. Reported as: "it would be preferable to stop the real-time scene
## before I do an export, and today I've just been restarting the program."
##
## Tearing down the STREAM is the half the editor cannot do alone: the playback, the Director's
## attachment to the stage and the subtitle overlay all belong to the owner, which is why
## `end_stream` exists and is wired beside `begin_stream` (see main._end_generative_stream).
## The synth editor has had both since it was written; this path was given only the opening
## half, so nothing was ever able to close it.
func _stop_speaking() -> void:
	if _chunks.is_empty() and _playback == null:
		return
	Spectrum.set_stream_paused(false)
	_reset_playback()
	if end_stream.is_valid():
		end_stream.call()
	_sync_speak_buttons()
	_set_status("Stopped. Space or ▶ reads again from the top.")


## Pure: text in, chunk plan out. Shared by playback and by export, so an export
## cannot disturb the reading in progress.
##
## The speaker cues are resolved HERE and nowhere else: past this point a chunk
## carries a slot number and every consumer - the request, the resampler, the
## seam, the room - reads its settings from that. Nothing downstream has to know
## that a script can change voice.
func _build_chunks(body: String) -> Array:
	var out: Array = []
	var sentence_no := 0
	var bare: PackedStringArray = PackedStringArray()
	_plan_note = ""
	var segs := _split_speakers(body)
	_hold_i = 0
	for seg in segs:
		var text := String((seg as Dictionary)["text"])
		var who := String((seg as Dictionary)["speaker"])
		# Asked per PASSAGE rather than of the whole box, so a macro sitting in a
		# stripped authoring note is not reported as one that will be missing
		# from the reading - it was never going to be read either way.
		bare.append_array(TextNorm.unresolved_macros(text))
		var part := _cut(text, sentence_no)
		var chunks: Array = part["chunks"]
		sentence_no = int(part["sentence_no"])
		if chunks.is_empty():
			continue
		# PLACEMENT IS PER PASSAGE. A speaker's turn is its own piece of
		# discourse - it opens in its own register and settles across its own
		# paragraphs - so measuring it against the whole chapter would hand the
		# second voice the contour of a paragraph it is not in.
		_place_chunks(chunks, text)
		var fade := bool((seg as Dictionary).get("fade", false))
		var leans: Array = (seg as Dictionary).get("leans", [])
		var cursor := 0
		for c in chunks:
			(c as Dictionary)["speaker"] = who
			if fade:
				(c as Dictionary)["fade"] = true
			# A CHUNK'S DELIVERY is the one marked where its first word is in the passage
			var aim := Vector4.ZERO
			if not leans.is_empty():
				var first := ""
				for w in (c as Dictionary)["words"]:
					first = String((w as Dictionary).get("text", "")).strip_edges()
					if not first.is_empty():
						break
				var found := text.find(first, cursor) if not first.is_empty() else -1
				if found >= 0:
					cursor = found + first.length()
				for sp in leans:
					if int((sp as Array)[0]) <= (found if found >= 0 else cursor):
						aim = (sp as Array)[1]
			(c as Dictionary)["lean_aim"] = aim
		out.append_array(chunks)
	Delivery.ease_leans(out)
	out = _trim_to_outro(out)
	# LAST, so it wins the status line. TextNorm has already warned into the log,
	# but this is the surface someone is looking at with their hand on Play, and
	# a macro with no default is words missing from a reading about to be made.
	if not bare.is_empty():
		_note("%d macro(s) will not read as intended: %s - write ${NAME:value}"
			% [bare.size(), ", ".join(bare)])
	return out


## One finding about the script, for the line that reports the plan.
func _note(msg: String) -> void:
	_plan_note += ("  " if _plan_note.is_empty() else "; ") + msg


## One passage, cut at sentence boundaries. `sentence_no` runs across the WHOLE
## script rather than restarting per passage: [Subtitles] windows the display by
## that index, and two speakers sharing sentence 0 would have the overlay draw
## both at once.
func _cut(body: String, sentence_no: int) -> Dictionary:
	var out: Array = []
	var toks: Array = []
	var words: Array = []
	var holds: Array = []          # [{tok, sec, before}] - see Splice.chunk
	var sentences := 0
	var parsed := Phonemes.parse(body)
	var stressed_at := Delivery.stressed_words(parsed)
	var flat := -1
	for sentence in parsed:
		for w in sentence:
			flat += 1
			var ph: Array = w.phones
			var st: Array = w.get("stress", [])
			var start := toks.size()
			# HESITATIONS, in the order the phonemizer met their sentinels - which is the
			# order _split_speakers queued their lengths in.
			for key in ["hold_before", "hold"]:
				var n := int(w.get(key, 0))
				if n <= 0:
					continue
				var sec := 0.0
				for _k in n:
					if _hold_i < _holds.size():
						sec += float(_holds[_hold_i])
					_hold_i += 1
				if sec > 0.0:
					holds.append({"tok": start, "sec": sec, "before": key == "hold_before"})
			# A HUM IS HELD, not spoken in passing - see Splice.HUM_SECONDS.
			var hum_key := String(w.text).to_lower()
			if Splice.HUM_SECONDS.has(hum_key):
				holds.append({"tok": start, "sec": 0.0, "before": false,
					"hum": float(Splice.HUM_SECONDS[hum_key])})
			# ghost's dictionary returns stress 0 for every phone of most
			# monosyllables, so no stress mark was ever emitted for them and the
			# model heard a flat reading. Promote the nucleus - but only for
			# CONTENT words, because eSpeak leaves function words unstressed and
			# promoting "the" to "ðˈʌ" is worse than leaving it alone. Phrasing
			# already made that distinction; w.stressed carries it.
			var lex: Array = []
			for i in ph.size():
				lex.append(int(st[i]) if i < st.size() else -1)
			if bool(w.get("stressed", false)) and not lex.has(1):
				var nucleus := Phonemes.stress_vowel(ph, st)
				if nucleus >= 0 and nucleus < lex.size():
					lex[nucleus] = 1
			# A token carries its SOURCE TEXT so the host can phonemize it with
			# eSpeak - whose transcriptions these voices were trained on - and
			# carries ghost's ARPAbet only as a fallback, or as an authored
			# [K AE T] override, which always wins.
			var arpa: Array = []
			for i in ph.size():
				# the stress digit lives in a parallel array; the ARPAbet path
				# needs it re-attached to the phone itself
				var d: int = lex[i]
				arpa.append(String(ph[i]) + (str(d) if d >= 0 else ""))
			# SEND THE REAL MARK. phonemes.gd already walks the terminal
			# punctuation off each word and records it verbatim (including the
			# case where a quote was hiding it - `early,"`); this used to
			# collapse it back to "." or "," via the coarse pause_after class,
			# which is where the reading lost its colons - heard as a comma -
			# and its question marks, heard as a full stop, so the interrogative
			# contour was never even asked for.
			#
			# pause_after stays as the fallback for a word whose mark has no
			# printable form (a line break), and the allow-list keeps anything
			# unexpected away from the voice's phoneme_id_map.
			var punct := String(w.get("punct", ""))
			if not PUNCT_ALLOWED.has(punct):
				punct = ""
				match String(w.pause_after):
					"stop": punct = "."
					"comma": punct = ","
			var tok := {"text": String(w.text), "punct": punct, "fallback": arpa}
			if bool(w.get("literal", false)):
				tok["arpa"] = arpa
			# A WORD NO DICTIONARY HOLDS (the audit's UNKNOWN), spelled as written: eSpeak would be
			# guessing at it, so the host reads it as Wiktionary has it, its full vowels stressed
			# (lexicon.py - the user, 2026-10-16: cosine "co-seen", cotangent "co-angent")
			elif String(w.get("display", w.text)).to_lower() == String(w.text).to_lower() \
					and not Phonemes.is_known(String(w.text)):
				tok["rare"] = true
			# A WORD LEANED ON (`*so*`, `**so**`) is SPOKEN leaned on: the host holds its stressed
			# vowel longer and lifts the word a little (piper.py `EMPHASIS`). Sent only when set,
			# so an unmarked sentence is the request it always was.
			if stressed_at.has(flat):
				tok["emph"] = int(stressed_at[flat])
			toks.append(tok)
			# ONE SUBTITLE ENTRY PER SOURCE RUN. `2009` is three spoken words and
			# one thing on the page, so the words after the first in a rewritten
			# run do not get their own entry - they extend this one's END, and
			# the highlight sweeps the numeral across all three rather than
			# flashing it over the first syllable. See Phonemes.parse.
			var span := int(w.get("src_span", -1))
			if span >= 0 and not words.is_empty() \
					and int((words[words.size() - 1] as Dictionary).get("span", -1)) == span:
				(words[words.size() - 1] as Dictionary)["end"] = start
			else:
				# A run whose first word the phonemizer dropped would leave a
				# continuation with nothing to draw; show what is being said
				# rather than an empty card.
				var shown := String(w.get("display", w.text))
				words.append({"text": shown if not shown.is_empty() else String(w.text),
					"index": start, "end": start, "span": span, "sentence": sentence_no,
					"emph": int(w.get("emph", 0))})
		sentence_no += 1
		sentences += 1
		if sentences >= CHUNK_SENTENCES:
			out.append({"tokens": toks, "words": words, "holds": holds})
			toks = []
			words = []
			holds = []
			sentences = 0
	if not toks.is_empty():
		out.append({"tokens": toks, "words": words, "holds": holds})
	return {"chunks": out, "sentence_no": sentence_no}








## Keep LOOKAHEAD chunks in flight and start playback as soon as the chunk we
## are waiting for exists.
## How much finished audio is waiting to be heard: decoded but not yet pushed,
## plus whatever is still sitting in the ring.
func _buffered_seconds() -> float:
	var queued := 0
	if _playback != null and _ring_capacity > 0:
		queued = maxi(0, _ring_capacity - int(_playback.get_frames_available()))
	return float(maxi(_pending.size() - _read, 0) + queued) / float(maxi(_sr, 1))


## Which checkpoint a slot reads with. A tab may name a voice this install does
## not have - a config copied between machines, a model deleted - and the answer
## to that is to read in whatever IS selected, not to fall silent halfway
## through a chapter.
func _voice_id_of(s: Dictionary) -> String:
	var want := String(s["voice"])
	for v in _voice_meta:
		if String((v as Dictionary).get("id", "")) == want:
			return want
	var i := _voices.selected
	if i >= 0 and i < _voice_meta.size():
		return String((_voice_meta[i] as Dictionary).get("id", ""))
	return ""


## A slot's reader id, clamped to what its own model actually holds. Slots are
## copied when a tab is added, so a speaker id chosen on libritts (904 readers)
## can easily outlive the switch to a single-speaker voice.
func _speaker_of(s: Dictionary) -> int:
	var vid := _voice_id_of(s)
	for v in _voice_meta:
		if String((v as Dictionary).get("id", "")) == vid:
			return clampi(int(s["speaker"]), 0, maxi(0, int((v as Dictionary).get("speakers", 1)) - 1))
	return maxi(0, int(s["speaker"]))

## [method Delivery.request_args] for slot [param s], with the reader this install's voice holds - and
## how the host may look up a word eSpeak would guess at (lexicon.py): from Wiktionary, kept in its
## cache; never in a process that must not write the user's things (a gate, a probe), so a test is
## the same on every machine.
func _request_args(s: Dictionary, ch: Dictionary) -> Dictionary:
	var a := Delivery.request_args(s, ch, _speaker_of(s))
	a["lexicon"] = "off" if Settings.is_read_only() else "fetch"
	return a


## [method Delivery.gap_before], with the Turn dial as it stands.
func _gap_before(chunks: Array, idx: int, s: Dictionary) -> float:
	return Delivery.gap_before(chunks, idx, s, _turn.value if _turn != null else 1.0)




func _pump() -> void:
	if _voice_meta.is_empty():
		return
	# THE INTRO IS NOT LOOKAHEAD. It is seeded into the queue as silence before anything is
	# requested, so counting it made an Intro of LOOKAHEAD_SECONDS or more look like a full
	# buffer: nothing was ever requested, the stream never opened, and Play did nothing at
	# all ("at 9 the video breaks, at 7 it works"). Only the SPEECH queued counts; the intro
	# still to be pushed is taken off (an underestimate once it plays, so it stays safe).
	var intro_left := maxf(0.0, _lead_in - float(_pushed) / float(maxi(_sr, 1)))
	var planned := false
	while _in_flight < LOOKAHEAD and _next_to_request < _chunks.size() \
			and _buffered_seconds() - intro_left < LOOKAHEAD_SECONDS:
		var idx := _next_to_request
		if not planned:
			planned = true
			_plan_near(_chunks, idx)
		_next_to_request += 1
		_in_flight += 1
		var s := _cfg_of(String((_chunks[idx] as Dictionary).get("speaker", "")))
		var id := _host.request("", _voice_id_of(s),
			TAKE_DIR + "/chunk_%d_%d.wav" % [idx, _epoch], _request_args(s, _chunks[idx]), null)
		_req_chunk[id] = {"idx": idx, "epoch": _epoch}


## Append every chunk that is ready AND next in order to the one stream. Out of
## order arrivals wait: audio has to go out in the order it was written.
func _drain_ready() -> void:
	while true:
		if _fade_done:
			return                   # the outro mark's fade has run out: the reading is over
		var found := -1
		for i in _ready_takes.size():
			if int(_ready_takes[i]["index"]) == _next_to_play:
				found = i
				break
		if found < 0:
			return
		var take: Dictionary = _ready_takes[found]
		_ready_takes.remove_at(found)
		var idx := int(take["index"])
		_next_to_play += 1

		var pcm := Splice.read_wav(String(take["wav"]))
		if pcm.is_empty():
			continue
		var who := ""
		var holds: Array = []
		if idx >= 0 and idx < _chunks.size():
			who = String((_chunks[idx] as Dictionary).get("speaker", ""))
			holds = (_chunks[idx] as Dictionary).get("holds", [])
		var s := _cfg_of(who)
		# THE TONE IS ALREADY IN IT: the host played the take back at the preset's ratio, and
		# every time it returned is in the take's own seconds (`play_ratio`), so nothing here
		# has a ratio left to apply.
		var ratio := 1.0
		# THE HESITATIONS go in now, in the chunk's own time - so the word timings below can be
		# moved by exactly what was inserted before them.
		var spliced := Splice.chunk(pcm, holds, take.get("spans", []), ratio, _sr)
		pcm = spliced["pcm"]
		# THE READER MOVES IN THE PAUSE before the sentence they come in for - so this
		# mark goes BEFORE the gap (the first one follows the voice's, which opens the chain)
		var near: Dictionary = (_chunks[idx] as Dictionary).get("near", {}) \
			if idx >= 0 and idx < _chunks.size() else {}
		var near_first := _fx_marked
		if near_first:
			Delivery.near_mark(_fx_marks, near, _pushed + _pending.size() - _read, _fx_queued_near)
		if _next_to_play > 1:
			# a breath between sentences, at the seam the host cannot see.
			# Scaled by Pause like every other rest, or the control would do
			# nothing at all at CHUNK_SENTENCES = 1 - every sentence boundary in
			# the reading IS a seam, and they would all stay 0.32 s. A handover
			# takes the Turn rest on top.
			var seam := _gap_before(_chunks, idx, s)
			var gap := PackedFloat32Array()
			gap.resize(int(seam * float(_sr)))
			_pending.append_array(gap)
			_elapsed += seam
		# SCHEDULE THE ROOM, do not switch it here. This runs when a chunk is
		# DECODED, which is seconds ahead of when it is heard - dialing the
		# chain now would put the next speaker's room over the end of this one's
		# last sentence. The mark carries the frame instead, and _process applies
		# it as the playhead reaches it. The first mark sits at 0 so the intro is
		# already in the opening voice's room rather than in nobody's.
		#
		# AFTER the gap, deliberately: the handover silence belongs to the voice
		# leaving it, whose reverb is still decaying through it. Dialing the new
		# room at the start of the rest would cut that tail over to a different
		# space halfway down, which is the one thing a room never does.
		if who != _fx_queued_name:
			_fx_queued_name = who
			_fx_marks.append({
				"at": 0 if not _fx_marked else _pushed + _pending.size() - _read,
				"speaker": who})
			_fx_marked = true
		if not near_first:
			Delivery.near_mark(_fx_marks, near, _pushed + _pending.size() - _read, _fx_queued_near)
			_fx_marked = true
		# the model timed each chunk from zero; shift into stream time
		for w in take["words"]:
			var d: Dictionary = (w as Dictionary).duplicate()
			# moved by the hesitations spliced in before it
			d["t0"] = Splice.shifted(float(d["t0"]), spliced["cuts"], ratio, true) + _elapsed
			d["t1"] = Splice.shifted(float(d["t1"]), spliced["cuts"], ratio, false) + _elapsed
			_sub_words.append(d)
		_chunk_at[idx] = _pushed + (_pending.size() - _read)
		# THE OUTRO MARK: the fade starts where the first chunk after it does
		if _fade_len > 0.0 and _fade_at < 0 and idx >= 0 and idx < _chunks.size() \
				and bool((_chunks[idx] as Dictionary).get("fade", false)):
			_fade_at = _pushed + (_pending.size() - _read)
		_pending.append_array(pcm)
		_elapsed += float(pcm.size()) / float(_sr)
		# ...and the reading ENDS where the fade does: the rest of this chunk, and every
		# chunk after it, is never heard
		if _fade_at >= 0 and not _fade_done:
			var end := _fade_at + int(_fade_len * float(_sr))
			var have := _pushed + (_pending.size() - _read)
			if have >= end:
				_pending.resize(_pending.size() - (have - end))
				_elapsed -= float(have - end) / float(_sr)
				_fade_done = true
				_outro_queued = true
				_chunks = _chunks.slice(0, _next_to_play)
		# THE OUTRO, after the last chunk: silence on the stream, the way the intro is silence
		# before the first and the export pads both ends. A stream that simply runs dry stops the
		# session clock with it, so the show froze on the last word instead of playing out the
		# outro ("it doesn't respect the 7.0 second outro I specified").
		if _next_to_play >= _chunks.size() and not _outro_queued:
			var outro := maxf(0.0, Director.outro_hold)
			if _fade_at >= 0:
				# the text ran out inside the fade: silence to the fade's end, no more
				var have := _pushed + (_pending.size() - _read)
				outro = maxf(0.0, float(_fade_at + int(_fade_len * float(_sr)) - have) / float(_sr))
				_fade_done = true
			var tail := PackedFloat32Array()
			tail.resize(int(outro * float(_sr)))
			_pending.append_array(tail)
			_elapsed += outro
			_outro_queued = true
		_set_status("Chunk %d of %d - %.0fs of audio ready."
			% [_next_to_play, _chunks.size(), _elapsed])
		# HOLD THE FIRST SAMPLE UNTIL THERE IS A LEAD. Chunks are one sentence each
		# (CHUNK_SENTENCES = 1), and sentence lengths are wildly uneven: measured on
		# chapter 3, the opening sentence renders to 1.13 s and the next to 14.49 s. The
		# stream used to open on whatever the first chunk happened to be, so playback
		# drained that 1.13 s and then starved for as long as the 14.49 s sentence took
		# to synthesize. Nothing was wrong with the audio - no chunk carries more than
		# 0.27 s of internal silence - it simply ran out.
		#
		# So wait for a real lead before starting. The intro doubles as that lead, which
		# is why this is one condition and not two, and the floor covers the case where
		# the intro is turned off entirely. Once open it stays open: the drain is
		# continuous from here and a mid-reading stall is the pump's business, not this.
		if not _stream_open:
			var have := float(_pending.size() - _read) / float(_sr)
			var lead := maxf(_lead_in, LIVE_PREROLL)
			if have < lead and _next_to_play < _chunks.size():
				continue          # keep accumulating; nothing is lost, it is all queued
			# same text, same music: the pad's note choices are seeded
			_fx.pad_seed = hash(_fingerprint_text())
			_fx.setup(_sr)
			# every dial onto the fresh chain, in one call - the preset's own nudge
			# to the bed included: a mood is carried by the room as much as by the
			# reading. The opening voice's, not the tab on screen's.
			_fx_live_name = String((_fx_marks[0] as Dictionary).get("speaker", who)) \
				if not _fx_marks.is_empty() else who
			Delivery.apply_fx(_fx, _cfg_of(_fx_live_name))
			# the session opens on the FIRST chunk and never again - that is the
			# whole point: one unbroken take, so the Director does not re-cut
			# and the harmonic seed does not re-derive every few sentences
			_stream_open = true
			if begin_stream.is_valid():
				_playback = begin_stream.call(hash(_fingerprint_text()), _sr, _sub_words)
			# the place opens with the stream: its first sample is the stream's first, at the show
			# time the stream's frame 0 is heard at
			_open_environment(Spectrum.stream_origin())
			# NO SCRUB HOOKS HERE. Seeking a live generator was implemented and is
			# WITHDRAWN - see the note above _seek_take.
			# MEASURE the ring, do not compute it. Godot sizes a generator's
			# buffer to a power of two (131071 frames measured), not to
			# STREAM_BUFFER * sample_rate (88200) - so the computed figure made
			# `queued` NEGATIVE, `played` start ~1.9 s ahead, and the subtitles
			# open in the middle of the text. An empty ring reports its whole
			# capacity as available, and it is empty exactly here, before the
			# first push.
			if _playback != null:
				_ring_capacity = int(_playback.get_frames_available())


## SEEKING A LIVE GENERATOR IS WITHDRAWN, and this note is the record of why.
##
## It was built, it worked in the sense that the playhead moved, and it was wrong in two
## ways that only showed up in use. A generator's ring cannot be cleared while playback is
## active, so every seek had to stop and restart the stream - and repeated restarts left
## the session audibly wrong, the voice doubling and then trebling as more seeks were made,
## with the Director's transitions stalling alongside it. Neither reproduced in a headless
## measurement (a freshly synthesized take autocorrelates clean, with no delayed copy), and
## guessing further at engine-side playback state without being able to run the UI is how
## the first two attempts at this shipped.
##
## The deeper problem is that it could not have served its purpose anyway. The reason to
## scrub is to check what a given moment WILL LOOK LIKE when exported - and a seek cannot
## answer that here, because the Director is a simulation rather than a function of time:
## its scene choice and hold schedule evolve from the events it has actually seen, so
## seeking forward shows the scene that happens to be up rather than the one the export
## will have. A control that answers a different question from the one being asked is worse
## than no control.
##
## What DOES answer it: render the take, then open the rendered file. A file boot is
## seekable for real (one operation, no restart - see Spectrum.seek) and replays the same
## deterministic show from the same seed, so scrubbing it shows exactly what the export
## will contain. `--scene <name>` remains the fastest way to inspect one scene.

## Re-generate everything not yet committed to the stream, at the new pace.
##
## Audio already pushed - and audio decoded and waiting in _pending - is
## finished business: its subtitles are placed and _elapsed has advanced past
## it, so rewriting it would desync the overlay. Everything from the next
## un-drained chunk onward is thrown away and re-requested, so the new pace
## lands within a chunk or two rather than at the end of the chapter.
func _repace() -> void:
	if _chunks.is_empty() or _next_to_play >= _chunks.size():
		return
	_epoch += 1                     # in-flight replies from the old pace are now stale
	_ready_takes.clear()
	# Same reasoning as _jump_to_chunk: the host keeps computing what it was given, so the
	# accounting for it has to survive or the pump will pile more on top.
	_next_to_request = _next_to_play
	_set_status("%s at pace %.2fx, pause %.2fx - regenerating from chunk %d…"
		% [_tab_name(), _rate.value, clampf(_pause.value, 0.0, Delivery.MAX_PAUSE_SCALE), _next_to_play + 1])
	_pump()




# --- export ------------------------------------------------------------------


## What an export of this reading is called, without an extension; "" keeps the exporter's own
## name (see [member Exporter.name_provider]). The reading's [member publish] says.
func export_name() -> String:
	return publish.name()


## What an upload of the take at [param take] says (see [member Exporter.upload_provider]): the
## YouTube card's title, visibility and playlist over what [member publish] adds; {} without a
## card, or with its box clear.
func upload_meta(take: String) -> Dictionary:
	return _youtube.meta(publish.upload_base(take)) if _youtube != null else {}


## Gate for the export button. The procedural path asks whether a seed has been
## caught; here the only requirements are text and a loaded voice.
func can_export_take() -> bool:
	return _has_reading() \
		and not _voice_meta.is_empty() and _host != null and _host.is_up()


## Render the WHOLE text to one WAV, independent of whatever is playing - with what the take is of
## held by [member publish] while it renders, and what goes with it written after.
func export_take() -> String:
	if not publish.before_take():
		return ""
	var path: String = await _render_take()
	var said := publish.after_take(path)
	if not said.is_empty():
		_set_status(said)
	return path


## A coroutine, because the host answers asynchronously and the exporter awaits
## this. It deliberately does NOT reuse the playback queue: export must capture
## the entire reading including the part not yet spoken, and must not disturb a
## reading in progress.
func _render_take() -> String:
	var body := _reading_body().strip_edges()
	if body.is_empty() or _voices.selected < 0:
		return ""
	_refresh_cast(body)
	var chunks := _build_chunks(body)
	if chunks.is_empty():
		return ""
	var stamp := Time.get_ticks_msec()
	var pcm := PackedFloat32Array()
	var words: Array = []
	var elapsed := 0.0
	# Where the reading changes voice, in frames of the finished take - the
	# export's copy of [member _fx_marks], for the same reason and applied the
	# same way at the bottom of this function.
	var marks: Array = []
	var last_who := ""
	var last_near := {}
	_plan_near(chunks, 0)

	var fade_start := -1          # the outro mark's fade, as a sample of the reading (-1: none)
	for i in chunks.size():
		_set_status("Rendering for export: %d of %d…" % [i + 1, chunks.size()])
		# The SAME arguments the preview used, from the SAME builder. An export
		# that re-derived its own would be a different performance from the one
		# that was auditioned, which is the one thing the render must never be.
		var who := String((chunks[i] as Dictionary).get("speaker", ""))
		var s := _cfg_of(who)
		var ratio := 1.0  # the host has played the Tone back already - see _drain_ready
		var id := _host.request("", _voice_id_of(s),
			TAKE_DIR + "/export_%d_%d.wav" % [stamp, i], _request_args(s, chunks[i]), null)
		var res: Array = []
		while true:
			res = await _host.synthesized
			if int(res[0]) == id:
				break
		var out: Dictionary = res[1]
		var wav := String(out.get("wav", ""))
		if wav.is_empty():
			continue
		var part := Splice.read_wav(wav)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(wav))
		# The same splice the live window makes, from the same function.
		var spliced := Splice.chunk(part, (chunks[i] as Dictionary).get("holds", []),
			out.get("tokens", []), ratio, _sr)
		part = spliced["pcm"]
		# the reader moves in the pause before the sentence, as in _drain_ready
		var near: Dictionary = (chunks[i] as Dictionary).get("near", {})
		if not marks.is_empty():
			Delivery.near_mark(marks, near, pcm.size(), last_near)
		if i > 0:
			var seam := _gap_before(chunks, i, s)
			var gap := PackedFloat32Array()
			gap.resize(int(seam * float(_sr)))
			pcm.append_array(gap)
			elapsed += seam
		# after the gap, for the reason spelled out in _drain_ready
		var opening := marks.is_empty()
		if opening or who != last_who:
			last_who = who
			marks.append({"at": pcm.size(), "speaker": who})
		if opening:
			Delivery.near_mark(marks, near, pcm.size(), last_near)
		var by_index := {}
		for sp in out.get("tokens", []):
			by_index[int((sp as Dictionary).get("index", -1))] = sp
		var rows: Array = []
		for w in chunks[i]["words"]:
			var span: Variant = by_index.get(int(w["index"]))
			var tail: Variant = by_index.get(int(w.get("end", w["index"])))
			if tail == null:
				tail = span
			rows.append({"text": String(w["text"]), "sentence": int(w["sentence"]),
				"emph": int(w.get("emph", 0)), "speaker": who,
				"t0": 0.0 if span == null else
					Splice.shifted(float((span as Dictionary).get("t0", 0.0)), spliced["cuts"], ratio, true)
					+ elapsed,
				"t1": 0.0 if tail == null else
					Splice.shifted(float((tail as Dictionary).get("t1", 0.0)), spliced["cuts"], ratio, false)
					+ elapsed,
				"ok": span != null})
		words.append_array(_bridge_words(rows, "export chunk %d" % i))
		if fade_start < 0 and bool((chunks[i] as Dictionary).get("fade", false)):
			fade_start = pcm.size()
		pcm.append_array(part)
		elapsed += float(part.size()) / float(_sr)

	if pcm.is_empty():
		return ""
	# THE BOOKEND, written into the take itself. Held silence at the head and tail of the
	# render, so the video opens and closes on something rather than starting mid-word.
	#
	# It goes in HERE, before the effects chain, and that ordering is the entire point.
	# VoiceFX is a filter, not a source: given real samples to write into, the ambience
	# pad - which is an independent instrument on its own clock, unlike the resonance,
	# which can only ring when the voice excites it - swells through the intro and decays
	# through the outro. Pad the PCM afterwards and both ends are digital silence.
	var intro := maxf(0.0, Director.intro_hold)
	var outro := maxf(0.0, Director.outro_hold)
	# THE OUTRO MARK: the reading ends where its fade does - cut there (or filled out with
	# silence, if the text ran out first) - and the fade IS the outro, so none is added after
	var fade_n := int(_fade_len * float(_sr))
	if fade_start >= 0:
		pcm.resize(fade_start + fade_n)
		var cut := float(fade_start + fade_n) / float(_sr)
		var heard: Array = []
		for w in words:
			if float((w as Dictionary).get("t0", 0.0)) < cut:
				heard.append(w)
		words = heard
		outro = _fade_len
	var pad_out := 0.0 if fade_start >= 0 else outro
	if intro > 0.0 or pad_out > 0.0:
		var padded := PackedFloat32Array()
		padded.resize(int(intro * float(_sr)) + pcm.size() + int(pad_out * float(_sr)))
		var head := int(intro * float(_sr))
		for i in pcm.size():
			padded[head + i] = pcm[i]
		pcm = padded

	# the ambience the user has been listening to belongs in the render, so the
	# export matches the audition - a fresh chain, since the live one is
	# mid-reading and carries its own tails
	var fx := VoiceFX.new()
	fx.pad_seed = hash(body)
	fx.setup(_sr)
	# SEED THE KEY, or the intro is silent anyway. The pad picks its tonic from the
	# tracked pitch of the voice, and the tracker returns 0 on silence - so during a
	# leading pad of pure zeros `_tonic` never rises off 0, `_start_tone` refuses to
	# schedule anything, and the bed only begins once the narration has already started,
	# which is precisely backwards. Measuring the voice FIRST and handing the chain its
	# key up front is what lets the bed be playing before the first word.
	if intro > 0.0:
		fx.prime_key(pcm)
	# ONE CHAIN, RE-DIALED per passage - never one chain per voice. The effects
	# are stateful, so a second chain would start each speaker in a dead room and
	# cut the previous one's tail off at the change; re-dialing shares the decay
	# across the join, which is what a room in the world does when the person
	# talking in it changes.
	if marks.is_empty():
		marks = [{"at": 0, "speaker": ""}]
	var head := int(intro * float(_sr))
	for m in marks:
		(m as Dictionary)["at"] = int((m as Dictionary)["at"]) + head
	(marks[0] as Dictionary)["at"] = 0        # the first voice owns the intro
	# STEREO ONLY WHEN SOMEBODY LEANS: a take where nobody moves is the same mono file it
	# always was, at half the size.
	var leans := false
	var wet := PackedVector2Array()
	var cfg: Dictionary = _cfg_of(String((marks[0] as Dictionary)["speaker"]))
	for k in marks.size():
		var m: Dictionary = marks[k]
		# every mark is applied, even one with no audio before the next: a distance and a
		# voice can change at the same frame
		if m.has("speaker"):
			cfg = _cfg_of(String(m["speaker"]))
			leans = leans or float(cfg["lean"]) > 0.0
			Delivery.apply_fx(fx, cfg)
		if m.has("near"):
			Delivery.near_to(fx, m["near"])
		var a := int(m["at"])
		var b := pcm.size() if k == marks.size() - 1 else int((marks[k + 1] as Dictionary)["at"])
		if b > a:
			wet.append_array(fx.process_stereo(pcm.slice(a, b)))
	# THE PLACE, under the whole take - its first sample at show time 0, since the take carries its own
	# bookend - so the export hears the gusts the render shows. Rendered on a worker: minutes of take are
	# a long while of GDScript, and the panel stays live through an export.
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
	# ...faded AFTER the effects, so the room and the ambience bed go down with the voice
	if fade_start >= 0:
		var f0 := head + fade_start
		for i in range(f0, wet.size()):
			var u := float(i - f0) / maxf(1.0, float(fade_n))
			wet[i] *= 0.0 if u >= 1.0 else 0.5 + 0.5 * cos(PI * u)

	var path := TAKE_DIR + "/take_%d.wav" % stamp
	var abs_path := Splice.write_wav(path, wet, 2 if leans else 1, _sr)
	# ALWAYS written now, words or not: the book medium reads the chapter from it.
	var side := FileAccess.open(path.get_basename() + ".json", FileAccess.WRITE)
	if side != null:
		# Word timings shift with the audio they describe. Doing it here, once,
		# keeps every consumer honest: the karaoke overlay, the live session and
		# the export render all read this file and none of them needs to know a
		# bookend exists.
		var shifted: Array = []
		for w in words:
			var d: Dictionary = (w as Dictionary).duplicate()
			d["t0"] = float(d.get("t0", 0.0)) + intro
			d["t1"] = float(d.get("t1", 0.0)) + intro
			shifted.append(d)
		# THE BOOK rides along: a render has no editor, and a medium that typesets
		# pages needs the chapter those words came from (see BookMedium).
		side.store_string(JSON.stringify({
			"words": shifted, "bookend": {"in": intro, "out": outro},
			"book": book_document(body)}))
		side.close()
	_set_status("Rendered %.1fs for export (%.0fs intro, %.0fs outro)." % [elapsed, intro, outro])
	return abs_path




# --- subtitles ----------------------------------------------------------------


## KEEP EVERY WORD, even one the aligner had no span for.
##
## Both paths below used to `continue` past a word whose token the host did not return a span
## for, which deletes it from the karaoke line without a word anywhere about it. That is how a
## chapter render came back reading "an opponent who left the building in" with the year simply
## absent (the root cause was upstream - see TextNorm._expand_numbers - but this is what made it
## SILENT, and it would hide the next one just as well).
##
## A word with no span keeps its text and takes a timing interpolated across the gap between its
## nearest aligned neighbors, so the line reads correctly and the highlight sweeps through it at
## a plausible rate. The count is reported once per take, because an aligner that misses words is
## a real fault worth seeing in the log even when the subtitle no longer loses them.
static func _bridge_words(rows: Array, label: String) -> Array:
	var missing := 0
	var n := rows.size()
	for i in n:
		if bool((rows[i] as Dictionary)["ok"]):
			continue
		missing += 1
		# The aligned neighbors either side, and how many unaligned words share the gap.
		var lo := i - 1
		while lo >= 0 and not bool((rows[lo] as Dictionary)["ok"]):
			lo -= 1
		var hi := i + 1
		while hi < n and not bool((rows[hi] as Dictionary)["ok"]):
			hi += 1
		var t0: float = float((rows[lo] as Dictionary)["t1"]) if lo >= 0 else 0.0
		var t1: float = float((rows[hi] as Dictionary)["t0"]) if hi < n else t0 + 0.25
		if t1 <= t0:
			t1 = t0 + 0.25
		var run := float(maxi(1, (hi if hi < n else n) - (lo + 1)))
		var k := float(i - (lo + 1))
		var step := (t1 - t0) / run
		var row: Dictionary = rows[i]
		row["t0"] = t0 + step * k
		row["t1"] = t0 + step * (k + 1.0)
	if missing > 0:
		push_warning("ghost/voice: %s - the aligner returned no span for %d of %d words; "
			% [label, missing, n] + "their subtitle timing is interpolated (text is intact)")
	var out: Array = []
	for r in rows:
		var d: Dictionary = r
		out.append({"text": d["text"], "sentence": d["sentence"], "t0": d["t0"], "t1": d["t1"],
			"emph": int(d.get("emph", 0)), "speaker": String(d.get("speaker", ""))})
	return out


## Rebuild word timings from the per-phone durations the model returned.
##
## The backend hands back one entry per phone we sent, in order, so the word
## spans recorded at plan time index straight into it. This is what restores the
## karaoke overlay: main._attach_subtitles picks up any take that has a sidecar,
## so the neural path gets subtitles with no special casing anywhere.
func _words_for(idx: int, spans: Array) -> Array:
	if idx < 0 or idx >= _chunks.size() or spans.is_empty():
		return []
	var by_index := {}
	for s in spans:
		by_index[int((s as Dictionary).get("index", -1))] = s
	var rows: Array = []
	# WHO SAYS IT rides with each word: the subtitles color each voice its own way
	var who := String((_chunks[idx] as Dictionary).get("speaker", ""))
	for w in _chunks[idx]["words"]:
		var span: Variant = by_index.get(int(w["index"]))
		# A run's card is up from its first word to its LAST - `end` is that word
		# when the entry covers a rewritten run, and the entry's own word when it
		# does not.
		var tail: Variant = by_index.get(int(w.get("end", w["index"])))
		if tail == null:
			tail = span
		rows.append({"text": String(w["text"]), "sentence": int(w["sentence"]),
			"emph": int(w.get("emph", 0)), "speaker": who,
			"t0": 0.0 if span == null else float((span as Dictionary).get("t0", 0.0)),
			"t1": 0.0 if tail == null else float((tail as Dictionary).get("t1", 0.0)),
			"ok": span != null})
	return _bridge_words(rows, "chunk %d" % idx)

