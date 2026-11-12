extends Node2D

## ghost entry point.
##
## Almost nothing lives here on purpose: the audio is owned by [Spectrum] and the
## visuals by [Director]. main owns the *session lifecycle* - showing the notes list,
## opening a note in the workspace its components name ([method Components.workspace_of]),
## and tearing it back down to the list (the ⌂) - and maps the global keys. Scenes are added
## as children here.

const Bake := preload("res://src/audio/bake.gd")

## How long the show clock may stand still in a render before it is reported, in seconds of render time.
const CLOCK_STALL_WARN := 0.5

var _list: Node = null               # the notes list, while no note is open (step 8)
var _note_panel: Node = null         # a note with nothing attached (NotePanel)
var _note := ""                      # the note open now, "" on the list
var _feedback: Node = null
var _chrome: Node = null             # shared session furniture (exporter/assistant/feedback)
var _mask_editor: Node = null
var _synth_editor: Node = null
var _synth_active := false           # a synth take is playing as the session
var _generative: Node = null         # the generative editor, when that mode is up
var _stream: Node = null             # the live VoiceStream feeding the session
var _subtitles: Node = null          # karaoke overlay, present when the audio has a sidecar
var _status_t := 0.0     # throttle for writing render progress (export mode)

# The stage: scenes render in a SubViewport shown through a TextureRect under the UI, so the governor
# can run the stage every 2nd, 3rd or 6th frame while the UI composites at full rate. Export mode
# bypasses the governor. Its pixel size is the Graphics menu's Resolution row (_sync_stage_size): the
# frame in canvas units unless chosen, 1920 x 1080 at any window.
var _stage: SubViewport = null
var _stage_view: TextureRect = null
# What the show is carried on (medium.gd). Mounted inside the stage, so the governor stops the medium
# and every panel viewport nested under it together. Persists across a note's takes (rebuilding it per
# take would discard the page and its render targets); `_clear_stage` removes it with the note.
var _medium: Medium = null
# The governor (stage_governor.gd) reads this thread's own time on a frame the stage ran in, from the
# frame's first `_process` (_frame_begins) to the moment it is handed to the renderer (_frame_handed),
# never the whole frame's time (which includes the graphics card and the display).
var _governor := StageGovernor.new()
var _frame_began := 0                # ticks (usec) as this frame's processing began
var _frame_own_ms := 0.0             # what the last frame cost this thread, until the renderer took it
var _slow_said := false              # slow frames this thread is not behind: said once a scene
var _slow_t := -1.0                  # seconds the stage's time on the card has been measured for that, -1 when not

# Export render mode: the exporter relaunched this instance in Movie Maker mode (--export). It runs
# the session with no overlays and quits when the song ends.
var _export_mode := false
var _filter_said := ""               # last look printed, so a resize does not repeat it
## --until <seconds>: stop there. 0 means "the whole thing".
var _until := 0.0
## Whether to report a stalled show clock. On for every render; a plain session can ask with `--clock-watch`
## (needs no encoder and runs at the speed of the audio).
var _clock_watch := false
# The render clock watch. Every scene and the karaoke line are driven by `Spectrum.current.time` while a
# render writes one video frame per engine iteration; if that clock stops while iterations continue, the
# output holds a still while the audio plays on. Export only: a live session drops frames for ordinary
# reasons and would only produce noise.
var _clock_t := -1.0
var _clock_stuck := 0.0
var _clock_frames := 0

