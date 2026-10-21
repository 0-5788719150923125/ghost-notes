extends RefCounted
class_name MaskTracks

## MaskTracks - THE CLIP'S TRACKS: the trim lanes under the marker strip, a second clip imported onto
## the timeline, and every track kept in step with the master clock. A part of [MaskEditor]
## (next/structure.md, step 25).
##
## The main clip's own lane and one per `session.tracks` entry, all on the editor's one
## [TimelineView]; a track imported is a lane first and a transcode second ([method finish_import]);
## a track's sound is a sidecar `.ogg` demuxed in the background ([method poll_audio]); split and
## delete edit `session.tracks`; and each frame [method sync] decides which track is playing - a
## continuation that owns the main view, or a picture-in-picture over it - and keeps its player on the
## master's time.
##
## IT HOLDS ITS OWN STATE (each track's players and views, the background jobs, the import in
## flight) and reads the rest through [member editor]: the session, the master player, the lanes'
## column and the video's area, the undo stack, the status line.

## The [MaskEditor] this is a part of: everything read through it is something this part
## is handed, and the list of them is what it depends on.
var editor: MaskEditor

var audio_jobs: Array = []  # background sidecar-.ogg extractions, {pid, index, ogg}
## Runtime state per session.tracks[i] - NOT persisted (session.tracks holds only
## the data; players/views are rebuilt from it every _ready_with_session). Each:
## {player: VideoStreamPlayer, view: TextureRect, active: bool}. `active` tracks
## whether the track is CURRENTLY the one playing (see sync) so entering/
## leaving its window on the master timeline only seeks+starts/pauses it once,
## not every frame.
var runtime: Array = []
var _import_dialog: FileDialog
var import_pid := -1
var _import_pending := {}   # {source, video, index} - the lane is added up front, this tracks its transcode
# Per-lane reserved height. MUST cover a TrackLane's own minimum (26px, see
# track_lane.gd) PLUS the _lanes_col VBox's inter-lane separation (2px), or the
# lane stack overflows its allocated rect and - drawing above the marker strip it
# abuts - spills over the timeline's top edge, clipping the marker flags and the
# playhead timestamp tag (worsening with each imported track). 26 + 2 = 28.
const _LANE_H := 28.0
# The volume knob every lane gets (see _volume_knob) is anchored top-left, offset_right
# 34 - a lane's own label must start past that plus a small gap, or the two draw on top
# of each other whenever the lane's own left edge sits near local x0 (the primary lane's
# offset is always 0, so this bites it every time - see feedback/0009).
const _LANE_LABEL_LEFT := 38.0

# --- tracks: trim lanes, import, playback sync ------------------------------------------------

## A secondary track's own composited view: a raw (unshaded - the masking
## effects system keys off ONE frame's colors via the primary's shader chain,
## not built for a second independent source yet) picture-in-picture box. It
## takes over the SAME inset slot _mask_wrap occupies (bottom-right) rather
## than getting its own corner - there is only ever one PiP box on screen at
## a time; see sync, which hides _mask_wrap for as long as a track's
## own box is showing (feedback/0056: a stray, always-empty second box used
## to sit at a separate default corner on top of the real one).
func build_view(i: int) -> void:
	var track: Dictionary = editor.session.tracks[i]
	var player := VideoStreamPlayer.new()
	player.stream = load(ProjectSettings.globalize_path(String(track.video_path)))
	player.expand = true
	editor._composition_parent.add_child(player)

	var wrap := Control.new()
	wrap.anchor_left = editor._mask_wrap.anchor_left
	wrap.anchor_top = editor._mask_wrap.anchor_top
	wrap.anchor_right = editor._mask_wrap.anchor_right
	wrap.anchor_bottom = editor._mask_wrap.anchor_bottom
	editor._composition_parent.add_child(wrap)

	var view := TextureRect.new()
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_SCALE
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrap.add_child(view)

	var border := StyleBoxFlat.new()
	border.bg_color = Color(0, 0, 0, 0)
	border.set_border_width_all(2)
	border.border_color = Color(0.6, 0.9, 1.0, 0.85)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", border)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(panel)

	# The track's audio plays through a real AudioStreamPlayer (the SAME proven path as
	# the main clip) - VideoStreamPlayer's own embedded audio does NOT play when the
	# video is driven by manual seeking, which is why the track was silent. We demux the
	# track .ogv's Vorbis into a sidecar .ogg once (fast stream-copy, cached), and mute
	# the video player's audio so nothing double-plays.
	player.volume = 0.0

	while runtime.size() <= i:
		runtime.append({})
	runtime[i] = {"player": player, "view": view, "wrap": wrap, "audio": null, "active": false}
	player.paused = true
	player.play()   # must be playing before .stream_position can be set (see sync)
	_ensure_track_audio(i)   # attaches .audio now (cached sidecar) or when ffmpeg finishes


