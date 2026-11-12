extends RefCounted
class_name MaskTracks

## MaskTracks - the clip's tracks: the trim lanes under the marker strip, a second clip imported onto the timeline, and
## every track kept in step with the master clock. A part of [MaskEditor] (next/structure.md).
##
## The main clip's own lane and one per `session.tracks` entry, all on the editor's one [TimelineView]. An imported
## track is a lane first and a transcode second ([method finish_import]); its sound is a sidecar `.ogg` demuxed in the
## background ([method poll_audio]); each frame [method sync] decides which track is playing (a continuation that owns
## the main view, or a picture-in-picture over it) and keeps its player on the master's time.
##
## It holds its own state (each track's players and views, the background jobs, the import in flight) and reads the
## rest through [member editor]: the session, the master player, the lanes' column and the video's area, the undo
## stack, the status line.

## The [MaskEditor] this is a part of: everything read through it is something this part is handed.
var editor: MaskEditor

var audio_jobs: Array = []  # background sidecar-.ogg extractions, {pid, index, ogg}
## Runtime state per session.tracks[i], not persisted (rebuilt from the data every _ready_with_session):
## {player: VideoStreamPlayer, view: TextureRect, active: bool}. `active` is whether the track is currently the one
## playing (see sync), so entering or leaving its window seeks and starts or pauses it once, not every frame.
var runtime: Array = []
var _import_dialog: FileDialog
var import_pid := -1
var _import_pending := {}   # {source, video, index} - the lane is added up front, this tracks its transcode
# Per-lane reserved height: a TrackLane's own minimum (26px, see track_lane.gd) plus the _lanes_col VBox's
# inter-lane separation (2px); less and the stack overflows onto the marker strip's flags and playhead tag.
const _LANE_H := 28.0
# A lane's label starts past the volume knob (anchored top-left, offset_right 34) plus a small gap.
const _LANE_LABEL_LEFT := 38.0

# --- tracks: trim lanes, import, playback sync ------------------------------------------------

## A secondary track's own composited view: a raw (unshaded) picture-in-picture box, since the masking effects key
## off one frame's colors through the primary's shader chain. It takes the same inset slot _mask_wrap occupies
## (bottom-right): only one PiP box is on screen at a time, and sync hides _mask_wrap while a track's box shows.
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

	# The track's audio plays through a real AudioStreamPlayer (the main clip's path): VideoStreamPlayer's embedded
	# audio does not play when the video is driven by manual seeking. The track .ogv's Vorbis is demuxed into a cached
	# sidecar .ogg, and the video player is muted so nothing double-plays.
	player.volume = 0.0

	while runtime.size() <= i:
		runtime.append({})
	runtime[i] = {"player": player, "view": view, "wrap": wrap, "audio": null, "active": false}
	player.paused = true
	player.play()   # must be playing before .stream_position can be set (see sync)
	_ensure_track_audio(i)   # attaches .audio now (cached sidecar) or when ffmpeg finishes


## Give track `i` its AudioStreamPlayer, from a sidecar .ogg beside the track's .ogv (same basename). If it exists,
## attach it; otherwise extract it in the background (never a synchronous main-thread stall) and poll_audio attaches
## it on finish. The original source is preferred (the .ogv may lack audio), re-encoded to Vorbis; if even the source
## has no audio, poll_audio records no_audio so it is not retried.
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
	# Prefer the original import; fall back to the .ogv (only new imports embed audio) when the source is gone.
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
				# ffmpeg produced nothing: the track has no audio stream. Recorded so extraction is not retried.
				editor.session.tracks[idx]["no_audio"] = true
				editor._mark_dirty()
			audio_jobs.remove_at(j)


func _track_getter(i: int, field: String) -> Callable:
	return func(): return float(editor.session.tracks[i].get(field, 0.0))


func _track_setter(i: int, field: String) -> Callable:
	return func(v): editor.session.tracks[i][field] = v


