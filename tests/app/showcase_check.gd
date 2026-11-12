extends Node

## showcase_check - the README's animation records only when it would change (src/app/showcase.gd).
##
##   tests/run_boot_probe.sh tests/app/showcase_check.gd 120
##
## On files of its own under user:// (never docs/showcase.*):
##   - The stamp's digest is of the listed files: an edit to a file the recording never loaded leaves the
##     animation current; an edit to one it did, a deleted file, a missing webp and an unreadable stamp make it
##     stale (the listed-file edit is the control).
##   - The recording's list is the resource cache's: a script this process loaded is on it, one it has not is not.
##   - The trigger never records from a test (read-only) process.
##   - At most once a day: a recording begun ([method Showcase.mark_started]) holds the next back for [constant
##     Showcase.DAY]; control: one begun a day and a minute ago does not. None begun, or an unreadable file,
##     holds nothing back.
##   - The song is the storyboard's length and the same every time: the holds of storyboards/showcase.yaml add
##     up to [constant Showcase.SONG] (control: the default board's do not), and two songs are byte-identical.
##   - A child ghost stopped has not failed: with [method Subprocess.closing] true, the recorder's watcher
##     encodes nothing, says it was stopped and lets go of its claim, and the voice host reports no failure.
##     Control: the same two watchers with nothing closing - a recorder gone without its capture file did not
##     finish, and a voice host gone is a failure.
##
## It never records: a recording takes minutes on the GPU; `--showcase-now` asks for one.

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
	_check_day(dir)
	_check_closing(dir)
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
	_ok(files.has("res://src/app/showcase.gd") and files.has("res://src/stage/storyboard.gd"),
		"the list holds the scripts this process has loaded (%d files)" % files.size())
	for p in Showcase.ALWAYS:
		_ok(files.has(p), "...and %s, which is read rather than loaded" % p)
	_ok(not ResourceLoader.has_cached("res://src/audio/bake_runner.gd") and not files.has("res://src/audio/bake_runner.gd"),
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


func _check_day(dir: String) -> void:
	var now := Time.get_unix_time_from_system()
	var started := dir.path_join(Showcase.STARTED)
	DirAccess.remove_absolute(started)
	_ok(Showcase.next_due(dir) <= now, "none begun yet: a launch may record")
	Showcase.mark_started(dir)
	var due := Showcase.next_due(dir)
	_ok(due > now and absf(due - (now + Showcase.DAY)) < 5.0,
		"a recording begun holds the next back for a day (%.0f s)" % (due - now))
	_put(started, str(int(now - Showcase.DAY - 60)))
	_ok(Showcase.next_due(dir) <= now, "the control: one begun a day and a minute ago holds nothing back")
	_put(started, "garbled")
	_ok(Showcase.next_due(dir) <= now, "a file that cannot be read holds nothing back")
	DirAccess.remove_absolute(started)


## The two watchers of a child, with the child gone: once because it died, once because ghost is
## closing and killed it.
func _check_closing(dir: String) -> void:
	for closing in [false, true]:
		Subprocess._closing = closing
		var show := Showcase.new()
		show._work = dir
		show._render_pid = 999999999          # nobody's: gone, as far as the registry knows
		_put(dir.path_join("claim"), "1")
		show._process(0.0)
		var host := VoiceHost.new()
		var failures: Array = []
		host.failed.connect(func(stage: String, _msg: String) -> void: failures.append(stage))
		host._state = "up"
		host._pid = 999999999
		host._process(1.0)
		if closing:
			_ok(show.ended.contains("stopped") and not FileAccess.file_exists(dir.path_join("claim")),
				"closing, the recorder says it was stopped and lets go of its claim ('%s')" % show.ended)
			_ok(failures.is_empty() and host._state == "up", "closing, the voice host reports no failure (%s)" % str(failures))
		else:
			_ok(show.ended.contains("without finishing"),
				"the control: a recorder gone on its own is a recording that did not finish ('%s')" % show.ended)
			_ok(failures == ["host"], "the control: a voice host gone on its own is a failure (%s)" % str(failures))
		show.free()
		host.free()
	Subprocess._closing = false


func _put(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _ok(cond: bool, msg: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + msg)
	if not cond:
		_fails.append(msg)
