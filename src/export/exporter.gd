extends CanvasLayer
class_name Exporter

## Exporter - renders the visualization to a video in the background, as separate processes polled by PID.
##
## Persistent (main creates it once, never frees it), so an in-flight export and its status survive the song ending and the
## return to the home screen. The Export button asks for a quality (720p@30 / 1080p@60 / 4K@60) and a path, then:
##
##   1. Bake (headless): a one-shot `bake_runner` process analyzes the song into a spectrum cache, kept per song.
##   2. Render (Movie Maker): a second process loads the cache (`--bake-file`) and records the visualization and audio to a
##      scratch AVI. Its window is moved off-screen by main.
##   3. Transcode (ffmpeg): the AVI is encoded to the chosen MP4 (H.264 + AAC) while it is written; on Linux what has been
##      encoded is given back as it goes and the scratch leaves the folder (see [member _live_encode]). Godot writes only
##      AVI, whose 32-bit RIFF sizes corrupt past ~4 GB; the MP4 uses 64-bit offsets and is far smaller.
##   4. Upload (only when the note has a YouTube card with "Upload after export" ticked): the saved MP4 goes up as the card
##      describes it, see [member upload_provider], [YouTubeCard] and youtube.gd. The sign-in it needs is settled as the
##      export starts, beside the render. The menu says nothing of YouTube: the card holds the choice, the Google client,
##      the sign-in and a waiting upload's resume.
##
## Status ("Analyzing… / Rendering… / Finalizing… / Saved ✓") shows in the main window.

const Bake := preload("res://src/audio/bake.gd")
const YouTube := preload("res://src/export/youtube.gd")

# Output quality presets, offered when the Export button is pressed. `w`/`h` is the file's resolution and `fps` what Movie
# Maker records at.
#
# `ss` is the supersample factor: the render runs at ss x the output and ffmpeg resolves it back down. This is the only
# antialiasing there is: everything is drawn as flat CanvasItem triangles (see TriBatch), a wireframe edge is a thin quad,
# and Godot's msaa_2d is inert in the export (frames at msaa_2d 0, 4x and 8x are byte-identical). At 1.5x the excess energy
# near Nyquist falls from +114% to +16% of ground truth before the codec, and edge pixels with no partial coverage from
# 61-73% to 12-19%.
#
# 1.5x rather than 2x because the cost is the scratch file, not time: the MJPEG intermediate grows 80%, which pulls Godot's
# 4 GiB AVI wrap in from ~5.7 to ~3.1 minutes of 60 fps video (2x wraps at ~2.0 minutes). 4K stays native: 1.5x of it wraps
# in about a minute.
const QUALITIES := [
	{"label": "720p · 30 fps  (HD, smaller file)", "w": 1280, "h": 720, "fps": 30, "tag": "720p", "ss": 1.5},
	{"label": "1080p · 60 fps  (Full HD)", "w": 1920, "h": 1080, "fps": 60, "tag": "1080p", "ss": 1.5},
	{"label": "4K · 60 fps  (UHD, full resolution)", "w": 3840, "h": 2160, "fps": 60, "tag": "4k", "ss": 1.0},
]
const DEFAULT_QUALITY := 1
## The portrait presets, the landscape ones turned (next/notes.md step 10). No 4K portrait: Shorts stop at 1080p and
## Instagram at 1920 pixels wide.
const PORTRAIT_QUALITIES := [
	{"label": "720 x 1280 · 30 fps  (portrait: Shorts, Reels, TikTok)", "w": 720, "h": 1280, "fps": 30, "tag": "720p-portrait", "ss": 1.5},
	{"label": "1080 x 1920 · 60 fps  (portrait, Full HD)", "w": 1080, "h": 1920, "fps": 60, "tag": "1080p-portrait", "ss": 1.5},
]
## A portrait video longer than this is not a Short (seconds).
const SHORT_MAX := 180.0

## The quality menu's "A stretch again" ([method _ask_stretch]; [Stitch]).
const STRETCH_ID := 1001
## The status line's widest (see [method _place_status]).
const STATUS_W := 588.0
## What the sign-in dialog says. Google's "Access blocked" page never comes back to Ghost Notes, so the dialog names it
## rather than waiting out the timeout in silence.
const SIGN_BLOCKED := ("\"Access blocked\" or \"has not completed the Google verification process\"? "
	+ "While the Google Cloud project %s is in Testing, only its own test users can sign in - another "
	+ "project's list does not count. Add your Google account as a test user of that project (Google "
	+ "Cloud, Google Auth Platform, Audience) and open the page again, or pick another Client on the YouTube card.")
const SIGN_WAIT := ("Your browser should be showing Google's sign-in. Choose the Google account that "
	+ "owns the channel - and the channel, when Google asks which - and allow Ghost Notes to upload "
	+ "videos. This window closes by itself.\n\n"
	+ "No page? It may have opened behind another window: open it again, or copy the link into the "
	+ "browser you use.")

## Set by a mode that owns its own export path (Masking: a headless relaunch against the session json), so the shared button
## steps aside. That mode builds its own button at the same bottom-right offsets; this layer is 250 and the editor's is 100,
## so without this the shared button would sit over the working one and eat its clicks.
var suppressed := false
## How far up the current mode has asked the bottom-right row to sit. See
## Chrome.bottom_inset.
var _inset := 0.0

var _btn: Button
var _status: Label
var _dialog: FileDialog
var _quality_menu: PopupMenu
var _state := "idle"     # idle | baking | rendering | transcoding | stitching | upload_wait | uploading | done
## A stretch rendered again ([Stitch]): {old, t0, t1, span} while one is under way, {} otherwise.
var _stretch := {}
var _stretch_dialog: ConfirmationDialog
var _stretch_old: LineEdit
var _stretch_from: LineEdit
var _stretch_to: LineEdit
var _stitch_steps: Array = []    # the ffmpeg runs still to go, each an argv
var _stitch_pid := -1
var _bake_pid := -1
var _render_pid := -1
var _transcode_pid := -1
## The sliding window. The transcode runs during the render, reading the AVI as Movie Maker writes it (`-follow`), and on
## Linux the bytes it has read are released from disk behind it (`fallocate --punch-hole`), so the scratch holds seconds of
## video, not the film.
var _live_encode := false        # the transcode is following the render
var _punched := 0                # bytes released from the head of the AVI so far
var _punch_t := 0.0
## The scratch also leaves the folder. A release frees blocks but cannot shorten the file: Movie Maker writes at its own
## offset, so the AVI's length still grows to the whole film, which is what a file manager shows. Once a release has worked,
## the name is unlinked. The render and the encoder go on through the handles they hold; ghost holds one more ([member _hold],
## reached by path as [member _held]) to measure and release through, and the kernel frees the file when the last closes.
var _hold: FileAccess = null
var _held := ""                  # /proc/<ghost>/fd/<n> for _hold; "" = reach the scratch by name
var _unlinked := false           # the scratch's name is gone from the folder
var _released := false           # some of it was given back, so it can never be encoded again
## True when this render runs on the real desktop rather than a display of its own, where burying the window corrupts the
## picture. Shown to the user before it can be spoiled.
var _note_no_virtual_display := false
var _out := ""           # the final file the user chose (.mp4)
var _avi := ""           # the intermediate Movie Maker AVI (transcoded away, then deleted)
var _song := ""
var _cache := ""
var _done_t := 0.0
var _pct := 0            # last progress read from the render/bake process
var _song_dur := 0.0     # song length captured at export START (the live song may end mid-transcode)
var _quality: Dictionary = QUALITIES[DEFAULT_QUALITY]
var _announced := false  # one-shot console note the first time export becomes ready
var _note_t := 0.0       # countdown for self-clearing informational notes
var _prepping := false   # a provider take is rendering (async) - ignore re-clicks
var _stall_t := 0.0      # seconds since the render last showed ANY sign of life
var _stall_frac := -1.0  # high-water fractional progress the watchdog has seen
var _stall_size := 0     # high-water size of the movie file being written
var _yt: YouTube               # the sign-in and the upload
var _client_dialog: FileDialog # the Google client file, asked for once
var _client_then := Callable() # what an imported client file leads on to
var _upload_this := false      # this export goes to YouTube once it is saved
var _upload_meta := {}         # what it goes up as: asked of the mode once the take was rendered
var _upload_file := ""         # the file going up (an earlier export's, on a resume)
var _thumb_why := ""           # why the YouTube card's thumbnail could not be had for it, "" when it could
var _sign := ""                # the sign-in an upload needs: "" | checking | client | signing_in | ok | failed
var _sign_why := ""
var _sign_attempt := 0         # which sign-in may still report: a newer one, or a cancel, moves it on
var _sign_then := Callable()   # what the sign-in leads on to, kept for "Try again"
var _sign_scopes: Array = []   # ...and what it asks Google for
var _sign_channel := ""        # ...and the channel it is for: "" for whichever the person picks
var _sign_named := ""          # ...called this, when the card knows
var _sign_through := ""        # ...the client the card picked, "" for the channel's own (YouTube.client_for)
var _sign_move := false        # ...and whether the person asked to sign a channel still signed in in again
var _sign_landed := ""         # the channel the last sign-in that settled is for
var _sign_dialog: AcceptDialog # what Ghost Notes is waiting for while the browser signs in
var _sign_again: Button
var _sign_copy: Button

# The watchdog exists for one failure: a render that can never finish (the audio failed to load, so the session has no end
# and Movie Maker records silence until the disk fills). It must never fire on a render that is merely slow.
#
# Liveness is two fine-grained signals, the fractional playback position and the movie file growing on disk; either counts,
# with a long fuse. Integer percent is too coarse: one percent of a 344 s take is 3.4 s of video, which a heavy scene can
# spend over a minute producing.
const STALL_LIMIT := 300.0
## How long the following encoder waits on a file that has stopped growing before it decides the render is over
## (microseconds, ffmpeg's unit). A render that pauses longer is caught by [method _encoder_quit_early].
const FOLLOW_TIMEOUT_US := 60000000
## Seconds the render's virtual display outlives its last client (see [method virtual_display]).
const XVFB_LINGER := 10
## The head of the AVI is never released: Movie Maker seeks back there to finish its header.
const PUNCH_KEEP := 1 << 20
## ...and the release stays this far behind the encoder's read position.
const PUNCH_BEHIND := 8 << 20
const STALL_MIN_GROWTH := 65536   # bytes; below this the file is not really moving

