extends RefCounted
class_name MaskPrep

## MaskPrep - the clip made ready, a part of [MaskEditor]: transcoded once into the session's folder
## ([method prep]), guarded against a second writer on the same output ([method looks_live]),
## finished into a session ([method finish_session]), and measured - its length and its frame size,
## seeded by ffprobe and confirmed from the first decoded frame ([method probe_duration],
## [method sync_size]).
##
## WHAT IT IS HANDED is written out: every `editor.` below is something it reads of the editor (the
## session, the prep's state and processes, the player, the status line).
##
## Two real ffmpeg processes (not a shell chain) so each can be polled and reported
## like exporter.gd's bake/render/transcode steps: video first (the slow part - can
## be minutes on a long clip), then audio (fast, PCM decode). Progress comes from the
## same `-progress <file>` mechanism the export transcode step already uses.
##
## Two writers on the SAME -y output path interleave and corrupt it - not
## hypothetical, this is here because it happened (twice: a second launch mid-prep
## raced the first, and separately a manual external ffmpeg run raced the app). The
## first version of this guard tracked a PID and called Subprocess.alive() on
## it - which crashes (engine-level ECHILD) the moment the PID belongs to a process
## this instance didn't spawn itself, e.g. a PREVIOUS launch's child, exactly the
## cross-instance case the guard exists for. An mtime check answers the actual
## question - "did anything touch this file recently" - without caring who the
## writer is or whether this instance could ever see its PID.

## The [MaskEditor] this is a part of: everything read through it is something this part
## is handed, and the list of them is what it depends on.
var editor: MaskEditor

# THE SOURCE CLIP'S OWN FRAME SIZE
# Everything that has to know the picture's SHAPE reads this: the editor's
# letterboxed video slot (_build_editor_ui), the export's recorded resolution
# (_write_render_override), the meta mirror's hand-built pane
# (_shrink_into_video_pane) and the umbra eye fit's aspect correction. A portrait
# clip (1080x1920) is therefore not a special case anywhere - it is just this pair
# being taller than it is wide, and the editor pillarboxes it (black bars either
# side) exactly the way a short clip already letterboxes. Nothing here assumes
# 16:9; the several places that used to hardcode 1.7778 / 1920x1080 were the ONLY
# reason a vertical clip came out horizontally squashed.
#
# Seeded by ffprobe at session-ready - the editor layout and the export launch
# both need it BEFORE a frame has decoded - then confirmed from the decoded
# texture itself the first frame it exists (sync_size), which is
# authoritative and also covers a machine with no ffprobe on PATH.
const _SRC_SIZE_FALLBACK := Vector2i(1920, 1080)
var src_size := _SRC_SIZE_FALLBACK
var size_confirmed := false   # the decoded texture has had its say
var _prep_src_dur := 0.0         # source clip duration (seconds), for the video step's %
const _PREP_PROGRESS_FILE := "user://mask_prep_progress.txt"

# --- one-time prep: ffmpeg -> masks/<slug>/{video.ogv, audio.wav} -----------------------------

func prep(source: String, dir: String, video: String, audio: String) -> void:
	var abs_dir := ProjectSettings.globalize_path(dir)
	DirAccess.make_dir_recursive_absolute(abs_dir)
	_prep_src_dur = probe_duration(source)
	_progress_reset(_PREP_PROGRESS_FILE)
	# Small GOP (-g 25 = ~1 keyframe/sec at typical fps) keeps scrubbing responsive on
	# long clips; theora is the only format VideoStreamPlayer decodes natively (see
	# next/mask_mode_spike notes - WebM/H.264 need a GDExtension, so every source
	# clip gets this one-time transcode regardless of its original codec).
	# Written as .part and promoted on completion (see promote_part): a
	# half-written media file at its REAL name is scanned by the Godot editor's
	# importer, and a truncated WAV wedges it in an infinite seek loop -
	# hanging every editor boot AND every headless compile check (including
	# the assistant's reload gate) until the file is deleted by hand.
	var args := PackedStringArray([
		"-y", "-loglevel", "error", "-i", source, "-an",
		"-c:v", "libtheora", "-q:v", "6", "-g", "25",
		"-progress", ProjectSettings.globalize_path(_PREP_PROGRESS_FILE), "-nostats",
		"-f", "ogg", ProjectSettings.globalize_path(video) + ".part"])
	editor._prep_video_pid = Subprocess.start("ffmpeg", args, "clip prep (video)")
	editor._prep_state = "prepping_video" if editor._prep_video_pid > 0 else "idle"
	if editor._prep_video_pid <= 0:
		editor._set_status("⚠  Could not start ffmpeg (is it on PATH?)")
	else:
		# In the log too: for a long clip THIS is the slow stage (libtheora is
		# single-threaded), and the console should say what's grinding.
		print("ghost mask: prep started - transcoding %s (%.0fs) -> %s" % [
			source, _prep_src_dur, video])
		_touch_lock(abs_dir)
		editor._set_status("⏳  Preparing clip (video)…  0%")


