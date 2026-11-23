extends PropSection
class_name EpisodeProps

## EpisodeProps - a table show's props on the Props card ([PropsCard]): what the open episode's table uses, and what is set aside
## from it.
##
##   Used       the things in `table.json`, each ticked: unticked, it moves to the table's `aside` list, which nothing stands and no
##              agent reads - the table is a hand's version then (kept, passed by Generate) and the work blocked on it goes stale
##              ([method EpisodeCard._hand_write]). Keep puts the thing in the library ([ThingLibrary]); Select picks it on the stage.
##   Set aside  the `aside` list, each unticked: ticked, it is used again.
##
## An entry's × takes the thing off the table for good, from either list, as a hand's version too.
##
## A game's model ([GameDiorama]) adds two lists, Keep alone on each, so what was modeled for one night can be kept in the
## library and found again on the next:
##
##   The land   each place on the board (`diorama.json`)
##   Figures    each figure modeled for the night (`minis.json`)
##
## Its shelves on the Dex are the library's ([LibraryProps]: kept and seen props), each offered to Use on this episode's table. A
## prop's picture is taken once and kept by its hash ([PropStudio]); a row's when it first shows.

const GROUPS := [
	{"key": "table", "label": "Used", "tip": "What this episode's table uses. Untick one to set it aside: the table is then yours, and the work done on it is blocked again on Generate."},
	{"key": "aside", "label": "Set aside", "tip": "Taken off this episode's table and kept here: tick one to use it again."},
	{"key": "board", "label": "The land", "tip": "The places modeled on this game's board. Keep one to find it again on another night."},
	{"key": "figures", "label": "Figures", "tip": "The figures modeled for this game. Keep one to find it again on another night."},
]
## What a row's tick says on hover.
const ON_TIP := "Ticked, this episode's table uses it; unticked, it is set aside and kept here."

var card: EpisodeCard
## The library's shelves, which this section offers to Use, and whose pictures its rows share.
var library := LibraryProps.new()

var _table_key := ""              # the episode and its table's digest, as last read
var _table := {}
var _hashes := {}                 # a thing's name -> its hash ([method ThingLibrary.hash_of]), for the table as last read
var _models_key := ""
var _models := {}                 # "place" / "figure" -> name -> {thing, materials, hash}, the board and the figures as last read


func _init(c: EpisodeCard) -> void:
	card = c


# --- what stands -----------------------------------------------------------------------------------

func groups() -> Array:
	return GROUPS


func rows() -> Array:
	var out: Array = []
	var t := _read_table()
	var mats: Dictionary = t.get("materials", {}) if t.get("materials") is Dictionary else {}
	var kept := library.kept_by_hash()
	var pics := library.pictures
	for list in ["things", "aside"]:
		for th in (t.get(list, []) if t.get(list) is Array else []):
			if not (th is Dictionary) or String((th as Dictionary).get("name", "")).is_empty():
				continue
			var thing: Dictionary = th
			var name := String(thing["name"])
			var h := String(_hashes.get(name, ""))
			var as_kept := String(kept.get(h, ""))
			var line := PackedStringArray()
			if not pics.size_of(h).is_empty():
				line.append(pics.size_of(h))
			if not as_kept.is_empty():
				line.append("in your library" if as_kept == name else "in your library as %s" % as_kept)
			var verbs: Array = [
				{"key": "keep", "label": "Kept" if not as_kept.is_empty() else "Keep", "off": not as_kept.is_empty(),
					"tip": ("In your library as %s." % as_kept) if not as_kept.is_empty() else "Keep it in your library, to use again later."}]
			if list == "things":
				verbs.append({"key": "select", "label": "Select", "tip": "Select it on the stage: its rows open in the timeline's inspector."})
			out.append({"key": ("thing:" if list == "things" else "aside:") + name, "name": name, "line": " - ".join(line),
				"tip": String(thing.get("why", name)), "group": "table" if list == "things" else "aside",
				"picture": pics.of(h, thing, mats), "on": list == "things", "on_tip": ON_TIP, "verbs": verbs,
				"remove_tip": "Take it off this episode's table for good: the table is then yours, as unticking it makes it."})
	var models := _read_models()
	for kind in ["place", "figure"]:
		var by: Dictionary = models.get(kind, {})
		for name in by:
			var m: Dictionary = by[name]
			var h := String(m["hash"])
			var as_kept := String(kept.get(h, ""))
			out.append({"key": "%s:%s" % [kind, name], "name": String(name), "line": "in your library" if not as_kept.is_empty() else "",
				"tip": String(name), "group": "board" if kind == "place" else "figures", "picture": pics.of(h, m["thing"], m["materials"]),
				"verbs": [{"key": "keep", "label": "Kept" if not as_kept.is_empty() else "Keep", "off": not as_kept.is_empty(),
					"tip": ("In your library as %s." % as_kept) if not as_kept.is_empty() else "Keep it in your library, to use again on another night."}],
				"remove_off": "Model it again from its row on the Episode card."})
	return out


