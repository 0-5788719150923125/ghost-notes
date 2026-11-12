extends RefCounted
class_name TakeCache

## TakeCache - every sentence the voice has said, kept by what it said and how (next/editing.md step 3). The
## host's reply for one chunk of a reading - its audio and its word and phone timings - is kept under a digest of
## the voice, the voice's own record and every argument the request carried (the text, its delivery, its pace):
## the same request is the same performance, so a reading heard again, or an export after one sentence changed,
## asks the host only for what it has not said.
##
## Kept under `user://take_cache/<key>.wav` and `.json`. Past [constant MOST] entries the oldest go. A process
## that may not write the author's things reads it and never adds to it.

const DIR := "user://take_cache"
## How many sentences are kept: a 40-minute reading is about a thousand.
const MOST := 6000
## ...and how many of the oldest go when there are more.
const PRUNE := 1000

## Where it is kept: moved aside under test.
static var root := DIR


## The key of a request: the voice [param voice] with its record [param meta] (a voice trained again is another
## performance) and the request's [param args], text and all.
static func key_of(voice: String, meta: Dictionary, args: Dictionary) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(JSON.stringify({"voice": voice, "meta": meta, "args": args}, "", true).to_utf8_buffer())
	return ctx.finish().hex_encode()


## What is kept under [param key]: `{wav (absolute), out (the host's reply as it came, its `wav` this file)}`, {} for nothing.
static func find(key: String) -> Dictionary:
	var base := ProjectSettings.globalize_path(root).path_join(key)
	if not FileAccess.file_exists(base + ".wav") or not FileAccess.file_exists(base + ".json"):
		return {}
	var out: Variant = JSON.parse_string(FileAccess.get_file_as_string(base + ".json"))
	if not (out is Dictionary):
		return {}
	(out as Dictionary)["wav"] = base + ".wav"
	return {"wav": base + ".wav", "out": out}


## [param wav] (the host's file for the request) and its reply [param out] kept under [param key] - copied, so its owner may
## still do as it likes with its own. "" kept (or nothing to keep), else why not.
static func put(key: String, wav: String, out: Dictionary) -> String:
	var src := ProjectSettings.globalize_path(wav)
	if key.is_empty() or not FileAccess.file_exists(src):
		return ""
	var dir := ProjectSettings.globalize_path(root)
	DirAccess.make_dir_recursive_absolute(dir)
	var base := dir.path_join(key)
	if DirAccess.copy_absolute(src, base + ".wav.part") != OK or DirAccess.rename_absolute(base + ".wav.part", base + ".wav") != OK:
		return "could not keep %s" % src.get_file()
	var reply := out.duplicate(true)
	reply.erase("wav")
	var f := FileAccess.open(base + ".json", FileAccess.WRITE)
	if f == null:
		return "could not keep the reply for %s" % src.get_file()
	f.store_string(JSON.stringify(reply))
	f.close()
	_prune(dir)
	return ""


## [param key]'s audio copied to [param to] (a file its user may remove as it removes the host's), "" when there is none.
static func copy_out(key: String, to: String) -> String:
	var hit := find(key)
	if hit.is_empty():
		return ""
	var dst := ProjectSettings.globalize_path(to)
	DirAccess.make_dir_recursive_absolute(dst.get_base_dir())
	return dst if DirAccess.copy_absolute(String(hit["wav"]), dst) == OK else ""


static func _prune(dir: String) -> void:
	var files := DirAccess.get_files_at(dir)
	if files.size() <= MOST * 2:
		return
	var waves: Array = []
	for f in files:
		if String(f).ends_with(".wav"):
			waves.append([FileAccess.get_modified_time(dir.path_join(f)), String(f)])
	waves.sort()
	for i in mini(PRUNE, waves.size()):
		var stem := String(waves[i][1]).get_basename()
		DirAccess.remove_absolute(dir.path_join(stem + ".wav"))
		DirAccess.remove_absolute(dir.path_join(stem + ".json"))