## Give track `i` its AudioStreamPlayer, from a sidecar .ogg demuxed from the track's
## .ogv. If the sidecar already exists we attach immediately; otherwise ffmpeg runs in
## the BACKGROUND (was OS.execute - a synchronous main-thread stall that could hang the
## whole editor while audio kept playing) and poll_audio attaches it on finish.
## The sidecar lives beside the .ogv (same basename, .ogg). If it exists, attach it.
## Otherwise extract it - preferring the ORIGINAL SOURCE, which always has the audio:
## the old -an transcode stripped it from the .ogv, so demuxing the .ogv gave nothing.
## Re-encode to Vorbis (the source is usually aac/mp3, not copyable to ogg). Background
## + quiet; if even the source has no audio, poll_audio records no_audio so we
## don't retry forever. Once a sidecar exists it's cached and this is a no-op.
func _ensure_track_audio(i: int) -> void:
	if i < 0 or i >= editor.session.tracks.size():
		return
	var track: Dictionary = editor.session.tracks[i]
	var video_path := String(track.get("video_path", ""))
	if video_path.is_empty():
		return
	var abs_ogg := ProjectSettings.globalize_path(video_path.get_basename() + ".ogg")
	if FileAccess.file_exists(abs_ogg):
		_attach_track_audio(i, abs_ogg)
		return
	if bool(track.get("no_audio", false)):
		return   # already learned there's no audio anywhere for this track
	# Prefer the original import (has audio); fall back to the .ogv (only new imports
	# embed audio) when the source is gone or was never recorded.
	var src := String(track.get("source_path", ""))
	var abs_src := ProjectSettings.globalize_path(src) if src.begins_with("res://") else src
	if src.is_empty() or not FileAccess.file_exists(abs_src):
		abs_src = ProjectSettings.globalize_path(video_path)
	if not FileAccess.file_exists(abs_src):
		return
	var pid := Subprocess.start("ffmpeg", ["-y", "-loglevel", "quiet", "-i", abs_src,
		"-vn", "-c:a", "libvorbis", "-q:a", "4", abs_ogg])
	if pid > 0:
		audio_jobs.append({"pid": pid, "index": i, "ogg": abs_ogg})


## Load a track's sidecar .ogg into an AudioStreamPlayer and hang it on the runtime.
func _attach_track_audio(i: int, abs_ogg: String) -> void:
	if i < 0 or i >= runtime.size() or not (runtime[i] is Dictionary):
		return
	var stream := AudioStreamOggVorbis.load_from_file(abs_ogg)
	if stream == null:
		return
	var ap := AudioStreamPlayer.new()
	ap.stream = stream
	editor.add_child(ap)
	runtime[i]["audio"] = ap


## Poll the background sidecar extractions; attach each track's audio as ffmpeg finishes.
func poll_audio() -> void:
	for j in range(audio_jobs.size() - 1, -1, -1):
		var job: Dictionary = audio_jobs[j]
		if not Subprocess.alive(int(job.pid)):
			var idx := int(job.index)
			if FileAccess.file_exists(String(job.ogg)):
				_attach_track_audio(idx, String(job.ogg))
			elif idx >= 0 and idx < editor.session.tracks.size():
				# ffmpeg produced nothing - this track has no audio stream. Record it so
				# we don't re-run (and re-fail) the extraction on every future load.
				editor.session.tracks[idx]["no_audio"] = true
				editor._mark_dirty()
			audio_jobs.remove_at(j)


func _track_getter(i: int, field: String) -> Callable:
	return func(): return float(editor.session.tracks[i].get(field, 0.0))


func _track_setter(i: int, field: String) -> Callable:
	return func(v): editor.session.tracks[i][field] = v


