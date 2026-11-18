extends RefCounted
class_name EnvironmentLibrary

## EnvironmentLibrary - elements of an environment kept to use on any note (next/environment.md; [Surroundings]): the library's
## `environment` shelf ([Library]), one file per element, `<slug>.json`: `{name, element}` - the element as a note keeps it, its kind,
## its number and what it sets, so it is the same variant wherever it is used. Kept by a person's choice, never automatically; used, it
## is copied into the note. A file read from the shelf is made safe as a note's is ([method Surroundings.element]).

const SHELF := "environment"


## The shelf's folder, absolute.
static func dir() -> String:
	return Library.shelf(SHELF)


## Every element kept, sorted by name: each `{name, element, file}`.
static func entries() -> Array:
	var out: Array = []
	if not DirAccess.dir_exists_absolute(dir()):
		return out
	for fn in DirAccess.get_files_at(dir()):
		if String(fn).ends_with(".json"):
			var e := read_file(dir().path_join(fn))
			if not e.is_empty():
				e["file"] = dir().path_join(fn)
				out.append(e)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a["name"]).naturalnocasecmp_to(String(b["name"])) < 0)
	return out


## The element kept as [param name]: `{name, element}`, {} for none.
static func read(name: String) -> Dictionary:
	return read_file(dir().path_join(Manuscript.slug(name) + ".json"))


## The entry in the file at [param path], made safe; {} where it is no element.
static func read_file(path: String) -> Dictionary:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	if not (d is Dictionary):
		return {}
	var name := Props._text((d as Dictionary).get("name", ""), 60)
	var el := Surroundings.element((d as Dictionary).get("element"))
	if name.is_empty() or el.is_empty():
		return {}
	el.erase("off")
	el["name"] = name
	return {"name": name, "element": el}


## Element [param el] kept as [param name] (one of that name already kept is replaced). "" kept, else why not.
static func keep(el: Dictionary, name: String) -> String:
	var to := name.strip_edges().left(60)
	var safe := Surroundings.element(el)
	if to.is_empty() or safe.is_empty():
		return "an element needs a name and a kind to be kept"
	if not Library.writable():
		return "this session cannot write the library"
	safe.erase("off")
	safe["name"] = to
	return _write({"name": to, "element": safe})


## The name element [param el] is kept as - the same kind, number and properties - or "" where it is not kept.
static func kept_as(el: Dictionary, entries_now: Array) -> String:
	var want := _what(el)
	for e in entries_now:
		if _what((e as Dictionary)["element"]) == want:
			return String((e as Dictionary)["name"])
	return ""


## The element kept as [param name] taken off the shelf, to the trash ([method Library.trash]). "" done, else why not.
static func remove(name: String) -> String:
	var path := dir().path_join(Manuscript.slug(name) + ".json")
	if not FileAccess.file_exists(path):
		return "%s is not in the library" % name
	if not Library.writable():
		return "this session cannot write the library"
	return "" if Library.trash(path) == OK else "could not take %s off the shelf" % name


## The element kept as [param name] called [param new_name]. "" done, else why not.
static func rename(name: String, new_name: String) -> String:
	var e := read(name)
	if e.is_empty():
		return "%s is not in the library" % name
	var to := new_name.strip_edges().left(60)
	if to.is_empty():
		return "it needs a name"
	if Manuscript.slug(to) != Manuscript.slug(name) and not read(to).is_empty():
		return "another is called %s" % to
	if not Library.writable():
		return "this session cannot write the library"
	(e["element"] as Dictionary)["name"] = to
	var err := _write({"name": to, "element": e["element"]})
	if err.is_empty() and Manuscript.slug(to) != Manuscript.slug(name):
		DirAccess.remove_absolute(dir().path_join(Manuscript.slug(name) + ".json"))
	return err


## What an element is, as one value to tell two apart by: its kind, number and properties, never its name or whether it is set aside.
static func _what(el: Dictionary) -> String:
	var safe := Surroundings.element(el)
	safe.erase("name")
	safe.erase("off")
	return JSON.stringify(safe, "", true)


static func _write(e: Dictionary) -> String:
	DirAccess.make_dir_recursive_absolute(dir())
	var path := dir().path_join(Manuscript.slug(String(e["name"])) + ".json")
	var f := FileAccess.open(path + ".part", FileAccess.WRITE)
	if f == null:
		return "could not write " + path
	f.store_string(JSON.stringify(e, "\t"))
	f.close()
	return "" if DirAccess.rename_absolute(path + ".part", path) == OK else "could not move %s into place" % path
