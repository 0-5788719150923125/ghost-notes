extends PropSection
class_name EpisodeProps

## EpisodeProps - a table show's props on the Props card ([PropsCard]): what the open episode's table uses, and what is set aside
## from it.
##
##   Used       the things in `table.json`, each ticked: unticked, it moves to the table's `aside` list, which nothing stands and no
##              agent reads - the table is a hand's version then (kept, passed by Generate) and the work blocked on it goes stale
##              ([method EpisodeCard._hand_write]). Select picks it on the stage; Keep, in the 3D view its picture opens ([PropViewer],
##              [method PropSection.keep_prop]), puts the thing in the library ([ThingLibrary]), and the row then says so.
##   Set aside  the `aside` list, each unticked: ticked, it is used again.
##
## An entry's × takes the thing off the table for good, from either list, as a hand's version too.
##
## A game's model ([GameDiorama]) adds two lists, each kept from its 3D view, so what was modeled for one night can be kept in the
## library and found again on the next:
##
##   The land   each place on the board (`diorama.json`)
##   Figures    each figure modeled for the night (`minis.json`)
##
## The kept ornaments and textures its things wear ([OrnamentLibrary], next/surfaces.md) stand under Surfaces worn, each with Refine…
## and its versions ([OrnamentDesign]): every prop wearing one follows the version used.
##
## A game told in sticker pages (next/sticker_book.md) adds two more, Keep alone on each, so a night's drawings are drawn the same on
## the next ([StickerLibrary]):
##
##   Characters  each character and thing its pages drew, by its model, with how many poses it has
##   Sets        each place its pages stand in
##
## Its shelves on the Dex are the library's ([LibraryProps]: kept and seen props), each offered to Use on this episode's table. A
## prop's picture is taken once and kept by its hash ([PropStudio]); a row's when it first shows.

const GROUPS := [
	{"key": "table", "label": "Used", "tip": "What this episode's table uses. Untick one to set it aside: the table is then yours, and the work done on it is blocked again on Generate."},
	{"key": "aside", "label": "Set aside", "tip": "Taken off this episode's table and kept here: tick one to use it again."},
	{"key": "board", "label": "The land", "tip": "The places modeled on this game's board. Open one and Keep it to find it again on another night."},
	{"key": "figures", "label": "Figures", "tip": "The figures modeled for this game. Open one and Keep it to find it again on another night."},
	{"key": "cast", "label": "Characters", "tip": "Who and what this episode's pictures drew, each painted once and stuck on every page they are in. Keep one to draw it the same on another night."},
	{"key": "sets", "label": "Sets", "tip": "The places this episode's pictures stand in, each painted once. Keep one to use it again on another night."},
	{"key": "ornaments", "label": "Surfaces worn", "tip": "The ornaments and textures from your library this episode's things wear. Refine one, or step through its versions: every prop wearing it follows."},
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
var _thumbs := StickerThumbs.new()


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
			# kept from its 3D view (the picture opens it): the row says where it is
			var verbs: Array = []
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
				"verbs": [], "remove_off": "Model it again from its row on the Episode card."})
	out.append_array(_sticker_rows())
	out.append_array(_ornament_rows(t))
	return out


## The kept ornaments the table's things wear by name, and the kept textures its materials wear, once each.
func _ornament_rows(t: Dictionary) -> Array:
	var names := {}
	for th in (t.get("things", []) if t.get("things") is Array else []):
		if th is Dictionary:
			_worn((th as Dictionary).get("parts", []), names)
	var textures := {}
	for m in ((t["materials"] as Dictionary).values() if t.get("materials") is Dictionary else []):
		if m is Dictionary and (m as Dictionary).get("texture") is String:
			textures[String((m as Dictionary)["texture"]).strip_edges().to_lower()] = true
	var out: Array = []
	for nm in names.keys() + textures.keys():
		var e := OrnamentLibrary.find(String(nm), OrnamentLibrary.ORNAMENT if names.has(nm) else OrnamentLibrary.TEXTURE)
		if e.is_empty() or out.any(func(r: Dictionary) -> bool: return String(r["name"]) == String(e["name"])):
			continue
		var n := (e["versions"] as Array).size()
		var used := int(e["used"])
		out.append({"key": "ornament:" + String(e["name"]), "name": String(e["name"]), "group": "ornaments",
			"line": "%s  ·  version %d of %d" % [String(e["words"]).left(60), used + 1, n], "tip": String(e["words"]),
			"picture": _swatch(String(e["code"]), String(e["kind"])),
			"remove_off": "Take it off a thing by refining that thing; remove it from your library on the Dex.",
			"verbs": [{"key": "refine", "label": "Refine…", "tip": "Ask its designer for a change: a new version, which every prop wearing it shows."},
				{"key": "older", "label": "‹", "tip": "Use the version before this one.", "off": used <= 0},
				{"key": "newer", "label": "›", "tip": "Use the version after this one.", "off": used >= n - 1}]})
	return out


## The names a list of parts (and their groups' parts) wear as their ornament's kind, gathered in [param into].
static func _worn(parts: Variant, into: Dictionary) -> void:
	for p in (parts if parts is Array else []):
		if not (p is Dictionary):
			continue
		var o: Variant = (p as Dictionary).get("ornament")
		if o is Dictionary and (o as Dictionary).get("kind") is String:
			into[String((o as Dictionary)["kind"]).strip_edges().to_lower()] = true
		_worn((p as Dictionary).get("parts", []), into)


## The swatch of an ornament's or a texture's code ([param kind]) once taken ([method OrnamentLibrary.swatch]), asked for if not; null
## until then.
func _swatch(code: String, kind: String) -> Variant:
	if code.is_empty():
		return null
	var sw := OrnamentLibrary.swatch(code, kind)
	return library.pictures.of(ThingLibrary.hash_of(sw["thing"], sw["materials"]), sw["thing"], sw["materials"])