## Rebuild every trim/track lane from session state (the primary clip's own trim
## block, plus one per session.tracks entry) and recompute the shared
## TimelineView's cached extent. Called after any STRUCTURAL change (import,
## delete, undo/redo) - never mid-drag; see TrackLane.drag_ended and
## TimelineView.refresh's own doc for why that distinction matters here.
func refresh_lanes() -> void:
	if editor._lanes_col == null:
		return
	for c in editor._lanes_col.get_children():
		# OUT OF THE COLUMN AT ONCE, not only freed at the frame's end: an old lane's getters name
		# the track by the index it was built for, and after a delete that index ran past the end
		# of the list for the rest of the frame (out-of-bounds errors in the log, one per lane)
		editor._lanes_col.remove_child(c)
		c.queue_free()

	var primary := TrackLane.new()
	primary.tview = editor._tview
	primary.label = String(editor.session.video_path).get_file()
	primary.reserved_left = _LANE_LABEL_LEFT
	primary.color = Color(0.55, 0.75, 1.0)
	primary.movable = false
	primary.full_duration = editor.session.duration
	primary.get_in = func(): return editor.session.clip_in
	primary.set_in = func(v): editor.session.clip_in = v
	primary.get_out = func(): return editor.session.effective_clip_out()
	primary.set_out = func(v): editor.session.clip_out = v
	primary.get_fade_in = func(): return editor.session.main_fade_in
	primary.set_fade_in = func(v): editor.session.main_fade_in = v
	primary.get_fade_out = func(): return editor.session.main_fade_out
	primary.set_fade_out = func(v): editor.session.main_fade_out = v
	primary.get_snap_targets = _snap_targets_for.bind(-1)
	primary.drag_started.connect(func(): editor._undo.push("", "trimmed the main clip"))
	primary.drag_ended.connect(_refresh_ruler)
	primary.changed.connect(editor._mark_dirty)
	editor._lanes_col.add_child(primary)
	# The main clip's own pull-rope volume (mirrors each track's), so its level in the
	# mix is set independently.
	primary.add_child(_volume_knob(
		func(): return float(editor.session.main_volume),
		func(v): editor.session.main_volume = v,
		Color(0.55, 0.75, 1.0), true))
	# Split, same corner/behavior as a secondary track's - the main clip is otherwise
	# just track -1 (see _snap_targets_for), so it gets the same cut at the playhead
	# (see _split_main). No delete button here: unlike an imported track, the primary
	# clip is never optional - there's always exactly one.
	var main_split := Button.new()
	main_split.text = "✂"
	main_split.custom_minimum_size = Vector2(20, 18)
	main_split.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	main_split.offset_left = -22
	main_split.offset_top = 2
	main_split.offset_right = -2
	main_split.offset_bottom = 20
	main_split.focus_mode = Control.FOCUS_NONE
	main_split.tooltip_text = "Split the main track at the playhead"
	main_split.pressed.connect(_split_main)
	primary.add_child(main_split)

	for i in editor.session.tracks.size():
		var lane := TrackLane.new()
		lane.tview = editor._tview
		lane.label = String(editor.session.tracks[i].get("video_path", "")).get_file()
		lane.reserved_left = _LANE_LABEL_LEFT
		lane.color = Color(0.6, 0.95, 0.7)
		lane.movable = true
		lane.full_duration = float(editor.session.tracks[i].get("duration", 0.0))
		lane.get_in = _track_getter(i, "clip_in")
		lane.set_in = _track_setter(i, "clip_in")
		lane.get_out = _track_getter(i, "clip_out")
		lane.set_out = _track_setter(i, "clip_out")
		lane.get_offset = _track_getter(i, "offset")
		lane.set_offset = _track_setter(i, "offset")
		lane.get_fade_in = _track_getter(i, "fade_in")
		lane.set_fade_in = _track_setter(i, "fade_in")
		lane.get_fade_out = _track_getter(i, "fade_out")
		lane.set_fade_out = _track_setter(i, "fade_out")
		lane.get_snap_targets = _snap_targets_for.bind(i)
		lane.get_playhead = func(): return editor.playhead()
		lane.drag_started.connect(func(): editor._undo.push("", "trimmed a track"))
		lane.drag_ended.connect(_refresh_ruler)
		lane.changed.connect(editor._mark_dirty)
		editor._lanes_col.add_child(lane)
		# The delete button OVERLAYS the lane's own top-right corner rather than
		# sitting beside it in an HBoxContainer - an inline sibling would shrink
		# the lane's own width below the primary lane's/_timeline's, and every
		# lane's x_of() must span the exact same pixel width or their blocks
		# stop lining up against a shared second.
		var del := Button.new()
		del.text = "✕"
		del.custom_minimum_size = Vector2(20, 18)
		del.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		del.offset_left = -22
		del.offset_top = 2
		del.offset_right = -2
		del.offset_bottom = 20
		del.focus_mode = Control.FOCUS_NONE
		del.tooltip_text = "Remove this track"
		var idx := i
		del.pressed.connect(func(): _delete_track(idx))
		lane.add_child(del)
		# Split, just left of delete - cuts this track in two at the playhead (see
		# _split_track). Same overlay approach as delete, for the same reason: an
		# inline sibling would shrink the lane's own width out from under the
		# shared timeline's pixel mapping.
		var split := Button.new()
		split.text = "✂"
		split.custom_minimum_size = Vector2(20, 18)
		split.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		split.offset_left = -46
		split.offset_top = 2
		split.offset_right = -26
		split.offset_bottom = 20
		split.focus_mode = Control.FOCUS_NONE
		split.tooltip_text = "Split this track at the playhead"
		split.pressed.connect(func(): _split_track(idx))
		lane.add_child(split)
		# Pull-rope volume knob, on the LEFT of the lane so it never sits under the floating
		# assistant chat button (bottom-right, where the old right-side controls landed).
		# The track's own AudioStreamPlayer mixes with the main clip; sync reads
		# `volume` every frame, so pulling it changes the level live.
		lane.add_child(_volume_knob(
			func(): return float(editor.session.tracks[idx].get("volume", 1.0)),
			func(v): editor.session.tracks[idx]["volume"] = v,
			Color(0.6, 0.95, 0.7)))

	# The lane stack sits directly above the marker strip, and the video's own
	# letterboxed slot (see _build_editor_ui) has to shrink to match - otherwise
	# an imported track (or several) grows this stack tall enough to push its
	# lanes/delete-buttons over the bottom of the video instead of the reserved
	# strip below it.
	reserve_lanes(1 + editor.session.tracks.size())
	_refresh_ruler()