## A mode whose audio is made on demand (a reading: its voices are a function of its words and settings) registers a
## provider that renders the current take to disk and returns its path, so export works from the first moment.
var take_provider := Callable()

## The take provider makes the export's audio even while a file plays: a reading's kept take plays as a file ([method
## ReadingStream.play]), and its export still pins its episode and writes what goes with the take ([method
## ReadingPanel.export_take], which hands over the kept take).
var take_first := false

## Optional companion to [member take_provider]: true when the provider has something worth rendering (a reading: words and
## a voice to read them). When false the button grays out.
var take_ready := Callable()

## What the video is called, when the mode knows: a name without an extension (an episode's title), or "" for the exporter's
## own `ghost_notes_<quality>`. Asked as the save dialog opens; goes through [method safe_name].
var name_provider := Callable()

## What an upload of the take at the given path says: `{title, description, chapters, tags, privacy, playlist,
## playlist_title, channel, channel_name, record}` - `channel` the id of the channel it goes to ("" when the note has none
## yet), `record` a file the upload's result is kept in - plus the thumbnail as the YouTube card chose it: `thumbnail` (a
## picture), `thumbnail_at` (a moment of the video to take a frame at) or neither, `thumbnail_why` saying why the choice
## could not be had. {} when nothing is to go up (no YouTube card, or "Upload after export" not ticked). Asked with "" as the
## save path is chosen, which decides whether this export goes up; asked again with the take once rendered, so a mode can
## time chapters from it.
var upload_provider := Callable()
## What the note's show is (`() -> Dictionary`, a panel's `show_plan()`): the storyboard the render must walk comes from the
## note, not from what the Director holds (a reading that is not playing has let its storyboard go). Unset (the command
## line), the Director's own is used.
var show_provider := Callable()


## The group the session's exporter is found by ([method of]).
const GROUP := "ghost_exporter"


## The exporter in this tree, or null - for what sits beside it in `export/` and needs it (the YouTube card's sign-in).
static func of(n: Node) -> Exporter:
	if n == null or not n.is_inside_tree():
		return null
	return n.get_tree().get_first_node_in_group(GROUP) as Exporter


func _ready() -> void:
	add_to_group(GROUP)
	layer = 250          # above the notes list (200), so status shows there too
	# remove a stale override.cfg left by a killed render - never from a read-only process (a probe, the README's recording),
	# which may run beside the author's own export
	if not Settings.is_read_only():
		_clear_override()
	_build_ui()
	_place_status()
	get_viewport().size_changed.connect(_place_status)


## An export does not survive the app. Every step is a separate process (see the class doc) and `OS.create_process` detaches
## them, so on close the bake, the render and the transcode are stopped here. The pids go through [Subprocess], so `Boot`
## would reap them anyway; this does it first and also clears the render's `override.cfg`, which the generic reap cannot
## know about. The scratch AVI goes with the render: nothing resumes a render.
##
## WM_CLOSE_REQUEST reaches every node when the window is asked to close; EXIT_TREE covers programmatic quits. Both, because
## either can be the one that happens.
func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_CLOSE_REQUEST and what != NOTIFICATION_EXIT_TREE:
		return
	if _state == "idle" or _state == "done":
		return
	if _state in ["preparing", "upload_wait", "uploading"]:
		# the video is saved and the upload waits in pending.json: nothing to stop or clear
		print("ghost: YouTube upload interrupted - ghost is closing; resume it from a note's YouTube card")
		return
	for pid in [_bake_pid, _render_pid, _transcode_pid]:
		Subprocess.stop(int(pid))
	_bake_pid = -1
	_render_pid = -1
	_transcode_pid = -1
	_clear_override()
	_drop_scratch()
	print("ghost: export stopped - ghost is closing")


func _build_ui() -> void:
	_btn = Button.new()
	_btn.text = "⤓"                    # icon-only - matches assistant.gd's chat-bubble toggle
	_btn.tooltip_text = "Render this visualization + audio to a video file (in the background)"
	_btn.focus_mode = Control.FOCUS_NONE
	_btn.custom_minimum_size = Vector2(40, 40)
	_btn.visible = false
	_btn.modulate.a = 0.0       # fade in elegantly when it becomes eligible
	_btn.pressed.connect(_on_export)
	# The row's (Chrome.row_button): hidden, it closes up rather than leaving a hole. With no Chrome (a gate building an
	# exporter by hand), at its old slot in the row.
	var ch := Shell.of(self)
	if ch != null:
		ch.row_button(&"export", _btn)
	else:
		_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		_btn.offset_left = -112
		_btn.offset_top = -68
		_btn.offset_right = -72
		_btn.offset_bottom = -28
		add_child(_btn)

	_status = Label.new()
	_status.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	# wrapped, growing up and left, never toward the buttons or past the screen's edge (see _place_status)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_status.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_status.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_status.add_theme_constant_override("shadow_offset_x", 1)
	_status.add_theme_constant_override("shadow_offset_y", 1)
	_status.visible = false
	add_child(_status)
	_place_status()

	# Quality picker, shown first when Export is pressed, before the save dialog.
	_quality_menu = PopupMenu.new()
	for i in QUALITIES.size():
		_quality_menu.add_item(QUALITIES[i].label, i)
	_quality_menu.add_separator()
	# a stretch of an earlier export rendered again (next/editing.md step 13; [Stitch])
	_quality_menu.add_item("A stretch again, into an earlier export…", STRETCH_ID)
	_quality_menu.set_item_tooltip(_quality_menu.get_item_index(STRETCH_ID),
		"Render only a stretch of an export you made before - a late fix - and put it back in its place: the rest of the\n"
		+ "video is copied as it was, never rendered again. The earlier file is kept beside it.")
	_quality_menu.id_pressed.connect(_on_quality)
	add_child(_quality_menu)
	_build_stretch_dialog()

	_dialog = FileDialog.new()
	_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_dialog.use_native_dialog = true
	_dialog.title = "Export video"
	_dialog.filters = PackedStringArray(["*.mp4 ; Video (MP4, H.264 + AAC)"])
	_dialog.current_file = "ghost_notes.mp4"
	# Default to the Downloads folder so an export lands somewhere predictable.
	var downloads := OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	if not downloads.is_empty():
		_dialog.current_dir = downloads
	_dialog.size = Vector2i(800, 560)
	_dialog.file_selected.connect(_on_path)
	add_child(_dialog)

	# The author's Google client file, asked for the first time an upload is ticked and kept from then on (see youtube.gd).
	_client_dialog = FileDialog.new()
	_client_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_client_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_client_dialog.use_native_dialog = true
	_client_dialog.title = "Import your Google OAuth client (the JSON file from Google Cloud)"
	_client_dialog.filters = PackedStringArray(["*.json ; Google OAuth client (JSON)"])
	if not downloads.is_empty():
		_client_dialog.current_dir = downloads
	_client_dialog.size = Vector2i(800, 560)
	_client_dialog.file_selected.connect(_on_client_file)
	_client_dialog.canceled.connect(_on_client_cancel)
	add_child(_client_dialog)
	_yt = YouTube.new()
	add_child(_yt)
	# The sign-in, visible while it waits: the page can open behind another window, and Google's "Access blocked" never comes
	# back, so the person sees what is awaited.
	_sign_dialog = AcceptDialog.new()
	_sign_dialog.title = "Sign in to YouTube"
	_sign_dialog.dialog_autowrap = true
	_sign_again = _sign_dialog.add_button("Open the page again", false, "again")
	_sign_copy = _sign_dialog.add_button("Copy the link", false, "copy")
	_sign_dialog.custom_action.connect(_on_sign_action)
	_sign_dialog.confirmed.connect(_on_sign_close)
	_sign_dialog.canceled.connect(_on_sign_close)
	add_child(_sign_dialog)


func _process(dt: float) -> void:
	match _state:
		"baking":
			if Subprocess.alive(_bake_pid):
				_poll_pct()
				_set_status("⏳  Analyzing audio…  %d%%" % _pct, Color(0.95, 0.92, 0.7))
			elif FileAccess.file_exists(_cache):
				_start_render()                  # bake finished -> render from the cache
			else:
				_fail("⚠  Bake failed (is ffmpeg on PATH?)")
		"rendering":
			_tick_render(dt)
		"transcoding":
			_tick_transcode()
		"stitching":
			_tick_stitch()
		"preparing":
			_set_status("⇪  Taking the thumbnail for %s…" % _out.get_file(), Color(0.95, 0.92, 0.7))
		"upload_wait":
			# the video is saved and queued; it goes up once the sign-in settles
			match _sign:
				"ok":
					_run_upload()
				"failed":
					if YouTube.signed_in(str(YouTube.pending().get("channel", ""))):
						_run_upload()        # a sign-in is kept: what failed was reaching Google - try now
					else:
						_state = "done"
						_done_t = 60.0
						_set_status("⚠  Not uploaded: %s - resume it from the YouTube card" % _sign_why,
							Color(1.0, 0.7, 0.6))
				"client":
					_set_status("⇪  %s waits for your Google client file" % _upload_file.get_file(),
						Color(0.95, 0.92, 0.7))
				"signing_in":
					_set_status("⇪  %s waits for the YouTube sign-in in your browser" % _upload_file.get_file(),
						Color(0.95, 0.92, 0.7))
				_:
					_set_status("⇪  Checking the YouTube sign-in…", Color(0.95, 0.92, 0.7))
		"uploading":
			_set_status("⇪  Uploading %s to YouTube …  %d%%" % [_upload_file.get_file(),
				int(round(_yt.progress * 100.0))], Color(0.95, 0.92, 0.7))
		"done":
			_done_t -= dt
			if _done_t <= 0.0:
				_status.visible = false
				_state = "idle"
	# the take renders with the state still idle: keep its line, and the sign-in beside it, current
	if _prepping and _upload_this:
		_set_status("⏳  Rendering the take…", Color(0.95, 0.92, 0.7))
	# The button fades in once eligible (idle, not mid-export, past the delay) and out otherwise.
	# an informational note (e.g. "nothing to export yet") clears itself
	if _note_t > 0.0 and _state == "idle":
		_note_t -= dt
		if _note_t <= 0.0:
			_status.visible = false
	# A panel open above the row (the log, the Assistant, the Environment) has the space the progress line uses: the line steps
	# aside while one is open.
	var ch := Shell.of(self)
	_status.modulate.a = 0.0 if ch != null and ch.panel_open() else 1.0
	if suppressed:
		_btn.visible = false
		_btn.modulate.a = 0.0
		# The status line stays: an export started before the mode took over is still running.
		return
	var want := _state == "idle" and _can_export()
	if want and not _announced:
		_announced = true
		print("ghost: export ready (⤓ bottom-right)")
	_btn.modulate.a = lerpf(_btn.modulate.a, 1.0 if want else 0.0, 1.0 - exp(-6.0 * dt))
	_btn.visible = _btn.modulate.a > 0.02
	# grayed, never gone: nothing to render yet
	var content := _has_content()
	_btn.disabled = not content
	_btn.tooltip_text = ("Render this visualization + audio to a video file (in the background)"
		if content else
		"Nothing to render yet - catch a seed (or play a song) first")


