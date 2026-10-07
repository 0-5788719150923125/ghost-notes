extends Node
class_name Showcase

## Showcase - the README's animation, recorded from the real app: a Manual note playing
## `storyboards/showcase.yaml` (a blue prism flies in and divides into a blue one and a red one,
## the pair lock, then take opposite highways), with the note's panel, the row and the transport
## around it - the UI as a person sees it, not a picture of the stage alone. Praxis records its
## README stills from its own frontend the same way (its `tools/render_web.py`).
##
## ONLY WHEN IT WOULD CHANGE. The recording keeps a list of every file it LOADED - each script,
## shader, scene and font Godot's resource cache holds while the show plays, the storyboard and
## `project.godot` ([method loaded_files]) - and `docs/showcase.json` stamps a digest of their
## contents with the engine's version. A launch hashes those same files again and records only when
## the digest moved, so an edit to a scene the show never draws costs nothing, and an edit to the
## prism, the panel or the transport records it again. The webp is written only when its bytes
## differ, so a recording that comes out the same leaves git with nothing to show.
##
## ONLY IN DEVELOPMENT: the trigger runs where Godot's own `editor` feature is (the project run from
## its source with the editor binary), never in an exported build ([method skip_reason]), and never
## in a render, a probe, a headless run or the phone shell. It needs `xvfb-run` - the recording runs
## on a virtual display, never as a window on the author's desktop - and FFmpeg for the webp; when
## either is missing it says so once and records nothing.
##
## HOW IT IS MADE: a second ghost under Movie Maker (`--write-movie` to a PNG sequence, `--fixed-fps`,
## so every frame is one fixed step of show time however slow the frame was to draw), started with
## `--showcase <work>` ([ShowcaseRecorder]): read-only like an export, and on a user:// of its own
## (`XDG_DATA_HOME` under the work folder) so the author's settings, folds and notes never reach the
## picture. It makes the note, opens it the way the notes list does, presses Play, and quits after
## [method frames] frames. This node then encodes the last of them to an animated webp.
##
##   godot --headless --path . -- --showcase-now     records it now, stale or not, then quits

## The webp's size, frame rate and quality (libwebp, 0-100). Movie Maker records at the project's
## own size whatever the window ([method recorded_size]), and FFmpeg scales that down to this - the
## UI as a 1280-pixel window would draw it, edges smoothed by the larger render.
const SIZE := Vector2i(1280, 720)
const FPS := 15
const QUALITY := 72
## The storyboard it plays, and the song's length - the storyboard's holds, end to end.
const STORYBOARD := "showcase"
const SONG := 15.0
## The note's bookends: the picture fades up from an empty void and back down to it, so the
## animation loops on the void.
const INTRO := 0.5
const OUTRO := 1.0
## The note the recording makes. Its title is the header of the panel in the picture.
const TITLE := "A prism divides"
const BODY := "One blue prism, then two - a blue one and a red one.\n"

## What the README shows, and the stamp beside it.
const OUT := "res://docs/showcase.webp"
const STAMP := "res://docs/showcase.json"
## The work folder, on the real disk (dist/ is git-ignored; /tmp is a RAM disk and the frames are
## a few hundred MB).
const WORK := "res://dist/showcase"
## A recording claimed less than this long ago (seconds) is left to finish: two launches at once
## record once.
const CLAIM_S := 900
## Folders whose files a recording could load. Everything else in the project (tests, hosts,
## reference imagery, the work folder itself) is never part of the show.
const SOURCE_DIRS := ["src", "shaders", "scenes", "fonts", "storyboards", "data"]
## Read with FileAccess rather than loaded as resources, so the cache never lists them.
const ALWAYS := ["res://project.godot", "res://scenes/main.tscn", "res://storyboards/showcase.yaml"]

var _render_pid := -1
var _encode_pid := -1
var _work := ""
var _quit_after := false


## Why the trigger does nothing in this process ("" when it may record). A person's ordinary
## launch prints nothing at all unless a recording is due. `--showcase-now` asks from a terminal,
## so it may be headless: this process only starts the recording and encodes it.
static func skip_reason() -> String:
	if not OS.has_feature("editor"):
		return "not a development build"
	var asked := OS.get_cmdline_user_args().has("--showcase-now")
	if DisplayServer.get_name() == "headless" and not asked:
		return "headless"
	var tree := Engine.get_main_loop() as SceneTree
	var st: Node = tree.root.get_node_or_null("Settings") if tree != null else null
	if st != null and bool(st.is_read_only()):
		return "a read-only process"
	var boot: Node = tree.root.get_node_or_null("Boot") if tree != null else null
	if boot != null and bool(boot.handheld()):
		return "the phone shell"
	return ""


