extends RefCounted
class_name DeliveryLibrary

## DeliveryLibrary - deliveries kept to say any note's words with (next/delivery.md, "Tuning a delivery"): the library's `deliveries`
## shelf ([Library]), one delivery a pair of files - `<slug>.json` (`{name, about, spec}`, the spec as its Lab or its designer left
## it, [method DeliveryBank.spec_of]) and `<slug>.wav` (its last test, to hear on the Dex). Kept by a person's Keep, never
## automatically. A delivery kept under a bank row's name or an act's ("excited", "drawn") is said that way in every note that says
## it, unless a note tunes its own; one under a new name is a word every note's script may say. Read once and held: [member version]
## moves on every write, and the shelf is read again then.

const SHELF := "deliveries"

## Moves whenever the shelf is written: the Dex and every note's list read it again.
static var version := 0
static var _held: Array = []
static var _held_at := -1


## The shelf's folder, absolute.
static func dir() -> String:
	return Library.shelf(SHELF)


## Every delivery kept, sorted by name: each `{name, about, spec, file, wav}`.
static func entries() -> Array:
	if _held_at == version:
		return _held
	_held_at = version
	_held = []
	if not DirAccess.dir_exists_absolute(dir()):
		return _held
	for f in DirAccess.get_files_at(dir()):
		if not f.ends_with(".json"):
			continue
		var j: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir().path_join(f)))
		if not (j is Dictionary) or not ((j as Dictionary).get("spec") is Dictionary):
			continue
		var e: Dictionary = j
		e["name"] = clean_name(String(e.get("name", "")))
		if String(e["name"]).is_empty():
			continue
		e["file"] = dir().path_join(f)
		e["wav"] = dir().path_join(f.get_basename() + ".wav")
		_held.append(e)
	_held.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a["name"]).naturalnocasecmp_to(String(b["name"])) < 0)
	return _held


## The delivery kept as [param name], {} for none.
static func find(name: String) -> Dictionary:
	var n := clean_name(name)
	for e in entries():
		if String((e as Dictionary)["name"]) == n:
			return e
	return {}


## Every delivery kept, as a note's tuning reads it ([method DeliveryBank.defs_for]): `{name: spec}`.
static func tuned() -> Dictionary:
	var out := {}
	for e in entries():
		out[String((e as Dictionary)["name"])] = (e as Dictionary)["spec"]
	return out


## What each delivery kept under a name of its own is, for what an agent is told ([method DeliveryBank.listed]): `{name: about}`.
static func about() -> Dictionary:
	var out := {}
	for e in entries():
		var n := String((e as Dictionary)["name"])
		if not DeliveryBank.is_named(n):
			out[n] = String((e as Dictionary).get("about", ""))
	return out


## [param name] as a script can say it: lowercase words of letters, hyphens and spaces; "" where nothing of it can be said, or it
## would read as something else (a degree, an axis given a number, a shape).
static func clean_name(name: String) -> String:
	var rx := RegEx.new()
	rx.compile("[^a-z\\- ]")
	var n := " ".join(rx.sub(name.to_lower(), "", true).split(" ", false)).strip_edges()
	if n.is_empty() or DeliveryBank.DEGREES.has(n) or DeliveryBank.AXES.has(n) or DeliveryBank.SHAPES.has(n):
		return ""
	return n.left(40)


## [param spec] kept as [param name], what it is said by [param about], its last test [param wav] beside it ("" for none). One kept
## under that name is written over. "" kept, else why not.
static func keep(name: String, spec: Dictionary, about_ := "", wav := "") -> String:
	if not Library.writable():
		return "this session is read-only"
	var n := clean_name(name)
	if n.is_empty():
		return "a delivery is named in lowercase words a script can say (not a degree, an axis or a shape)"
	if spec.is_empty():
		return "nothing to keep"
	DirAccess.make_dir_recursive_absolute(dir())
	var slug := n.replace(" ", "-").validate_filename().left(48)
	var path := dir().path_join(slug + ".json")
	var f := FileAccess.open(path + ".part", FileAccess.WRITE)
	if f == null:
		return "could not write " + path
	f.store_string(JSON.stringify({"name": n, "about": about_.strip_edges().left(240), "spec": spec}, "\t"))
	f.close()
	if DirAccess.rename_absolute(path + ".part", path) != OK:
		return "could not write " + path
	if not wav.is_empty() and FileAccess.file_exists(wav):
		DirAccess.copy_absolute(wav, dir().path_join(slug + ".wav"))
	version += 1
	return ""


## The delivery kept as [param name] taken off the shelf, to the trash. "" done, else why not.
static func remove(name: String) -> String:
	if not Library.writable():
		return "this session is read-only"
	var e := find(name)
	if e.is_empty():
		return "no delivery is kept as %s" % name
	Library.trash(String(e["file"]))
	if FileAccess.file_exists(String(e["wav"])):
		Library.trash(String(e["wav"]))
	version += 1
	return ""


## The delivery kept as [param name] kept as [param new_name] instead. "" done, else why not.
static func rename(name: String, new_name: String) -> String:
	var e := find(name)
	if e.is_empty():
		return "no delivery is kept as %s" % name
	var n := clean_name(new_name)
	if n.is_empty():
		return "a delivery is named in lowercase words a script can say"
	if n == String(e["name"]):
		return ""
	if not find(n).is_empty():
		return "a delivery is kept as %s already" % n
	var wav := String(e["wav"]) if FileAccess.file_exists(String(e["wav"])) else ""
	var err := keep(n, e["spec"], String(e.get("about", "")), wav)
	if not err.is_empty():
		return err
	return remove(String(e["name"]))