## The ruler's length, taken again from the session. Called when a gesture ENDS, never during
## one ([TimelineView]: a ruler that rescales under the handle being dragged).
func _refresh_ruler() -> void:
	if editor.session != null:
		editor._tview.refresh(editor.session.timeline_extent())


## Collapse the lane stack (and expand the video letterbox into the space that
## frees up) to fit exactly `count` rows. Called with the full track count
## right after any structural change (above), and every frame with however
## many lanes are actually on screen right now - once TrackLane starts hiding
## itself for clips scrolled entirely out of the current zoom/pan window, the
## fixed-for-the-whole-track-count reservation left a dead black band where
## those rows used to be instead of actually collapsing - see feedback/0023.
func reserve_lanes(count: int) -> void:
	var reserved := 90.0 + float(count) * _LANE_H + editor.bottom_lift()
	editor._lanes_col.offset_top = -reserved
	editor._lanes_col.offset_bottom = -90 - editor.bottom_lift()
	if editor._video_area != null:
		editor._video_area.offset_bottom = -reserved
	# THE EXPORT BUTTON RIDES ABOVE THE BOTTOM CHROME. Its offsets are the ones
	# every mode uses (-68/-28 from the bottom edge, matching assistant.gd's
	# toggle row), and in every other mode the bottom of the frame is empty - but
	# here it is the marker strip and the lane stack, so the button sat ON the
	# timeline. `reserved` is exactly the height of that furniture, so anchoring to
	# it keeps the button clear however many tracks are open.
	# THE WHOLE BOTTOM-RIGHT ROW RIDES ABOVE THE BOTTOM CHROME - this editor's own
	# export button AND the shared furniture (⤓ / 💬 / >_), all off ONE number, and
	# all with the SAME arithmetic. They were laid out two different ways at first,
	# which is why the row came out staggered rather than in a line: the shared
	# buttons sit at -28..-68 from the bottom edge, so anything joining that row has
	# to be -28 - inset .. -68 - inset and not "inset plus a margin".
	#
	# `reserved` is exactly what the marker strip and the trim/track lanes occupy, over
	# the shared transport's rail ([method MaskEditor.bottom_lift]), and it is what the
	# video area is inset by, so the row stays clear however many tracks are open.
	var inset := reserved - 14.0
	# IN THE ROW once there is one (Chrome.row_button, the slot the shared ⤓ leaves while it is
	# suppressed); the row is lifted by the claim below. Placed by hand only without a Chrome.
	var ch_r := editor._export.chrome()
	if ch_r != null and editor._export_btn != null and editor._export_btn.get_parent() == editor:
		ch_r.row_button(&"mask_export", editor._export_btn)
	if editor._export_btn != null and editor._export_btn.get_parent() == editor:
		editor._export_btn.offset_bottom = -28.0 - inset
		editor._export_btn.offset_top = -68.0 - inset
	if editor._status != null:
		# ITS OWN LINE, ABOVE THE BUTTON ROW - see Exporter.set_bottom_inset for
		# why. The face-track line and the export progress both live here and both
		# outgrow the space beside four buttons.
		editor._status.offset_bottom = -74.0 - inset
		editor._status.offset_top = -110.0 - inset
		editor._status.offset_right = -28.0
	# SET EVERY FRAME, not once at build time. The suppression used to be done in
	# _build_export_ui, which runs before the chrome has joined its group in some
	# boot orders - so it silently found nothing, the shared button stayed live on
	# its higher CanvasLayer, and it went on covering this one and eating the click.
	var ch_i := editor._export.chrome()
	if ch_i != null:
		ch_i.claim_bottom(&"mask", inset)
		ch_i.suppress_export(&"mask")


