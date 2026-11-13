extends Node
class_name Showcase

## Showcase - the README's animation, recorded from the real app: a note with a song playing
## `data/showcase.json` (a blue prism flies in and divides into a blue one and a red one, they divide again
## into the corners of a larger tetrahedron that turns as one, it comes apart, and the last, red, drifts out),
## with the note's panel, the row and the transport around it. The same note is the demo note every desktop
## starts with ([method make_demo_note]), its storyboard its own to edit.
##
## Only when it would change: the recording keeps a list of every file it loaded (each script, shader,
## scene and font in Godot's resource cache while the show plays, the storyboard and `project.godot` -
## [method loaded_files]) and `docs/showcase.json` stamps a digest of their contents with the engine's
## version. A launch hashes the same files and records only when the digest moved. The webp is written only
## when its bytes differ.
##
## At most once a day: a launch records only once [constant DAY] has passed since the last recording began
## ([method next_due]: `dist/showcase/started`, this checkout's alone, never in git), finished or not;
## `--showcase-now` records regardless. The day is read before the digest, so a launch inside it hashes
## nothing.
##
## Only in development: the trigger runs where Godot's `editor` feature is, never in an exported build
## ([method skip_reason]), a render, a probe, a headless run or the phone shell. It needs `xvfb-run` (the
## recording runs on a virtual display) and FFmpeg for the webp; when either is missing it says so once and
## records nothing.
##
## How it is made: a second ghost under Movie Maker (`--write-movie` to a PNG sequence, `--fixed-fps`),
## started with `--showcase <work>` ([ShowcaseRecorder]): read-only like an export, with a user:// of its
## own (`XDG_DATA_HOME` under the work folder) so the author's settings and notes never reach the picture.
## It makes the note, opens it the way the notes list does, presses Play and quits after [method frames]
## frames. This node then encodes the last of them to an animated webp.
##
##   godot --headless --path . -- --showcase-now     records it now, stale or not, then quits

## The webp's size, frame rate and quality (libwebp, 0-100). Movie Maker records at the project's own size
## whatever the window ([method recorded_size]), and FFmpeg scales that down to this. An animated webp keeps
## only what each frame changes, so where a lit thing goes back to black a faint lossy smear stays on the void;
## clearing it (quality 97) costs about three times the size.
const SIZE := Vector2i(1280, 720)
const FPS := 15
const QUALITY := 72
## The storyboard it plays: the song is as long as its entries, end to end ([method song]).
const STORYBOARD := "res://data/showcase.json"
## The note's bookends: the picture fades up from an empty void and back down to it, so the animation loops.
const INTRO := 0.5
const OUTRO := 1.0
## The note the recording makes. Its title is the header of the panel in the picture.
const TITLE := "A prism divides"
const BODY := "One blue prism, then two, then a shape of many - and then none.\n"
## The demo note's song ([method make_demo_note]): written once beside the author's things.
const DEMO_SONG := "user://demo/a_prism_divides.wav"

## What the README shows, and the stamp beside it.
const OUT := "res://docs/showcase.webp"
const STAMP := "res://docs/showcase.json"
## The work folder, on the real disk (dist/ is git-ignored; /tmp is a RAM disk and the frames are a few
## hundred MB).
const WORK := "res://dist/showcase"
## A recording claimed less than this long ago (seconds) is left to finish: two launches at once record once.
const CLAIM_S := 900
## The least time between two recordings a launch starts (seconds), and the file in the work folder
## that holds when the last one began (unix seconds).
const DAY := 86400
const STARTED := "started"
## Folders whose files a recording could load. Everything else in the project (tests, hosts,
## reference imagery, the work folder itself) is never part of the show.
const SOURCE_DIRS := ["src", "shaders", "scenes", "fonts", "data"]
## Read with FileAccess rather than loaded as resources, so the cache never lists them.
const ALWAYS := ["res://project.godot", "res://scenes/main.tscn", STORYBOARD]

var _render_pid := -1
var _encode_pid := -1
var _work := ""
var _quit_after := false
## How the last recording ended, as it was said ("" while none has).
var ended := ""


## Why the trigger does nothing in this process ("" when it may record). `--showcase-now` asks from a
## terminal, so it may be headless: this process only starts the recording and encodes it.
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
	return int(round((INTRO + song() + OUTRO) * FPS))


## The song's length in seconds: the storyboard's entries end to end at its tempo (each holds for its own
## seconds). 0 where the storyboard does not load.
static func song() -> float:
	var sb := Storyboard.load_file(STORYBOARD)
	if not bool(sb.ok):
		return 0.0
	var tempo := float(sb.sensitivity) if float(sb.sensitivity) > 0.0 else 1.0
	return float(Storyboard.schedule(sb.sequence, tempo, 8.0)["end"])