func _tick_render(dt: float) -> void:
	if not Subprocess.alive(_render_pid):
		_clear_override()                # render finished -> restore live resolution
		# The render reports success only by PID exit; check it produced the AVI (a crashed Movie Maker exits too) before
		# transcoding nothing.
		if _live_encode:
			# the encoder has been following all along; it finishes by itself once the file stops growing (FOLLOW_TIMEOUT_US)
			_state = "transcoding"
		elif FileAccess.file_exists(_avi) and _file_size(_avi) > 65536:
			_repair_avi_sizes(_avi)
			_start_transcode()
		else:
			_fail("⚠  Render produced no file (see console)")
		return
	_poll_pct()
	# stall watchdog (see the consts): alive = the playback position advanced at all, or the movie file grew
	_stall_t += dt
	var frac := Bake.read_progress()
	if frac > _stall_frac:
		_stall_frac = frac
		_stall_t = 0.0
	var sz := _scratch_len()
	if not _live_encode and _transcode_pid <= 0 and sz > 65536:
		_start_transcode(true)
	if _live_encode and not Subprocess.alive(_transcode_pid) and _riff_size() == 0:
		_encoder_quit_early()
		if _state != "rendering":
			return
	if _live_encode:
		_punch_t -= dt
		if _punch_t <= 0.0:
			_punch_t = 2.0
			_punch_behind_encoder()
	if sz > _stall_size + STALL_MIN_GROWTH:
		_stall_size = sz
		_stall_t = 0.0
	if _stall_t > STALL_LIMIT:
		Subprocess.stop(_render_pid)
		_clear_override()
		_drop_scratch()
		_fail("⚠  Render stalled at %d%% - frozen for %d min (see console)"
			% [_pct, int(STALL_LIMIT / 60.0)])
		push_warning("ghost export: render stalled (no frames, no progress); killed pid %d"
			% _render_pid)
		return
	# one decimal: whole percents on a long take sit still for minutes on heavy scenes, which reads as a freeze
	# the warning rides the progress line: it is the only text on screen for hours
	var how := " …  %.1f%%" % (maxf(_stall_frac, 0.0) * 100.0)
	if _note_no_virtual_display:
		how += "   ⚠ leave the render window visible"
	_set_status("⏺  Rendering %s%s" % [_out.get_file(), how],
		Color(0.95, 0.92, 0.7))


func _tick_transcode() -> void:
	if Subprocess.alive(_transcode_pid):
		_set_status("⏳  Finalizing %s …  %d%%" % [_out.get_file(), _read_transcode_pct()], Color(0.95, 0.92, 0.7))
	elif FileAccess.file_exists(_out) and _file_size(_out) > 4096 and not _stretch.is_empty():
		_drop_scratch()
		_start_stitch()                   # a stretch: put back into the earlier export
	elif FileAccess.file_exists(_out) and _file_size(_out) > 4096:
		_drop_scratch()                   # transcode ok -> the scratch goes, and its space with it
		_state = "done"
		_done_t = 30.0
		_set_status("✓  Saved  %s%s" % [_out, _shorts_note()], Color(0.82, 0.95, 0.86))
		print("ghost: exported -> ", _out)
		if _upload_this:
			_queue_upload()
	elif _released:
		# what the encoder read was given back as it went, so there is no whole AVI to keep
		_upload_this = false
		_drop_scratch()
		_state = "done"
		_done_t = 30.0
		_set_status("⚠  Transcode failed (see console)", Color(1.0, 0.7, 0.6))
		push_warning("ghost export: transcode failed")
	else:
		# Transcode failed (ffmpeg missing or errored): keep the raw AVI so the work is not lost.
		_upload_this = false
		_drop_scratch(false)
		_state = "done"
		_done_t = 30.0
		_set_status("⚠  Transcode failed; raw file kept: %s" % _avi, Color(1.0, 0.7, 0.6))
		push_warning("ghost export: transcode failed; kept AVI at " + _avi)


# --- a stretch again ([Stitch]; next/editing.md step 13) ------------------------------------------------------------------

func _build_stretch_dialog() -> void:
	_stretch_dialog = ConfirmationDialog.new()
	_stretch_dialog.title = "A stretch again"
	_stretch_dialog.ok_button_text = "Render the stretch"
	var col := VBoxContainer.new()
	var say := Label.new()
	say.text = ("The earlier export, and the stretch of it to render again. Only that stretch is rendered - widened to the "
		+ "video's keyframes, every two seconds - and put back in its place; the rest is copied as it was. The note must be "
		+ "the one the export was made from, with the same words.")
	say.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	say.custom_minimum_size = Vector2(480, 0)
	col.add_child(say)
	_stretch_old = _stretch_field(col, "The earlier export (.mp4)")
	_stretch_from = _stretch_field(col, "From (m:ss or seconds)")
	_stretch_to = _stretch_field(col, "To (m:ss or seconds)")
	_stretch_dialog.add_child(col)
	_stretch_dialog.confirmed.connect(_on_stretch)
	add_child(_stretch_dialog)


func _stretch_field(col: Container, label: String) -> LineEdit:
	var l := Label.new()
	l.text = label
	col.add_child(l)
	var e := LineEdit.new()
	col.add_child(e)
	return e


func _ask_stretch() -> void:
	if _stretch_old.text.strip_edges().is_empty() and not _out.is_empty() and FileAccess.file_exists(_out):
		_stretch_old.text = _out
	_stretch_dialog.popup_centered(Vector2i(560, 0))


## [param s] ("1:23", "83", "1:02:03") as seconds, -1 for nothing readable.
static func clock_seconds(s: String) -> float:
	var parts := s.strip_edges().split(":")
	var t := 0.0
	for p in parts:
		if not p.strip_edges().is_valid_float():
			return -1.0
		t = t * 60.0 + float(p)
	return t if not parts.is_empty() else -1.0


## The stretch asked for: the earlier export read (its size and rate must be one of the qualities, so the stretch is encoded as
## it was), and the export's own way taken from there with only the stretch rendered.
func _on_stretch() -> void:
	var old := _stretch_old.text.strip_edges()
	var t0 := clock_seconds(_stretch_from.text)
	var t1 := clock_seconds(_stretch_to.text)
	if not FileAccess.file_exists(old) or t0 < 0.0 or t1 <= t0:
		_fail("⚠  A stretch needs an earlier export that is there, and a From before its To")
		return
	var probe: Array = []
	OS.execute("ffprobe", ["-v", "error", "-select_streams", "v:0", "-show_entries", "stream=width,height,r_frame_rate",
		"-of", "csv=p=0", old], probe)
	var got := String("".join(probe)).strip_edges().split(",")
	var fit := {}
	if got.size() >= 3:
		var rate := got[2].split("/")
		var fps := float(rate[0]) / maxf(1.0, float(rate[1])) if rate.size() == 2 else float(rate[0])
		for q in qualities_for(Director.resolved_frame()):
			if int(q.w) == int(got[0]) and int(q.h) == int(got[1]) and absf(float(q.fps) - fps) < 0.01:
				fit = q
	if fit.is_empty():
		_fail("⚠  %s is no export of this frame's qualities, so a stretch could not be encoded to match it" % old.get_file())
		return
	_quality = fit
	_stretch = {"old": old, "t0": t0, "t1": t1}
	_on_path(old.get_basename() + ".stretch.mp4")


## The stretch put back ([Stitch]): the earlier export's head and tail copied, the stretch's pictures, joined under its whole sound.
func _start_stitch() -> void:
	var old := String(_stretch["old"])
	var sp: Vector2 = _stretch.get("span", Vector2.ZERO)
	var parts_dir := old.get_basename() + ".stitch"
	DirAccess.make_dir_recursive_absolute(parts_dir)
	var length := _media_seconds(old)
	var parts: Array = []
	_stitch_steps = []
	var head := parts_dir.path_join("head.mp4")
	var head_args := Stitch.head_args(old, sp.x, float(_quality.fps), head)
	if not head_args.is_empty():
		_stitch_steps.append(head_args)
		parts.append(head)
	var pic := parts_dir.path_join("stretch.mp4")
	_stitch_steps.append(Stitch.picture_args(_out, pic))
	parts.append(pic)
	var tail := parts_dir.path_join("tail.mp4")
	var tail_args := Stitch.tail_args(old, sp.y, length, tail)
	if not tail_args.is_empty():
		_stitch_steps.append(tail_args)
		parts.append(tail)
	var list := parts_dir.path_join("parts.txt")
	var f := FileAccess.open(list, FileAccess.WRITE)
	if f == null:
		_fail("⚠  Could not write the stitch's list")
		return
	f.store_string(Stitch.list_text(parts))
	f.close()
	_stitch_steps.append(Stitch.join_args(list, old, parts_dir.path_join("whole.mp4")))
	_stitch_pid = -1
	_state = "stitching"