func _ready() -> void:
	#window-close runs _shutdown (see _notification): the WM close button must run our teardown
	get_tree().set_auto_accept_quit(false)
	var args := OS.get_cmdline_user_args()
	if args.has("--apply-update"):
		get_tree().quit(AppUpdate.run_helper(args))
		return
	if args.has("--update-smoke-hold"):
		await get_tree().create_timer(3.0).timeout
		get_tree().quit()
		return
	if args.has("--app-version"):
		print(JSON.stringify(AppUpdate.build_info()))
		get_tree().quit()
		return
	#Export templates ignore --script, so the exported app enters its offline analyzer through the main
	#scene; the editor uses bake_runner.gd.
	if args.has("--bake-song"):
		get_tree().quit(SpectrumBake.run_cli(args))
		return
	if args.has("--export-smoke"):
		var note_path := _arg_value(args, "--export-smoke-note")
		if not note_path.is_empty():
			var raw := FileAccess.get_file_as_string(note_path)
			var block := FrontMatter.read_block(raw)
			if raw.is_empty() or not block.ok or not Components.attached_of(block.data).has("table"):
				printerr("ghost/export-smoke: could not recognize a Table note: ", note_path,
					" (", block.error, ")")
				get_tree().quit(1)
				return
		var paths := ["res://hosts/voice/host.py", "res://hosts/voice/requirements.txt",
			"res://hosts/capture/capture.py", "res://hosts/face/face_track.py"]
		for path in paths:
			if BundledHosts.path(path).is_empty():
				printerr("ghost/export-smoke: missing ", path)
				get_tree().quit(1)
				return
		for face in CardTable.FACES:
			if CardTable.font(String(face)) == ThemeDB.fallback_font:
				printerr("ghost/export-smoke: missing card font ", face)
				get_tree().quit(1)
				return
		for path in [CardTable.BOOK_FACE, CardTable.BOOK_ITALIC]:
			if CardTable.font(path) == ThemeDB.fallback_font:
				printerr("ghost/export-smoke: missing card font ", path)
				get_tree().quit(1)
				return
		var feedback_probe := FeedbackConsole.new()
		var feedback_dir := feedback_probe.dir
		feedback_probe.free()
		if Boot.project_dir() != OS.get_executable_path().get_base_dir() \
				or not Boot.project_args().is_empty() \
				or feedback_dir != "user://feedback" \
				or MaskEditor._masks_dir() != "user://masks":
			printerr("ghost/export-smoke: exported paths are not physical/user data paths")
			get_tree().quit(1)
			return
		print("ghost/export-smoke: PASS")
		get_tree().quit(0)
		return
	#`--deps` is handled before everything else so it needs no mode, window or audio device. Pairs with
	#`--headless`; exits non-zero when something a feature needs is missing.
	if args.has("--deps"):
		var rows := Deps.report()
		print(Deps.format_report(rows))
		get_tree().quit(0 if Deps.verdict(rows).is_empty() else 1)
		return
	#`--provision [all|update]`: install ghost's own dependencies now, printing each step (the jobs an
	#ordinary launch runs in the background). Exits non-zero if anything asked for could not be had.
	if args.has("--provision"):
		_provision(_arg_value(args, "--provision"))
		return
	#`--episode-check <dir>`: print what is wrong with an episode as it stands, then exit; non-zero when
	#anything is (next/editing.md).
	if args.has("--episode-check"):
		var said := TableEpisode.at_dir(_arg_value(args, "--episode-check")).problems()
		for p in said:
			print("ghost: episode - " + p)
		print("ghost: episode - %s" % ("nothing wrong" if said.is_empty() else "%d problem(s)" % said.size()))
		get_tree().quit(0 if said.is_empty() else 1)
		return
	if args.has("--showcase-now"):
		add_child(Showcase.new())
		return
	#The phone shell (next/notes.md): on a phone, or with --handheld, only the notes list and editor - no
	#stage, transport, furniture or agent.
	if Boot.handheld():
		add_child(preload("res://src/app/phone_shell.gd").new())
		return
	#Mask mode is a standalone authoring tool (see mask_editor.gd) tied to one clip, not the audio-reactive
	#show: it does not touch the Director (a live editor conducts only the transport) and is checked
	#before everything else.
	if args.has("--mask-render"):
		_begin_mask_render(_arg_value(args, "--mask-render"))
		return
	_export_mode = args.has("--export")
	if not _arg_value(args, "--until").is_empty():
		_until = float(_arg_value(args, "--until"))
	_clock_watch = _export_mode or args.has("--clock-watch")
	if _export_mode:
		#Boot (first autoload) already hid the window, and the exporter's override.cfg set the output
		#resolution and stretch mode at engine startup (Movie Maker locks resolution before any script
		#runs). Run clean and quit when the song ends.
		Spectrum.song_finished.connect(func(): get_tree().quit())
		_begin_session()
		#`--from <seconds>`: render only a stretch from there (Stitch puts it back into the earlier export)
		var from := float(_arg_value(args, "--from")) if not _arg_value(args, "--from").is_empty() else 0.0
		if from > 0.0 and Spectrum.has_audio():
			Spectrum.render_from(from)
			Director.seek_show(from)
			print("ghost export: rendering from %.2fs" % from)
		#A render with no audio has no end (song_finished never fires), so report a failure and exit
		#non-zero instead of recording silence forever.
		if not Spectrum.has_audio():
			printerr("ghost: EXPORT ABORTED - the audio did not load (%s)" %
				_arg_value(args, "--audio"))
			get_tree().quit(1)
			return
		#With this flag the Synthesis panel opens over the take and plays itself (see synth_editor.gd's
			#autopilot), so the UI is in the video. It generates no audio and persists nothing.
		if args.has("--synth-autopilot"):
			_open_synth_autopilot()
		return
	#The live window stretches in "canvas_items" mode (project.godot): 2D rasterizes at the window's
	#native resolution while the coordinate system scales proportionally. (Export overrides this; see
	#_apply_export_resolution.)
	#The chrome is the shared session furniture (exporter, assistant, feedback console), created once
	#here for every interactive mode; it persists across sessions so an in-flight export and a queued
	#assistant dispatch survive the return to the home screen.
	_chrome = preload("res://src/app/chrome.gd").new()
	add_child(_chrome)
	#something docked under the show took, or gave back, part of the frame: the stage refits
	_chrome.stage_room_changed.connect(_sync_stage_size)
	if args.has("--showcase"):
		var rec := ShowcaseRecorder.new()
		rec.main = self
		rec.work = _arg_value(args, "--showcase")
		add_child(rec)
		return
	add_child(Showcase.new())
	Spectrum.song_finished.connect(_on_song_finished)
	_adopt_old_episodes()
	#each note's medium, moved once into its `medium:` block
	_adopt_old_media()
	#the demo note, made once on a machine (the phone shell returned above, so never on a phone)
	_seed_demo_note()
	if args.has("--mask-edit"):
		start_workspace("clip", _arg_value(args, "--mask-edit"))
		return
	if args.has("--synth"):
		start_workspace("lab")
		return
	# --table: straight into the Table workspace (its document is the one it last had open)
	if args.has("--table"):
		start_workspace("table")
		return
	# --note <path>: open one note, run by whatever its blocks say it is
	if args.has("--note"):
		open_note(_arg_value(args, "--note"))
		return
	if _wants_direct_boot():
		_begin_session()                 # CLI flags: straight into a song session
	else:
		_show_list()


# A CLI flag means "I know what I want" (authoring, automation, headless): boot straight into a song
# session, past the list, so the --audio/--scene/--storyboard flows and headless tests are unchanged.
func _wants_direct_boot() -> bool:
	var args := OS.get_cmdline_user_args()
	return args.has("--audio") or args.has("--scene") or args.has("--storyboard")


func _show_list() -> void:
	var list := preload("res://src/app/notes_list.gd").new()
	list.open_note = open_note
	_list = list
	_note = ""
	add_child(list)
	if _chrome != null and is_instance_valid(_chrome):
		_chrome.set_home(Callable())
		_chrome.set_note("")


## Moves the episodes' folder from `user://cards/` to [constant TableEpisode.ROOT] once (a rename in
## place, nothing copied). Never in a process that may not write the author's things, and never over a
## folder already there. Remove once it has run.
func _adopt_old_episodes() -> void:
	var old := ProjectSettings.globalize_path("user://cards")
	var now := ProjectSettings.globalize_path(TableEpisode.ROOT)
	if Settings.is_read_only() or TableEpisode.root != TableEpisode.ROOT \
			or not DirAccess.dir_exists_absolute(old) or DirAccess.dir_exists_absolute(now):
		return
	if DirAccess.rename_absolute(old, now) != OK:
		push_warning("ghost: could not move the episodes from %s to %s" % [old, now])
		return
	print("ghost: the episodes moved to %s" % now)


