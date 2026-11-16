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
## Its shelves on the Dex are the library's ([LibraryProps]: kept and seen props), each offered to Use on this episode's table. A
## prop's picture is taken once and kept by its hash ([PropStudio]); a row's when it first shows.

const GROUPS := [
	{"key": "table", "label": "Used", "tip": "What this episode's table uses. Untick one to set it aside: the table is then yours, and the work done on it is blocked again on Generate."},
	{"key": "aside", "label": "Set aside", "tip": "Taken off this episode's table and kept here: tick one to use it again."},
]
## What a row's tick says on hover.
const ON_TIP := "Ticked, this episode's table uses it; unticked, it is set aside and kept here."

var card: EpisodeCard
## The library's shelves, which this section offers to Use, and whose pictures its rows share.
var library := LibraryProps.new()

var _table_key := ""              # the episode and its table's digest, as last read
var _table := {}
var _hashes := {}                 # a thing's name -> its hash ([method ThingLibrary.hash_of]), for the table as last read


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
				"picture": pics.of(h, thing, mats), "on": list == "things", "on_tip": ON_TIP, "verbs": verbs})
	return out


func set_on(key: String, on: bool) -> String:
	var from := "aside" if on else "things"
	var to := "things" if on else "aside"
	var name := key.substr(key.find(":") + 1)
	var err := card._hand_write("table", func() -> String: return move_thing(name, from, to))
	card._after_hand("table", err)
	return err


## Thing [param name] moved from the table's [param from] list to its [param to] list ("things" stands, "aside" does not), as a hand
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
			dst.append(src[i])
			src.remove_at(i)
			t[from] = src
			t[to] = dst
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
	if th.is_empty():
		return {"error": "%s is not on this table" % name}
	var mats: Dictionary = _table.get("materials", {}) if _table.get("materials") is Dictionary else {}
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


func want_pictures(keys: Array) -> void:
	library.want_pictures(keys)


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