func _tick_stitch() -> void:
	if _stitch_pid > 0 and Subprocess.alive(_stitch_pid):
		_set_status("⏳  Putting the stretch back into %s…" % String(_stretch["old"]).get_file(), Color(0.95, 0.92, 0.7))
		return
	if not _stitch_steps.is_empty():
		_stitch_pid = Subprocess.start("ffmpeg", _stitch_steps.pop_front(), "stitch")
		if _stitch_pid <= 0:
			_fail("⚠  Could not start ffmpeg to put the stretch back")
			_stretch = {}
		return
	var old := String(_stretch["old"])
	var parts_dir := old.get_basename() + ".stitch"
	var whole := parts_dir.path_join("whole.mp4")
	if not FileAccess.file_exists(whole) or _file_size(whole) < 4096:
		_fail("⚠  The stretch could not be put back (see the console); %s is as it was, the stretch at %s" % [old.get_file(), _out])
		_stretch = {}
		return
	var kept := Stitch.kept_name(old)
	if DirAccess.rename_absolute(old, kept) != OK or DirAccess.rename_absolute(whole, old) != OK:
		_fail("⚠  Could not put the stitched video in place: it is at %s" % whole)
		_stretch = {}
		return
	for p in DirAccess.get_files_at(parts_dir):
		DirAccess.remove_absolute(parts_dir.path_join(p))
	DirAccess.remove_absolute(parts_dir)
	DirAccess.remove_absolute(_out)
	var sp: Vector2 = _stretch.get("span", Vector2.ZERO)
	_state = "done"
	_done_t = 30.0
	_set_status("✓  %s - %s put back into %s (the earlier one kept as %s)" % [Clock.text(sp.x), Clock.text(sp.y), old.get_file(), kept.get_file()],
		Color(0.82, 0.95, 0.86))
	print("ghost: a stretch %.1f-%.1fs put back into %s; the earlier kept as %s" % [sp.x, sp.y, old, kept])
	_stretch = {}


## How long a video is, seconds (ffprobe), 0 when it cannot be read.
static func _media_seconds(path: String) -> float:
	var got: Array = []
	OS.execute("ffprobe", ["-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", path], got)
	return float(String("".join(got)).strip_edges())


# The button is always visible. It may only be disabled (grayed, with a tooltip saying why) when there is no content: no
# song loaded and no provider that could make one. It is never gated on timing: a reading restarted by an edit resets the
# playback clock, so a time gate could never be satisfied.
func _can_export() -> bool:
	return true


func _has_content() -> bool:
	if not Spectrum.audio_path().is_empty():
		return true
	if not take_provider.is_valid():
		return false
	return not take_ready.is_valid() or bool(take_ready.call())


# Refresh the cached percentage from the worker process (ignore mid-write misreads).
func _poll_pct() -> void:
	var p := Bake.read_progress()
	if p >= 0.0:
		_pct = int(round(p * 100.0))


# Step 0: pick the output resolution / fps; the menu pops up by the button. The pickers come first (quality, then path, then
# the background pipeline): a take that needs rendering is made in _on_path, after the user commits. A click with
# nothing to export and no way to make it explains itself instead of opening a doomed dialog.
func _on_export() -> void:
	if _prepping:
		return
	# Every export ends in an ffmpeg transcode. ghost downloads FFmpeg itself, so on a first run it may still be on its way:
	# say so now rather than after the render.
	if not Deps.has("ffmpeg"):
		Provision.ensure("ffmpeg")
		_note_t = 6.0
		_set_status("⏳  " + Deps.hint("ffmpeg"), Color(1.0, 0.85, 0.6))
		return
	_song = "" if take_first and take_provider.is_valid() else Spectrum.audio_path()
	if _song.is_empty() and not take_provider.is_valid():
		_note_t = 4.0
		_set_status("⚠  Nothing to export yet - play or speak something first",
			Color(1.0, 0.85, 0.6))
		return
	# An upload whose title cannot be made (the note's YouTube card names a macro the note does not fill, YouTubeCard.why_not)
	# says so now, before the render it would follow
	var refused := str(_upload_peek().get("refused", ""))
	if not refused.is_empty():
		_note_t = 8.0
		_set_status("⚠  " + refused, Color(1.0, 0.85, 0.6))
		return
	_label_qualities()
	var btn_rect := _btn.get_global_rect()
	_quality_menu.reset_size()
	var pos := Vector2i(btn_rect.position) + Vector2i(0, -int(_quality_menu.get_contents_minimum_size().y) - 8)
	_quality_menu.position = pos
	_quality_menu.popup()


func _on_quality(id: int) -> void:
	if id == STRETCH_ID:
		_ask_stretch()
		return
	var list := qualities_for(Director.resolved_frame())
	if id < 0 or id >= list.size():
		return
	_stretch = {}            # a whole export, never a stretch left from before
	_quality = list[id]
	var named := safe_name(String(name_provider.call())) if name_provider.is_valid() else ""
	_dialog.current_file = ("%s.mp4" % named) if not named.is_empty() else "ghost_notes_%s.mp4" % _quality.tag
	_dialog.popup_centered()


## [param title] as a file name every system accepts, still reading as the title: a colon becomes
## " -", the characters Windows refuses go, whitespace collapses, no trailing dot or space, and
## it stops at a word before 120 characters. "" when nothing is left.
static func safe_name(title: String) -> String:
	var t := title.replace(":", " -")
	var out := ""
	for ch in t:
		if ch.unicode_at(0) >= 32 and not "/\\*?\"<>|".contains(ch):
			out += ch
	out = Manuscript._rx("\\s+").sub(out, " ", true).strip_edges()
	if out.length() > 120:
		out = out.substr(0, 120)
		var cut := out.rfind(" ")
		if cut > 60:
			out = out.substr(0, cut)
	while out.ends_with(".") or out.ends_with(" "):
		out = out.left(-1)
	return out


func _on_path(out_path: String) -> void:
	# Re-entrancy guard: this method awaits a take render, and the native file dialog can deliver file_selected more than once.
	# Two overlapping runs would render the same take file from two threads and a reader in another process could open it
	# mid-write.
	if _prepping:
		return
	# The upload is decided with the path, by the note's YouTube card, and the sign-in starts now, while the person is still
	# at the machine to answer the browser, asking for what this upload needs (a playlist needs more than an upload). It runs
	# beside the render rather than in front of it.
	var peek := _upload_peek()
	_upload_this = not peek.is_empty() and not peek.has("refused")
	_upload_meta = {}
	# (a stretch goes back into a file, and the file goes up once it is whole, if at all)
	if not _stretch.is_empty():
		_upload_this = false
	if _upload_this:
		_check_sign_in(Callable(), scopes_for(peek), str(peek.get("channel", "")), str(peek.get("channel_name", "")),
			str(peek.get("client", "")))
	# _song was resolved at click time (_on_export): the live audio path. A session without a finished take renders one
	# now, after quality and path are committed: the provider is a coroutine, and the await is required.
	if _song.is_empty() and take_provider.is_valid():
		_prepping = true
		_set_status("⏳  Rendering the take…", Color(0.95, 0.92, 0.7))
		_song = String(await take_provider.call())
		_prepping = false
	if _song.is_empty():
		_song = Spectrum.audio_path()
	if _song.is_empty():
		_fail("⚠  No song to export")
		return
	_out = out_path
	if _out.get_extension().to_lower() != "mp4":
		_out += ".mp4"
	# what the upload says, asked of the mode now that the take exists (a mode times chapters from it)
	if _upload_this:
		var meta: Variant = upload_provider.call(_song) if upload_provider.is_valid() else {}
		_upload_meta = meta if meta is Dictionary else {}
		if _upload_meta.has("refused"):
			push_warning("ghost export: %s - the video is only saved" % str(_upload_meta["refused"]))
			_upload_meta = {}
		if _upload_meta.is_empty():
			_upload_this = false
			push_warning("ghost export: the mode described nothing to upload - the video is only saved")
	# Capture the duration now: the transcode runs for minutes, and the live song may have ended and Spectrum.song_length()
	# read 0.
	_song_dur = Spectrum.song_length()
	if _song_dur <= 0.0 and _song.get_extension().to_lower() == "wav":
		# a provider-rendered take Spectrum has not finished streaming: the file itself says how long it is ([method
		# _wav_seconds])
		_song_dur = _wav_seconds(_song)
	# Say what was decided, in the terminal: which file and how long are what export failures disagree about, and neither is
	# visible from the UI.
	print("ghost/export: take=%s  %.2fs @ %d Hz  ->  %s"
		% [_song, _song_dur, _wav_rate(_song) if _song.get_extension().to_lower() == "wav" else 0, _out])
	if _song_dur <= 1.0:
		printerr("ghost/export: WARNING - the take reads as %.2fs, so the render "
			% _song_dur + "will stop there. Check the text in the panel.")

	# Movie Maker records to this intermediate AVI (beside the final file, on the same disk), encoded to the chosen .mp4 as it
	# is written and on Linux taken out of the folder (see _hold). It is scratch only, so its 4 GB RIFF limit never reaches
	# the user.
	_avi = _out.get_basename() + ".render.avi"
	_cache = Bake.cache_path(_song)
	if FileAccess.file_exists(_cache):
		_start_render()                          # already analyzed -> straight to render
	else:
		_start_bake()


# Step 1: headless analysis (no window). Writes the spectrum cache, then exits.
func _start_bake() -> void:
	_pct = 0
	Bake.write_progress(0.0)
	var exe := OS.get_executable_path()
	var args := Subprocess.own_log("bake") + PackedStringArray(["--headless"])
	args.append_array(Boot.project_args())
	if OS.has_feature("editor"):
		args.append_array(PackedStringArray(["--script", "res://src/audio/bake_runner.gd"]))
	args.append_array(PackedStringArray(["--", "--bake-song", _song, "--bake-out", _cache]))
	_bake_pid = Subprocess.start(exe, args, "bake")
	if _bake_pid > 0:
		_state = "baking"
		print("ghost: analyzing audio (pid ", _bake_pid, ") -> ", _cache)
	else:
		_fail("⚠  Could not start the analysis process")


