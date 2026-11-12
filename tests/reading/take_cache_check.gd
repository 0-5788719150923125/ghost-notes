extends SceneTree

## take_cache_check - EVERY SENTENCE THE VOICE HAS SAID, KEPT, by what it said and how ([TakeCache]; next/editing.md step 3).
##
##   godot --headless --path . --script res://tests/reading/take_cache_check.gd
##
## On a cache of its own (never the author's):
##   - the same voice, record and request give the same key; THE CONTROLS: another word, another delivery, the voice trained
##     again (its record changed), each another key;
##   - a reply kept is found again - its audio a copy, its timings as they came, its `wav` the kept file - and copied out for a
##     user to remove as it removes the host's; THE CONTROL: a key never kept finds nothing.

const ROOT := "user://take_cache_check"

var _fails := 0


func _initialize() -> void:
	TakeCache.root = ROOT
	_rmrf(ProjectSettings.globalize_path(ROOT))
	var meta := {"id": "emma", "engine": "kokoro"}
	var args := {"text": "The tide came in.", "speed": 1.0, "pitch": 0.0}
	var k := TakeCache.key_of("emma", meta, args)
	_ok(k == TakeCache.key_of("emma", meta.duplicate(), args.duplicate()) and k.length() == 64, "the same request gives the same key")
	var other_text := args.duplicate()
	other_text["text"] = "The tide went out."
	var other_pace := args.duplicate()
	other_pace["speed"] = 1.1
	var retrained := meta.duplicate()
	retrained["trained"] = "2026-11-11"
	_ok(TakeCache.key_of("emma", meta, other_text) != k and TakeCache.key_of("emma", meta, other_pace) != k
		and TakeCache.key_of("emma", retrained, args) != k and TakeCache.key_of("bella", meta, args) != k,
		"the controls: another word, another delivery, the voice trained again, another voice - each another key")
	var host_wav := ProjectSettings.globalize_path(ROOT).path_join("host.wav")
	DirAccess.make_dir_recursive_absolute(host_wav.get_base_dir())
	var f := FileAccess.open(host_wav, FileAccess.WRITE)
	f.store_string("RIFF-not-really")
	f.close()
	var reply := {"wav": host_wav, "tokens": [{"t0": 0.1, "t1": 0.4, "text": "The"}], "sample_rate": 24000}
	_ok(TakeCache.put(k, host_wav, reply).is_empty() and FileAccess.file_exists(host_wav), "a reply is kept, the host's own file left to its owner")
	var hit := TakeCache.find(k)
	_ok(not hit.is_empty() and String(hit["wav"]) != host_wav and FileAccess.get_file_as_string(String(hit["wav"])) == "RIFF-not-really"
		and int((hit["out"] as Dictionary)["sample_rate"]) == 24000 and ((hit["out"] as Dictionary)["tokens"] as Array).size() == 1
		and String((hit["out"] as Dictionary)["wav"]) == String(hit["wav"]), "it is found again: a copy of the audio, the timings as they came")
	var out := TakeCache.copy_out(k, ROOT.path_join("chunk_0.wav"))
	_ok(not out.is_empty() and FileAccess.file_exists(out) and out != String(hit["wav"]), "copied out for a user to remove as it would the host's")
	_ok(TakeCache.find(TakeCache.key_of("emma", meta, other_text)).is_empty(), "the control: a key never kept finds nothing")
	_rmrf(ProjectSettings.globalize_path(ROOT))
	TakeCache.root = TakeCache.DIR
	if _fails == 0:
		print("take_cache_check: ALL OK")
		quit(0)
		return
	print("take_cache_check: %d FAILED" % _fails)
	quit(1)


func _rmrf(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for d in DirAccess.get_directories_at(path):
		_rmrf(path.path_join(d))
	for f in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	DirAccess.remove_absolute(path)


func _ok(cond: bool, msg: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + msg)
	if not cond:
		_fails += 1
