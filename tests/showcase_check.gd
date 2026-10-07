extends Node

## showcase_check - THE README'S ANIMATION RECORDS ONLY WHEN IT WOULD CHANGE (src/showcase.gd).
##
##   tests/run_boot_probe.sh tests/showcase_check.gd 120
##
## What it holds, on files of its own under user:// (never docs/showcase.*):
##   - the stamp's digest is of the LISTED files: an edit to a file the recording never loaded leaves
##     the animation current, an edit to one it did makes it stale, and so do a deleted file, a
##     missing webp and an unreadable stamp. The edit to a listed file is the control: if it did not
##     make the stamp stale, "current" would prove nothing.
##   - the recording's list is the resource cache's: a script this process has loaded is on it, one it
##     has not loaded is not (the control for the first).
##   - the trigger never records from a test (read-only) process.
##   - the song is the storyboard's length, and made the same every time: the holds of
##     storyboards/showcase.yaml add up to [constant Showcase.SONG] (the control: the default board's
##     do not), and two songs written are byte-identical.
##
## It never records: a recording is two and a half minutes on the GPU, and `--showcase-now` is how
## to ask for one.

const DIR := "user://showcase_check"

var _fails: Array = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var dir := ProjectSettings.globalize_path(DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	_check_stamp(dir)
	_check_loaded()
	_ok(not Showcase.skip_reason().is_empty(),
		"the trigger does not record from a test process ('%s')" % Showcase.skip_reason())
	_check_song(dir)
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.remove_absolute(dir)
	if _fails.is_empty():
		print("showcase_check: ALL OK")
		get_tree().quit(0)
		return
	print("showcase_check: %d FAILURE(S)" % _fails.size())
	for f in _fails:
		print("   ", f)
	get_tree().quit(1)


func _check_stamp(dir: String) -> void:
	var a := dir.path_join("a.gd")
	var b := dir.path_join("b.gdshader")
	var other := dir.path_join("other.gd")
	var out := dir.path_join("showcase.webp")
	var stamp := dir.path_join("showcase.json")
	for p in [a, b, other, out]:
		_put(p, "first " + p.get_file())
	var files := PackedStringArray([a, b])
	_put(stamp, JSON.stringify({"digest": Showcase.digest(files), "files": Array(files)}))
	_ok(not Showcase.stale(out, stamp), "a fresh stamp is current")
	_put(other, "edited")
	_ok(not Showcase.stale(out, stamp), "an edit to a file the recording never loaded leaves it current")
	_put(a, "edited")
	_ok(Showcase.stale(out, stamp), "the control: an edit to a file it loaded makes it stale")
	_put(a, "first a.gd")
	_ok(not Showcase.stale(out, stamp), "...and undoing the edit makes it current again")
	DirAccess.remove_absolute(b)
	_ok(Showcase.stale(out, stamp), "a file it loaded, deleted, makes it stale")
	_put(b, "first b.gdshader")
	DirAccess.remove_absolute(out)
	_ok(Showcase.stale(out, stamp), "no webp is stale")
	_put(out, "webp")
	_put(stamp, "not json")
	_ok(Showcase.stale(out, stamp), "an unreadable stamp is stale")


func _check_loaded() -> void:
	var files := Showcase.loaded_files()
	_ok(files.has("res://src/showcase.gd") and files.has("res://src/storyboard.gd"),
		"the list holds the scripts this process has loaded (%d files)" % files.size())
	for p in Showcase.ALWAYS:
		_ok(files.has(p), "...and %s, which is read rather than loaded" % p)
	_ok(not ResourceLoader.has_cached("res://src/bake_runner.gd") and not files.has("res://src/bake_runner.gd"),
		"the control: a script never loaded here is not on it")


func _check_song(dir: String) -> void:
	var total := 0.0
	var board := Storyboard.load_file(Showcase.STORYBOARD)
	for e in board.get("sequence", []):
		total += float((e as Dictionary).get("hold", 0.0))
	_ok(is_equal_approx(total, Showcase.SONG),
		"the showcase storyboard's holds add up to the song (%.1f s, the song %.1f s)" % [total, Showcase.SONG])
	var other := 0.0
	for e in Storyboard.load_file("default").get("sequence", []):
		other += float((e as Dictionary).get("hold", 0.0))
	_ok(not is_equal_approx(other, Showcase.SONG), "the control: the default board's do not (%.1f s)" % other)
	var one := dir.path_join("one.wav")
	var two := dir.path_join("two.wav")
	_ok(ShowcaseRecorder.write_song(one) and ShowcaseRecorder.write_song(two), "the song is written")
	var bytes := FileAccess.get_file_as_bytes(one)
	_ok(bytes.size() == 44 + int(Showcase.SONG * ShowcaseRecorder.RATE) * 2,
		"...%.1f seconds of it (%d bytes)" % [Showcase.SONG, bytes.size()])
	_ok(bytes == FileAccess.get_file_as_bytes(two), "...and the same every time")


func _put(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _ok(cond: bool, msg: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + msg)
	if not cond:
		_fails.append(msg)