# Step 2: Movie Maker render that loads the cache (--bake-file) and draws at once.
func _start_render() -> void:
	_pct = 0
	_begin_scratch()
	Bake.write_progress(0.0)
	# Movie Maker locks its output resolution to the project's viewport size at engine startup, so the only way to drive it is
	# override.cfg, which Godot reads from the project root at boot. The chosen resolution is written there in "viewport"
	# stretch mode (an offscreen buffer of exactly that size, independent of the display) and removed when the render
	# finishes. Render at the supersampled size; the transcode resolves it back to w x h (see QUALITIES).
	_write_override(_render_w(), _render_h())
	var exe := OS.get_executable_path()
	var args := Subprocess.own_log("render") + Boot.project_args() + PackedStringArray([
		"--write-movie", _avi, "--fixed-fps", str(_quality.fps),
		"--", "--export", "--bake-file", _cache, "--audio", _song])
	# A STRETCH ONLY ([Stitch]): from the keyframe before it to the one after
	if not _stretch.is_empty():
		var sp := Stitch.span(float(_stretch["t0"]), float(_stretch["t1"]), _song_dur)
		_stretch["span"] = sp
		args.append_array(PackedStringArray(["--from", "%.3f" % sp.x, "--until", "%.3f" % sp.y]))
	# The seed: pin it only when there is a live session to reproduce (passing session_seed() otherwise would pin the render to
	# 0). Omitting --seed lets the render resolve it from the audio's own fingerprint (see Director._resolve_seed), so the
	# same take always renders the same show.
	var seed_val := Director.session_seed()
	if seed_val != 0:
		args.append("--seed")
		args.append(str(seed_val))
	# The medium, passed explicitly: `--medium` overrides the saved setting for one run, and the render must reproduce the
	# session, not the remembered default.
	args.append("--medium")
	args.append(Director.resolved_medium())
	# ...and the frame, for the same reason
	args.append("--frame")
	args.append(Director.resolved_frame())
	var board := _storyboard_arg()
	if not board.is_empty():
		args.append("--storyboard")
		args.append(board)
	# A display of its own, so the desktop cannot freeze the recording. Godot does not render while the compositor is not
	# drawing its window (`window_can_draw()`), and the movie writer then re-captures the last buffer while the audio clock
	# advances: the film holds a still for as long as the window is minimized, covered or throttled. On its own X display
	# there is no compositor; the NVIDIA driver still renders on the real GPU (tests/run_quiet.sh relies on that).
	#
	# Not required: without xvfb the render works, and the caller is told the cost.
	var runner := exe
	var run_args := args
	var virtual := virtual_display(exe, args)
	if not virtual.is_empty():
		runner = virtual[0]
		run_args = virtual.slice(1)
		print("ghost export: rendering on a virtual display - the desktop cannot freeze it")
	else:
		# xvfb-run is Linux-only; elsewhere the advice is the whole message.
		var fix := ("  " + Deps.hint("xvfb")) if OS.get_name() == "Linux" else ""
		push_warning("ghost export: no virtual display; the render window must stay drawable "
			+ "for the WHOLE render. Minimizing or burying it freezes the recorded picture "
			+ "while the audio keeps going." + fix)
		_note_no_virtual_display = true
	_render_pid = Subprocess.start(runner, run_args, "render")
	if _render_pid > 0:
		_state = "rendering"
		_stall_t = 0.0
		_stall_frac = -1.0
		_stall_size = 0
		if _render_w() != int(_quality.w):
			print("ghost: rendering %dx%d -> %dx%d @ %d fps (pid %d) -> %s" % [
				_render_w(), _render_h(), _quality.w, _quality.h, _quality.fps, _render_pid, _avi])
		else:
			print("ghost: rendering %dx%d @ %d fps (pid %d) -> %s" % [
				_quality.w, _quality.h, _quality.fps, _render_pid, _avi])
	else:
		_clear_override()
		_fail("⚠  Could not start the render process")


## The argv that runs `exe args` on a virtual display of its own (see [method _start_render]), or [] without xvfb-run. `-a`
## picks a free display number; the screen must be at least the size of the window (the 480x270 floater), never of the
## recorded viewport. [param screen] is for a caller that records the window itself ([Showcase]).
##
## Godot dies with its wrapper: Subprocess binds xvfb-run's shell to ghost, but a pact does not pass to the shell's
## children, so Godot gets a pact with the shell, and Xvfb ends [constant XVFB_LINGER] seconds after its last client leaves
## (the delay covers a connection a client opens and closes before its own).
static func virtual_display(exe: String, args: PackedStringArray, screen := Vector2i(960, 540)) -> PackedStringArray:
	var xvfb := Deps.resolve("xvfb-run")
	if xvfb.is_empty():
		return PackedStringArray()
	var argv := PackedStringArray([xvfb, "-a", "-s", "-screen 0 %dx%dx24 -terminate %d" % [screen.x, screen.y, XVFB_LINGER]])
	argv.append_array(Subprocess.pact_prefix())
	argv.append(exe)
	argv.append_array(args)
	return argv


# Step 3: transcode the scratch AVI into the chosen MP4 (H.264 + AAC) via ffmpeg. `-fflags +genpts` re-derives timestamps so
# a damaged AVI index is bypassed; audio is re-encoded from decoded PCM.
func _start_transcode(follow := false) -> void:
	var dur := _song_dur
	if not follow:
		_pct = 0              # reset from the render's 100% so "Finalizing" starts fresh, not stuck full
	_progress_reset()
	# Color signaling. Godot's MJPEG is yuvj420p (full range, BT.601) and ffmpeg passes the pixels through untouched, but did
	# not say so: without a `colr` box a player guesses BT.709 limited range for 1080p, which crushes the quarter to half of
	# the frame below code 16 to black (this content is mostly shadow).
	#
	# `setparams` is required: the bare -color_primaries/-color_trc output options are silently ignored by ffmpeg 8.x;
	# setparams stamps the frames, which the encoder reads. The matrix stays bt470bg because that is what Godot's writer
	# used. Do not use ffmpeg's `colorspace` filter to force limited range: it clamps instead of scaling.
	var gop := int(_quality.fps * Stitch.GOP_S)   # a keyframe every 2 s - YouTube's guidance (x264 defaults to 250), and where a stretch is cut ([Stitch])
	# The downscale is the antialiasing resolve (see QUALITIES). lanczos rather than bicubic, which lands ~18% below ground
	# truth in near-Nyquist energy (slightly soft). It must come before setparams, which stamps the outgoing frames.
	var vf := "setparams=color_primaries=bt709:color_trc=bt709:colorspace=bt470bg:range=pc"
	if _render_w() != int(_quality.w):
		vf = "scale=%d:%d:flags=lanczos," % [int(_quality.w), int(_quality.h)] + vf
	# following the render: read the AVI as it grows, and take a quiet file as the end of it
	var input := PackedStringArray(["-i", _avi])
	if follow:
		input = PackedStringArray(["-nostdin", "-follow", "1", "-rw_timeout", str(FOLLOW_TIMEOUT_US),
			"-i", "file:" + _avi])
	var args := PackedStringArray(["-y", "-fflags", "+genpts"]) + input + PackedStringArray([
		"-vf", vf,
		# crf 20: the MJPEG intermediate is the quality floor (crf 16 gains +0.1 dB for +51% size). `-tune grain` is what pays:
		# the default settings smear fine procedural detail (93.3% of high-frequency energy kept, 99.6% with grain tuning for
		# +1% size). `medium` rather than `fast` because grain tuning needs the extra analysis.
		"-c:v", "libx264", "-crf", "20", "-preset", "medium", "-tune", "grain", "-pix_fmt", "yuv420p",
		"-color_range", "pc", "-colorspace", "bt470bg",
		"-color_primaries", "bt709", "-color_trc", "bt709", "-chroma_sample_location", "center",
		# +faststart puts the index at the front: Instagram's API requires it
		"-g", str(gop), "-keyint_min", str(gop), "-movflags", "+write_colr+faststart",
		"-c:a", "aac", "-b:a", "192k",
		"-progress", ProjectSettings.globalize_path(_PROGRESS_FILE), "-nostats", "-loglevel", "error",
		_out])
	_transcode_pid = Subprocess.start("ffmpeg", args, "transcode")
	if follow:
		_live_encode = _transcode_pid > 0
		_punched = PUNCH_KEEP
		_punch_t = 2.0
		if _live_encode:
			_hold_scratch()
			print("ghost: encoding while rendering (pid %d) %s -> %s" % [_transcode_pid, _avi, _out])
		return
	if _transcode_pid > 0:
		_state = "transcoding"
		print("ghost: transcoding (pid %d, %.0fs) %s -> %s" % [_transcode_pid, dur, _avi, _out])
	else:
		# No ffmpeg: the MP4 cannot be made. Leave the raw AVI so the render is not wasted.
		_state = "done"
		_done_t = 30.0
		_set_status("⚠  ffmpeg not found; raw file kept: %s" % _avi, Color(1.0, 0.7, 0.6))


## Release the AVI's bytes the following encoder has already read. Linux only (a punched hole frees the blocks while the file
## keeps its length); the encoder's read position comes from /proc. Elsewhere the encode still follows the render but the
## space comes back only at the end.
func _punch_behind_encoder() -> void:
	if OS.get_name() != "Linux" or _transcode_pid <= 0 or not Deps.has("fallocate"):
		return
	# Only while the header says "size unknown": mid-render Movie Maker writes 0 for the RIFF size, so the encoder reads
	# straight through and everything behind it is done with. A finished header names the index at the end, and a reader that
	# jumps there would have its unread data released under it.
	if _riff_size() != 0:
		return
	var pos := _encoder_read_pos()
	var upto := (pos - PUNCH_BEHIND) / 4096 * 4096
	if pos < 0 or upto <= _punched:
		return
	var target := _release_target()
	if target.is_empty():
		return
	var out: Array = []
	var code := Deps.execute("fallocate", ["--punch-hole", "--offset", str(_punched),
		"--length", str(upto - _punched), target], out)
	if code == 0:
		_punched = upto
		_released = true
		_unlink_scratch()
	else:
		push_warning("ghost export: could not release scratch space (%s) - the file will grow" % str(out))
		_punched = 1 << 62               # stop trying


## How far into the AVI the encoder has read: its open descriptor's offset, from /proc.
func _encoder_read_pos() -> int:
	var dir := "/proc/%d/fd" % _transcode_pid
	var d := DirAccess.open(dir)
	if d == null:
		return -1
	var want := ProjectSettings.globalize_path(_avi)
	for fd in DirAccess.get_files_at(dir):
		var link := d.read_link(dir.path_join(fd))
		if link != want and link != want + " (deleted)":
			continue
		# read, not sized: /proc files report a length of 0
		var f := FileAccess.open("/proc/%d/fdinfo/%s" % [_transcode_pid, fd], FileAccess.READ)
		if f == null:
			return -1
		for line in f.get_buffer(4096).get_string_from_utf8().split("\n"):
			if line.begins_with("pos:"):
				return int(line.substr(4).strip_edges())
	return -1