## Writes each note's `picture:`, `letter:` or `dispatch:` block as the one `medium:` block
## ([method Components.adopted_medium]). Never in a process that may not write the author's things;
## once per machine (`[notes] media_moved`; a note that would not write is tried again next launch).
## Remove once it has run.
func _adopt_old_media() -> void:
	if Settings.is_read_only() or NoteStore.root != NoteStore.DEFAULT \
			or bool(Settings.read(NoteStore.SECTION, "media_moved", false)):
		return
	var moved := 0
	for row in NoteStore.list():
		var path := String((row as Dictionary)["path"])
		var blocks := NoteStore.blocks_of(path)
		var now := Components.adopted_medium(blocks)
		if blocks.has("medium") or not now.has("medium"):
			continue
		var err := FrontMatter.write_block(path, now)
		if not err.is_empty():
			push_warning("ghost: could not move the medium of %s into its `medium:` block - %s" % [path.get_file(), err])
			return
		moved += 1
	Settings.write(NoteStore.SECTION, "media_moved", true)
	if moved > 0:
		print("ghost: %d note(s) keep their medium in a `medium:` block now" % moved)


## Makes the demo note once ([method Showcase.make_demo_note]: the README's prism, its storyboard the
## note's own to edit): once per machine (`[notes] demo_made`), so a deleted demo stays deleted; never
## in a process that may not write the author's things, nor under a notes folder moved aside.
func _seed_demo_note() -> void:
	if Settings.is_read_only() or NoteStore.root != NoteStore.DEFAULT \
			or bool(Settings.read(NoteStore.SECTION, "demo_made", false)):
		return
	var path := Showcase.make_demo_note()
	if path.is_empty():
		return
	Settings.write(NoteStore.SECTION, "demo_made", true)
	print("ghost: the demo note \"%s\" is in the notes list (%s)" % [Showcase.TITLE, path])


## Open a note: every note opens the same way. What it has attached is read off its blocks
## ([method Components.attached_of]), and the workspace those components name runs it
## ([method Components.workspace_of]) - its own panel, unless something attached is an editor of
## its own (a voice's reading, a show of cards, the voice lab, a clip). A workspace that reads the
## note's text is pointed at the note before it is built; a clip is the note's own block's path.
##
## Every note starts from nothing: the last note's stage went with it ([method _clear_stage]), the
## picture settings go back to their defaults ([method Director.reset_show]) for the note's blocks to
## set, and nothing plays until Play.
func open_note(path: String) -> void:
	if path.is_empty() or not FileAccess.file_exists(path):
		push_warning("ghost: there is no note at '%s'" % path)
		_show_list()
		return
	var blocks := NoteStore.blocks_of(path)
	var ws := Components.workspace_of(Components.attached_of(blocks))
	_note = path
	Director.reset_show()
	Films.set_frequency(Films.FREQ_DEFAULT)
	match ws:
		"reading", "table", "lab":
			var section := String((Components.WORKSPACES[ws] as Dictionary)["section"])
			Settings.write(section, "doc_path", path)
			Settings.write(section, "sync", true)
			start_workspace(ws, "", path)
		"clip":
			var clip: Variant = blocks.get("clip", {})
			start_workspace(ws, String((clip as Dictionary).get("path", "")) if clip is Dictionary else "", path)
		_:
			start_workspace(ws, "", path)


func reopen_note(path: String) -> void:
	_end_session(false)
	open_note(path)


## Open a file from disk as the note, from inside a note (its Script card's Open...). Like the list's
## "Existing note...": the file joins the list and opens through the one session path. Nothing is
## written into it, and the note left behind is left as it is. Returns "" once it is open, or why it
## could not be.
func open_file(path: String) -> String:
	var why := leave_blocker()
	if not why.is_empty():
		return why
	if not FileAccess.file_exists(path) or not NoteStore.add(path):
		return "There is no file at %s." % path
	_end_session(false)
	open_note(path.simplify_path())
	return ""


## The note open now was saved into another file (its Script card's Save...): [param to] is the note
## from here on - what "⋯" deletes, what the list shows and what opens next time. The panel has moved
## already ([signal DocSource.moved]). One note, one file: a note Ghost Notes kept in its own folder
## goes to the trash once the new file is written, a file added by hand leaves the list, and a file
## in an added folder stays listed with its folder; all of those are the author's files, left as they
## were. What was made for it, in folders named by its path (a letter's sketches, its steps' work), is
## moved to the new path's. Returns what became of [param from], as a sentence for the panel to say.
func note_moved(from: String, to: String) -> String:
	if _note.is_empty() or from.simplify_path() != _note.simplify_path() \
			or to.simplify_path() == from.simplify_path() or not FileAccess.file_exists(to):
		return ""
	_note = to
	NoteStore.add(to)
	if _chrome != null and is_instance_valid(_chrome):
		_chrome.set_note(_note, delete_note, open_file)
	var kept := ""
	var may := not Settings.is_read_only()
	for why in [LetterSketches.carry(from, to, may), NoteUpload.carry(from, to, may)]:
		if not String(why).is_empty():
			push_warning("ghost: " + String(why))
			kept += " " + String(why)
	if not FileAccess.file_exists(from):
		return kept.strip_edges()
	if NoteStore.is_own(from):
		var err := NoteStore.trash(from)
		if not err.is_empty():
			push_warning("ghost: " + err)
			return err + kept
		return "%s, which Ghost Notes was keeping for it, went to the trash.%s" % [from.get_file(), kept]
	if NoteStore.is_added(from):
		NoteStore.remove(from)
		return "%s is left as it was, and is off the list.%s" % [from.get_file(), kept]
	return "%s is left as it was.%s" % [from.get_file(), kept]


## Delete the note open now (its panel's "⋯", once asked - see [DeleteDialog]): it is left as the ⌂
## leaves it, its panel writing what it holds, then thrown away ([param answer] "trash") or let go of
## the list with its file kept ("forget"). The list comes back without it.
func delete_note(path: String, answer: String) -> void:
	if not leave_blocker().is_empty():
		return
	_end_session(false)
	var err := ""
	if answer == "trash":
		err = NoteStore.trash(path)
	elif answer == "forget":
		NoteStore.remove(path)
	if not err.is_empty():
		push_warning("ghost: " + err)
	_show_list()