func start_audio() -> void:
	_touch_lock(ProjectSettings.globalize_path(editor._pending.dir))   # bridge the gap while
	# video.ogv's mtime goes stale and audio.wav doesn't exist yet - see looks_live.
	# Two outputs, one decode: the PCM the waveform/envelope tooling needs,
	# and the compressed sidecar playback actually attaches (see
	# _ready_with_session for why the raw WAV is too slow to load live).
	var abs_a := ProjectSettings.globalize_path(String(editor._pending.audio))
	var args := PackedStringArray([
		"-y", "-loglevel", "error", "-i", String(editor._pending.source), "-vn",
		"-acodec", "pcm_s16le", "-ar", "44100", "-ac", "2",
		"-f", "wav", abs_a + ".part",
		"-vn", "-c:a", "libvorbis", "-q:a", "5",
		"-f", "ogg", abs_a.get_basename() + ".ogg.part"])
	editor._prep_audio_pid = Subprocess.start("ffmpeg", args, "clip prep (audio)")
	editor._prep_state = "prepping_audio" if editor._prep_audio_pid > 0 else "idle"
	editor._set_status("⏳  Preparing clip (audio)…")


func _progress_reset(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string("")


## Same `out_time_us=` polling exporter.gd's transcode step uses, against the
## source clip's OWN duration (captured before the video step starts).
func read_pct() -> int:
	if _prep_src_dur <= 0.0 or not FileAccess.file_exists(_PREP_PROGRESS_FILE):
		return 0
	var text := FileAccess.get_file_as_string(_PREP_PROGRESS_FILE)
	var best := -1.0
	for line in text.split("\n"):
		if line.begins_with("out_time_us=") or line.begins_with("out_time_ms="):
			best = maxf(best, line.substr(12).to_float() / 1_000_000.0)
	if best < 0.0:
		return 0
	return clampi(int(round(best / _prep_src_dur * 100.0)), 0, 99)


func finish_session(source: String, video: String, audio: String) -> void:
	var abs_video := ProjectSettings.globalize_path(video)
	var dur := probe_duration(abs_video)
	# A theora/ogg file caught mid-write can still probe successfully - ffmpeg
	# doesn't flush on every frame, so a writer can look "stale" by mtime alone
	# during a buffering gap and still be actively growing. duration <= 0.0 catches
	# a totally unparseable file; this catches the sneakier case where it parses
	# fine but is truncated (this is exactly how a real 16:22 clip got cached at
	# 2:14 - the audio step's own duration is ground truth, extracted whole, so a
	# video duration meaningfully short of it means "not actually done yet", not
	# "shorter clip").
	var audio_dur := probe_duration(ProjectSettings.globalize_path(audio))
	var incomplete := dur <= 0.0 or (audio_dur > 0.0 and dur < audio_dur - 2.0)
	if incomplete:
		var dir := video.get_base_dir()
		if looks_live(dir, video):
			editor._prep_state = "waiting_external"
			editor._set_status("⏳  Preparing clip (already in progress elsewhere)…")
			return
		editor._set_status("⚠  Cached clip looked incomplete - re-preparing…")
		prep(source, dir, video, audio)
		return
	editor.session = MaskSession.new()
	editor.session.source_path = source
	editor.session.video_path = video
	editor.session.audio_path = audio
	editor.session.duration = dur
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(editor._session_path.get_base_dir()))
	editor.session.save(ProjectSettings.globalize_path(editor._session_path))
	print("ghost mask: session ready - %s (%.0fs)" % [editor._session_path, dur])
	editor._ready_with_session()


const _STALE_AFTER := 10.0   # seconds since last write before a prep counts as abandoned

# --- prep liveness: is SOMETHING actively writing this clip's output right now? ---------------

func _lock_path(dir: String) -> String:
	return dir.path_join(".prep.lock")


## Move a finished prep output from its .part name into place. Outputs are
## written under a name the editor's importer ignores because a truncated
## media file at its REAL name is not just garbage, it's a trap: a killed
## prep left a half-written audio.wav whose WAV import looped forever on
## seeks past EOF (audio_stream_wav.cpp), hanging every editor scan until
## the file was hand-deleted. A missing .part (ffmpeg died at startup) is
## a no-op here - the duration validation downstream reports it.
func promote_part(dest: String) -> void:
	var abs_dest := ProjectSettings.globalize_path(dest)
	if FileAccess.file_exists(abs_dest + ".part"):
		if FileAccess.file_exists(abs_dest):
			DirAccess.remove_absolute(abs_dest)
		DirAccess.rename_absolute(abs_dest + ".part", abs_dest)


func _touch_lock(abs_dir: String) -> void:
	var f := FileAccess.open(_lock_path(abs_dir), FileAccess.WRITE)
	if f != null:
		f.store_string(str(Time.get_unix_time_from_system()))


func clear_lock(dir: String) -> void:
	var p := _lock_path(ProjectSettings.globalize_path(dir))
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(p)


func _fresh(path: String, now: float) -> bool:
	return FileAccess.file_exists(path) and now - FileAccess.get_modified_time(path) < _STALE_AFTER