## A fresh scratch for a new render. A file already at the path goes first: the live encoder starts on whatever is there.
func _begin_scratch() -> void:
	_drop_scratch(false)
	_unlinked = false
	_released = false
	_transcode_pid = -1
	_live_encode = false
	_punched = PUNCH_KEEP
	if not _avi.is_empty() and FileAccess.file_exists(_avi):
		DirAccess.remove_absolute(_avi)


## Hold the scratch open and learn which descriptor holds it, so it can still be measured and released once its name is
## gone (see [member _hold]). The render and the encoder are other processes, so the one descriptor of ghost's that names
## the scratch is this one. Linux only (needs /proc); elsewhere the scratch keeps its name to the end.
func _hold_scratch() -> void:
	_drop_scratch(false)
	if OS.get_name() != "Linux":
		return
	_hold = FileAccess.open(_avi, FileAccess.READ)
	var dir := "/proc/%d/fd" % OS.get_process_id()
	var d := DirAccess.open(dir)
	if _hold == null or d == null:
		return
	var want := ProjectSettings.globalize_path(_avi)
	for fd in DirAccess.get_files_at(dir):
		if d.read_link(dir.path_join(fd)) == want:
			_held = dir.path_join(fd)
			return


## Take the scratch's name out of the folder, only once a release has worked through ghost's own handle.
func _unlink_scratch() -> void:
	if _unlinked or _held.is_empty():
		return
	if DirAccess.remove_absolute(_avi) == OK:
		_unlinked = true
		print("ghost: the scratch is given back as it is encoded - %s is out of the folder" % _avi.get_file())


## Where fallocate reaches the scratch: through ghost's own descriptor when there is one (checked to still be the scratch),
## else by name.
func _release_target() -> String:
	var want := ProjectSettings.globalize_path(_avi)
	if _held.is_empty():
		return "" if _unlinked else want
	var d := DirAccess.open(_held.get_base_dir())
	var link := d.read_link(_held) if d != null else ""
	return _held if link == want or link == want + " (deleted)" else ""


## Let go of the scratch: close ghost's handle; with [param remove], delete it if it still has a name.
func _drop_scratch(remove := true) -> void:
	if _hold != null:
		_hold.close()
		_hold = null
	_held = ""
	if remove and not _unlinked and not _avi.is_empty() and FileAccess.file_exists(_avi):
		DirAccess.remove_absolute(_avi)


func _scratch_len() -> int:
	return _hold.get_length() if _hold != null else _file_size(_avi)


## The RIFF size in the scratch's header: 0 while Movie Maker is still writing, -1 when it cannot be read.
func _riff_size() -> int:
	var f := _hold if _hold != null else FileAccess.open(_avi, FileAccess.READ)
	if f == null:
		return -1
	f.seek(4)
	return f.get_32()


## The encoder quit while the render went on: the header is unfinished, so Movie Maker is still writing. A following
## encoder ends itself only after FOLLOW_TIMEOUT_US with nothing new, so this is a render stalled that long, or ffmpeg
## failing. Left alone, the render fills a file nobody reads and the export calls the short MP4 saved.
func _encoder_quit_early() -> void:
	if not _released:
		# nothing given back yet, so the AVI is whole: let the render finish and encode it then
		push_warning("ghost export: the encoder stopped early - encoding once the render finishes")
		_live_encode = false
		_drop_scratch(false)
		return
	var at := _read_transcode_pct()
	Subprocess.stop(_render_pid)
	_clear_override()
	_drop_scratch()
	_fail("⚠  Encoding stopped at %d%% while the render went on - export abandoned (see console)" % at)


const _PROGRESS_FILE := "user://transcode_progress.txt"


func _progress_reset() -> void:
	var f := FileAccess.open(_PROGRESS_FILE, FileAccess.WRITE)
	if f != null:
		f.store_string("")
		f.close()


# ffmpeg writes `out_time_us=<microseconds>` lines to the progress file; the fraction of the captured song duration
# (`_song_dur`) it has reached is the transcode percent. Tolerates partial reads.
func _read_transcode_pct() -> int:
	if _song_dur <= 0.0 or not FileAccess.file_exists(_PROGRESS_FILE):
		return _pct
	var text := FileAccess.get_file_as_string(_PROGRESS_FILE)
	var best := -1.0
	for line in text.split("\n"):
		if line.begins_with("out_time_us="):
			best = maxf(best, line.substr(12).to_float() / 1_000_000.0)
		elif line.begins_with("out_time_ms="):     # older ffmpeg (value is microseconds despite the name)
			best = maxf(best, line.substr(12).to_float() / 1_000_000.0)
	if best >= 0.0:
		_pct = clampi(int(round(best / _song_dur * 100.0)), 0, 99)
	return _pct


# Godot's AVI writer keeps 32-bit RIFF/LIST size fields; past 4 GiB the sizes wrap (mod 2^32) while the chunks after them
# stay correct. The repair sets the RIFF size and the movi LIST size to 0 ("size unknown, read to end of file"), so any
# demux becomes a sequential walk of the intact chunks. No-op under 4 GiB.
func _repair_avi_sizes(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.READ_WRITE)
	if f == null:
		return
	if f.get_length() < 4294967296:
		f.close()
		return
	f.seek(4)
	f.store_32(0)                       # RIFF size -> unknown
	var pos := 12
	for i in 64:                        # walk top-level chunks to the movi LIST
		f.seek(pos)
		var tag := f.get_buffer(4).get_string_from_ascii()
		var csize := f.get_32()
		if tag == "LIST" and f.get_buffer(4).get_string_from_ascii() == "movi":
			f.seek(pos + 4)
			f.store_32(0)               # movi size -> unknown
			print("ghost export: repaired wrapped >4GiB AVI sizes in ", path.get_file())
			break
		if csize <= 0 or tag.is_empty():
			break
		pos += 8 + csize + (csize & 1)
	f.close()


## The sample rate a WAV declares, from its fmt chunk (canonical 44-byte header, rate at byte 24). Falls back to the
## formant synthesizer's rate if the file cannot be read.
static func _wav_rate(path: String) -> int:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null or f.get_length() < 44:
		return Voice.SR
	f.seek(24)
	var rate := f.get_32()
	f.close()
	return rate if rate > 0 else Voice.SR


## How long a PCM WAV plays: its `data` chunk over the byte rate its `fmt ` chunk gives (rate x channels x bytes a sample),
## the chunks walked in case others come between; 0 when unreadable. Never from an assumed format: a neural voice renders at
## its model's rate (Piper's 22050), and a take is stereo when a voice leans ([VoiceFX]).
static func _wav_seconds(path: String) -> float:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null or f.get_length() < 12 or f.get_buffer(4).get_string_from_ascii() != "RIFF":
		return 0.0
	f.get_32()
	if f.get_buffer(4).get_string_from_ascii() != "WAVE":
		return 0.0
	var byte_rate := 0
	while f.get_position() + 8 <= f.get_length():
		var id := f.get_buffer(4).get_string_from_ascii()
		var size := f.get_32()
		var body := f.get_position()
		if id == "fmt " and size >= 16:
			f.seek(body + 8)
			byte_rate = f.get_32()
		elif id == "data":
			# a take still being written may say 0, or more than is there: what is there is what plays
			var have := f.get_length() - body
			return float(have if size == 0 or size > have else size) / float(byte_rate) if byte_rate > 0 else 0.0
		f.seek(body + size + (size & 1))
	return 0.0


func _file_size(path: String) -> int:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return 0
	var s := f.get_length()
	f.close()
	return s


# override.cfg lives in the project root only for the duration of a render; Godot reads it at startup to override
# project.godot (the export's output resolution and stretch mode). _ready() also clears a stale copy.
func _override_path() -> String:
	return Boot.project_dir().path_join("override.cfg")


## The size the scene is rendered at: the output size times the preset's supersample factor, rounded to an even number of
## pixels (yuv420p cannot encode an odd dimension). The output size is `_quality.w/h`; ffmpeg resolves one to the other.
func _render_w() -> int:
	return _even(int(_quality.w) * float(_quality.get("ss", 1.0)))


func _render_h() -> int:
	return _even(int(_quality.h) * float(_quality.get("ss", 1.0)))


static func _even(v: float) -> int:
	return int(round(v * 0.5)) * 2


## The presets a show in [param frame] is exported at.
static func qualities_for(frame: String) -> Array:
	return PORTRAIT_QUALITIES if frame == "portrait" else QUALITIES


## The quality items as the show's frame has them: a portrait show's two presets in the first two places, the 4K one grayed
## with why. The items keep their ids.
func _label_qualities() -> void:
	var list := qualities_for(Director.resolved_frame())
	for i in QUALITIES.size():
		var at := _quality_menu.get_item_index(i)
		if at < 0:
			continue
		var have := i < list.size()
		_quality_menu.set_item_text(at, String(list[i].label) if have else String(QUALITIES[i].label) + "  - landscape only")
		_quality_menu.set_item_disabled(at, not have)
		_quality_menu.set_item_tooltip(at, "" if have else "No 4K portrait: Shorts stop at 1080p and Instagram at 1920 pixels wide.")


## The OS window an export records in, and the override's stretch: a window shaped like the frame. Under the project's
## `expand` aspect Godot widens the viewport to the window's shape, so a 1080x1920 render in a 480x270 window would lose the
## edges of the picture (next/notes.md, "the trap"). A portrait override shapes the window like the frame and says
## `aspect="keep"`; a landscape one is written plainly.
static func override_text(w: int, h: int) -> String:
	var portrait := h > w
	var win := Vector2i(270, 480) if portrait else Vector2i(480, 270)
	var t := "[display]\n\nwindow/size/viewport_width=%d\nwindow/size/viewport_height=%d\nwindow/size/window_width_override=%d\nwindow/size/window_height_override=%d\nwindow/stretch/mode=\"viewport\"\n" % [w, h, win.x, win.y]
	if portrait:
		t += "window/stretch/aspect=\"keep\"\n"
	return t + "\n[editor]\n\nmovie_writer/video_quality=1.0\n"