## Start a workspace - a key of [constant Components.WORKSPACES] - through one path: every note
## opened, and the command line's `--synth`, `--table` and `--mask-edit`. [param source] is the clip
## (the `clip` workspace); [param note] the note it runs, "" from the command line. Builds the note's
## own panel, a panel that reads the text, or Masking's editor (which never touches the Director or
## Spectrum).
func start_workspace(key: String, source := "", note := "") -> void:
	match key:
		"note":
			if note.is_empty():
				push_warning("ghost: a note's own panel needs a note - open one with --note")
				return
			_open_note_panel(note)
		"reading", "table":
			_open_reading(key)
		"lab":
			_open_synth_editor()
		"clip":
			_open_mask_editor(source, note)
		_:
			push_warning("ghost: there is no workspace '%s'" % key)


func _open_note_panel(path: String) -> void:
	var panel: Node = preload("res://src/app/note_panel.gd").new()
	panel.path = path
	panel.reopen = reopen_note
	panel.note_moved = note_moved
	panel.begin_song = _begin_song
	panel.restage = _restage
	_note_panel = panel
	add_child(panel)
	# a song note's export goes up as its YouTube card says (nothing without one)
	if _chrome.exporter != null:
		_chrome.exporter.upload_provider = panel.upload_meta
		_chrome.exporter.show_provider = panel.show_plan
	_feedback = _chrome.attach_feedback()
	_entered_mode()


## A note's song, loaded and waiting at its start (a note opens stopped; the transport plays it).
## [param show] is what the note's cards say of its picture ([method _attach_show]); without a Medium
## the song plays to an empty frame.
func _begin_song(path: String, show: Dictionary) -> void:
	Spectrum.lead_in = Director.intro_hold
	Spectrum.tail = Director.outro_hold
	Spectrum.begin(path)
	if not Spectrum.has_audio():
		return
	Spectrum.transport_stop()
	_attach_show(show)
	_attach_subtitles()


## Put a note's show up as its components describe it - one path for a song's and a reading's.
## [param show]: `picture` (the note has one: the Director cuts scenes on the sound; without it there
## is no stage), `board` (the storyboard it walks, in its loaded form; {} where nothing is written and
## the seed chooses) and `source` (the file a render can load that board from, "" for one the note
## keeps itself).
func _attach_show(show: Dictionary) -> void:
	if not bool(show.get("picture", false)):
		return
	var board: Variant = show.get("board", {})
	if board is Dictionary and not (board as Dictionary).is_empty():
		Director.load_board(board as Dictionary, String(show.get("source", "")))
	Director.attach(_stage_host(), _medium)


func _restage(show: Dictionary) -> void:
	if not Director.is_attached():
		return
	Director.detach()
	_attach_show(show)


func _begin_session(audio_path := "") -> void:
	#The bookend is decided before the first sample, since Spectrum.begin starts playback. Whether the
	#silence is held here or already baked into the audio is resolved inside begin(), which knows which
	#file got loaded.
	Spectrum.lead_in = Director.intro_hold
	Spectrum.tail = Director.outro_hold
	Spectrum.begin(audio_path)
	Director.attach(_stage_host(), _medium)
	_attach_subtitles()
	if _export_mode:
		#The view the show is laid out in, said once for the render's log: Movie Maker records a picture of
		#the viewport's size, so where the window's shape differs only the middle of a wider view is kept
		#(next/notes.md, "the trap"). portrait_render_check reads it.
		var view := get_viewport().get_visible_rect().size
		print("ghost export: view %dx%d, frame %s" % [view.x, view.y, Director.resolved_frame()])
		return                         # render clean: no overlays (the Director fades the video ends)
	_feedback = _chrome.attach_feedback()   # press ` to critique a scene
	_entered_mode()


# The song ended. Manual mode loops: restart the audio in place and keep the show running (the
# Director's walk, the storyboard's tail and the dial's modulations carry across). Whether the sequence
# replays is the board's own `loop` field. Auto stops at the end and stays in its note.
func _on_song_finished() -> void:
	#A synth take is endless like a manual session: loop the narration in place.
	if _synth_active:
		Spectrum.replay()
		print("ghost: take looped (synthesis session continues)")
		return
	#A reading's kept take ends as a reading does: over, the stage left as it is, Play from the top
	if _generative != null and is_instance_valid(_generative) and _generative.has_method("take_playing") \
			and _generative.take_playing():
		_generative.take_ended()
		return
	if Director.is_manual():
		Spectrum.replay()
		print("ghost: song looped (manual session continues)")
		return
	#A song that ends leaves the note open and the transport waiting at the start.
	Spectrum.transport_stop()


func leave_mode() -> String:
	var why := leave_blocker()
	if not why.is_empty():
		return why
	_end_session()
	return ""


## Why the mode up now cannot be left this moment, or "" when it can: an export making its take from
## this mode (the take is a coroutine on the mode's panel; the export would wait on a freed panel
## forever), or the mode's own say (`leave_blocker()`: Masking while it exports).
func leave_blocker() -> String:
	if _chrome != null and is_instance_valid(_chrome) and _chrome.exporter != null \
			and _chrome.exporter.preparing():
		return "An export is rendering this mode's take - leave once the render has started."
	for n in [_mask_editor, _synth_editor, _note_panel]:
		if n != null and is_instance_valid(n) and n.has_method("leave_blocker"):
			var w := String(n.leave_blocker())
			if not w.is_empty():
				return w
	return ""


func _entered_mode() -> void:
	if _chrome != null and is_instance_valid(_chrome):
		_chrome.set_home(leave_mode, leave_blocker)
		_chrome.set_note(_note, delete_note if not _note.is_empty() else Callable(),
			open_file if not _note.is_empty() else Callable())


