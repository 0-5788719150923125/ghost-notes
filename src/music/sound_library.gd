extends RefCounted
class_name SoundLibrary

## SoundLibrary - sound effects kept to use on any note (next/sound_effects.md; [SoundEffects]): the library's `sounds` shelf
## ([Library]), one sound a pair of files - `<slug>.json` (`{name, words, patch}`, the patch as its designer left it) and
## `<slug>.wav` (it made into sound, to hear on the shelf). Kept by a person's choice, never automatically; used on a mark, its
## patch is copied in as a new version of that mark's sound.

const SHELF := "sounds"

## Moves whenever the shelf is written: the Dex reads it again.
static var version := 0


## The shelf's folder, absolute.
static func dir() -> String:
	return Library.shelf(SHELF)


## Every sound kept, sorted by name: each `{name, words, patch, file, wav}`.
static func entries() -> Array:
	var out: Array = []
	if not DirAccess.dir_exists_absolute(dir()):
		return out
	for f in DirAccess.get_files_at(dir()):
		if not f.ends_with(".json"):
			continue
		var j: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir().path_join(f)))
		if not (j is Dictionary) or not ((j as Dictionary).get("patch") is Dictionary):
			continue
		var e: Dictionary = j
		e["file"] = dir().path_join(f)
		e["wav"] = dir().path_join(f.get_basename() + ".wav")
		out.append(e)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a.get("name", "")).naturalnocasecmp_to(String(b.get("name", ""))) < 0)
	return out


## The kept sound named [param name], {} for none.
static func find(name: String) -> Dictionary:
	for e in entries():
		if String((e as Dictionary).get("name", "")) == name:
			return e
	return {}


## [param patch] kept as [param name] (said by [param words]), its sound [param wav] beside it. "" kept, else why not.
static func keep(name: String, words: String, patch: Dictionary, wav: String) -> String:
	if not Library.writable():
		return "this session is read-only"
	var n := name.strip_edges()
	if n.is_empty() or patch.is_empty():
		return "nothing to keep"
	DirAccess.make_dir_recursive_absolute(dir())
	var slug := n.to_lower().replace(" ", "-").validate_filename().left(48)
	var path := dir().path_join(slug + ".json")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return "could not write " + path
	f.store_string(JSON.stringify({"name": n, "words": words, "patch": patch}, "\t"))
	f.close()
	if FileAccess.file_exists(wav):
		DirAccess.copy_absolute(wav, dir().path_join(slug + ".wav"))
	version += 1
	return ""


## The kept sound [param name] taken off the shelf, to the trash. "" done, else why not.
static func remove(name: String) -> String:
	if not Library.writable():
		return "this session is read-only"
	var e := find(name)
	if e.is_empty():
		return "no sound is kept as %s" % name
	Library.trash(String(e["file"]))
	if FileAccess.file_exists(String(e["wav"])):
		Library.trash(String(e["wav"]))
	version += 1
	return ""


## A name for a sound said by [param words]: its first few words.
static func name_for(words: String) -> String:
	var w := words.split(" ", false)
	var n := " ".join(w.slice(0, mini(w.size(), 6))).trim_suffix(",").trim_suffix(".")
	return n.capitalize() if n.length() < 3 else n[0].to_upper() + n.substr(1)