## Rebuild every trim/track lane from session state (the primary clip's trim block plus one per session.tracks entry)
## and recompute the shared TimelineView's cached extent. Called after a structural change (import, delete,
## undo/redo), never mid-drag; see TrackLane.drag_ended and TimelineView.refresh.
func refresh_lanes() -> void:
	if editor._lanes_col == null:
		return
	for c in editor._lanes_col.get_children():
		# Out of the column at once, not only freed at frame's end: an old lane's getters name its track by the index it
		# was built for, which can run past the list after a delete.
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
	# Split, as on a secondary track: the main clip is track -1 (see _snap_targets_for) and is cut at the playhead
	# (see _split_main). No delete: there is always exactly one primary clip.
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
		# The delete button overlays the lane's top-right corner instead of sitting beside it: an inline sibling would
		# shrink the lane's width, and every lane's x_of() must span the same pixel width to line up.
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
		# Split, left of delete: cuts this track at the playhead (see _split_track); overlaid for the same reason.
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
		# Pull-rope volume knob on the left of the lane, clear of the assistant chat button (bottom-right). sync reads
		# `volume` every frame, so pulling it changes the level live.
		lane.add_child(_volume_knob(
			func(): return float(editor.session.tracks[idx].get("volume", 1.0)),
			func(v): editor.session.tracks[idx]["volume"] = v,
			Color(0.6, 0.95, 0.7)))

	# The lane stack sits above the marker strip, and the video's letterboxed slot (see _build_editor_ui) shrinks to
	# match so lanes never spill over the video.
	reserve_lanes(1 + editor.session.tracks.size())
	_refresh_ruler()


## The ruler's length, taken again from the session. Called when a gesture ends, never during one ([TimelineView]).
func _refresh_ruler() -> void:
	if editor.session != null:
		editor._tview.refresh(editor.session.timeline_extent())


## Collapse the lane stack (and expand the video letterbox into the freed space) to fit exactly `count` rows. Called
## with the full track count after a structural change and every frame with the number of lanes on screen, since
## TrackLane hides itself for clips scrolled out of the zoom/pan window.
func reserve_lanes(count: int) -> void:
	var reserved := 90.0 + float(count) * _LANE_H + editor.bottom_lift()
	editor._lanes_col.offset_top = -reserved
	editor._lanes_col.offset_bottom = -90 - editor.bottom_lift()
	if editor._video_area != null:
		editor._video_area.offset_bottom = -reserved
	# The editor's export button and the shared bottom-right row (⤓ / 💬 / >_) ride above the bottom chrome off one
	# number and one piece of arithmetic: the shared buttons sit at -28..-68 from the bottom edge, so anything joining
	# the row is -28 - inset .. -68 - inset. `reserved` is what the marker strip and the trim/track lanes occupy, over
	# the shared transport's rail ([method MaskEditor.bottom_lift]); the video area is inset by it too.
	var inset := reserved - 14.0
	# In the row once there is one (Chrome.row_button, the slot the shared ⤓ leaves while suppressed), lifted by the
	# claim below; placed by hand only without a Chrome.
	var ch_r := editor._export.chrome()
	if ch_r != null and editor._export_btn != null and editor._export_btn.get_parent() == editor:
		ch_r.row_button(&"mask_export", editor._export_btn)
	if editor._export_btn != null and editor._export_btn.get_parent() == editor:
		editor._export_btn.offset_bottom = -28.0 - inset
		editor._export_btn.offset_top = -68.0 - inset
	if editor._status != null:
		# Its own line above the button row (see Exporter.set_bottom_inset): the face-track line and the export
		# progress outgrow the space beside four buttons.
		editor._status.offset_bottom = -74.0 - inset
		editor._status.offset_top = -110.0 - inset
		editor._status.offset_right = -28.0
	# Set every frame, not once at build time: the chrome may join its group after this editor builds.
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


## Cut track `i` into two lanes at the playhead, both pointing at the same source video/audio (video_path is shared,
## so the new half finds the existing sidecar .ogg). The left half keeps this track's identity and index (clip_out
## trimmed); the right half duplicates the fields, with clip_in advanced to the split's local source position and
## offset set to the playhead, so the blocks sit edge to edge. It is appended at the end of session.tracks, never
## inserted at i+1: audio_jobs and runtime are index-keyed.
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


## Cut the main clip in two at the playhead, as _split_track does for the primary lane. The main clip has no offset
## (master time and source time are one clock, see TrackLane._bounds), so the playhead is the split point. The left
## half stays the main clip (clip_out trimmed); the right half is appended to session.tracks as an ordinary track on
## the same video_path/source_path with its own offset.
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
	# Already open (double-tap of T): bring it forward.
	if _import_dialog != null and is_instance_valid(_import_dialog):
		_import_dialog.popup_centered()
		return
	# An import is already transcoding: a second would clobber the pending state (they share import_pid/_import_pending).
	if import_pid > 0:
		editor._set_status("⏳  A track is still importing - one at a time")
		return
	# Immediate feedback that T registered, before the dialog.
	editor._set_status("📁  Choose a video to import as a second track…")
	_import_dialog = FileDialog.new()
	_import_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_import_dialog.access = FileDialog.ACCESS_FILESYSTEM
	# In-window dialog, not native: the native (portal) dialog shows nothing without xdg-desktop-portal.
	_import_dialog.use_native_dialog = false
	_import_dialog.title = "Import a second track (picture-in-picture)"
	_import_dialog.filters = PackedStringArray(["*.mp4, *.mov, *.mkv, *.webm, *.ogv ; Video"])
	var downloads := OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	if not downloads.is_empty():
		_import_dialog.current_dir = downloads
	_import_dialog.size = Vector2i(820, 560)
	_import_dialog.file_selected.connect(_start_track_import)
	# Free the dialog however it closes, so the next T opens a fresh one. _start_track_import is connected first, so it
	# runs before the close on a pick.
	_import_dialog.file_selected.connect(func(_p): _close_import_dialog())
	_import_dialog.canceled.connect(_close_import_dialog)
	editor.add_child(_import_dialog)
	_import_dialog.popup_centered()