## The size Movie Maker records at: the project's viewport, set before any script runs (`--resolution`
## changes the window, not the recording).
static func recorded_size() -> Vector2i:
	return Vector2i(int(ProjectSettings.get_setting("display/window/size/viewport_width")),
		int(ProjectSettings.get_setting("display/window/size/viewport_height")))


## Every file the show has loaded so far, as res:// paths: the resource cache's view of [constant
## SOURCE_DIRS], plus [constant ALWAYS]. A resource freed before the call is missed, so the recorder calls
## it as the show plays, not once at the end.
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


## The digest of [param files]: each path and its content, in order, with the engine's version and the
## recording's own shape. A file that is gone hashes as gone.
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


## When a launch may next start a recording (unix seconds): a [constant DAY] after the last one
## began, in [param work] - 0 when none has, or what it wrote cannot be read.
static func next_due(work: String) -> float:
	var said := FileAccess.get_file_as_string(work.path_join(STARTED)).strip_edges()
	return said.to_float() + DAY if said.is_valid_float() else 0.0


## A recording begins now, in [param work]: the next is a [constant DAY] away ([method next_due]).
static func mark_started(work: String) -> void:
	var f := FileAccess.open(work.path_join(STARTED), FileAccess.WRITE)
	if f != null:
		f.store_string(str(int(Time.get_unix_time_from_system())))
		f.close()


## The demo note: the note this recording plays, made in the notes folder with its song ([constant
## DEMO_SONG] by default; a gate's seam) and a copy of the storyboard kept in its folder as its own
## ([NoteStoryboard]), so its timeline edits it. A machine's first desktop launch makes it once ([method
## main._seed_demo_note]); the recording makes it in a folder of its own. Returns the note's path, or "" with the
## reason pushed as a warning.
static func make_demo_note(song_path := DEMO_SONG) -> String:
	var read := Storyboard.read_raw(STORYBOARD)
	if not bool(read["ok"]):
		push_warning("ghost: could not read the demo note's storyboard - %s" % String(read["error"]))
		return ""
	var song := ProjectSettings.globalize_path(song_path)
	DirAccess.make_dir_recursive_absolute(song.get_base_dir())
	if not FileAccess.file_exists(song) and not ShowcaseRecorder.write_song(song):
		push_warning("ghost: could not write the demo note's song (%s)" % song)
		return ""
	var note := NoteStore.create(TITLE, BODY, {"song": {"path": song}, "medium": {"format": "full"},
		"bookends": {"intro": INTRO, "outro": OUTRO}})
	if note.is_empty():
		return ""
	var err := NoteStoryboard.write(NoteUpload.folder_of(note), read["data"])
	if not err.is_empty():
		push_warning("ghost: could not keep the demo note's storyboard - %s" % err)
	return note


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
	_work = ProjectSettings.globalize_path(WORK)
	if not _quit_after and Time.get_unix_time_from_system() < next_due(_work):
		return
	if not _quit_after and not stale():
		return
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
	#kept out of the editor's scan, or it imports every frame as a texture
	if not FileAccess.file_exists(_work.path_join(".gdignore")):
		FileAccess.open(_work.path_join(".gdignore"), FileAccess.WRITE).close()
	for f in DirAccess.get_files_at(frames_dir):
		DirAccess.remove_absolute(frames_dir.path_join(f))
	DirAccess.remove_absolute(_work.path_join("capture.json"))
	var fc := FileAccess.open(claim, FileAccess.WRITE)
	if fc != null:
		fc.store_string(str(OS.get_process_id()))
		fc.close()
	mark_started(_work)
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
	print(("ghost showcase: recording the README animation in the background (pid %d, log %s) - the next"
		+ " no sooner than a day from now") % [_render_pid, _work.path_join("render.log")])
	set_process(true)


func _process(_dt: float) -> void:
	#stopped by ghost closing, not ended: nothing to encode, and the claim goes ([method
	#Subprocess.closing], [method next_due])
	if Subprocess.closing():
		_render_pid = -1
		_encode_pid = -1
		_done("stopped as Ghost Notes closed - a launch a day after it began records it (--showcase-now: at once)", 0)
		return
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
	# (a recorder that died early wrote no capture file: read as "not finished", never parsed)
	var said := FileAccess.get_file_as_string(_work.path_join("capture.json"))
	var cap: Variant = JSON.parse_string(said) if not said.strip_edges().is_empty() else null
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
	ended = msg
	print("ghost showcase: " + msg)
	if _quit_after:
		get_tree().quit(code)
