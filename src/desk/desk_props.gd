extends PropSection
class_name DeskProps

## DeskProps - what is on a desk, on the Props card ([PropsCard]): an entry for each thing on it ([constant DeskLook.THINGS]),
## pictured as it is on this desk ([method DeskLook.of]), its × taking it off; "+ Add a prop" opens the Dex on the desk's things not on
## it, each pictured as the desk's number draws it ([method DeskLook.spec_of]), Use setting it out. What is on it is the rows' own
## ([method DeskRows.set_thing]): until one changes, the desk's number chooses what is on it, and the first change keeps it. Handed to
## the panel by the format the rows are on ([LetterFormat], [DeskFormat]).
##
## A thing opened in 3D is refined into versions (next/working_props.md): kept in the library on its first refine, and played on the
## desk by the version used ([method refined], [method DeskRows.set_make]) - Desk's own puts the number's back.

const GROUPS := [{"key": "desk", "label": "On the desk",
	"tip": "What is on this desk. Until one is taken off or added the desk's number chooses them; the first change keeps them. Open one's picture to turn it in 3D and refine it."}]
const SHELVES := [{"key": "desk_things", "label": "A desk's things", "tip": "What a desk can hold and this one does not, each as the desk's number draws it."}]

var desk: DeskRows
## Where kept props and their versions are, and every picture.
var library := LibraryProps.new()
var _specs := {}                  # "kind|seed" -> [hash, thing, materials]: one as the number draws it
var _on_desk := {}                # the desk as it stands ("seed|picks" -> {kind: [hash, thing, materials]}), its things the desk's own


func _init(rows: DeskRows) -> void:
	desk = rows


func groups() -> Array:
	return GROUPS


func rows() -> Array:
	var out: Array = []
	var on := desk.desk_things()
	var makes := desk.desk_makes()
	for k in DeskLook.THINGS:
		if not String(k) in on:
			continue
		var row: Dictionary = DeskLook.THINGS[k]
		var p := prop_of(String(k))
		var h := String(p.get("hash", ""))
		var line := library.pictures.size_of(h)
		if bool(row.get("lit", false)):
			line = "it burns" if line.is_empty() else line + " - it burns"
		var verbs: Array = []
		if makes.has(k):
			verbs.append({"key": "own", "label": "Desk's own", "tip": "Back to the one the desk's number draws."})
		out.append({"key": String(k), "name": String(p.get("name", DeskRows.thing_name(String(row["label"])))), "line": line, "tip": String(row["blurb"]),
			"group": "desk", "picture": library.pictures.of(h, p["thing"], p["materials"]) if not p.is_empty() else null, "verbs": verbs,
			"remove_tip": "Take it off the desk. \"+ Add a prop\" sets it out again."})
	return out


func remove(key: String) -> String:
	if not DeskLook.THINGS.has(key):
		return "a desk sets out no such thing"
	desk.set_thing(key, false)
	return ""


func shelves() -> Array:
	return SHELVES


## The desk's things not on it, each as the desk's number draws it.
func offers() -> Array:
	var out: Array = []
	var on := desk.desk_things()
	for k in DeskLook.THINGS:
		if String(k) in on:
			continue
		var p := prop_of(String(k))
		var h := String(p.get("hash", ""))
		out.append({"key": String(k), "name": String(p.get("name", DeskRows.thing_name(String((DeskLook.THINGS[k] as Dictionary)["label"])))),
			"line": library.pictures.size_of(h), "shelf": "desk_things", "tip": String((DeskLook.THINGS[k] as Dictionary)["blurb"]),
			"picture": library.pictures.image(h) if not h.is_empty() else null})
	return out


func adds() -> Dictionary:
	return {"label": "+ Add a prop", "verb": "Use", "tip": "Set it out on the desk, placed by the desk's number."}


func add(key: String) -> String:
	if not DeskLook.THINGS.has(key):
		return "a desk sets out no such thing"
	desk.set_thing(key, true)
	return ""


func set_on(key: String, on: bool) -> String:
	if not DeskLook.THINGS.has(key):
		return "a desk sets out no such thing"
	desk.set_thing(key, on)
	return ""


