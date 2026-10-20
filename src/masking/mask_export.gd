extends RefCounted
class_name MaskExport

## MaskExport - Masking's export, a part of [MaskEditor]: the editor relaunches itself in Movie
## Maker mode (`--mask-render`) to record the session at the clip's own size, then muxes the clip's
## sound back in with ffmpeg ([method _on_export_path], [method poll],
## [method _start_transcode]); the shared session furniture it is reached through ([method chrome]).
##
## WHAT IT IS HANDED is written out: every `editor.` below is something it reads of the editor (the
## session and its path, the render's state and processes, the status line, the clip's size).
##
## Movie Maker locks its output size to the project's viewport size at ENGINE
## STARTUP, before a single script in the relaunched process runs - so the only way
## to ask for anything other than project.godot's 1920x1080 is override.cfg, which
## Godot reads from the project root at boot. It is written here (in the editor, by
## the process that knows the clip) immediately before the render process is
## created, and removed the moment that process exits. Same mechanism, same
## reasoning, as exporter.gd's quality presets - see its _write_override.
##
## THE SIZE ASKED FOR IS THE SOURCE CLIP'S OWN, which is what makes a vertical clip
## export vertically: a 1080x1920 source records a 1080x1920 movie instead of being
## squeezed into a 16:9 frame. Before this, every mask export was 1920x1080 whatever
## went in - correct by coincidence for a 1080p landscape clip, an upscale for
## anything smaller, and a distortion for anything not 16:9.
##
## Capped on the long side because the fixed 1920x1080 window used to cap it there
## anyway: a 4K source should not silently turn into a 4K render (minutes per frame,
## tens of GB of scratch AVI) just because this now honors the source.

## The [MaskEditor] this is a part of: everything read through it is something this part
## is handed, and the list of them is what it depends on.
var editor: MaskEditor

var _dialog: FileDialog
var _out := ""
var _avi := ""

# --- export: relaunch in Movie Maker mode (--mask-render), then ffmpeg mux --------------------

## The shared session furniture, if this session has any (the render relaunch and
## the gates run without it). BY GROUP, not by walking the tree: the first cut
## walked two levels down from the root and the exporter is three - root, main,
## chrome, exporter - so it silently found nothing and the suppression below never
## happened. The button stayed on top, grayed, swallowing every click.
func chrome() -> Node:
	if editor.get_tree() == null:
		return null
	return editor.get_tree().get_first_node_in_group("ghost_chrome")


func build_ui() -> void:
	editor._export_btn = Button.new()
	editor._export_btn.focus_mode = Control.FOCUS_NONE
	editor._export_btn.text = "⤓"                    # icon-only - matches assistant.gd's chat-bubble toggle
	editor._export_btn.tooltip_text = "Render this mask session to a video file (in the background)"
	editor._export_btn.custom_minimum_size = Vector2(40, 40)
	editor._export_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	# Same 40x40 box, same row (-28/-68), as assistant.gd's toggle, right of this one -
	# see that file's _TOGGLE_SIZE/_TOGGLE_ROW_BOTTOM doc for why the numbers match.
	editor._export_btn.offset_left = -112
	editor._export_btn.offset_top = -68
	editor._export_btn.offset_right = -72
	editor._export_btn.offset_bottom = -28
	editor._export_btn.pressed.connect(_on_export_pressed)
	editor.add_child(editor._export_btn)
	# The SHARED export button steps aside - see Exporter.suppressed. Masking has
	# its own export (a headless relaunch against the session json rather than the
	# bake pipeline), and the shared one is on a higher CanvasLayer, so left alone
	# it covers this one and swallows the click while grayed out.
	var ch := chrome()
	if ch != null:
		ch.suppress_export(&"mask")

	_dialog = FileDialog.new()
	_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_dialog.use_native_dialog = true
	_dialog.title = "Export mask video"
	_dialog.filters = PackedStringArray(["*.mp4 ; Video (MP4, H.264 + AAC)"])
	_dialog.current_file = "ghost_mask.mp4"
	var downloads := OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	if not downloads.is_empty():
		_dialog.current_dir = downloads
	_dialog.size = Vector2i(800, 560)
	_dialog.file_selected.connect(_on_export_path)
	editor.add_child(_dialog)


