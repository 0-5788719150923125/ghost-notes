extends PropSection
class_name DeskRecipes

## DeskRecipes - the things a desk sets out ([constant DeskLook.THINGS]) on the Dex's shelf: each as the first desk draws it, to look
## at in 3D and keep in the library, where a set dresser and any scene can use it. A desk's mat lies under its pad, never on its own,
## and is not offered.

const SHELVES := [{"key": "desk_things", "label": "Desk things", "tip": "What a desk sets out - mugs, pencils, books, candles - as the first desk draws each. Open one and Keep it to use it anywhere."}]
## The desk's number each is drawn at.
const SEED := 1

## Where the pictures come from, and where a kept one goes.
var library := LibraryProps.new()
var _specs := {}                 # kind -> [hash, thing, materials]


func shelves() -> Array:
	return SHELVES


func offers() -> Array:
	var out: Array = []
	var kept := library.kept_by_hash()
	for k in _kinds():
		var sp := _spec(String(k))
		var h := String(sp[0])
		var as_kept := String(kept.get(h, ""))
		var row: Dictionary = DeskLook.THINGS[k]
		var line := library.pictures.size_of(h)
		if not as_kept.is_empty():
			line = "in your library as %s" % as_kept + (" - " + line if not line.is_empty() else "")
		out.append({"key": "desk:" + String(k), "name": DeskRows.thing_name(String(row["label"])), "line": line,
			"shelf": "desk_things", "tip": String(row["blurb"]), "picture": library.pictures.image(h)})
	return out


## A desk's thing is said, kept, to be what the desk's row says it is.
func keep_line(key: String) -> String:
	return String((DeskLook.THINGS[key.substr(5)] as Dictionary)["blurb"]) if key.begins_with("desk:") and DeskLook.THINGS.has(key.substr(5)) else ""


func prop_of(key: String) -> Dictionary:
	if not key.begins_with("desk:") or not _kinds().has(key.substr(5)):
		return {}
	var sp := _spec(key.substr(5))
	if (sp[1] as Dictionary).is_empty():
		return {}
	return {"name": DeskRows.thing_name(String((DeskLook.THINGS[key.substr(5)] as Dictionary)["label"])), "thing": sp[1],
		"materials": sp[2], "hash": String(sp[0])}


func model_of(key: String) -> Dictionary:
	var p := prop_of(key)
	if p.is_empty():
		return {}
	return await PropStudio.model(p["thing"], p["materials"], String(p["hash"]))


func versions_of() -> PropVersions:
	return library.versions_of()


func want_pictures(keys: Array) -> void:
	library.pictures.want(_asked(keys))


func prepare_pictures(keys: Array) -> void:
	library.pictures.prepare(_asked(keys))


func picture(key: String) -> Variant:
	var p := prop_of(key)
	return library.pictures.image(String(p["hash"])) if not p.is_empty() else null


func settle() -> void:
	library.settle()


## The kinds offered: every thing a desk sets out but its mat.
static func _kinds() -> Array:
	return DeskLook.THINGS.keys().filter(func(k: String) -> bool: return not bool((DeskLook.THINGS[k] as Dictionary).get("layer", false)))


## Kind [param kind] as the first desk writes it, worked out once: `[hash, thing, materials]`.
func _spec(kind: String) -> Array:
	if not _specs.has(kind):
		var sp := DeskLook.spec_of(kind, SEED)
		var things: Array = sp.get("things", []) if sp.get("things") is Array else []
		var thing: Dictionary = things[0] if not things.is_empty() else {}
		var mats: Dictionary = sp.get("materials", {}) if sp.get("materials") is Dictionary else {}
		_specs[kind] = [ThingLibrary.hash_of(thing, mats) if not thing.is_empty() else "", thing, mats]
	return _specs[kind]


func _asked(keys: Array) -> Array:
	var out: Array = []
	for k in keys:
		var p := prop_of(String(k))
		if not p.is_empty():
			out.append([String(p["hash"]), p["thing"], p["materials"]])
	return out
