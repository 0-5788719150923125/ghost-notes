extends RefCounted
class_name ThingLibrary

## ThingLibrary - THINGS KEPT TO BE PUT ON ANOTHER TABLE (next/editing.md step 8: "a library of things (a thing as `table.json`
## holds one, with its materials - the brief's fixed block is that shape)"). A thing a set dresser made, or a person shaped, kept
## by its name in `user://library/things/` with the materials its parts are made of; put on another episode's table it is that
## thing again, its name made its own there, and only the materials that table lacks are added - a table's own material of the
## same name is its own.

const DIR := "user://library/things"

## Where the library lives. Moved aside under test, so a gate never writes the author's library.
static var root := DIR


## THING [param thing] KEPT, with the materials of [param table] its parts use. "" kept, else why not.
static func keep(thing: Dictionary, table: Dictionary) -> String:
	var name := String(thing.get("name", "")).strip_edges()
	if name.is_empty():
		return "a thing needs a name to be kept"
	var mats := {}
	var have: Dictionary = table.get("materials", {}) if table.get("materials") is Dictionary else {}
	for m in materials_used(thing):
		if have.has(m):
			mats[m] = have[m]
	var dir := ProjectSettings.globalize_path(root)
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join(Manuscript.slug(name) + ".json")
	var f := FileAccess.open(path + ".part", FileAccess.WRITE)
	if f == null:
		return "could not write " + path
	f.store_string(JSON.stringify({"thing": thing, "materials": mats}, "\t"))
	f.close()
	return "" if DirAccess.rename_absolute(path + ".part", path) == OK else "could not move %s into place" % path


## Every thing kept, by name, sorted.
static func names() -> Array:
	var out: Array = []
	var dir := ProjectSettings.globalize_path(root)
	if not DirAccess.dir_exists_absolute(dir):
		return out
	for fn in DirAccess.get_files_at(dir):
		if String(fn).ends_with(".json"):
			var e := read_file(dir.path_join(fn))
			if not e.is_empty():
				out.append(String((e["thing"] as Dictionary).get("name", "")))
	out.sort()
	return out


## The thing kept as [param name]: `{thing, materials}`, {} for none.
static func read(name: String) -> Dictionary:
	return read_file(ProjectSettings.globalize_path(root).path_join(Manuscript.slug(name) + ".json"))


static func read_file(path: String) -> Dictionary:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	if not (d is Dictionary) or not ((d as Dictionary).get("thing") is Dictionary):
		return {}
	if not ((d as Dictionary).get("materials") is Dictionary):
		(d as Dictionary)["materials"] = {}
	return d


## [param table] WITH [param entry] ([method read]) PUT ON IT: the thing appended, named so no other thing on the table has its name,
## standing at [param at] (centimeters from the middle of the reading); the materials it uses that the table lacks added. A new
## table; the one handed is not changed.
static func put_on(table: Dictionary, entry: Dictionary, at := Vector2.ZERO) -> Dictionary:
	var out := table.duplicate(true)
	var thing: Dictionary = (entry.get("thing", {}) as Dictionary).duplicate(true)
	var things: Array = out.get("things", []) if out.get("things") is Array else []
	var taken := {}
	for t in things:
		if t is Dictionary:
			taken[String((t as Dictionary).get("name", ""))] = true
	var base := String(thing.get("name", "thing"))
	var name := base
	var n := 2
	while taken.has(name):
		name = "%s %d" % [base, n]
		n += 1
	thing["name"] = name
	thing["at"] = [at.x, at.y]
	things.append(thing)
	out["things"] = things
	var mats: Dictionary = out.get("materials", {}) if out.get("materials") is Dictionary else {}
	for m in (entry.get("materials", {}) as Dictionary):
		if not mats.has(m):
			mats[m] = (entry["materials"] as Dictionary)[m]
	out["materials"] = mats
	return out


## The materials [param part] (a thing, or one of its parts) and every part inside it are made of.
static func materials_used(part: Dictionary) -> Array:
	var out: Array = []
	if part.get("material") is String and not String(part["material"]).is_empty():
		out.append(String(part["material"]))
	for p in (part.get("parts", []) if part.get("parts") is Array else []):
		if p is Dictionary:
			for m in materials_used(p):
				if not out.has(m):
					out.append(m)
	return out