## The frames a recording keeps: the bookends and the song between them.
static func frames() -> int:
	return int(round((INTRO + SONG + OUTRO) * FPS))


## The size Movie Maker records at: the project's viewport, set before any script runs (measured:
## `--resolution` changes the window and not the recording).
static func recorded_size() -> Vector2i:
	return Vector2i(int(ProjectSettings.get_setting("display/window/size/viewport_width")),
		int(ProjectSettings.get_setting("display/window/size/viewport_height")))


## EVERY FILE THE SHOW HAS LOADED SO FAR, as res:// paths: the resource cache's view of
## [constant SOURCE_DIRS], plus [constant ALWAYS]. Called during a recording; a resource freed
## before the call is missed, so the recorder calls it as the show plays, not once at the end.
static func loaded_files() -> PackedStringArray:
	var out := PackedStringArray(ALWAYS)
	for d in SOURCE_DIRS:
		_walk("res://" + d, out)
	out.sort()
	return out


static func _walk(dir: String, out: PackedStringArray) -> void:
	var da := DirAccess.open(dir)
	if da == null:
		return
	for f in da.get_files():
		if f.ends_with(".import") or f.ends_with(".uid"):
			continue
		var p := dir.path_join(f)
		if not out.has(p) and ResourceLoader.has_cached(p):
			out.append(p)
	for sub in da.get_directories():
		_walk(dir.path_join(sub), out)


## THE DIGEST of [param files]: each path and its content, in order, with the engine's version and
## the recording's own shape. A file that is gone hashes as gone, so deleting one moves it too.
static func digest(files: PackedStringArray) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(("%s|%dx%d@%d|q%d" % [Engine.get_version_info().string, SIZE.x, SIZE.y, FPS, QUALITY]).to_utf8_buffer())
	var sorted := files.duplicate()
	sorted.sort()
	for p in sorted:
		ctx.update(("\n" + p + "=").to_utf8_buffer())
		ctx.update(FileAccess.get_sha256(p).to_utf8_buffer() if FileAccess.file_exists(p) else "gone".to_utf8_buffer())
	return ctx.finish().hex_encode()


## Is the README's animation out of date: no webp, no stamp, or the files it loaded have changed?
## [param out] and [param stamp_path] are a gate's seam.
static func stale(out := OUT, stamp_path := STAMP) -> bool:
	if not FileAccess.file_exists(out) or not FileAccess.file_exists(stamp_path):
		return true
	var stamp: Variant = JSON.parse_string(FileAccess.get_file_as_string(stamp_path))
	if not (stamp is Dictionary) or not (stamp.get("files") is Array):
		return true
	return digest(PackedStringArray(stamp["files"])) != String(stamp.get("digest", ""))


func _ready() -> void:
	set_process(false)
	_quit_after = OS.get_cmdline_user_args().has("--showcase-now")
	var why := skip_reason()
	if not why.is_empty():
		if _quit_after:
			_done("not recorded: %s" % why, 1)
		return
	if not _quit_after and not stale():
		return
	_work = ProjectSettings.globalize_path(WORK)
	var claim := _work.path_join("claim")
	if not _quit_after and FileAccess.file_exists(claim) \
			and Time.get_unix_time_from_system() - FileAccess.get_modified_time(claim) < CLAIM_S:
		return
	var godot := OS.get_executable_path()
	var argv := Exporter.virtual_display(godot, PackedStringArray(), recorded_size() + Vector2i(64, 64))
	if argv.is_empty():
		_done("the README animation is out of date, but it is recorded only on a virtual display - %s"
			% Deps.hint("xvfb"), 1)
		return
	if Deps.resolve("ffmpeg").is_empty():
		_done("the README animation is out of date, but FFmpeg is not installed yet", 1)
		return
	_start(argv, claim)