## What the render is told to walk, "" for the seeded show: the note's storyboard as its panel plans it ([member
## show_provider]), else the one the Director is walking. A file's is its path; one a note keeps is written out in its loaded
## form beside the render's other scratch.
func _storyboard_arg() -> String:
	var plan: Variant = show_provider.call() if show_provider.is_valid() else {}
	var board: Variant = (plan as Dictionary).get("board", {}) if plan is Dictionary else {}
	if board is Dictionary and not (board as Dictionary).is_empty():
		var named := String((plan as Dictionary).get("source", ""))
		return named if not named.is_empty() else _write_board(Storyboard.raw_of(board as Dictionary))
	if not Director.is_manual():
		return ""
	var source := Director.storyboard_source()
	return source if not source.is_empty() else _write_board(Director.storyboard_data())


func _write_board(data: Dictionary) -> String:
	var path := ProjectSettings.globalize_path("user://export_storyboard.yaml")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("ghost export: could not write the note's storyboard for the render (%s)" % path)
		return ""
	f.store_string(Storyboard.to_yaml(data))
	f.close()
	return path


func _write_override(w: int, h: int) -> void:
	var f := FileAccess.open(_override_path(), FileAccess.WRITE)
	if f == null:
		push_warning("ghost export: could not write override.cfg (resolution may default)")
		return
	# viewport_* set the rendered (recorded) resolution; window_*_override shrink the OS window to a floater. In "viewport"
	# stretch mode the two are independent. The window must stay drawable: minimizing it makes Godot skip rendering (see
	# boot.gd).
	# The intermediate's quality (the [editor] half of [method override_text]; see MaskExport.write_override): Godot writes
	# .avi as MJPEG in yuvj420p at `video_quality` 0.75, a lossy generation before x264 sees a frame (42.6 dB through the
	# default intermediate against 45.5 for a single generation). The bigger scratch file is deleted seconds later.
	f.store_string(override_text(w, h))
	f.close()


func _clear_override() -> void:
	var path := _override_path()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _fail(msg: String) -> void:
	_clear_override()
	_upload_this = false
	_stretch = {}            # a stretch that failed is over: the next export is a whole one
	_state = "done"
	_done_t = 8.0
	_set_status(msg, Color(1.0, 0.7, 0.6))
	push_warning("ghost export: " + msg)


func _set_status(text: String, color: Color) -> void:
	var t := text + _sign_note()
	if t != _status.text:
		_status.text = t
		# back to one line's height after the text: a label grown by a long line does not shrink by itself
		_status.offset_top = -110.0 - _inset
	_status.add_theme_color_override("font_color", color)
	_status.visible = true


# --- YouTube -------------------------------------------------------------------------------------

## While an export going to YouTube is being made, how its sign-in stands, on the progress line.
func _sign_note() -> String:
	if not _upload_this or not (_prepping or _state in ["baking", "rendering", "transcoding"]):
		return ""
	match _sign:
		"client":
			return "   ⇪ import your Google client file"
		"signing_in":
			return "   ⇪ sign in to YouTube in your browser"
		"ok":
			var named := YouTube.name_of(YouTube.channel(_sign_landed))
			return "   ⇪ YouTube: " + (named if not named.is_empty() else "signed in")
		"failed":
			return "   ⇪ no upload: " + _sign_why
	return ""


## Is a mode's take being made for an export right now? The take is a coroutine on the mode's panel ([member
## take_provider]), so the mode must not be left meanwhile (see main.leave_blocker).
func preparing() -> bool:
	return _prepping


## What the mode would upload now, {} for nothing (see [member upload_provider]).
func _upload_peek() -> Dictionary:
	if not upload_provider.is_valid():
		return {}
	var m: Variant = upload_provider.call("")
	return m if m is Dictionary else {}


## The scopes an upload described by [param meta] asks Google for: the upload's, and the
## playlists' when it joins one.
static func scopes_for(meta: Dictionary) -> Array:
	return [YouTube.SCOPE, YouTube.PLAYLIST_SCOPE] if not str(meta.get("playlist", "")).is_empty() else [YouTube.SCOPE]


# --- what a YouTube card asks of the exporter -----------------------------------------------------
#
# The sign-in, its dialog and the Google client's file dialog stay here, beside the upload that waits on them: the exporter
# outlives every note. A card ([YouTubeCard]) calls these and reads [method youtube].

## The sign-in and the upload (youtube.gd), for a card to read its phase and progress and to list playlists through.
func youtube() -> Node:
	return _yt


## Sets uploads up, visibly: the sign-in of channel [param channel] (called [param named]; "" for a new one) asking for
## [param scopes], when none is kept or it may not do all of them; and the Google client file first when a sign-in is
## needed and none is kept. A browser goes through the client [param through] names, "" for the channel's own ([method
## YouTube.client_for]); [param move] opens it even for a channel still signed in, which keeps that sign-in unless this one
## lands. [param then] runs once signed in, handed the channel's id; nothing runs on a cancel or a failure.
func youtube_sign_in(then := Callable(), scopes: Array = [YouTube.SCOPE], channel := "", named := "", through := "", move := false) -> void:
	_check_sign_in(then, scopes, channel, named, through, move)


## Ask for a Google client file (another one, when one is kept); [param then] runs once it is imported.
func youtube_import_client(then := Callable()) -> void:
	_client_then = then
	_client_dialog.popup_centered()


## Sign out of channel [param channel] and take it off the list.
func youtube_sign_out(channel: String) -> void:
	_sign_out(channel)


## Send the upload that waits in pending.json (an earlier export's, from any note).
func youtube_resume() -> void:
	_resume_upload()


## Is an upload on its way - its thumbnail being taken, its sign-in awaited, or its bytes going up?
func youtube_busy() -> bool:
	return _state in ["preparing", "upload_wait", "uploading"]


## The sign-in an upload needs, settled where the person can see it: channel [param channel]'s kept sign-in is renewed, and
## one that is missing, has lapsed or may not do all of [param scopes] (or a new channel's, "") opens the browser beside a
## dialog that says what is awaited, can open the page again, copy its link, and cancel; with no Google client kept, its
## file is asked for first. A sign-in that lands on another channel than [param channel] (called [param named]) is kept for
## that one and fails this, saying so. A newer check replaces one still waiting. [param then] runs once signed in, handed
## the channel; the export's own check runs nothing (its upload waits on [member _sign]). [param through] and [param move]:
## see [method youtube_sign_in]. Only the person's own press moves a channel.
func _check_sign_in(then := Callable(), scopes: Array = [YouTube.SCOPE], channel := "", named := "", through := "", move := false) -> void:
	_sign_attempt += 1
	var mine := _sign_attempt
	_sign_then = then
	_sign_scopes = scopes
	_sign_channel = channel
	_sign_named = named
	_sign_through = through
	_sign_move = move
	_sign_why = ""
	_sign = "checking"
	if YouTube.signed_in(channel) and not move:
		var tok: Dictionary = await _yt.access_token(channel)
		if mine != _sign_attempt:
			return
		if not tok.has("error") and YouTube.missing_scopes(scopes, channel).is_empty():
			_signed_in(then, channel)
			return
		if tok.has("error") and not tok.has("signed_out"):
			# Google could not be reached: a browser would not help
			_sign = "failed"
			_sign_why = str(tok["error"])
			if then.is_valid():
				_show_sign_failed(_sign_why)
			return
	if not YouTube.has_client():
		_sign = "client"
		_client_then = func() -> void: _check_sign_in(then, scopes, channel, named, through, move)
		_client_dialog.popup_centered()
		return
	# A sign-in replaces the one kept, so it asks again for what that one could already do
	var ask: Array = [YouTube.SCOPE]
	for sc in scopes + ([YouTube.PLAYLIST_SCOPE] if YouTube.granted(YouTube.PLAYLIST_SCOPE, channel) else []):
		if not ask.has(sc):
			ask.append(sc)
	_sign = "signing_in"
	_show_sign_wait()
	var got: Dictionary = await _yt.sign_in(ask, through, channel)
	if mine != _sign_attempt:
		return
	var err := str(got.get("error", ""))
	var landed: Dictionary = got.get("channel", {}) if got.get("channel") is Dictionary else {}
	var id := str(landed.get("id", ""))
	if err.is_empty() and not channel.is_empty() and id != channel:
		var meant := named if not named.is_empty() else YouTube.name_of(YouTube.channel(channel))
		meant = meant if not meant.is_empty() else "the channel this note uploads to"
		err = "that signed in to %s, not %s - sign in again and choose %s" % [YouTube.name_of(landed), meant, meant]
	if err.is_empty() and not YouTube.missing_scopes(scopes, id).is_empty():
		err = "Google signed in without letting Ghost Notes see and manage the channel's playlists"
	if err.is_empty():
		_signed_in(then, id)
		return
	_sign = "failed"
	_sign_why = err
	_show_sign_failed(err)


func _signed_in(then: Callable, channel: String) -> void:
	_sign = "ok"
	_sign_landed = channel
	_sign_dialog.hide()
	if _state == "idle":
		_note_t = 5.0
		_set_status("✓  Signed in to YouTube as %s" % YouTube.name_of(YouTube.channel(channel)), Color(0.82, 0.95, 0.86))
	if then.is_valid():
		then.call(channel)


func _show_sign_wait() -> void:
	var meant := _sign_named if not _sign_named.is_empty() else YouTube.name_of(YouTube.channel(_sign_channel))
	_sign_dialog.dialog_text = ("Signing in%s through %s.\n\n" % [" to " + meant if not meant.is_empty() else "", _sign_project()]
		+ SIGN_WAIT + "\n\n" + SIGN_BLOCKED % _sign_project())
	_sign_dialog.ok_button_text = "Cancel"
	_sign_again.text = "Open the page again"
	_sign_copy.text = "Copy the link"
	_sign_copy.visible = true
	if not _sign_dialog.visible:
		_sign_dialog.popup_centered(Vector2i(560, 0))


func _show_sign_failed(why: String) -> void:
	var hint := SIGN_BLOCKED % _sign_project() if why.contains("timed out") or why.contains("access_denied") else ""
	_sign_dialog.dialog_text = "The YouTube sign-in did not finish: %s.%s" % [why, ("\n\n" + hint) if not hint.is_empty() else ""]
	_sign_dialog.ok_button_text = "Close"
	_sign_again.text = "Try again"
	_sign_copy.visible = false
	if not _sign_dialog.visible:
		_sign_dialog.popup_centered(Vector2i(560, 0))