func _on_export_pressed() -> void:
	_dialog.popup_centered()


func _on_export_path(out_path: String) -> void:
	_out = out_path if out_path.get_extension().to_lower() == "mp4" else out_path + ".mp4"
	_avi = _out.get_basename() + ".render.avi"
	if FileAccess.file_exists(_avi):
		DirAccess.remove_absolute(_avi)   # a stale scratch AVI from an interrupted prior export
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(editor._session_path.get_base_dir()))
	editor.session.save(ProjectSettings.globalize_path(editor._session_path))   # the relaunch reads THIS file
	# The relaunch must be TOLD what shape to record in, and it has to be told
	# before it boots - see write_override.
	var rsz := render_size()
	write_override(rsz)
	var exe := OS.get_executable_path()
	var args := Subprocess.own_log("mask_render") + Boot.project_args() + PackedStringArray([
		"--write-movie", _avi, "--fixed-fps", "25",
		"--", "--mask-render", editor._session_path])
	editor._render_pid = Subprocess.start(exe, args, "mask render")
	if editor._render_pid > 0:
		editor._render_state = "rendering"
		editor._set_status("⏺  Rendering %d×%d…" % [rsz.x, rsz.y])
	else:
		clear_override()   # nothing booted; don't leave it lying for the next launch
		editor._set_status("⚠  Could not start the render process")


func poll() -> void:
	match editor._render_state:
		"rendering":
			if Subprocess.alive(editor._render_pid):
				return
			# The render process has read its override at boot and is gone - take it
			# back out of the project root now, so a later launch (an F5 reload
			# included, see _reload_requested) comes up in the normal live window
			# mode and never inherits the render's offscreen resolution.
			clear_override()
			if _file_size(_avi) > 65536:
				_repair_avi_sizes(_avi)   # Godot's 32-bit AVI sizes wrap past 4 GiB; fix before transcode
				_start_transcode()
			else:
				editor._set_status("⚠  Render produced no file (see console)")
				editor._render_state = "idle"
		"transcoding":
			if Subprocess.alive(editor._transcode_pid):
				return
			# Always clear the scratch AVI - never leave an intermediate behind.
			if _file_size(_out) > 4096:
				DirAccess.remove_absolute(_avi)
				editor._set_status("✓  Saved  " + _out)
			else:
				DirAccess.remove_absolute(_avi)
				editor._set_status("⚠  Transcode failed (see console)")
			editor._render_state = "idle"
	# A reload asked for while this export was in flight (see _reload_requested) is
	# held here until the export just went idle, then re-asked - re-checking the
	# assistant's own busy state fresh rather than assuming it's still the same.
	if editor._render_state == "idle" and editor._reload_after_export:
		editor._reload_after_export = false
		editor._reload_requested()


func _start_transcode() -> void:
	editor._set_status("⏳  Finalizing…")
	# `-fflags +genpts` re-derives timestamps so a damaged/wrapped AVI index (see
	# _repair_avi_sizes) is bypassed instead of trusted - without it a >4 GiB render
	# transcodes to a broken file or fails outright, leaving the raw .render.avi behind.
	# `-pix_fmt yuv420p` keeps the MP4 playable everywhere (VLC/QuickTime/browsers).
	# The scratch AVI is deleted by poll once the .mp4 is there. If ghost closes
	# mid-transcode, ffmpeg dies with it (see [Subprocess]) and the AVI stays - it is then
	# the only complete copy of the render - until the next export clears it.
	editor._transcode_pid = Subprocess.start("ffmpeg", PackedStringArray([
		"-y", "-loglevel", "error", "-fflags", "+genpts", "-i", _avi,
		"-c:v", "libx264", "-preset", "medium", "-crf", "18", "-pix_fmt", "yuv420p",
		"-c:a", "aac", "-b:a", "192k", _out]), "mask transcode")
	editor._render_state = "transcoding"


