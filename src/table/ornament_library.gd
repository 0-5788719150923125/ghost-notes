extends RefCounted
class_name OrnamentLibrary

## OrnamentLibrary - surfaces written by an agent, kept to wear on any prop (next/surfaces.md; [Ornaments]): ornaments (a part's
## `ornament`) and textures (a material's `texture`), on the library's `ornaments` shelf ([Library]), a folder each -
## `<slug>/ornament.json` (`{name, kind, words, versions: [{code, said}], used}`, `kind` [constant ORNAMENT] or [constant TEXTURE])
## beside the conversation its designer made it in ([OrnamentDesign]). A version is kept, never deleted; the one used is what every
## prop wearing it by its name draws ([method code_of]). Read once and held until the shelf is written here ([member version]).
##
## A swatch shows one: an ornament on a turned vase and a plaque, a texture on a bowl and a block ([method swatch]), photographed as
## any prop is ([PropPictures]).

const SHELF := "ornaments"
const FILE := "ornament.json"
## What a kept one is: an ornament or a texture ([constant Ornaments.HOOKS]).
const ORNAMENT := Ornaments.ORNAMENT
const TEXTURE := Ornaments.TEXTURE
## The name a new one is given until it is named, numbered after any so called: an ornament's, a texture's.
const NEW_NAME := "Ornament"
const NEW_TEXTURE := "Texture"

## Moves whenever the shelf is written: the Dex and whatever holds an entry read it again.
static var version := 0
static var _held: Array = []
static var _held_for := ""
static var _lock := Mutex.new()


## The shelf's folder, absolute.
static func dir() -> String:
	return Library.shelf(SHELF)


## Where the ornament named [param name] is kept: its folder.
static func folder(name: String) -> String:
	return dir().path_join(Manuscript.slug(name))


## Every ornament and texture kept, sorted by name: each `{name, kind, words, versions, used, code, folder}` - `code` its version used
## ("" while it has none). Read again only when the shelf is written or moved; any thread.
static func entries() -> Array:
	var stamp := "%s|%d" % [dir(), version]
	_lock.lock()
	if stamp != _held_for:
		_held = _read_all()
		_held_for = stamp
	var out := _held.duplicate(true)
	_lock.unlock()
	return out


static func _read_all() -> Array:
	var out: Array = []
	if not DirAccess.dir_exists_absolute(dir()):
		return out
	for sub in DirAccess.get_directories_at(dir()):
		var e := _read(dir().path_join(sub))
		if not e.is_empty():
			out.append(e)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a["name"]).naturalnocasecmp_to(String(b["name"])) < 0)
	return out


## The entry in folder [param at] made safe, {} where it is none.
static func _read(at: String) -> Dictionary:
	var path := at.path_join(FILE)
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	if not (d is Dictionary):
		return {}
	var name := Props._text((d as Dictionary).get("name", ""), 60)
	if name.is_empty():
		return {}
	var kind := TEXTURE if (d as Dictionary).get("kind") == TEXTURE else ORNAMENT
	var versions: Array = []
	for v in ((d as Dictionary).get("versions", []) if (d as Dictionary).get("versions") is Array else []):
		if v is Dictionary and (v as Dictionary).get("code") is String:
			versions.append({"code": String((v as Dictionary)["code"]).left(Ornaments.LONGEST), "said": Props._text((v as Dictionary).get("said", ""), 400)})
	var used := clampi(int((d as Dictionary).get("used", versions.size() - 1)), -1, versions.size() - 1)
	return {"name": name, "kind": kind, "words": Props._text((d as Dictionary).get("words", ""), 400), "versions": versions, "used": used,
		"code": String((versions[used] as Dictionary)["code"]) if used >= 0 else "", "folder": at}


## The one named [param name] (in any case), {} for none - or for one that is not a [param kind], where it says one.
static func find(name: String, kind := "") -> Dictionary:
	var want := name.strip_edges().to_lower()
	if want.is_empty():
		return {}
	for e in entries():
		if String((e as Dictionary)["name"]).to_lower() == want:
			return e if kind.is_empty() or String((e as Dictionary)["kind"]) == kind else {}
	return {}


## Every [param kind] kept that has been made, as an agent is told of them: each `{name, words}`.
static func listing(kind := ORNAMENT) -> Array:
	var out: Array = []
	for e in entries():
		if not String((e as Dictionary)["code"]).is_empty() and String((e as Dictionary)["kind"]) == kind:
			out.append({"name": String((e as Dictionary)["name"]), "words": String((e as Dictionary)["words"])})
	return out


## The code the ornament named [param name] draws (its version used), "" for none.
static func code_of(name: String) -> String:
	return String(find(name).get("code", ""))


## A new [param kind] to be made from [param words] (perhaps none yet), called [param name] or a new name of its own: its name, ""
## where it cannot be kept.
static func make(words := "", name := "", kind := ORNAMENT) -> String:
	if not Library.writable():
		return ""
	var to := name.strip_edges().left(60)
	if to.is_empty() or not find(to).is_empty():
		var n := 1
		var base := NEW_TEXTURE if kind == TEXTURE else NEW_NAME
		to = base
		while not find(to).is_empty() or DirAccess.dir_exists_absolute(folder(to)):
			n += 1
			to = "%s %d" % [base, n]
	var err := _write({"name": to, "kind": kind, "words": words.strip_edges().left(400), "versions": [], "used": -1}, folder(to))
	return to if err.is_empty() else ""