## The Cloud project the sign-in at hand goes through, which is whose test users Google asks after.
func _sign_project() -> String:
	return YouTube.client_name(YouTube.client_for(_sign_through, _sign_channel))


func _on_sign_action(action: StringName) -> void:
	match String(action):
		"again":
			if _yt.phase == "signing_in":
				_yt.reopen_sign_in()
			else:
				_check_sign_in(_sign_then, _sign_scopes, _sign_channel, _sign_named, _sign_through, _sign_move)
		"copy":
			DisplayServer.clipboard_set(_yt.sign_in_url)
			_sign_copy.text = "Link copied"


## The dialog closed: while a sign-in waits, that cancels it. An export goes on and saves its video; the upload then waits
## to be resumed from the menu.
func _on_sign_close() -> void:
	_sign_copy.text = "Copy the link"
	if _sign != "signing_in":
		return
	_sign_attempt += 1
	_yt.stop_sign_in()
	_sign = "failed"
	_sign_why = "the sign-in was cancelled"
	if _state == "idle":
		_note_t = 5.0
		_set_status("YouTube sign-in cancelled", Color(0.95, 0.92, 0.7))


## The Google client file, picked: imported, then on to whatever asked for it (a sign-in).
func _on_client_file(path: String) -> void:
	var then := _client_then
	_client_then = Callable()
	var err: String = YouTube.import_client(path)
	if not err.is_empty():
		_note_t = 10.0
		_set_status("⚠  " + err, Color(1.0, 0.7, 0.6))
		_client_failed(err)
		return
	_note_t = 6.0
	_set_status("✓  Google client imported - it stays on the Client list of every YouTube card", Color(0.82, 0.95, 0.86))
	if then.is_valid():
		then.call()


## No client file was picked: a sign-in that waited on one has failed, and an upload waiting on it stays resumable.
func _on_client_cancel() -> void:
	_client_then = Callable()
	_client_failed("no Google client file was imported")


func _client_failed(why: String) -> void:
	if _sign != "client":
		return
	_sign_attempt += 1
	_sign = "failed"
	_sign_why = why


## The saved export joins the queue at once, so a quit, a lapsed sign-in or a dropped connection leaves it resumable, and
## goes up once the sign-in settles (see the `upload_wait` state).
func _queue_upload() -> void:
	_upload_this = false
	# The thumbnail first, as the YouTube card chose it: a picture made for it, beside the video so the queued upload holds its
	# own; or a frame of the saved video at the moment named. One that cannot be had only costs the thumbnail, and the line
	# says why.
	var thumb := ""
	var given := str(_upload_meta.get("thumbnail", ""))
	var at := float(_upload_meta.get("thumbnail_at", -1.0))
	_thumb_why = str(_upload_meta.get("thumbnail_why", ""))
	if not given.is_empty():
		thumb = _beside(given, _out)
	elif at >= 0.0:
		_state = "preparing"
		thumb = await _take_thumbnail(_out, at)
	# the note's channel; a note with none yet goes to the one its sign-in lands on
	var channel := str(_upload_meta.get("channel", ""))
	if channel.is_empty() and _sign == "ok":
		channel = _sign_landed
	var q: Dictionary = YouTube.queue(_out, YouTube.video_body(_upload_meta, _out.get_file().get_basename()),
		channel, str(_upload_meta.get("record", "")), thumb, str(_upload_meta.get("playlist", "")))
	if q.has("error"):
		_state = "done"
		_done_t = 30.0
		_set_status("✓  Saved  %s   ⚠ not uploaded: %s" % [_out, q["error"]], Color(1.0, 0.85, 0.6))
		return
	_upload_file = _out
	_state = "upload_wait"


## A frame of [param video] at [param at] seconds, as a 1280x720 JPEG beside it (YouTube's thumbnail size): its path, or ""
## when ffmpeg could not make one.
func _take_thumbnail(video: String, at: float) -> String:
	var jpg := video.get_basename() + ".thumbnail.jpg"
	DirAccess.remove_absolute(jpg)
	var pid := Subprocess.start("ffmpeg", thumbnail_args(video, jpg, at, int(_quality.h) > int(_quality.w)), "thumbnail")
	if pid <= 0:
		return ""
	var t0 := Time.get_ticks_msec()
	while Subprocess.alive(pid) and Time.get_ticks_msec() - t0 < 30000:
		await (Engine.get_main_loop() as SceneTree).process_frame
	if Subprocess.alive(pid):
		Subprocess.stop(pid)
		return ""
	if _file_size(jpg) < 1024:
		push_warning("ghost export: no thumbnail could be taken from %s at %.1f s" % [video.get_file(), at])
		return ""
	print("ghost: thumbnail taken at %.1f s -> %s" % [at, jpg])
	return jpg


## The picture at [param image] copied beside [param video] as its thumbnail: the copy's path, or the picture's own when it
## cannot be copied.
static func _beside(image: String, video: String) -> String:
	var to := video.get_basename() + ".thumbnail." + image.get_extension().to_lower()
	if not FileAccess.file_exists(image):
		return ""
	DirAccess.remove_absolute(to)
	return to if DirAccess.copy_absolute(image, to) == OK else image


## ffmpeg's arguments for [method _take_thumbnail]: seek, one frame, scaled to 1280x720 (720x1280 for a portrait frame).
static func thumbnail_args(video: String, jpg: String, at: float, portrait := false) -> PackedStringArray:
	return PackedStringArray(["-y", "-nostdin", "-loglevel", "error", "-ss", "%.3f" % maxf(at, 0.0), "-i", video,
		"-frames:v", "1", "-vf", "scale=%s:flags=lanczos" % ("720:1280" if portrait else "1280:720"), "-q:v", "2", jpg])


## What a finished portrait export says when it is too long to be a Short.
func _shorts_note() -> String:
	if int(_quality.h) > int(_quality.w) and _song_dur > SHORT_MAX:
		return "   - %s long, so not a Short (3:00 at most)" % Clock.text(_song_dur)
	return ""


func _resume_upload() -> void:
	var p: Dictionary = YouTube.pending()
	if p.is_empty():
		return
	_thumb_why = ""
	_upload_file = str(p.get("file", ""))
	_state = "upload_wait"
	_check_sign_in(Callable(), scopes_for(p), str(p.get("channel", "")))


## Send the queued upload; the state is set before the first await, so the frame loop starts it once. One queued before its
## note had a channel goes to the one its sign-in landed on.
func _run_upload() -> void:
	_state = "uploading"
	if _sign == "ok":
		YouTube.aim_pending(_sign_landed)
	# who it was meant for, read before the upload forgets its pending record
	var body: Variant = YouTube.pending().get("body", {})
	var status: Variant = (body as Dictionary).get("status", {}) if body is Dictionary else {}
	var asked := str((status as Dictionary).get("privacyStatus", YouTube.PRIVACY)) if status is Dictionary else YouTube.PRIVACY
	var res: Dictionary = await _yt.resume()
	_state = "done"
	_done_t = 60.0
	if res.has("error"):
		var later := "" if YouTube.pending().is_empty() else " - resume it from the YouTube card"
		_set_status("⚠  The YouTube upload stopped: %s%s" % [res["error"], later], Color(1.0, 0.7, 0.6))
		return
	var url := str(res.get("url", ""))
	var privacy := str(res.get("privacy", ""))
	DisplayServer.clipboard_set(url)
	if not privacy.is_empty() and privacy != asked:
		# what YouTube does with uploads from a Cloud project that has not passed its API audit
		_set_status("✓  On YouTube, but YouTube kept it %s: %s (link copied)" % [privacy, url], Color(1.0, 0.85, 0.6))
		push_warning("ghost: YouTube kept the upload %s - uploads from a Cloud project that has not "
			% privacy + "passed YouTube's API audit stay private until it does")
		return
	var thumb_err := str(res.get("thumbnail_error", "")) if not str(res.get("thumbnail_error", "")).is_empty() else _thumb_why
	if not thumb_err.is_empty():
		push_warning("ghost: YouTube - the thumbnail was not set: " + thumb_err)
	var list_err := str(res.get("playlist_error", ""))
	if not list_err.is_empty():
		push_warning("ghost: YouTube - the video was not added to its playlist: " + list_err)
	var warn := ("   ⚠ thumbnail not set: " + thumb_err) if not thumb_err.is_empty() else ""
	if not list_err.is_empty():
		warn += "   ⚠ not in the playlist: " + list_err
	_set_status("✓  On YouTube (%s): %s  (link copied)%s" % [privacy if not privacy.is_empty() else asked, url, warn],
		Color(0.82, 0.95, 0.86) if warn.is_empty() else Color(1.0, 0.85, 0.6))


func _sign_out(channel: String) -> void:
	var named := YouTube.name_of(YouTube.channel(channel))
	await _yt.sign_out(channel)
	_note_t = 6.0
	_set_status("Signed out of %s and took it off the list (the Google client file stays imported)"
		% (named if not named.is_empty() else "the channel"), Color(0.95, 0.92, 0.7))


## Lift the button and its status line clear of whatever the mode has put along the bottom of the frame. See
## Chrome.bottom_inset.
func set_bottom_inset(v: float) -> void:
	_inset = v
	if _btn != null and _btn.get_parent() == self:      # in the row, the row moves it
		_btn.offset_top = -68.0 - _inset
		_btn.offset_bottom = -28.0 - _inset
	_place_status()


## The status line has a row of its own above the buttons, and wraps: as wide as the window allows, never wider than
## [constant STATUS_W], ending at the row's right edge, extra lines growing upward. (See [method set_bottom_inset] for when
## a mode claims the bottom of the frame.)
func _place_status() -> void:
	if _status == null:
		return
	var w := STATUS_W
	var vp := get_viewport() if is_inside_tree() else null
	if vp != null:
		w = minf(STATUS_W, maxf(160.0, vp.get_visible_rect().size.x - 56.0))
	_status.offset_left = -28.0 - w
	_status.offset_right = -28.0
	_status.offset_top = -110.0 - _inset
	_status.offset_bottom = -74.0 - _inset