## Tear the session down and return to the notes list - the one teardown for every mode: the ⌂, and a
## note reopened as what a component attached to it made it ([param home] false). Every mode's nodes
## are freed (their `_exit_tree` saves and lets go of what they hold), the streams end, the Director is
## detached (which drops a storyboard), Spectrum stops and the stage is wiped. The persistent exporter
## is not freed (a render in progress and its status carry across), but what it asked of the mode is
## cleared.
func _end_session(home := true) -> void:
	#If the song ends while the feedback console is open and being typed in, defer the whole teardown
	#until they submit or cancel; the held scene stays frozen behind the modal.
	#The shell's console, whoever asked for it: Masking attaches it itself ([method
	#Shell.attach_feedback]), so the handle kept here is not the only way one comes to be open.
	var fb: Node = _chrome.feedback if _chrome != null and is_instance_valid(_chrome) else _feedback
	if fb != null and is_instance_valid(fb) and fb.is_open():
		if not fb.closed.is_connected(_end_session):
			fb.closed.connect(_end_session.bind(home), CONNECT_ONE_SHOT)
		return
	for n in [_list, _subtitles, _synth_editor, _mask_editor, _stream, _note_panel]:
		if n != null and is_instance_valid(n):
			n.queue_free()
	_chrome.detach_feedback()
	_feedback = null
	_subtitles = null
	_synth_editor = null
	_generative = null
	_mask_editor = null
	_stream = null
	_note_panel = null
	_list = null
	_synth_active = false
	_release_exporter()
	Director.set_game_paced(false)
	Director.set_aura(0.0)
	Director.detach()
	Spectrum.stop()
	_clear_stage()
	if home:
		_show_list()


## Wipe the stage: the medium a note was shown in goes with the note, and the stage is hidden until a
## show attaches again.
func _clear_stage() -> void:
	Director.medium_override = ""
	if _medium != null and is_instance_valid(_medium):
		_medium.release()
		_medium.queue_free()
	_medium = null
	_hide_stage()


## Nothing is showing: no picture on the stage until a show attaches ([method _stage_host]).
func _hide_stage() -> void:
	if _stage_view != null and is_instance_valid(_stage_view):
		_stage_view.visible = false


## The exporter as a session with no mode has it: the take, the name and the upload it asked of
## the mode go with the mode. An export already rendering carries on - it is Chrome's.
func _release_exporter() -> void:
	if _chrome == null or not is_instance_valid(_chrome) or _chrome.exporter == null:
		return
	var ex: Node = _chrome.exporter
	ex.take_provider = Callable()
	ex.take_first = false
	ex.take_ready = Callable()
	ex.name_provider = Callable()
	ex.upload_provider = Callable()
	ex.show_provider = Callable()
	ex.automation_available = false


## The stage the Director attaches scenes to (created on first session): a SubViewport with its own 3D
## world, shown through a TextureRect at child index 0, with all UI above it in the root viewport so
## the instrument stays responsive when a scene gets heavy.
func _stage_host() -> Node:
	if _stage != null:
		_sync_medium()
		_stage_view.visible = true
		return _stage
	_stage = SubViewport.new()
	_stage.own_world_3d = true
	_stage.transparent_bg = false
	_stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_stage)
	#How finely it is drawn (see graphics.gd), the live viewer's choice or an export's - set before a
	#medium is mounted, since a light takes its shadow's width from the filter's quality
	Graphics.bind_stage(_stage, _sync_stage_size)
	_stage_view = TextureRect.new()
	_stage_view.texture = _stage.get_texture()
	_stage_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_stage_view.stretch_mode = TextureRect.STRETCH_SCALE
	#the backdrop must never eat input: a fullscreen Control's default MOUSE_FILTER_STOP swallows clicks
	#that miss a panel
	_stage_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage_view)
	move_child(_stage_view, 0)       # the stage is the backdrop, always
	#The look (see filters.gd). The stage view is the one place the whole show is a single picture, so a
	#material here is a post-process over every scene at once and over nothing else (panels and the
	#karaoke line stay unfiltered).
	Director.filters_changed.connect(_sync_filters)
	get_viewport().size_changed.connect(_sync_stage_size)
	#...and when the show's frame changes (a portrait note, a medium without one): the stage refits
	Director.frame_changed.connect(_sync_stage_size)
	_sync_medium()
	#every scene gets a fresh measurement, so a light scene after a heavy one is not held at the old
	#level while the sparse active samples forgive (~15 s)
	Director.scene_cut.connect(func():
		_slow_said = false
		if _governor.cut():
			_stage.process_mode = Node.PROCESS_MODE_INHERIT
			_stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			print("ghost: stage governor -> level 0 (scene cut)"))
	get_tree().process_frame.connect(_frame_begins)
	RenderingServer.frame_pre_draw.connect(_frame_handed)
	_sync_stage_size()
	return _stage


func _frame_begins() -> void:
	_frame_began = Time.get_ticks_usec()


## Every `_process` and `_draw` of this frame has run, and nothing has been waited for yet.
func _frame_handed() -> void:
	_frame_own_ms = float(Time.get_ticks_usec() - _frame_began) / 1000.0


## Hand the Director's look to the stage view. Called when a filter changes, when the frame is
## resized, and once as the stage is built (an export render inherits the look through the same
## settings file).
func _sync_filters() -> void:
	if _stage_view == null or not is_instance_valid(_stage_view):
		return
	var look := Director.resolved_filters()
	Filters.apply(_stage_view, look, _stage_view.size)
	#Said once per change, not per call (this is reached by every window resize and every frame of a
	#dial being dragged): it tells a render's log what look it inherited.
	var said := Filters.describe(Director.resolved_filters(false))
	if said != _filter_said:
		_filter_said = said
		print("ghost: look %s" % said)


## Say so when the show's clock stops while the render keeps writing frames. Reports the first frame
## of a stall and again when it ends, with what the audio player was doing: `Spectrum` takes the clock
## from `get_playback_position()`, and a stopped player and one reporting a position that does not
## move look identical in the video.
func _watch_render_clock(delta: float) -> void:
	var t := Spectrum.current.time
	_clock_frames += 1
	if t > _clock_t + 0.0001:
		if _clock_stuck >= CLOCK_STALL_WARN:
			print("ghost: CLOCK RESUMED at %.2fs after %.2fs of render (%d frames) held at %.2fs"
				% [t, _clock_stuck, _clock_frames, _clock_t])
		_clock_t = t
		_clock_stuck = 0.0
		_clock_frames = 0
		return
	_clock_stuck += delta
	#Once per stall, on the frame it crosses the threshold.
	if _clock_stuck >= CLOCK_STALL_WARN and _clock_stuck - delta < CLOCK_STALL_WARN:
		var pos := -1.0
		var playing := false
		if Spectrum._player != null:
			playing = Spectrum._player.playing
			pos = Spectrum._player.get_playback_position()
		print("ghost: CLOCK STALLED at %.2fs (%d frames) - player.playing=%s position=%.3f"
			% [_clock_t, _clock_frames, str(playing), pos])