func _delete_track(i: int) -> void:
	if i < 0 or i >= editor.session.tracks.size():
		return
	editor._undo.push("", "deleted a track")
	if i < runtime.size():
		var rt: Dictionary = runtime[i]
		if rt.has("player"):
			(rt.player as Node).queue_free()
		if rt.has("wrap"):
			(rt.wrap as Node).queue_free()
		if rt.has("audio") and rt.audio != null:
			(rt.audio as Node).queue_free()
		runtime.remove_at(i)
	editor.session.tracks.remove_at(i)
	refresh_lanes()
	editor._mark_dirty()


## Cut track `i` into two independent lanes at the playhead, both still pointing
## at the SAME source video/audio (video_path is shared - _ensure_track_audio's
## sidecar .ogg is keyed off that path, so the new half finds the existing
## extraction and attaches instantly, no re-demux). The left half keeps this
## track's own identity and index (just trims its clip_out); the right half is
## a full duplicate of the fields - same clip_in..clip_out span, same volume -
## then re-pointed to start exactly at the split: its clip_in advances to the
## split's LOCAL position in the source, and its offset (where that lands on
## the MASTER timeline) is set to the playhead itself, so the two blocks sit
## edge-to-edge with no gap or overlap. From there each is an ordinary lane -
## TrackLane's own drag handles already shift/resize them independently.
## Appended at the END of session.tracks (never inserted at i+1): background
## sidecar-audio jobs (audio_jobs) and runtime are index-keyed,
## and an insert would silently misalign any in-flight job for a LATER track.
func _split_track(i: int) -> void:
	if i < 0 or i >= editor.session.tracks.size():
		return
	var track: Dictionary = editor.session.tracks[i]
	var offset := float(track.get("offset", 0.0))
	var cin := float(track.get("clip_in", 0.0))
	var cout := float(track.get("clip_out", 0.0))
	var master_t: float = editor.playhead()
	var split_local := master_t - offset + cin
	if split_local <= cin + 0.05 or split_local >= cout - 0.05:
		editor._set_status("✂  Move the playhead inside this track's span to split it there")
		return
	editor._undo.push("", "split a track")
	var right: Dictionary = track.duplicate()
	right["clip_in"] = split_local
	right["offset"] = master_t
	right["fade_in"] = 0.0
	track["clip_out"] = split_local
	track["fade_out"] = 0.0
	editor.session.tracks.append(right)
	editor._undo.reconcile_tracks()
	refresh_lanes()
	editor._mark_dirty()


