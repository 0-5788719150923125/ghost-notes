extends RefCounted
class_name DeliveryVersions

## DeliveryVersions - the versions of one delivery a note tunes, kept in the folder of its Lab beside the note (next/delivery.md,
## "Tuning a delivery"): `versions.json`, `{versions: [{spec, note, by, at}], used}` - each version the delivery's spec as it was then
## ([method DeliveryBank.spec_of]), the words that asked for it, who made it ("" a hand, its Lab's controls) and when. A version is kept,
## never deleted; the one used is the delivery as the note says it, while the note's list says it is tuned ([DeliverySection]).
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
	if not _held.has(key):
		var p := key.path_join(FILE)
		var j: Variant = JSON.parse_string(FileAccess.get_file_as_string(p)) if FileAccess.file_exists(p) else null
		_held[key] = j if j is Dictionary and (j as Dictionary).get("versions") is Array else {}
	return _held[key]


static func versions(dir: String) -> Array:
	return entry(dir).get("versions", [])


## The version used now, -1 for none.
static func used(dir: String) -> int:
	var vs := versions(dir)
	var u := int(entry(dir).get("used", -1))
	return u if u >= 0 and u < vs.size() else -1


## The spec of the version used now, {} for none.
static func spec(dir: String) -> Dictionary:
	var u := used(dir)
	return ((versions(dir)[u] as Dictionary).get("spec", {}) as Dictionary).duplicate(true) if u >= 0 else {}


## A spec as one value to tell two apart by: its JSON, keys sorted, numbers to the text's rounding.
static func what(spec_: Dictionary) -> String:
	return JSON.stringify(_rounded(spec_), "", true)


static func _rounded(v: Variant) -> Variant:
	if v is Dictionary:
		var out := {}
		for k in v:
			out[k] = _rounded(v[k])
		return out
	if v is Array:
		return (v as Array).map(func(x: Variant) -> Variant: return _rounded(x))
	if typeof(v) in [TYPE_INT, TYPE_FLOAT]:
		return snappedf(float(v), 0.001)
	return v


## Which version [param spec_] is, -1 for none.
static func of(dir: String, spec_: Dictionary) -> int:
	var vs := versions(dir)
	var want := what(spec_)
	var u := used(dir)
	if u >= 0 and what((vs[u] as Dictionary).get("spec", {})) == want:
		return u
	for i in range(vs.size() - 1, -1, -1):
		if what((vs[i] as Dictionary).get("spec", {})) == want:
			return i
	return -1


## [param spec_] kept as a new version in [param dir], asked for by [param note] and made by [param by] ("" a hand), and the one used
## from now: its index (one it is already is chosen again, not kept twice), -1 where it cannot be written.
static func add(dir: String, spec_: Dictionary, note: String, by: String) -> int:
	if not writable(dir) or spec_.is_empty():
		return -1
	var e := entry(dir).duplicate(true)
	var vs: Array = e.get("versions", [])
	var was := of(dir, spec_)
	if was >= 0:
		e["used"] = was
		return was if _write(dir, e) else -1
	vs.append({"spec": spec_.duplicate(true), "note": note.strip_edges().left(240), "by": by, "at": int(Time.get_unix_time_from_system())})
	e["versions"] = vs
	e["used"] = vs.size() - 1
	return vs.size() - 1 if _write(dir, e) else -1


## The version used now [param spec_] in place, as a hand moves its Lab's controls: written over while it is a hand's (a run of
## moves is one version), else kept as a new one. Its index, -1 where it cannot be written.
static func set_hand(dir: String, spec_: Dictionary) -> int:
	if not writable(dir) or spec_.is_empty():
		return -1
	var u := used(dir)
	var e := entry(dir).duplicate(true)
	var vs: Array = e.get("versions", [])
	if u >= 0 and u == vs.size() - 1 and String((vs[u] as Dictionary).get("by", "")).is_empty() \
			and String((vs[u] as Dictionary).get("note", "")).is_empty():
		(vs[u] as Dictionary)["spec"] = spec_.duplicate(true)
		(vs[u] as Dictionary)["at"] = int(Time.get_unix_time_from_system())
		e["versions"] = vs
		return u if _write(dir, e) else -1
	return add(dir, spec_, "", "")


## Version [param i] of [param dir] the one used from now: its spec, {} where there is no such version or it cannot be written.
static func use(dir: String, i: int) -> Dictionary:
	var vs := versions(dir)
	if i < 0 or i >= vs.size() or not writable(dir):
		return {}
	var e := entry(dir).duplicate(true)
	e["used"] = i
	if not _write(dir, e):
		return {}
	return ((vs[i] as Dictionary).get("spec", {}) as Dictionary).duplicate(true)


## Version [param i] in a few words, as a picker lists it: its number, what asked for it and who made it.
static func label_of(dir: String, i: int) -> String:
	var vs := versions(dir)
	if i < 0 or i >= vs.size():
		return ""
	var v: Dictionary = vs[i]
	var note := String(v.get("note", "")).replace("\n", " ")
	var by := String(v.get("by", ""))
	return "%d  ·  %s%s" % [i + 1, (note.left(48) + ("…" if note.length() > 48 else "")) if not note.is_empty() else "by hand",
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