# Godot's AVI writer keeps 32-bit RIFF/LIST size fields, and a full-resolution mask
# render crosses 4 GiB in a few minutes - past that the written sizes WRAP (mod 2^32)
# and the container lies about where the frame data ends, even though every 00db/01wb
# chunk after it is written correctly to EOF. Demuxers that trust those fields (and
# players, whose seeks hit the equally-wrapped idx1 offsets) stall, repeat frames, or
# break time indexing (this is why VLC's scrub bar goes wrong on the raw AVI). The
# repair is two words: RIFF size and the movi LIST size become 0 - "size unknown, read
# to end of file" - turning any demux into a clean sequential walk of the intact chunks.
# No-op for files under 4 GiB (their sizes are already correct). Mirrors exporter.gd.
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
			print("ghost mask export: repaired wrapped >4GiB AVI sizes in ", path.get_file())
			break
		if csize <= 0 or tag.is_empty():
			break
		pos += 8 + csize + (csize & 1)
	f.close()


func _file_size(path: String) -> int:
	if not FileAccess.file_exists(path):
		return 0
	var fa := FileAccess.open(path, FileAccess.READ)
	return fa.get_length() if fa != null else 0


const _RENDER_MAX_SIDE := 1920

# --- the export's recorded resolution ---------------------------------------------------------

func render_size() -> Vector2i:
	var w := float(maxi(2, editor._source_prep.src_size.x))
	var h := float(maxi(2, editor._source_prep.src_size.y))
	var s: float = minf(1.0, float(_RENDER_MAX_SIDE) / maxf(w, h))
	return Vector2i(_even(w * s), _even(h * s))


## Even, because yuv420p (the transcode's pixel format) cannot encode an odd
## dimension - a half-pixel would be rejected outright by x264.
static func _even(v: float) -> int:
	return maxi(2, int(round(v * 0.5)) * 2)


func _override_path() -> String:
	return Boot.project_dir().path_join("override.cfg")


func write_override(sz: Vector2i) -> void:
	var f := FileAccess.open(_override_path(), FileAccess.WRITE)
	if f == null:
		push_warning("ghost mask export: could not write override.cfg (render falls back to 1920x1080)")
		return
	# viewport_* is the RECORDED resolution; window_*_override shrinks the OS window
	# itself to an unobtrusive floater. In "viewport" stretch mode the two are
	# independent, so the movie is an offscreen buffer of exactly the clip's size
	# regardless of the monitor. The window keeps the clip's SHAPE (not a fixed
	# 480x270) purely so the little preview looks like what is being recorded. It
	# must stay a normal, drawable window - minimizing it makes Godot skip rendering
	# and the movie records frozen frames (see boot.gd).
	var s: float = 480.0 / float(maxi(2, maxi(sz.x, sz.y)))
	var win := Vector2i(_even(float(sz.x) * s), _even(float(sz.y) * s))
	f.store_string("[display]\n\nwindow/size/viewport_width=%d\nwindow/size/viewport_height=%d\nwindow/size/window_width_override=%d\nwindow/size/window_height_override=%d\nwindow/stretch/mode=\"viewport\"\n"
		% [sz.x, sz.y, win.x, win.y])
	# AND THE INTERMEDIATE'S QUALITY, which is the difference between one lossy
	# generation and two. Godot writes .avi as MJPEG in yuvj420p - lossy, and
	# already chroma-subsampled before x264 ever sees the frame - at
	# `video_quality` 0.75 by default. Measured on a real umbra frame against the
	# source: one generation (source -> x264 crf18) reads PSNR 45.5 dB; through
	# the 0.75 intermediate it reads 42.6; at 1.0 it reads 44.3. The default was
	# nearly DOUBLING the error (MSE 1.85 -> 3.57) to save space in a scratch file
	# that is deleted seconds later.
	#
	# 1.0 is not lossless - MJPEG cannot be - and the remaining ~1.2 dB is the
	# price of the container. Godot's only lossless writer is the PNG SEQUENCE (a
	# .png movie path writes out00000000.png... plus a .wav), which for a
	# ten-minute 1080p render is tens of gigabytes of scratch rather than a few,
	# so it is not the default.
	f.store_string("\n[editor]\n\nmovie_writer/video_quality=1.0\n")
	f.close()


## Remove it. Called when our render exits, and once at editor startup to clear a
## stale copy left behind by a render that was killed or crashed - left in place,
## it would boot the LIVE editor into the render's offscreen resolution.
func clear_override() -> void:
	var path := _override_path()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