## Start the recording: a fresh frames folder, the claim, and the second ghost on its own display
## and its own user:// ([constant WORK]/data).
func _start(argv: PackedStringArray, claim: String) -> void:
	var frames_dir := _work.path_join("frames")
	DirAccess.make_dir_recursive_absolute(frames_dir)
	# kept out of the editor's scan, or it imports every frame as a texture (the song loads from its
	# path, never through the importer)
	if not FileAccess.file_exists(_work.path_join(".gdignore")):
		FileAccess.open(_work.path_join(".gdignore"), FileAccess.WRITE).close()
	for f in DirAccess.get_files_at(frames_dir):
		DirAccess.remove_absolute(frames_dir.path_join(f))
	DirAccess.remove_absolute(_work.path_join("capture.json"))
	var fc := FileAccess.open(claim, FileAccess.WRITE)
	if fc != null:
		fc.store_string(str(OS.get_process_id()))
		fc.close()
	argv.append_array(["--path", ProjectSettings.globalize_path("res://"),
		"--log-file", _work.path_join("render.log"),
		"--write-movie", frames_dir.path_join("frame.png"), "--fixed-fps", str(FPS),
		"--", "--showcase", _work])
	# `env` sets the child's user:// and nothing else; the display wrapper comes after it
	var full := PackedStringArray(["XDG_DATA_HOME=" + _work.path_join("data")])
	full.append_array(argv)
	_render_pid = Subprocess.start("env", full, "showcase")
	if _render_pid <= 0:
		_done("could not start the README animation's recording", 1)
		return
	print("ghost showcase: recording the README animation in the background (pid %d, log %s)"
		% [_render_pid, _work.path_join("render.log")])
	set_process(true)


func _process(_dt: float) -> void:
	if _render_pid > 0:
		if Subprocess.alive(_render_pid):
			return
		_render_pid = -1
		_encode()
	elif _encode_pid > 0:
		if Subprocess.alive(_encode_pid):
			return
		_encode_pid = -1
		_publish()


## The recorder's last [method frames] frames, encoded to an animated webp beside them.
func _encode() -> void:
	var cap: Variant = JSON.parse_string(FileAccess.get_file_as_string(_work.path_join("capture.json")))
	if not (cap is Dictionary):
		_done("the recording ended without finishing - see %s" % _work.path_join("render.log"), 1)
		return
	var frames_dir := _work.path_join("frames")
	var pngs := Array(DirAccess.get_files_at(frames_dir)).filter(func(f: String) -> bool: return f.ends_with(".png"))
	pngs.sort()
	var keep := frames()
	if pngs.size() < keep:
		_done("the recording has %d frames, short of %d" % [pngs.size(), keep], 1)
		return
	var first := String(pngs[pngs.size() - keep])
	var img := Image.load_from_file(frames_dir.path_join(first))
	if img == null or img.get_size() != recorded_size():
		_done("the recording is %s, not %s - not used" % [img.get_size() if img != null else "unreadable", recorded_size()], 1)
		return
	var start := first.trim_prefix("frame").trim_suffix(".png")
	_encode_pid = Subprocess.start("ffmpeg", PackedStringArray([
		"-y", "-hide_banner", "-loglevel", "error",
		"-framerate", str(FPS), "-start_number", str(int(start)),
		"-i", frames_dir.path_join("frame%0" + str(start.length()) + "d.png"), "-frames:v", str(keep),
		"-vf", "scale=%d:%d:flags=lanczos" % [SIZE.x, SIZE.y],
		"-c:v", "libwebp_anim", "-lossless", "0", "-quality", str(QUALITY),
		"-compression_level", "6", "-loop", "0", "-an", _work.path_join("showcase.webp")]), "showcase")
	if _encode_pid <= 0:
		_done("could not start FFmpeg for the README animation", 1)


## The webp into docs/ - only when its bytes changed - and the stamp of what it was made from.
func _publish() -> void:
	var made := FileAccess.get_file_as_bytes(_work.path_join("showcase.webp"))
	if made.is_empty():
		_done("FFmpeg made no webp", 1)
		return
	var cap: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_work.path_join("capture.json")))
	var files := PackedStringArray(cap.get("files", []))
	var changed := made != FileAccess.get_file_as_bytes(OUT)
	if changed:
		_write(OUT, made)
	var stamp := JSON.stringify({"digest": digest(files), "frames": frames(), "files": Array(files)}, "\t") + "\n"
	if stamp != FileAccess.get_file_as_string(STAMP):
		_write(STAMP, stamp.to_utf8_buffer())
	_done("README animation %s (%d frames, %d KB)" % ["updated" if changed else "unchanged",
		frames(), made.size() / 1024], 0)


## Beside the target and renamed into place, so a reader never sees half a file.
static func _write(res_path: String, bytes: PackedByteArray) -> void:
	var path := ProjectSettings.globalize_path(res_path)
	var part := path + ".part"
	var f := FileAccess.open(part, FileAccess.WRITE)
	if f == null:
		push_warning("ghost showcase: could not write %s" % path)
		return
	f.store_buffer(bytes)
	f.close()
	DirAccess.rename_absolute(part, path)


func _done(msg: String, code: int) -> void:
	set_process(false)
	if not _work.is_empty():
		DirAccess.remove_absolute(_work.path_join("claim"))
	print("ghost showcase: " + msg)
	if _quit_after:
		get_tree().quit(code)