## Rebuild the medium if the setting changed since the last session. Director.set_medium says the
## change lands on the next session, and this is where that happens: the stage is built once and
## reused for every take.
func _sync_medium() -> void:
	var want := Director.resolved_medium()
	if _medium != null and is_instance_valid(_medium):
		if _medium.key == want:
			return
		_medium.release()
		_medium.queue_free()
	_medium = Medium.make(want)
	_medium.mount(_stage)
	_slow_said = false
	print("ghost: medium '%s'" % _medium.key)


func _sync_stage_size() -> void:
	if _stage == null:
		return
	var r := _frame_rect()
	#The stage is drawn at the Graphics menu's Resolution row: the frame's own canvas units unless
	#chosen. What is on the stage is told the stage's size, what lies over it the frame's.
	_stage.size = Graphics.stage_size(r.size)
	_stage_view.position = r.position
	_stage_view.size = r.size
	Director.frame_rect = r
	_sync_filters()
	if _medium != null and is_instance_valid(_medium):
		_medium.on_stage_resized(Vector2(_stage.size))
	if _subtitles != null and is_instance_valid(_subtitles):
		_subtitles.frame_rect = r


## The preview is the frame (next/notes.md): the stage is the show's frame - 16:9, or 9:16 for a
## portrait show - as large as the window holds it, centered, black beside it, so what is seen is what
## an export renders. In an export the window is the frame, and this is the whole of it.
##
## What is docked under the show takes its room from it ([member Chrome.stage_bottom]): with the
## storyboard's editor open the frame is fitted above it. Nothing claims any otherwise, and the fit is
## the window's.
func _frame_rect() -> Rect2:
	var vis := get_viewport().get_visible_rect().size
	if _chrome != null and is_instance_valid(_chrome) and _chrome.stage_bottom > 0.0:
		vis.y = maxf(vis.y * 0.3, vis.y - _chrome.stage_bottom)
	var fs := Vector2(Medium.FRAME_SIZES[Director.resolved_frame()])
	var k := minf(vis.x / fs.x, vis.y / fs.y)
	var size := (fs * k).round()
	return Rect2(((vis - size) * 0.5).round(), size)


func _process(delta: float) -> void:
	#Window cuts are noticed here, before anything else can return early: a film window is an ffmpeg
	#subprocess, and something has to see it exit and promote its output. This is the only `_process`
	#that is always running.
	Films.pump()
	Illustrations.pump()
	# ...and every other agent's writing and painting (the Table mode's episodes).
	AgentJobs.pump()
	if _clock_watch:
		_watch_render_clock(delta)
	if _until > 0.0 and Spectrum.current.time >= _until:
		print("ghost: --until %.1fs reached" % _until)
		get_tree().quit()
		return
	if _export_mode:
		_status_t += delta
		if _status_t >= 0.3:
			_status_t = 0.0
			var length := Spectrum.song_length()
			if length > 0.0:
				Bake.write_progress(Spectrum.current.time / length)
		return
	#The stage governor spaces out the stage's frames, never the UI's: a heavy scene blocks the whole main
	#loop for its full cost (stage_governor.gd). It is handed what the frame before cost this thread; a
	#frame that is slow for the graphics card's sake is not spaced out, and is said. Not while Movie Maker
	#records: every frame is one fixed step of show time, and a skipped stage frame would be held as a still.
	if _stage == null or not Engine.get_write_movie_path().is_empty():
		return
	if _governor.step(_frame_own_ms, delta):
		print("ghost: stage governor -> level %d (a stage frame costs this thread %.0f ms)" % [_governor.level, _governor.cost])
		if _governor.level == 0:
			_stage.process_mode = Node.PROCESS_MODE_INHERIT
			_stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if _governor.level > 0:
		if _governor.active:
			_stage.process_mode = Node.PROCESS_MODE_INHERIT
			_stage.render_target_update_mode = SubViewport.UPDATE_ONCE
		else:
			_stage.process_mode = Node.PROCESS_MODE_DISABLED
	_say_slow_frames(delta)


## Said once a scene: frames are slow and this thread is not why, so the governor spaces nothing out.
## Reports what the stage took of the graphics card's time, measured for a second first.
func _say_slow_frames(delta: float) -> void:
	if _slow_said:
		return
	if not _governor.slow_elsewhere:
		if _slow_t >= 0.0:
			_slow_t = -1.0
			Graphics.measure(false, "governor")
		return
	if _slow_t < 0.0:
		_slow_t = 0.0
		Graphics.measure(true, "governor")
		return
	_slow_t += delta
	if _slow_t < 1.0:
		return
	_slow_said = true
	_slow_t = -1.0
	print("ghost: frames are %.0f ms apart and this thread spends %.0f ms of that: the rest is waited for - the graphics card (the stage, %d x %d, takes %.1f ms of its time a frame; something else may be using it) or the display. The stage is not held back for it."
		% [_governor.whole, _governor.cost, _stage.size.x, _stage.size.y, Graphics.stage_ms()])
	Graphics.measure(false, "governor")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		#Deferred: this notification is still propagating, so the children are locked ("calling or
		#emitting") and freeing them here errors. One idle frame later they are free to free.
		call_deferred("_shutdown")