## The board's places and the night's figures, each a thing: read again only when either file changes.
func _read_models() -> Dictionary:
	var ep := card._episode
	if ep == null or not ep.wants_game():
		return {}
	var key := "%s|%s|%s" % [ep.dir, ep.digest("diorama") if ep.has("diorama") else "", ep.digest("minis") if ep.has("minis") else ""]
	if key == _models_key:
		return _models
	_models_key = key
	_models = {"place": {}, "figure": {}}
	var d: Variant = ep.read_json("diorama") if ep.has("diorama") else null
	if d is Dictionary:
		var mats: Dictionary = (d as Dictionary).get("materials", {}) if (d as Dictionary).get("materials") is Dictionary else {}
		for p in ((d as Dictionary).get("places", []) as Array):
			if p is Dictionary and (p as Dictionary).get("thing") is Dictionary:
				(_models["place"] as Dictionary)[String(p["name"])] = {"thing": p["thing"], "materials": mats, "hash": ThingLibrary.hash_of(p["thing"], mats)}
	var m: Variant = ep.read_json("minis") if ep.has("minis") else null
	if m is Dictionary and (m as Dictionary).get("figures") is Dictionary:
		var mats: Dictionary = (m as Dictionary).get("materials", {}) if (m as Dictionary).get("materials") is Dictionary else {}
		var figs: Dictionary = (m as Dictionary)["figures"]
		for name in figs:
			if figs[name] is Dictionary:
				(_models["figure"] as Dictionary)[String(name)] = {"thing": figs[name], "materials": mats, "hash": ThingLibrary.hash_of(figs[name], mats)}
	return _models


func set_on(key: String, on: bool) -> String:
	var from := "aside" if on else "things"
	var to := "things" if on else "aside"
	var name := key.substr(key.find(":") + 1)
	var err := card._hand_write("table", func() -> String: return move_thing(name, from, to))
	card._after_hand("table", err)
	return err


func remove(key: String) -> String:
	var from := "aside" if key.begins_with("aside:") else "things"
	var name := key.substr(key.find(":") + 1)
	var err := card._hand_write("table", func() -> String: return move_thing(name, from, ""))
	card._after_hand("table", err)
	return err


## Thing [param name] moved from the table's [param from] list to its [param to] list (none: off the table for good) ("things" stands, "aside" does not), as a hand
## writes it. "" written, else why not.
func move_thing(name: String, from: String, to: String) -> String:
	var ep := card._episode
	if ep == null or not ep.has("table"):
		return "this episode has no table yet"
	var raw: Variant = ep.read_json("table")
	if not (raw is Dictionary):
		return "the table is not readable"
	var t: Dictionary = (raw as Dictionary).duplicate(true)
	var src: Array = t.get(from, []) if t.get(from) is Array else []
	var dst: Array = t.get(to, []) if t.get(to) is Array else []
	for i in src.size():
		if src[i] is Dictionary and String((src[i] as Dictionary).get("name", "")) == name:
			if not to.is_empty():
				dst.append(src[i])
				t[to] = dst
			src.remove_at(i)
			t[from] = src
			if (t.get("aside", []) as Array).is_empty():
				t.erase("aside")
			return ep.write_json("table", t)
	return "%s is not %s" % [name, "set aside" if from == "aside" else "on the table"]


