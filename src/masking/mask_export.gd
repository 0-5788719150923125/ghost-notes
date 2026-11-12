extends RefCounted
class_name MaskExport

## MaskExport - Masking's export, a part of [MaskEditor]: the editor relaunches itself in Movie Maker mode
## (`--mask-render`) to record the session at the clip's own size, then muxes the clip's sound back in with ffmpeg
## ([method _on_export_path], [method poll], [method _start_transcode]); the shared session furniture it is reached
## through is [method chrome].
##
## Movie Maker fixes its output size to the project's viewport size at engine startup, so any size other than
## project.godot's is asked for through override.cfg, which Godot reads from the project root at boot. It is written
## just before the render process is created and removed when that process exits (same mechanism as exporter.gd's
## quality presets, see its _write_override).
##
## The size asked for is the source clip's own (a 1080x1920 clip records 1080x1920), capped to 1920 on the long side
## so a 4K source does not become a 4K render (minutes per frame, tens of GB of scratch AVI).

## The [MaskEditor] this is a part of: everything read through it is something this part is handed.
var editor: MaskEditor

var _dialog: FileDialog
var _out := ""
var _avi := ""

# --- export: relaunch in Movie Maker mode (--mask-render), then ffmpeg mux --------------------

## The shared session furniture, if this session has any (the render relaunch and the gates run without it). Found
## by group, not by walking the tree: the exporter's depth under the root varies.
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
	# Same 40x40 box and row (-28/-68) as assistant.gd's toggle (see its _TOGGLE_SIZE/_TOGGLE_ROW_BOTTOM), to its right.
	editor._export_btn.offset_left = -112
	editor._export_btn.offset_top = -68
	editor._export_btn.offset_right = -72
	editor._export_btn.offset_bottom = -28
	editor._export_btn.pressed.connect(_on_export_pressed)
	editor.add_child(editor._export_btn)
	# The shared export button steps aside (see Exporter.suppressed): Masking has its own export, and the shared one
	# sits on a higher CanvasLayer and would swallow the click while grayed out.
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
	# The relaunch is told the shape to record in before it boots (see write_override).
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
			# The render has read its override at boot: take it back out of the project root so a later launch (an
			# F5 reload included) comes up in the normal live window mode.
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
	# A reload asked for during the export (see _reload_requested) is held until it goes idle, then re-asked.
	if editor._render_state == "idle" and editor._reload_after_export:
		editor._reload_after_export = false
		editor._reload_requested()


func _start_transcode() -> void:
	editor._set_status("⏳  Finalizing…")
	# `-fflags +genpts` re-derives timestamps so a wrapped AVI index (see _repair_avi_sizes) is bypassed, not trusted.
	# `-pix_fmt yuv420p` keeps the MP4 playable everywhere. poll deletes the scratch AVI once the .mp4 is there; if
	# ghost closes mid-transcode, ffmpeg dies with it (see [Subprocess]) and the AVI stays, the only complete copy,
	# until the next export clears it.
	editor._transcode_pid = Subprocess.start("ffmpeg", PackedStringArray([
		"-y", "-loglevel", "error", "-fflags", "+genpts", "-i", _avi,
		"-c:v", "libx264", "-preset", "medium", "-crf", "18", "-pix_fmt", "yuv420p",
		"-c:a", "aac", "-b:a", "192k", _out]), "mask transcode")
	editor._render_state = "transcoding"


# Godot's AVI writer keeps 32-bit RIFF/LIST size fields, which wrap (mod 2^32) past 4 GiB, though the chunks after
# them are intact. Demuxers and players that trust them stall or misindex. The repair sets the RIFF size and the movi
# LIST size to 0 ("unknown, read to end of file"), so any demux walks the chunks sequentially. A no-op under 4 GiB.
# Mirrors exporter.gd.
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
	# viewport_* is the recorded resolution; window_*_override shrinks the OS window to a floater. In "viewport"
	# stretch mode the two are independent, so the movie is an offscreen buffer of exactly the clip's size. The
	# window keeps the clip's shape so the preview looks like what is recorded, and must stay a normal drawable
	# window: minimizing it makes Godot skip rendering and the movie records frozen frames (see boot.gd).
	var s: float = 480.0 / float(maxi(2, maxi(sz.x, sz.y)))
	var win := Vector2i(_even(float(sz.x) * s), _even(float(sz.y) * s))
	f.store_string("[display]\n\nwindow/size/viewport_width=%d\nwindow/size/viewport_height=%d\nwindow/size/window_width_override=%d\nwindow/size/window_height_override=%d\nwindow/stretch/mode=\"viewport\"\n"
		% [sz.x, sz.y, win.x, win.y])
	# The intermediate's quality: Godot writes .avi as MJPEG (lossy, chroma-subsampled) at video_quality 0.75 by
	# default; on an umbra frame PSNR against the source is 42.6 dB through 0.75, 44.3 at 1.0 (45.5 for x264 alone).
	# 1.0 is not lossless; Godot's lossless writer is the PNG sequence, tens of GB of scratch for a long render.
	f.store_string("\n[editor]\n\nmovie_writer/video_quality=1.0\n")
	f.close()


## Remove it. Called when our render exits, and once at editor startup to clear a copy left by a killed render
## (it would boot the live editor into the render's offscreen resolution).
func clear_override() -> void:
	var path := _override_path()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
