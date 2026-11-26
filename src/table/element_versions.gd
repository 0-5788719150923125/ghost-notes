extends RefCounted
class_name ElementVersions

## ElementVersions - the versions of one element of an environment, kept in the folder of its Refine… beside the note or the episode
## it is round ([EnvironmentSoundDesign]): `versions.json`, `{versions: [{element, note, by, at}], used}` - each version the element
## as it was then (never its name or whether it is set aside: [method EnvironmentLibrary.what]), the words that asked for it, who made
## it ("" a hand) and when. A version is kept, never deleted; which one the element is now is [method of] (an element changed by hand
## since is none of them), and making one the element again is the section's ([EnvironmentSection]).
##
## Read once and held ([method entry]); written whole by rename. The author's folders are written only from a session that may write
## the author's things; a gate's own folder ([member root_aside]) from any.

const FILE := "versions.json"
## A gate's own folder: what is kept under it is written whatever the session.
static var root_aside := ""
static var _held := {}            # folder -> its entry, read once


## Whether versions may be written in [param dir].
static func writable(dir: String) -> bool:
	if not root_aside.is_empty() and ProjectSettings.globalize_path(dir).begins_with(ProjectSettings.globalize_path(root_aside)):
		return true
	var tree := Engine.get_main_loop() as SceneTree
	var s: Node = tree.root.get_node_or_null("Settings") if tree != null and tree.root != null else null
	return s != null and not bool(s.call("is_read_only"))


## The versions kept in [param dir]: `{versions, used}` ({} for none). Read once and held.
static func entry(dir: String) -> Dictionary:
	var key := ProjectSettings.globalize_path(dir)
	if _held.has(key):
		return _held[key]
	var e := {}
	var p := key.path_join(FILE)
	if FileAccess.file_exists(p):
		var j: Variant = JSON.parse_string(FileAccess.get_file_as_string(p))
		if j is Dictionary and (j as Dictionary).get("versions") is Array:
			e = j
	_held[key] = e
	return e


## The versions kept in [param dir], the first first: each `{element, note, by, at}`.
static func versions(dir: String) -> Array:
	return (entry(dir).get("versions", []) as Array)


## The version last made or chosen (0-based), -1 for none.
static func used(dir: String) -> int:
	var n := versions(dir).size()
	return clampi(int(entry(dir).get("used", n - 1)), 0, n - 1) if n > 0 else -1


## Which version element [param el] is (the one last made or chosen first), -1 where it is none of them.
static func of(dir: String, el: Dictionary) -> int:
	var vs := versions(dir)
	var want := EnvironmentLibrary.what(el)
	var u := used(dir)
	if u >= 0 and EnvironmentLibrary.what((vs[u] as Dictionary).get("element", {})) == want:
		return u
	for i in range(vs.size() - 1, -1, -1):
		if EnvironmentLibrary.what((vs[i] as Dictionary).get("element", {})) == want:
			return i
	return -1


## Element [param el] kept as a new version in [param dir], asked for by [param note] and made by [param by] ("" a hand), and the
## one used from now: its index (one it is already is chosen again, not kept twice), -1 where it cannot be written.
static func add(dir: String, el: Dictionary, note: String, by: String) -> int:
	if not writable(dir):
		return -1
	var safe := Surroundings.element(el)
	if safe.is_empty():
		return -1
	safe.erase("name")
	safe.erase("off")
	var e := entry(dir).duplicate(true)
	var vs: Array = e.get("versions", [])
	var was := of(dir, safe)
	if was >= 0:
		e["used"] = was
		return was if _write(dir, e) else -1
	vs.append({"element": safe, "note": note.strip_edges().left(240), "by": by, "at": int(Time.get_unix_time_from_system())})
	e["versions"] = vs
	e["used"] = vs.size() - 1
	return vs.size() - 1 if _write(dir, e) else -1


## Version [param i] of [param dir] the one used from now: its element (no name, never set aside), {} where there is no such version
## or it cannot be written.
static func use(dir: String, i: int) -> Dictionary:
	var vs := versions(dir)
	if i < 0 or i >= vs.size() or not writable(dir):
		return {}
	var e := entry(dir).duplicate(true)
	e["used"] = i
	if not _write(dir, e):
		return {}
	return Surroundings.element((vs[i] as Dictionary).get("element", {}))


## Version [param i] in a few words, as a picker lists it: its number, what asked for it and who made it.
static func label_of(dir: String, i: int) -> String:
	var vs := versions(dir)
	if i < 0 or i >= vs.size():
		return ""
	var v: Dictionary = vs[i]
	var note := String(v.get("note", "")).replace("\n", " ")
	var by := String(v.get("by", ""))
	return "%d  ·  %s%s" % [i + 1, (note.left(48) + ("…" if note.length() > 48 else "")) if not note.is_empty() else "as it was",
		("  (%s)" % by) if not by.is_empty() else ""]


static func _write(dir: String, e: Dictionary) -> bool:
	var key := ProjectSettings.globalize_path(dir)
	DirAccess.make_dir_recursive_absolute(key)
	var p := key.path_join(FILE)
	var f := FileAccess.open(p + ".part", FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(e, "\t"))
	f.close()
	if DirAccess.rename_absolute(p + ".part", p) != OK:
		return false
	_held[key] = e
	return true