func act(key: String, verb: String) -> String:
	if not DeskLook.THINGS.has(key):
		return "a desk sets out no such thing"
	if verb == "own":
		desk.set_make(key, {})
		return ""
	return "nothing here does that"


func prop_of(key: String) -> Dictionary:
	if not DeskLook.THINGS.has(key):
		return {}
	var kept := String((desk.desk_makes().get(key, {}) as Dictionary).get("kept", ""))
	if not kept.is_empty():
		var e := ThingLibrary.read(kept)
		if not e.is_empty():
			return {"name": kept, "thing": e["thing"], "materials": e["materials"], "hash": String(e["hash"])}
	var sp := _own(key)
	if (sp[1] as Dictionary).is_empty():
		return {}
	return {"name": DeskRows.thing_name(String((DeskLook.THINGS[key] as Dictionary)["label"])), "thing": sp[1], "materials": sp[2],
		"hash": String(sp[0])}


func model_of(key: String) -> Dictionary:
	var p := prop_of(key)
	if p.is_empty():
		return {}
	return await PropStudio.model(p["thing"], p["materials"], String(p["hash"]))


## What on the desk throws light: its lamp, and each kind of candle on it ([DeskMedium] reads their shares).
func lit() -> Array:
	var out: Array = [{"key": "lamp", "name": "The desk lamp"}]
	for k in desk.desk_things():
		if bool((DeskLook.THINGS.get(String(k), {}) as Dictionary).get("lit", false)):
			out.append({"key": String(k), "name": DeskRows.thing_name(String((DeskLook.THINGS[k] as Dictionary)["label"]))})
	return out


func versions_of() -> PropVersions:
	return library.versions_of()


## A thing refined is played on the desk by the prop kept from it, whichever of its versions is used.
func refined(key: String, name: String) -> String:
	if not DeskLook.THINGS.has(key):
		return ""
	if desk.desk_makes().get(key, {}) == PropMakes.chosen({"kept": name}):
		return ""
	desk.set_make(key, {"kept": name})
	return ""


func want_pictures(keys: Array) -> void:
	library.pictures.want(_asked(keys))


func prepare_pictures(keys: Array) -> void:
	library.pictures.prepare(_asked(keys))


func picture(key: String) -> Variant:
	var p := prop_of(key)
	return library.pictures.image(String(p["hash"])) if not p.is_empty() else null


func settle() -> void:
	if library != null:
		library.settle()


## Thing [param kind] as the desk's own: as it stands on this desk where it is on it ([method DeskLook.of], what is kept playing
## none), else as the desk's number draws it: `[hash, thing, materials]`, worked out once.
func _own(kind: String) -> Array:
	var seed := desk.desk_seed()
	var picks := desk.picks()
	picks.erase("makes")
	var dkey := "%d|%s" % [seed, str(picks)]
	if not _on_desk.has(dkey):
		var by := {}
		for t in DeskLook.of(seed, DeskLook.picks_of(picks))["things"]:
			var td: Dictionary = t
			by[String(td["kind"])] = [ThingLibrary.hash_of(td["thing"], td["materials"]), td["thing"], td["materials"]]
		_on_desk = {dkey: by}
	var on: Dictionary = _on_desk[dkey]
	if on.has(kind):
		return on[kind]
	var key := "%s|%d" % [kind, seed]
	if not _specs.has(key):
		var sp := DeskLook.spec_of(kind, seed)
		var things: Array = sp.get("things", []) if sp.get("things") is Array else []
		var thing: Dictionary = things[0] if not things.is_empty() else {}
		var mats: Dictionary = sp.get("materials", {}) if sp.get("materials") is Dictionary else {}
		_specs[key] = [ThingLibrary.hash_of(thing, mats) if not thing.is_empty() else "", thing, mats]
	return _specs[key]


func _asked(keys: Array) -> Array:
	var out: Array = []
	for k in keys:
		var p := prop_of(String(k))
		if not p.is_empty():
			out.append([String(p["hash"]), p["thing"], p["materials"]])
	return out