## Workaround: with audio input enabled (the voice sampler's microphone; project.godot
## driver/enable_input) the engine's audio-driver teardown aborts in glibc on this system (PipeWire
## input stream finalization). App state persists on change and the stateful editors save in
## _exit_tree, so: free main's children (their save hooks run), then leave without the driver teardown.
## GHOST_CLEAN_EXIT=1 restores the normal quit path for debugging; remove when upstream is fixed.
func _shutdown() -> void:
	if not OS.get_environment("GHOST_CLEAN_EXIT").is_empty():
		get_tree().quit()
		return
	#queue_free, never free(): something in the tree is mid-call at close time and free() errors on
	#locked objects; the end-of-frame free still runs every _exit_tree save hook.
	for child in get_children():
		child.queue_free()
	await get_tree().process_frame
	#Must be here, before the hard exit: `OS.kill(OS.get_process_id())` is a SIGKILL on ourselves, so no
	#autoload `_exit_tree` and no engine child reaping runs, and every background program ghost started
	#(bake, Movie Maker render, ffmpeg, mask prep, voice host) would be inherited by init and carry on.
	#This function is the single funnel for both ways out (the close request and Escape, which raises no
	#WM_CLOSE_REQUEST). `Subprocess` also binds each child to this process in the kernel, which covers a
	#ghost killed from outside.
	Subprocess.reap_all()
	#Likewise the --live-tap recording: Spectrum writes it in _exit_tree, which the hard exit never reaches.
	Spectrum._write_tap()
	print("ghost: bye (hard exit - audio-input teardown workaround, see main._shutdown)")
	OS.kill(OS.get_process_id())


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F11:
				_toggle_fullscreen()
			KEY_N:
				#Skip a scene. Space is the transport's everywhere (transport.gd). Mask mode never attaches the
				#Director, so a skip there would be meaningless.
				if _mask_editor == null or not is_instance_valid(_mask_editor):
					Director.next()
			KEY_ESCAPE:
				call_deferred("_shutdown")   # outside the input propagation
											 # (children are locked during it)


func _provision(scope: String) -> void:
	if not scope in ["all", "update"] and Deps.entry(scope).is_empty():
		scope = ""
	print("ghost: provisioning %s" % ("everything" if scope == "all"
		else "updates" if scope == "update" else "the core (uv, FFmpeg, Python)" if scope.is_empty()
		else "the core and %s" % String(Deps.entry(scope).get("name", scope))))
	var ok: bool = await Provisioner.run_cli(scope)
	print("")
	print(Deps.format_report())
	get_tree().quit(0 if ok else 1)


func _arg_value(args: PackedStringArray, flag: String) -> String:
	var i := args.find(flag)
	if i >= 0 and i + 1 < args.size():
		return args[i + 1]
	return ""


## --synth: the voice-synthesis editor. Each reading renders a WAV take and plays it as a fresh
## session; the take loops when it ends, like a manual session.
func _open_synth_editor() -> void:
	var editor := preload("res://src/reading/synth_editor.gd").new()
	editor.note_path = _note
	editor.note_moved = note_moved
	editor.reopen = reopen_note
	editor.begin_stream = _begin_synth_stream
	editor.end_stream = _end_synth_stream
	_synth_editor = editor
	add_child(editor)
	if _chrome.exporter != null:
		_chrome.exporter.take_provider = editor.export_take
		_chrome.exporter.take_ready = editor.can_export_take
		_chrome.exporter.name_provider = Callable()
		_chrome.exporter.upload_provider = editor.upload_meta
		_chrome.exporter.automation_available = true
	_feedback = _chrome.attach_feedback()
	_entered_mode()


## The generative path: a small local neural voice run by the voice host subprocess. A separate editor
## from synth_editor, not a backend swap: the fishing game's economy is defined over the procedural
## engine's 25-dimensional genome, while a neural backend exposes a speaker id and three scalars.
##
## [param workspace] is which one the panel runs: a note read aloud, or a show of cards, whose reading
## is written by agents (its episode is a card on the same panel) - the same stream, export and
## subtitles.
func _open_reading(workspace := "reading") -> void:
	var editor := ReadingPanel.new()
	editor.workspace = workspace
	editor.note_path = _note
	editor.note_moved = note_moved
	editor.reopen = reopen_note
	editor.begin_stream = _begin_generative_stream
	editor.end_stream = _end_generative_stream
	editor.begin_take = _begin_generative_take
	_synth_editor = editor
	_generative = editor
	add_child(editor)
	if _chrome.exporter != null:
		_chrome.exporter.take_provider = editor.export_take
		_chrome.exporter.take_first = true
		_chrome.exporter.take_ready = editor.can_export_take
		_chrome.exporter.name_provider = editor.export_name
		_chrome.exporter.upload_provider = editor.upload_meta
		_chrome.exporter.show_provider = editor.show_plan
		_chrome.exporter.automation_available = false
		# no fishing game on this path, so nothing to record
	_feedback = _chrome.attach_feedback()
	_entered_mode()


## One session for the whole chapter: a generator playback lets the editor push each chunk's PCM into a
## single continuous stream, so the show sees one unbroken take however many chunks it was made from
## (the Director does not re-cut, nor the harmonic seed re-derive, per chunk). Subtitles ride the same
## array, which Subtitles.words allows to keep growing.
## The closing half of _begin_generative_stream: lets go of everything it attaches - the stage, the
## audio stream and the subtitle overlay - so the editor's Stop can end a reading.
func _end_generative_stream() -> void:
	Director.detach()
	Spectrum.stop()
	_hide_stage()
	if _subtitles != null and is_instance_valid(_subtitles):
		_subtitles.queue_free()
	_subtitles = null
	if _generative != null and is_instance_valid(_generative):
		_generative.subtitles = null


func _begin_generative_stream(fp: int, sr: int, words: Array) -> AudioStreamGeneratorPlayback:
	#Tear down first: this is called again every time the reading restarts (new text, voice or tone), and
	#a fresh Director stage must not be attached on top of the previous one.
	#A pause stays: a reading sought to while paused begins again paused (ReadingStream.seek_now)
	var held := Spectrum.paused
	Director.detach()
	Spectrum.stop()
	Spectrum.set_paused(held)
	var pb: AudioStreamGeneratorPlayback = Spectrum.begin_stream(fp, sr)
	#The reading's show is the note's: a Medium attached puts the stage up, a Storyboard is what it
	#walks - and a voice alone is heard, with its words over an empty frame
	_attach_show(_generative.show_plan() if _generative != null and is_instance_valid(_generative)
		else {"picture": true})
	if _subtitles != null and is_instance_valid(_subtitles):
		_subtitles.queue_free()
	var subs := preload("res://src/show/subtitles.gd").new()
	subs.words = words          # shared by reference; the editor appends to it
	if _generative != null and is_instance_valid(_generative) and _generative.has_method("book_document"):
		subs.document = _generative.book_document()
	_subtitles = subs
	add_child(subs)
	_bind_captions(subs)
	if _generative != null and is_instance_valid(_generative):
		_generative.subtitles = subs   # the editor re-bases its clock per frame
	return pb


