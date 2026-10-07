extends Node

## portrait_render_check - ONE SMALL REAL RENDER, read back (next/notes.md step 10): the only check that
## catches the trap. The exporter records the viewport inside a small window, on the belief that
## window and viewport are independent; under the project's `expand` aspect they are only while the
## two have one shape. MEASURED: a 1080x1920 render in the old 480x270 window lays the show out in a
## 3413x1920 view, and Movie Maker records its middle 1080 - the file is the size asked either way, so
## a file's size alone cannot see the trap; what was laid out has to be compared with what was kept.
##
##   GHOST_PROBE_GPU=1 tests/run_boot_probe.sh tests/portrait_render_check.gd 240
##
## Movie Maker runs as the exporter runs it - `override.cfg` written by [method Exporter.override_text],
## `--write-movie`, `--export` (which keeps the child's settings read-only) - for a moment of a full-frame
## show on a fixture song. The AVI's own header must say 1080x1920, and the view the child says it laid
## the show out in (its `ghost export: view` line, in a log of its own) must be that same picture.
## TWO-SIDED: the same render with the old override (a 480x270 window, no `aspect`) must lay out in a
## view the recording does not hold, or this proves nothing. Refused, not run, while an export is under
## way (its override.cfg is in the project).

var _fails: Array = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var root := ProjectSettings.globalize_path("res://").simplify_path()
	var override := root.path_join("override.cfg")
	if FileAccess.file_exists(override):
		print("portrait_render_check: an export is under way (override.cfg) - not run")
		get_tree().quit(1)
		return
	var song: String = preload("res://tests/fixture_audio.gd").silence(1.0)
	var good: Dictionary = await _render(root, Exporter.override_text(1080, 1920), song)
	_ok(good["recorded"] == Vector2i(1080, 1920), "the portrait render records 1080x1920 (%s)" % good["recorded"])
	_ok(good["view"] == good["recorded"], "...and the show was laid out in exactly that picture (view %s)" % good["view"])
	var old := "[display]\n\nwindow/size/viewport_width=1080\nwindow/size/viewport_height=1920\nwindow/size/window_width_override=480\nwindow/size/window_height_override=270\nwindow/stretch/mode=\"viewport\"\n"
	var trapped: Dictionary = await _render(root, old, song)
	_ok(trapped["recorded"] != Vector2i.ZERO and trapped["view"] != Vector2i.ZERO and trapped["view"] != trapped["recorded"],
		"the control: in the old landscape window the show is laid out in %s and %s of it recorded - the trap, measured"
			% [trapped["view"], trapped["recorded"]])
	if _fails.is_empty():
		print("portrait_render_check: ALL OK")
		get_tree().quit(0)
		return
	print("portrait_render_check: %d FAILURE(S)" % _fails.size())
	for f in _fails:
		print("   ", f)
	get_tree().quit(1)


func _ok(cond: bool, msg: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + msg)
	if not cond:
		_fails.append(msg)


## Render a moment with [param text] as the override: `recorded`, the AVI's frame size, and `view`, the
## view the child laid the show out in (each ZERO when none came).
func _render(root: String, text: String, song: String) -> Dictionary:
	var override := root.path_join("override.cfg")
	var avi := ProjectSettings.globalize_path("user://portrait_render_check.avi")
	var log := ProjectSettings.globalize_path("user://portrait_render_check.log")
	DirAccess.remove_absolute(avi)
	DirAccess.remove_absolute(log)
	var f := FileAccess.open(override, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	var args := PackedStringArray(["--path", root, "--log-file", log, "--write-movie", avi, "--fixed-fps", "10", "--quit-after", "40",
		"--", "--export", "--audio", song, "--until", "0.5", "--medium", "full", "--frame", "portrait"])
	var pid := OS.create_process(OS.get_executable_path(), args)
	var t0 := Time.get_ticks_msec()
	while pid > 0 and OS.is_process_running(pid) and Time.get_ticks_msec() - t0 < 120000:
		await get_tree().create_timer(0.25).timeout
	if pid > 0 and OS.is_process_running(pid):
		OS.kill(pid)
	DirAccess.remove_absolute(override)
	var out := {"recorded": _avi_size(avi), "view": Vector2i.ZERO}
	var said := RegEx.create_from_string("ghost export: view (\\d+)x(\\d+)").search(FileAccess.get_file_as_string(log))
	if said != null:
		out["view"] = Vector2i(int(said.get_string(1)), int(said.get_string(2)))
	DirAccess.remove_absolute(avi)
	DirAccess.remove_absolute(log)
	return out


## Width and height from an AVI's main header (`avih`: dwWidth and dwHeight, 32 and 36 bytes in).
static func _avi_size(path: String) -> Vector2i:
	if not FileAccess.file_exists(path):
		return Vector2i.ZERO
	var fh := FileAccess.open(path, FileAccess.READ)
	var head := fh.get_buffer(4096)
	fh.close()
	for i in head.size() - 48:
		if head[i] == 0x61 and head[i + 1] == 0x76 and head[i + 2] == 0x69 and head[i + 3] == 0x68:   # "avih"
			var d := i + 8
			return Vector2i(head.decode_u32(d + 32), head.decode_u32(d + 36))
	return Vector2i.ZERO