## Cut the MAIN clip in two at the playhead, same as _split_track but for the
## primary lane: the main clip has no `offset` of its own (master time and its
## source time are the same clock - see TrackLane._bounds), so the playhead
## position IS the split point directly, no offset arithmetic needed. The left
## half stays the main clip (just trims clip_out, same as dragging its own out
## handle inward). The right half can't stay "main" - there's only ever one -
## so it's appended to session.tracks as an ordinary track pointing at the same
## video_path/source_path, picking up at the split with its own offset. From
## there it's indistinguishable from any imported track: draggable, deletable,
## splittable again - the main clip is really just track -1 (see
## _snap_targets_for), and after a split its tail end is a track in fact, not
## just in spirit.
func _split_main() -> void:
	if editor._player == null:
		return
	var cin := editor.session.clip_in
	var cout := editor.session.effective_clip_out()
	var split_t: float = editor.playhead()
	if split_t <= cin + 0.05 or split_t >= cout - 0.05:
		editor._set_status("✂  Move the playhead inside the main clip's span to split it there")
		return
	editor._undo.push("", "split the main clip")
	var right := {
		"video_path": editor.session.video_path,
		"source_path": editor.session.source_path,
		"duration": editor.session.duration,
		"clip_in": split_t,
		"clip_out": cout,
		"offset": split_t,
		"fade_in": 0.0,
		"fade_out": editor.session.main_fade_out,
		"volume": editor.session.main_volume,
	}
	editor.session.clip_out = split_t
	editor.session.main_fade_out = 0.0
	editor.session.tracks.append(right)
	editor._undo.reconcile_tracks()
	refresh_lanes()
	editor._mark_dirty()


func prompt_import() -> void:
	# Already open (double-tap of T) - just bring it forward, don't stack a
	# second dialog behind the first.
	if _import_dialog != null and is_instance_valid(_import_dialog):
		_import_dialog.popup_centered()
		return
	# An import is already transcoding - don't let a second one clobber the
	# first's pending state mid-flight (they share import_pid/_import_pending).
	if import_pid > 0:
		editor._set_status("⏳  A track is still importing - one at a time")
		return
	# Immediate feedback that T registered, BEFORE the dialog - if the dialog
	# itself somehow fails to show, at least the keypress isn't silent.
	editor._set_status("📁  Choose a video to import as a second track…")
	_import_dialog = FileDialog.new()
	_import_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_import_dialog.access = FileDialog.ACCESS_FILESYSTEM
	# In-window dialog, NOT native. The native (portal) dialog silently shows
	# nothing on a Linux box without xdg-desktop-portal - the exact "I press T
	# and nothing happens" report. Godot's own dialog always renders in-window.
	_import_dialog.use_native_dialog = false
	_import_dialog.title = "Import a second track (picture-in-picture)"
	_import_dialog.filters = PackedStringArray(["*.mp4, *.mov, *.mkv, *.webm, *.ogv ; Video"])
	var downloads := OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	if not downloads.is_empty():
		_import_dialog.current_dir = downloads
	_import_dialog.size = Vector2i(820, 560)
	_import_dialog.file_selected.connect(_start_track_import)
	# Free the dialog whichever way it closes (pick or cancel), so the next T
	# opens a fresh one and the is_instance_valid guard above reads false
	# again. _start_track_import is connected first, so it runs before the
	# close on a pick.
	_import_dialog.file_selected.connect(func(_p): _close_import_dialog())
	_import_dialog.canceled.connect(_close_import_dialog)
	editor.add_child(_import_dialog)
	_import_dialog.popup_centered()


func _close_import_dialog() -> void:
	if _import_dialog != null and is_instance_valid(_import_dialog):
		_import_dialog.queue_free()
	_import_dialog = null