func _close_import_dialog() -> void:
	if _import_dialog != null and is_instance_valid(_import_dialog):
		_import_dialog.queue_free()
	_import_dialog = null


## The one-time ffmpeg->theora transcode _prep() does for the primary clip, PID-polled in _process(), never blocking.
## The track's lane is added first, transcode second: the lane is pure metadata (duration/offset/trim) and appears the
## instant a file is picked. The PiP video needs the .ogv, so build_view is deferred to finish_import; until then sync
## skips this index (no "player" in its runtime slot).
func _start_track_import(source: String) -> void:
	var slug := MaskEditor._slugify(source)
	var dir := editor._session_path.get_base_dir()
	var idx := editor.session.tracks.size()
	var video := dir + "/track_%s_%d.ogv" % [slug, idx]
	# The source has reliable duration metadata (our libtheora output does not), so the lane gets its real length up
	# front; finish_import re-confirms it from the .ogv. The floor keeps the lane visible if a probe fails.
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
	# Audio is kept: the track's VideoStreamPlayer plays the embedded Vorbis alongside the main clip, with per-track
	# volume (see sync); a source with no audio yields a silent stream. .part + promote, as in the main prep (see
	# _promote_part).
	var args := PackedStringArray([
		"-y", "-loglevel", "error", "-i", source,
		"-c:v", "libtheora", "-q:v", "6", "-g", "25",
		"-c:a", "libvorbis", "-q:a", "4",
		"-f", "ogg", ProjectSettings.globalize_path(video) + ".part"])
	import_pid = Subprocess.start("ffmpeg", args, "clip import")
	if import_pid <= 0:
		_cancel_pending_track()     # couldn't even start ffmpeg - roll the lane back out
		editor._set_status("⚠  Could not start ffmpeg for track import")


## Roll back the placeholder lane _start_track_import added (ffmpeg failed to start, or the transcode produced
## nothing usable). The pending track is always the last one (imports are serialized, see prompt_import's guard).
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
		# The transcode failed: take the lane back out rather than leave one whose PiP video never loads.
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


## Each imported track is driven off the primary player's clock (as the audio sync is, see _play's class doc), so
## live preview and an export relaunch trace the same picture. A track outside its [offset, offset+span) window on the
## master timeline is paused and hidden; entering it seeks its player to the matching local position and lets it run,
## re-seeking only on drift (video seeks are heavy and coarser than audio's 0.15s tolerance).
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
		# This track owns the PiP only when V has selected it (pip_track == i+1); the box is still gated by inset_show.
		var selected := editor._pip_track == i + 1
		# The clip's fade envelope: audio and video ramp together over fade_in seconds after the clip's start and
		# fade_out seconds before its end; g is 0 at a faded edge, 1 across the middle (see _clip_fade_gain / _track_level_db).
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
	# The main clip's PiP shows only when it is the selected source (pip_track == 0); _apply_frame_state set
	# _mask_wrap by inset_show alone, so correct it here.
	if editor._pip_track != 0:
		editor._mask_wrap.visible = false


## A left-anchored pull-rope volume knob for a lane (see VolumeKnob): hold and drag to set a continuous 0..1 level
## with an asymptotic ceiling. `getter` reads the stored volume and `setter` writes it (a track's `volume` or the main
## clip's `main_volume`). Left side because the right corner sits under the assistant chat button. `icon` shows the
## one-time speaker-glyph hint, for the main clip's knob only (see VolumeKnob.show_icon).
func _volume_knob(getter: Callable, setter: Callable, accent: Color, icon: bool = false) -> VolumeKnob:
	var k := VolumeKnob.new()
	k.accent = accent
	k.show_icon = icon
	k.set_anchors_preset(Control.PRESET_TOP_LEFT)
	# offset_left clears TrackLane._EDGE_W (8px): the primary lane's trim/fade "in" handles sit at local x0 = 0, and a
	# knob at the corner would eat clicks meant for that edge.
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