func act(key: String, verb: String) -> String:
	var kind := key.get_slice(":", 0)
	var name := key.substr(kind.length() + 1)
	match verb:
		"keep":
			return _keep_from(kind, name).get("error", "")
		"select":
			if kind != "thing":
				return "only what is used can be selected"
			var dock := card.open_dock()
			if dock != null:
				dock.inspect({"thing": name})
			return ""
	return library.act(key, verb)


## The thing a row names kept in the library, its picture taken: `{name}` (what it is kept as), or `{error}`. One kept already is
## not kept again.
func _keep_from(kind: String, name: String) -> Dictionary:
	var th := _thing_of(kind, name)
	var mats: Dictionary = _table.get("materials", {}) if _table.get("materials") is Dictionary else {}
	if kind in ["place", "figure"]:
		var m: Dictionary = (_read_models().get(kind, {}) as Dictionary).get(name, {})
		th = m.get("thing", {})
		mats = m.get("materials", {})
	if th.is_empty():
		return {"error": "%s is not on this table" % name}
	var h := ThingLibrary.hash_of(th, mats)
	var already := String(library.kept_by_hash().get(h, ""))
	if not already.is_empty():
		return {"name": already}
	var err := library.keep(th, mats, "")
	return {"error": err} if not err.is_empty() else {"name": String(library.kept_by_hash().get(h, name))}


## The thing row [param kind]:[param name] names as the table writes it ("thing" used, "aside" set aside), {} for none.
func _thing_of(kind: String, name: String) -> Dictionary:
	var t := _read_table()
	var list := "things" if kind == "thing" else "aside"
	for th in (t.get(list, []) if t.get(list) is Array else []):
		if th is Dictionary and String((th as Dictionary).get("name", "")) == name:
			return th
	return {}


func prop_of(key: String) -> Dictionary:
	var kind := key.get_slice(":", 0)
	var name := key.substr(kind.length() + 1)
	if kind in ["thing", "aside"]:
		var th := _thing_of(kind, name)
		if th.is_empty():
			return {}
		var mats: Dictionary = _table.get("materials", {}) if _table.get("materials") is Dictionary else {}
		return {"name": name, "thing": th, "materials": mats, "hash": String(_hashes.get(name, ""))}
	if kind in ["place", "figure"]:
		var m: Dictionary = (_read_models().get(kind, {}) as Dictionary).get(name, {})
		return {} if m.is_empty() else {"name": name, "thing": m["thing"], "materials": m["materials"], "hash": String(m["hash"])}
	return library.prop_of(key)


func model_of(key: String) -> Dictionary:
	var p := prop_of(key)
	if p.is_empty():
		return {}
	return await PropStudio.model(p["thing"], p["materials"], String(p["hash"]))


# --- adding: the library's shelves, each offered to Use here -----------------------------------------

func shelves() -> Array:
	return library.shelves()


func offers() -> Array:
	return library.offers()


func versions_of() -> PropVersions:
	return library.versions_of()


## A thing on the table refined takes the version of the prop kept from it that is used: its parts, scale and materials, written
## as a hand's version of the table; where it stands, its name, group and why stay. A thing already that version is left alone.
func refined(key: String, name: String) -> String:
	var kind := key.get_slice(":", 0)
	if kind != "thing" and kind != "aside":
		return ""
	var thing_name := key.substr(kind.length() + 1)
	var e := ThingLibrary.read(name)
	if e.is_empty():
		return "%s is not in the library" % name
	var th := _thing_of(kind, thing_name)
	var mats: Dictionary = _table.get("materials", {}) if _table.get("materials") is Dictionary else {}
	if th.is_empty() or ThingLibrary.hash_of(th, mats) == String(e["hash"]):
		return ""
	var err := card._hand_write("table", func() -> String: return replace_thing(thing_name, kind, e))
	card._after_hand("table", err)
	return err