## Same one-time ffmpeg->theora transcode _prep() does for the primary clip,
## minus the audio extraction step (v1 tracks are silent - see the class doc's
## scope note) - PID-polled in _process(), never blocking, matching the
## project's one established pattern for external subprocesses.
## Add the track's LANE first, transcode second. The lane is pure metadata
## (duration/offset/trim) - it doesn't need the transcoded video at all - so it
## appears the instant you pick a file, independent of the background ffmpeg run.
## The old order (transcode -> probe -> only THEN add the lane) meant any hiccup in
## that async tail left the timeline looking like nothing happened. The PiP VIDEO
## still needs the .ogv, so build_view is deferred to finish_import;
## until then sync just skips this index (no "player" in its runtime slot).
func _start_track_import(source: String) -> void:
	var slug := MaskEditor._slugify(source)
	var dir := editor._session_path.get_base_dir()
	var idx := editor.session.tracks.size()
	var video := dir + "/track_%s_%d.ogv" % [slug, idx]
	# The SOURCE file has reliable duration metadata (unlike our libtheora output),
	# so the lane gets its real length up front; the transcoded .ogv re-confirms it
	# in finish_import. Floor keeps the lane a visible width if a probe fails.
	var dur := editor._source_prep.probe_duration(source)
	if dur <= 0.0:
		dur = maxf(editor.session.duration, 1.0)
	editor._undo.push("", "imported a track")
	editor.session.tracks.append({
		"video_path": video, "source_path": source, "duration": dur,
		"clip_in": 0.0, "clip_out": dur, "offset": 0.0,
		"x": 0.68, "y": 0.04, "w": 0.28, "h": 0.28,
		"volume": 1.0,
	})
	while runtime.size() <= idx:
		runtime.append({})   # empty slot: sync skips it until the video loads
	refresh_lanes()                # the new timeline lane is on screen NOW
	editor._mark_dirty()
	_import_pending = {"source": source, "video": video, "index": idx}
	editor._set_status("⏳  Track added - transcoding its video in the background…")
	# Keep the audio this time (was -an): the track's own VideoStreamPlayer plays the
	# embedded Vorbis, mixed alongside the main clip, with per-track mute/volume (see
	# sync). A source with no audio just yields a silent stream - no failure.
	# .part + promote, same as the main prep - see _promote_part's doc.
	var args := PackedStringArray([
		"-y", "-loglevel", "error", "-i", source,
		"-c:v", "libtheora", "-q:v", "6", "-g", "25",
		"-c:a", "libvorbis", "-q:a", "4",
		"-f", "ogg", ProjectSettings.globalize_path(video) + ".part"])
	import_pid = Subprocess.start("ffmpeg", args, "clip import")
	if import_pid <= 0:
		_cancel_pending_track()     # couldn't even start ffmpeg - roll the lane back out
		editor._set_status("⚠  Could not start ffmpeg for track import")


## Roll back the placeholder lane _start_track_import added (ffmpeg failed to start,
## or the transcode produced nothing usable). The pending track is always the last
## one (imports are serialized - see prompt_import's guard).
func _cancel_pending_track() -> void:
	if _import_pending.has("index"):
		var idx := int(_import_pending.index)
		if idx >= 0 and idx < editor.session.tracks.size():
			editor.session.tracks.remove_at(idx)
			if idx < runtime.size():
				runtime.remove_at(idx)
			refresh_lanes()
			editor._mark_dirty()
	_import_pending = {}
	import_pid = -1


func finish_import() -> void:
	if not _import_pending.has("index"):
		_import_pending = {}
		return
	var idx := int(_import_pending.index)
	editor._source_prep.promote_part(String(_import_pending.video))
	var abs_video := ProjectSettings.globalize_path(String(_import_pending.video))
	var dur := editor._source_prep.probe_duration(abs_video)
	if dur <= 0.0 or idx < 0 or idx >= editor.session.tracks.size():
		# The lane is already on screen; the transcode still failed, so take it back
		# out rather than leave a lane whose PiP video would never load.
		_cancel_pending_track()
		editor._set_status("⚠  Track import failed (transcode produced no usable video)")
		return
	# Correct the lane to the actual transcoded length, keeping it full if untrimmed.
	var t: Dictionary = editor.session.tracks[idx]
	var was_full: bool = float(t.get("clip_out", 0.0)) >= float(t.get("duration", 0.0)) - 0.05
	t["duration"] = dur
	if was_full:
		t["clip_out"] = dur
	build_view(idx)          # now the .ogv exists: load its PiP player
	refresh_lanes()
	editor._mark_dirty()
	_import_pending = {}
	if editor._status != null:
		editor._status.visible = false


