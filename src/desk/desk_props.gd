extends PropSection
class_name DeskProps

## DeskProps - what is on a desk, on the Props card ([PropsCard]): a row for each thing a desk sets out ([constant DeskLook.THINGS]),
## pictured as the desk's number draws it ([method DeskLook.spec_of], [PropPictures]) and ticked while it is on the desk. A tick is
## the rows' own ([method DeskRows.set_thing]): until one changes, the desk's number chooses what is on it, and the first change
## keeps it. Handed to the panel by the format the rows are on ([LetterFormat], [DeskFormat]).

const GROUPS := [{"key": "desk", "label": "A desk's things",
	"tip": "What a desk can hold, ticked where this one uses it. Until one is ticked or unticked the desk's number chooses them; the first change keeps them."}]

var desk: DeskRows
var _pics := PropPictures.new()
var _specs := {}                  # "kind|seed" -> [hash, thing, materials]


func _init(rows: DeskRows) -> void:
	desk = rows


func groups() -> Array:
	return GROUPS


func rows() -> Array:
	var out: Array = []
	var on := desk.desk_things()
	var seed := desk.desk_seed()
	for k in DeskLook.THINGS:
		var row: Dictionary = DeskLook.THINGS[k]
		var sp := _spec(String(k), seed)
		var h := String(sp[0])
		var line := _pics.size_of(h)
		if bool(row.get("lit", false)):
			line = "it burns" if line.is_empty() else line + " - it burns"
		out.append({"key": String(k), "name": DeskRows.thing_name(String(row["label"])), "line": line, "tip": String(row["blurb"]),
			"group": "desk", "picture": _pics.of(h, sp[1], sp[2]), "on": String(k) in on,
			"on_tip": "Ticked, the desk uses it, placed and drawn by the desk's number; unticked, it does not."})
	return out


func set_on(key: String, on: bool) -> String:
	if not DeskLook.THINGS.has(key):
		return "a desk sets out no such thing"
	desk.set_thing(key, on)
	return ""


func prop_of(key: String) -> Dictionary:
	if not DeskLook.THINGS.has(key):
		return {}
	var sp := _spec(key, desk.desk_seed())
	if (sp[1] as Dictionary).is_empty():
		return {}
	return {"name": DeskRows.thing_name(String((DeskLook.THINGS[key] as Dictionary)["label"])), "thing": sp[1], "materials": sp[2],
		"hash": String(sp[0])}


func model_of(key: String) -> Dictionary:
	var p := prop_of(key)
	if p.is_empty():
		return {}
	return await PropStudio.model(p["thing"], p["materials"], String(p["hash"]))


## Thing [param kind] as the desk of [param seed] writes it: `[hash, thing, materials]`, worked out once.
func _spec(kind: String, seed: int) -> Array:
	var key := "%s|%d" % [kind, seed]
	if not _specs.has(key):
		var sp := DeskLook.spec_of(kind, seed)
		var things: Array = sp.get("things", []) if sp.get("things") is Array else []
		var thing: Dictionary = things[0] if not things.is_empty() else {}
		var mats: Dictionary = sp.get("materials", {}) if sp.get("materials") is Dictionary else {}
		_specs[key] = [ThingLibrary.hash_of(thing, mats) if not thing.is_empty() else "", thing, mats]
	return _specs[key]