## The reading's kept take, played whole ([method ReadingStream.play]; next/editing.md): the file at
## [param path] opened as a render opens it ([method _begin_session]'s steps) - its bookend and words
## its sidecar's, the show the reading's - so a seek is a seek inside one file and the live show is the
## export's. False when it would not load (nothing is left playing).
func _begin_generative_take(path: String) -> bool:
	Director.detach()
	Spectrum.stop()
	Spectrum.lead_in = Director.intro_hold
	Spectrum.tail = Director.outro_hold
	Spectrum.begin(path)
	if not Spectrum.has_audio() or Spectrum.audio_path() != path:
		Spectrum.stop()
		return false
	_attach_show(_generative.show_plan() if _generative != null and is_instance_valid(_generative)
		else {"picture": true})
	_attach_subtitles()
	if _generative != null and is_instance_valid(_generative):
		_generative.subtitles = _subtitles
	return true


## Export autopilot: the Synthesis panel, playing itself over the take being rendered. Not wired to
## begin_stream/end_stream - the editor must not synthesize live audio (the export's --audio take is
## the audio); it only drives the panel, HUD and Director scene jumps. The editor self-activates its
## autopilot from the --synth-autopilot flag in its own _ready.
func _open_synth_autopilot() -> void:
	var editor := preload("res://src/reading/synth_editor.gd").new()
	_synth_editor = editor
	add_child(editor)


## Start (or restart) the session on a live VoiceStream: audio begins the same frame Play is clicked
## (the stream synthesizes ahead of the playhead and the analyzer bus hears it like a song). Streamed
## takes loop inside the stream itself (song_finished never fires for a generator).
func _begin_synth_stream(stream: Node) -> void:
	if _synth_active:
		Director.detach()
		Spectrum.stop()
	if _stream != null and is_instance_valid(_stream):
		_stream.queue_free()
	_stream = stream
	add_child(stream)
	var pb: AudioStreamGeneratorPlayback = Spectrum.begin_stream(stream.fingerprint(), Voice.SR)
	stream.attach_playback(pb)
	Director.attach(_stage_host(), _medium)
	#synthesis is game paced: the fishing owns the cuts - a scene changes when a catch jumps it
	Director.set_game_paced(true)
	_attach_live_subtitles(stream)
	stream.completed.connect(_on_stream_completed)
	stream.restarted.connect(_on_stream_restarted)
	_synth_active = true


## Release the line: tear the synthesis session back down to the state the editor boots in (no voice,
## no show, no Director) while the editor stays open. The mirror of _begin_synth_stream.
func _end_synth_stream() -> void:
	if not _synth_active:
		return
	if _stream != null and is_instance_valid(_stream):
		_stream.queue_free()
	_stream = null
	if _subtitles != null and is_instance_valid(_subtitles):
		_subtitles.queue_free()
	_subtitles = null
	Director.set_game_paced(false)
	Director.set_aura(0.0)
	Director.detach()
	Spectrum.stop()
	_hide_stage()
	_synth_active = false


## Subtitles for a live stream: share the stream's growing word array directly (the sidecar file
## doesn't exist yet; the take is still being synthesized).
func _attach_live_subtitles(stream: Node) -> void:
	if _subtitles != null and is_instance_valid(_subtitles):
		_subtitles.queue_free()
	var subs := preload("res://src/show/subtitles.gd").new()
	subs.words = stream.words
	_subtitles = subs
	add_child(subs)
	_bind_captions(subs)


func _on_stream_completed(dur: float, wav_path: String) -> void:
	Spectrum.set_stream_info(wav_path, dur)
	if _subtitles != null and is_instance_valid(_subtitles):
		_subtitles.loop_length = dur
	print("ghost: take complete (%.1fs) -> %s" % [dur, wav_path])


## The stream replaced its content in place (an implicit re-speak): rebase the karaoke clock and forget
## the previous take's loop length until the new take finishes.
func _on_stream_restarted(base: float) -> void:
	if _subtitles != null and is_instance_valid(_subtitles):
		_subtitles.time_base = base
		_subtitles.loop_length = 0.0


## Karaoke subtitles are session content, not editor chrome: whenever the session's audio has a sidecar
## timing map (a synth take), attach the overlay - live sessions, reopened takes and export renders.
## Music without a sidecar gets nothing.
func _attach_subtitles() -> void:
	if _subtitles != null and is_instance_valid(_subtitles):
		_subtitles.queue_free()
	_subtitles = null
	var side: String = Subtitles.sidecar_for(Spectrum.audio_path())
	if side.is_empty():
		return
	var subs := preload("res://src/show/subtitles.gd").new()
	if subs.load_sidecar(side):
		_subtitles = subs
		add_child(subs)
		_bind_captions(subs)
		print("ghost: subtitles attached (%d words)" % (subs.words as Array).size())


## Hand a fresh caption source to the medium. One that prints the words itself (the book) answers
## true, and the overlay then stops drawing; its clock and cursor keep running, because that medium
## reads them.
func _bind_captions(subs: Node) -> void:
	subs.frame_rect = _frame_rect()      # the subtitles lay out in the frame, not the window
	if _medium != null and is_instance_valid(_medium) and _medium.bind_captions(subs):
		subs.overlay_hidden = true


## --mask-render <session.json>: the export relaunch. No notes list, no Director - just the clip,
## shader and audio, autoplaying, quitting when the audio ends (mirrors _export_mode, one layer down).
func _begin_mask_render(session_path: String) -> void:
	var editor := preload("res://src/masking/mask_editor.gd").new()
	editor.render_mode = true
	add_child(editor)
	editor.open_source(session_path)


## --mask-edit [path]: the interactive editor. `path` is a session .json, a raw source video
## (transcoded once and cached), or empty (its panel asks for one). [param note] is the note it is,
## where a clip chosen in the editor is written.
func _open_mask_editor(path: String, note := "") -> void:
	var editor := preload("res://src/masking/mask_editor.gd").new()
	editor.note_path = note
	editor.reopen = reopen_note
	_mask_editor = editor
	add_child(editor)
	editor.open_source(path)
	_entered_mode()


func _toggle_fullscreen() -> void:
	var mode := DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