## Each imported track is driven off the PRIMARY player's own clock (never its
## own independent playback state) - the same discipline the audio sync already
## follows (see _play's class doc), so live preview and an export relaunch trace
## the identical picture. A track that isn't currently inside its
## [offset, offset+span) window on the master timeline is paused and hidden;
## entering it seeks the track's own player to the matching local position and
## lets it run from there, only re-seeking again if it drifts (video seeks are
## heavy - constant tiny re-seeks would stutter, same reasoning as the 0.15s
## audio tolerance, just a bit wider since a video seek is coarser than an
## audio one).
func sync() -> void:
	if editor._player == null:
		return
	var master_t := editor.playhead()
	for i in editor.session.tracks.size():
		if i >= runtime.size():
			continue
		var rt: Dictionary = runtime[i]
		if not rt.has("player"):
			continue
		var track: Dictionary = editor.session.tracks[i]
		var offset := float(track.get("offset", 0.0))
		var cin := float(track.get("clip_in", 0.0))
		var cout := float(track.get("clip_out", 0.0))
		var local_t := master_t - offset + cin
		var inside: bool = cout > cin and local_t >= cin and local_t < cout
		var tplayer: VideoStreamPlayer = rt.player
		var wrap: Control = rt.wrap
		var taudio: AudioStreamPlayer = rt.get("audio")   # may be null (silent track)
		# This track owns the PiP only when V has selected it (pip_track == i+1). The
		# box is still gated by inset_show so track modes fade like the main PiP does.
		var selected := editor._pip_track == i + 1
		# The clip's fade envelope: audio AND video ramp together (coupled) over the
		# fade_in seconds after the clip's start and the fade_out seconds before its end.
		# g is 0 at a faded edge, 1 across the middle; see _clip_fade_gain / _track_level_db.
		var g := editor._clip_fade_gain(master_t - offset, cout - cin,
			float(track.get("fade_in", 0.0)), float(track.get("fade_out", 0.0)))
		if inside:
			wrap.visible = editor._last_inset_show > 0.001 and selected
			wrap.modulate.a = g   # VIDEO fade, coupled to the audio one below
			if not bool(rt.active) or absf(tplayer.stream_position - local_t) > 0.2:
				tplayer.stream_position = local_t
				rt.active = true
			tplayer.paused = not editor._playing
			var view: TextureRect = rt.view
			if view != null:
				view.texture = tplayer.get_video_texture()
			if taudio != null:
				# pull-rope volume × the fade envelope, as a log/dB level
				taudio.volume_db = editor._track_level_db(float(track.get("volume", 1.0)), g)
				if editor._playing:
					if not taudio.playing:
						taudio.play(local_t)
					taudio.stream_paused = false
					if absf(taudio.get_playback_position() - local_t) > 0.2:
						taudio.seek(local_t)
				else:
					taudio.stream_paused = true   # paused / scrubbing: freeze its sound
		else:
			wrap.visible = false
			tplayer.paused = true   # outside its window: no picture...
			rt.active = false
			if taudio != null and taudio.playing:
				taudio.stop()        # ...and no sound; re-entry restarts it clean
	# The main clip's PiP shows only when it is the selected source (pip_track == 0);
	# a selected track replaces it. _apply_frame_state set _mask_wrap by inset_show
	# alone, so correct it here now that we know which source V picked.
	if editor._pip_track != 0:
		editor._mask_wrap.visible = false


## A left-anchored pull-rope volume knob for a lane (see VolumeKnob): hold and drag
## away to set a continuous 0..1 level with an asymptotic ceiling. `getter` reads the
## stored volume, `setter` writes it - the same widget drives a track's `volume` and
## the main clip's `main_volume`. Left side deliberately: the right corner sits under
## the floating assistant chat button. `icon` shows the one-time speaker-glyph hint -
## reserved for the main clip's own knob only (see VolumeKnob.show_icon).
func _volume_knob(getter: Callable, setter: Callable, accent: Color, icon: bool = false) -> VolumeKnob:
	var k := VolumeKnob.new()
	k.accent = accent
	k.show_icon = icon
	k.set_anchors_preset(Control.PRESET_TOP_LEFT)
	# offset_left starts past TrackLane._EDGE_W (8px): the primary lane's own trim/fade
	# "in" handles sit at local x0 = 0 (its offset is always 0, and the default view
	# starts at t=0 too), so a knob planted right at the corner silently ate every click
	# meant for that edge - "drag the left edge" looked broken specifically on the main
	# track, since only ITS x0 is pinned to 0 - see feedback/0017.
	k.offset_left = 12
	k.offset_top = 2
	k.offset_right = 34
	k.offset_bottom = 20
	k.get_v = getter
	k.set_v = func(v):
		setter.call(v)
		editor._mark_dirty()   # cheap + debounced (autosave cooldown), fine to fire while pulling
	return k


## Master-timeline seconds a dragged clip should snap its start/end to: 0, the playhead,
## the primary clip's end, and every OTHER clip's start and end. exclude_i is the lane
## doing the dragging (-1 = the primary), so a clip never snaps to itself.
func _snap_targets_for(exclude_i: int) -> Array:
	var targets := [0.0, editor.session.effective_clip_out()]
	if editor._player != null:
		targets.append(editor.playhead())
	for j in editor.session.tracks.size():
		if j == exclude_i:
			continue
		var t: Dictionary = editor.session.tracks[j]
		var o := float(t.get("offset", 0.0))
		var span := float(t.get("clip_out", 0.0)) - float(t.get("clip_in", 0.0))
		targets.append(o)
		targets.append(o + span)
	return targets