## True if the lock file, the video output, or the audio output was modified within
## the last _STALE_AFTER seconds - covers both prep sub-steps (the lock's own touch
## bridges the gap before video.ogv exists yet; the outputs' own mtimes take over,
## and cover each other, for the rest).
func looks_live(dir: String, video: String) -> bool:
	var now := Time.get_unix_time_from_system()
	var abs_dir := ProjectSettings.globalize_path(dir)
	var abs_video := ProjectSettings.globalize_path(video)
	return _fresh(_lock_path(abs_dir), now) \
		or _fresh(abs_video, now) \
		or _fresh(abs_video + ".part", now) \
		or _fresh(abs_dir.path_join("audio.wav"), now) \
		or _fresh(abs_dir.path_join("audio.wav.part"), now)


# --- the clip's frame size and length, probed and confirmed -----------------------------------

## Robust video-duration probe. The fast path is the container's own duration,
## but our own libtheora transcode (see MaskTracks._start_track_import) routinely produces an
## .ogv whose header carries NO duration - ffprobe returns "N/A" for both
## format=duration AND stream=duration. That returned 0 here, and MaskTracks.finish_import
## reads 0 as "transcode failed" and silently adds no lane (the "Track import does
## nothing" bug). So when both are absent, fall back to counting video packets (fast,
## no decode) and dividing by the frame rate - every playable file has a definite
## packet count even when it lacks a duration field.
func probe_duration(path: String) -> float:
	var d := _ffprobe_float(["-show_entries", "format=duration"], path)
	if d > 0.0:
		return d
	d = _ffprobe_float(["-select_streams", "v:0", "-show_entries", "stream=duration"], path)
	if d > 0.0:
		return d
	var out := []
	Deps.execute("ffprobe", ["-v", "error", "-select_streams", "v:0", "-count_packets",
		"-show_entries", "stream=nb_read_packets,r_frame_rate", "-of", "default=nw=1", path], out)
	if out.size() > 0:
		var packets := 0.0
		var fps := 0.0
		for line in String(out[0]).split("\n"):
			var s := line.strip_edges()
			if s.begins_with("nb_read_packets="):
				packets = s.substr(16).to_float()
			elif s.begins_with("r_frame_rate="):
				var fr := s.substr(13).split("/")
				if fr.size() == 2 and fr[1].to_float() > 0.0:
					fps = fr[0].to_float() / fr[1].to_float()
				else:
					fps = s.substr(13).to_float()
		if packets > 0.0 and fps > 0.0:
			return packets / fps
	return 0.0


## One ffprobe query for a single float value (csv, no keys), 0.0 if it comes back
## empty or "N/A". See probe_duration for why the caller layers several of these.
func _ffprobe_float(entries: Array, path: String) -> float:
	var args := PackedStringArray(["-v", "error"])
	for e in entries:
		args.append(String(e))
	args.append("-of")
	args.append("csv=p=0")
	args.append(path)
	var out := []
	Deps.execute("ffprobe", args, out)
	if out.size() > 0:
		var s := String(out[0]).strip_edges()
		if s.is_valid_float():
			return s.to_float()
	return 0.0


## The clip's frame size in pixels, or a zero vector when ffprobe can't say.
## `csv=p=0:s=x` makes the whole answer one token - "1080x1920".
func _probe_size(path: String) -> Vector2i:
	var out := []
	Deps.execute("ffprobe", ["-v", "error", "-select_streams", "v:0",
		"-show_entries", "stream=width,height", "-of", "csv=p=0:s=x", path], out)
	if out.size() > 0:
		var parts := String(out[0]).strip_edges().split("x")
		if parts.size() >= 2 and parts[0].is_valid_int() and parts[1].is_valid_int():
			var sz := Vector2i(parts[0].to_int(), parts[1].to_int())
			if sz.x > 0 and sz.y > 0:
				return sz
	return Vector2i.ZERO


## The picture's width/height - >1 landscape, <1 portrait. See src_size.
func source_aspect() -> float:
	return float(maxi(1, src_size.x)) / float(maxi(1, src_size.y))


## Seed src_size from the prepared clip on disk, before anything has decoded.
## Silently keeps the 16:9 fallback if ffprobe is absent or unhelpful -
## sync_size corrects it from the real texture a frame or two later.
func resolve_size() -> void:
	if editor.session == null or editor.session.video_path.is_empty():
		return
	var sz := _probe_size(ProjectSettings.globalize_path(editor.session.video_path))
	if sz != Vector2i.ZERO:
		src_size = sz


## The decoded texture's size is the truth - adopt it the first frame it exists
## and re-fit the editor's video slot if the probe (or the fallback) disagreed.
## One-shot: after the first real frame the size never changes for a clip.
func sync_size() -> void:
	if size_confirmed or editor._player == null:
		return
	var tex := editor._player.get_video_texture()
	if tex == null or tex.get_width() <= 0 or tex.get_height() <= 0:
		return
	size_confirmed = true
	var sz := Vector2i(tex.get_width(), tex.get_height())
	if sz == src_size:
		return
	src_size = sz
	if editor._video_area != null:
		editor._video_area.ratio = source_aspect()