## A sticker book's characters, things and sets, each made ([StickerLibrary] says which are kept).
func _sticker_rows() -> Array:
	var out: Array = []
	var ep := card._episode
	if ep == null or not ep.wants_game() or not ep.composed():
		return out
	var g := ep.game()
	var poses: Array = g.get("poses", [])
	for kind in ["model", "thing"]:
		var list: Array = g.get("cast" if kind == "model" else "things", [])
		for i in list.size():
			var e: Dictionary = list[i]
			var st := "image:%s:%d" % [kind, i + 1]
			if not ep.has(st):
				continue
			var name := String(e.get("name", ""))
			var kept := StickerLibrary.kept_character(name, ep.file_of(st))
			var n := 0
			for j in poses.size():
				if String((poses[j] as Dictionary).get("who", "")).to_lower() == name.to_lower() and ep.has("image:pose:%d" % (j + 1)):
					n += 1
			var line := PackedStringArray()
			if kind == "model":
				line.append("%d pose%s besides standing" % [n, "" if n == 1 else "s"])
			if kept:
				line.append("in your library")
			out.append({"key": "%s:%s" % ["char" if kind == "model" else "stick", name], "name": name, "line": " - ".join(line),
				"tip": String(e.get("looks", name)), "group": "cast", "picture": _thumbs.of(ep.file_of(st)),
				"verbs": [{"key": "keep", "label": "Kept" if kept else "Keep", "off": kept,
					"tip": "In your library: a later night that draws %s draws it this way." % name if kept else "Keep it in your library, with every pose drawn of it, to draw it the same on another night."}],
				"remove_off": "Draw it again from its row on the Pipeline card."})
	var sets: Array = g.get("sets", [])
	for i in sets.size():
		var st := "image:set:%d" % (i + 1)
		if not ep.has(st):
			continue
		var name := String((sets[i] as Dictionary).get("name", ""))
		var kept := StickerLibrary.kept_set(name, ep.file_of(st))
		out.append({"key": "set:" + name, "name": name, "line": "in your library" if kept else "", "tip": String((sets[i] as Dictionary).get("looks", name)),
			"group": "sets", "picture": _thumbs.of(ep.file_of(st)),
			"verbs": [{"key": "keep", "label": "Kept" if kept else "Keep", "off": kept,
				"tip": "In your library." if kept else "Keep it in your library, to use again on another night."}],
			"remove_off": "Paint it again from its row on the Pipeline card."})
	return out


## Sticker row [param kind]:[param name] kept in the library: a character or thing with every pose drawn of it, or a set. "" done, else why not.
func _keep_sticker(kind: String, name: String) -> String:
	var ep := card._episode
	if ep == null or not ep.composed():
		return "this episode draws no sticker pages"
	var g := ep.game()
	if kind == "set":
		var sets: Array = g.get("sets", [])
		for i in sets.size():
			if String((sets[i] as Dictionary).get("name", "")) == name and ep.has("image:set:%d" % (i + 1)):
				return StickerLibrary.keep_set(name, String((sets[i] as Dictionary).get("looks", "")), ep.file_of("image:set:%d" % (i + 1)))
		return "%s is not painted yet" % name
	var step_kind := "model" if kind == "char" else "thing"
	var list: Array = g.get("cast" if kind == "char" else "things", [])
	for i in list.size():
		var e: Dictionary = list[i]
		var st := "image:%s:%d" % [step_kind, i + 1]
		if String(e.get("name", "")) != name or not ep.has(st):
			continue
		var poses := {}
		var all: Array = g.get("poses", [])
		for j in all.size():
			var q: Dictionary = all[j]
			if kind == "char" and String(q.get("who", "")).to_lower() == name.to_lower() and ep.has("image:pose:%d" % (j + 1)):
				poses[String(q.get("pose", ""))] = ep.file_of("image:pose:%d" % (j + 1))
		return StickerLibrary.keep_character(name, String(e.get("looks", "")), float(e.get("height", 170.0)), ep.file_of(st), ep.painted_of(st),
			poses, kind == "stick")
	return "%s is not drawn yet" % name


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
	if kind == "ornament":
		return _act_ornament(name, verb)
	match verb:
		"keep":
			# a sticker's Keep is its row's; a prop's is its 3D view's ([method PropSection.keep_prop])
			if kind in ["char", "stick", "set"]:
				return _keep_sticker(kind, name)
			return "keep a prop from its 3D view"
		"select":
			if kind != "thing":
				return "only what is used can be selected"
			var dock := card.open_dock()
			if dock != null:
				dock.inspect({"thing": name})
			return ""
	return library.act(key, verb)


## Verb [param verb] of the kept ornament [param name]: Refine… opens its designer's window, ‹ and › step through its versions.
func _act_ornament(name: String, verb: String) -> String:
	var e := OrnamentLibrary.find(name)
	if e.is_empty():
		return "%s is not in the library" % name
	match verb:
		"refine":
			OrnamentDesign.of(name).open()
			return ""
		"older", "newer":
			return OrnamentLibrary.use_version(name, int(e["used"]) + (-1 if verb == "older" else 1))
	return "nothing here does that"


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
	if key.begins_with("ornament:"):
		var e := OrnamentLibrary.find(key.substr(9))
		var code := String(e.get("code", ""))
		if code.is_empty():
			return null
		var sw := OrnamentLibrary.swatch(code, String(e["kind"]))
		return library.pictures.image(ThingLibrary.hash_of(sw["thing"], sw["materials"]))
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