## [param code] kept as a new version of [param name], what the designer said of it [param said], and used: its index, -1 where it
## is not what [param name] is ([method Ornaments.check]) or it cannot be kept.
static func add_version(name: String, code: String, said := "") -> int:
	var e := find(name)
	if e.is_empty() or not Ornaments.check(code, String(e["kind"])).is_empty():
		return -1
	var versions: Array = e["versions"]
	versions.append({"code": code.strip_edges(), "said": said.strip_edges().left(400)})
	e["used"] = versions.size() - 1
	return int(e["used"]) if _write(e, String(e["folder"])).is_empty() else -1


## Version [param i] of [param name] made the one used. "" done, else why not.
static func use_version(name: String, i: int) -> String:
	var e := find(name)
	if e.is_empty():
		return "%s is not in the library" % name
	if i < 0 or i >= (e["versions"] as Array).size():
		return "it has no such version"
	e["used"] = i
	return _write(e, String(e["folder"]))


## The words [param name] is made from set to [param words].
static func set_words(name: String, words: String) -> String:
	var e := find(name)
	if e.is_empty():
		return "%s is not in the library" % name
	e["words"] = words.strip_edges().left(400)
	return _write(e, String(e["folder"]))


## The ornament [param name] called [param new_name], its folder moved with it. "" done, else why not.
static func rename(name: String, new_name: String) -> String:
	var e := find(name)
	if e.is_empty():
		return "%s is not in the library" % name
	var to := new_name.strip_edges().left(60)
	if to.is_empty():
		return "it needs a name"
	if to.to_lower() != name.to_lower() and not find(to).is_empty():
		return "another is called %s" % to
	if not Library.writable():
		return "this session cannot write the library"
	var at := String(e["folder"])
	var dest := folder(to)
	if dest != at:
		if DirAccess.dir_exists_absolute(dest):
			return "another is called %s" % to
		if DirAccess.rename_absolute(at, dest) != OK:
			return "could not move it to its new name"
	e["name"] = to
	return _write(e, dest)


## The ornament [param name] taken off the shelf, to the trash ([method Library.trash]). "" done, else why not.
static func remove(name: String) -> String:
	var e := find(name)
	if e.is_empty():
		return "%s is not in the library" % name
	if not Library.writable():
		return "this session cannot write the library"
	var err := "" if Library.trash(String(e["folder"])) == OK else "could not take %s off the shelf" % name
	_changed()
	return err


## What shows [param code] as a [param kind], on its shelf and to its designer: an ornament round a turned vase's middle, six cells
## across, and on a plaque; a texture all over a turned clay bowl and a stone block. `{thing, materials}`.
static func swatch(code: String, kind := ORNAMENT) -> Dictionary:
	if kind == TEXTURE:
		var bowl := {"shape": "lathe", "smooth": true, "material": "swatch clay",
			"profile": [[0, 0], [3.2, 0], [3.4, 0.5, 0], [5.6, 3.5], [6.4, 6.5], [6.6, 7.0, 0], [6.0, 7.0], [5.2, 4.0], [2.8, 0.8], [0, 0.8]]}
		var block := {"shape": "box", "size": [9.0, 7.0, 6.0], "round": 0.6, "at": [12.0, 0.0, 0.0], "material": "swatch stone"}
		var tx := {"texture": "own", "texture_code": code, "bumps": 0.75}
		return {"thing": {"name": "swatch", "parts": [bowl, block]},
			"materials": {"swatch clay": tx.merged({"kind": "ceramic", "color": "#b8714a", "color2": "#5e3a26", "polish": 0.25}),
				"swatch stone": tx.merged({"kind": "stone", "color": "#cfc8b8", "color2": "#6e685c", "polish": 0.3, "pattern": 0.0})}}
	var orn := {"kind": "own", "code": code, "count": 6, "depth": 0.8, "from": 0.12, "to": 0.88}
	var vase := {"shape": "lathe", "smooth": true, "material": "swatch brass", "ornament": orn,
		"profile": [[0, 0], [4.2, 0], [4.6, 0.6, 0], [4.4, 1.2], [5.2, 6.0], [5.0, 10.5], [4.0, 12.0], [4.4, 12.6, 0], [4.4, 13.0], [0, 13.0]]}
	var plaque := {"shape": "box", "size": [9.0, 9.0, 0.8], "round": 0.3, "at": [11.0, 0.0, 0.0], "material": "swatch stone",
		"ornament": orn.duplicate()}
	return {"thing": {"name": "swatch", "parts": [vase, plaque]},
		"materials": {"swatch brass": {"kind": "metal", "color": "#c9a24a", "color2": "#5d4a26", "polish": 0.7, "wear": 0.35},
			"swatch stone": {"kind": "stone", "color": "#d8d2c4", "color2": "#8a8478", "polish": 0.4, "pattern": 0.1}}}


static func _write(e: Dictionary, at: String) -> String:
	if not Library.writable():
		return "this session cannot write the library"
	DirAccess.make_dir_recursive_absolute(at)
	var path := at.path_join(FILE)
	var kept := {"name": e["name"], "kind": e.get("kind", ORNAMENT), "words": e.get("words", ""), "versions": e.get("versions", []),
		"used": e.get("used", -1)}
	var f := FileAccess.open(path + ".part", FileAccess.WRITE)
	if f == null:
		return "could not write " + path
	f.store_string(JSON.stringify(kept, "\t"))
	f.close()
	var err := "" if DirAccess.rename_absolute(path + ".part", path) == OK else "could not move %s into place" % path
	_changed()
	return err


static func _changed() -> void:
	_lock.lock()
	version += 1
	_lock.unlock()