## Thing [param name] on the table's [param kind] list ("thing" used, "aside" set aside) made the kept prop [param e] ([method
## ThingLibrary.read]): its parts and scale, and the materials they use added as [method ThingLibrary.put_on] adds them, renamed
## where the table has another of the name. "" written, else why not.
func replace_thing(name: String, kind: String, e: Dictionary) -> String:
	var ep := card._episode
	if ep == null or not ep.has("table"):
		return "this episode has no table yet"
	var raw: Variant = ep.read_json("table")
	if not (raw is Dictionary):
		return "the table is not readable"
	var t: Dictionary = (raw as Dictionary).duplicate(true)
	var list := "things" if kind == "thing" else "aside"
	var things: Array = t.get(list, []) if t.get(list) is Array else []
	for i in things.size():
		if not (things[i] is Dictionary) or String((things[i] as Dictionary).get("name", "")) != name:
			continue
		var placed := ThingLibrary.put_on({"things": [], "materials": t.get("materials", {}) if t.get("materials") is Dictionary else {}}, e, null)
		var made: Dictionary = (placed["things"] as Array)[0]
		var th: Dictionary = (things[i] as Dictionary).duplicate(true)
		th["parts"] = made["parts"]
		if made.has("scale"):
			th["scale"] = made["scale"]
		else:
			th.erase("scale")
		things[i] = th
		t[list] = things
		t["materials"] = placed["materials"]
		return ep.write_json("table", t)
	return "%s is not on this table" % name


func want_pictures(keys: Array) -> void:
	library.want_pictures(keys)


func prepare_pictures(keys: Array) -> void:
	library.prepare_pictures(keys)


func picture(key: String) -> Variant:
	return library.picture(key)


func rename(key: String, name: String) -> String:
	return library.rename(key, name)


func exportable(key: String) -> bool:
	return library.exportable(key)


func export_to(key: String, path: String) -> String:
	return library.export_to(key, path)


func import_from(path: String) -> String:
	return library.import_from(path)


func adds() -> Dictionary:
	if card._episode != null and card._episode.has("table"):
		return {"label": "+ Add a prop", "verb": "Use",
			"tip": "Use it on this episode's table, at the middle of the reading - the table is then yours, to move it where it goes."}
	return {}


func add(key: String) -> String:
	var entry := {}
	var p := library.prop_of(key)
	if not p.is_empty():
		entry = library.entry(key.substr(5)) if key.begins_with("kept:") else ThingLibrary.entry_of(p["thing"], p["materials"])
	if entry.is_empty():
		return "that prop is gone"
	if card._episode == null or not card._episode.has("table"):
		return "this episode has no table yet"
	var err := card._hand_write("table", func() -> String:
		var t: Variant = card._episode.read_json("table")
		return card._episode.write_json("table", ThingLibrary.put_on(t if t is Dictionary else {}, entry)))
	card._after_hand("table", err)
	return err


# --- reading ----------------------------------------------------------------------------------------

## The open episode's table as written, read again only when its file changed; {} for none.
func _read_table() -> Dictionary:
	var ep := card._episode
	if ep == null or not ep.has("table"):
		_table_key = ""
		_table = {}
		return _table
	var key := "%s|%s" % [ep.dir, ep.digest("table")]
	if key != _table_key:
		_table_key = key
		var raw: Variant = ep.read_json("table")
		_table = raw if raw is Dictionary else {}
		_hashes = {}
		var mats: Dictionary = _table.get("materials", {}) if _table.get("materials") is Dictionary else {}
		for list in ["things", "aside"]:
			for th in (_table.get(list, []) if _table.get(list) is Array else []):
				if th is Dictionary:
					_hashes[String((th as Dictionary).get("name", ""))] = ThingLibrary.hash_of(th, mats)
	return _table
