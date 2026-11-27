extends RefCounted
class_name HeadBank

## HeadBank - the phrases a show's head performs (next/head.md, [HeadPlan]): its own habits, designed by an agent for the show and
## kept in the library, one file a show (`<library>/head/<show>.json`): `{phrases, line, versions}`, the banks before it kept a
## version back (at most [constant VERSIONS]). Read once and held until the file changes. A show is named by its Table block's
## `show`, else by its note's file ([method key_of]). Gate: tests/motion/head_plan_check.gd.

## The library's shelf the banks are kept on, and how many banks before the one used are kept.
const SHELF := "head"
const VERSIONS := 6

static var _held := {}             # a bank's path -> [modified time, phrases]
static var _lock := Mutex.new()


## The show a note's [param blocks] name (its Table block's `show`), else the stem of its file [param path]; "" for neither.
static func key_of(blocks: Dictionary, path := "") -> String:
	var t: Variant = blocks.get("table")
	if t is Dictionary and not String((t as Dictionary).get("show", "")).strip_edges().is_empty():
		return _slug(String((t as Dictionary)["show"]))
	return _slug(path.get_file().get_basename()) if not path.is_empty() else ""


## Where show [param key]'s bank is kept.
static func path_of(key: String) -> String:
	return Library.shelf(SHELF).path_join(_slug(key) + ".json")


## Show [param key]'s phrases, sanitized ([method HeadPlan.sanitize_phrase]); [] where it has none.
static func read(key: String) -> Array:
	if key.is_empty():
		return []
	var path := path_of(key)
	if not FileAccess.file_exists(path):
		return []
	var at := FileAccess.get_modified_time(path)
	_lock.lock()
	var held: Variant = _held.get(path)
	_lock.unlock()
	if held is Array and int((held as Array)[0]) == at:
		return ((held as Array)[1] as Array).duplicate(true)
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var out := phrases_of(d)
	_lock.lock()
	_held[path] = [at, out]
	_lock.unlock()
	return out.duplicate(true)


## The phrases a bank [param d] (as written) holds, sanitized, each name once.
static func phrases_of(d: Variant) -> Array:
	var out: Array = []
	var names := {}
	var src: Array = (d as Dictionary).get("phrases", []) if d is Dictionary and (d as Dictionary).get("phrases") is Array else []
	for p in src:
		var q := HeadPlan.sanitize_phrase(p)
		if q.is_empty() or String(q["name"]).is_empty() or names.has(q["name"]):
			continue
		names[q["name"]] = true
		out.append(q)
	return out


## Show [param key]'s bank written as [param phrases] (said by [param line]), the one before kept a version back. "" done, else why
## not.
static func write(key: String, phrases: Array, line := "") -> String:
	if key.is_empty():
		return "the show has no name to keep its head's phrases by"
	var safe := phrases_of({"phrases": phrases})
	if safe.is_empty():
		return "no phrase in it can be performed"
	var path := path_of(key)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var was: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	var versions: Array = (was as Dictionary).get("versions", []) if was is Dictionary and (was as Dictionary).get("versions") is Array else []
	if was is Dictionary and (was as Dictionary).get("phrases") is Array:
		versions.push_front({"phrases": (was as Dictionary)["phrases"], "line": String((was as Dictionary).get("line", ""))})
	var f := FileAccess.open(path + ".part", FileAccess.WRITE)
	if f == null:
		return "could not write " + path
	f.store_string(JSON.stringify({"phrases": safe, "line": line, "versions": versions.slice(0, VERSIONS)}, "\t"))
	f.close()
	return "" if DirAccess.rename_absolute(path + ".part", path) == OK else "could not move %s into place" % path


## A digest of [param phrases]: what a take placed by them is said from.
static func hash_of(phrases: Array) -> String:
	return JSON.stringify(phrases).sha256_text().left(16) if not phrases.is_empty() else ""


static func _slug(s: String) -> String:
	var out := ""
	for c in s.strip_edges().to_lower():
		out += c if (c >= "a" and c <= "z") or (c >= "0" and c <= "9") else "-"
	while out.contains("--"):
		out = out.replace("--", "-")
	return out.trim_prefix("-").trim_suffix("-")
