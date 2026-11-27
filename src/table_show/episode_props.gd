extends PropSection
class_name EpisodeProps

## EpisodeProps - a table show's props on the Props card ([PropsCard]): the table itself, what the open episode's table uses, and
## what is set aside from it.
##
##   The table  the table itself and each cloth laid on it ([TableProp]): its picture opens the table whole in 3D; its properties -
##              size, shape, edge, base, what its top is made of and its finish; a cloth's fabric, pattern, colors, size and lie -
##              each change written into `table.json` as a hand's version, as unticking a thing is; Refine… has an agent rewrite
##              the top and cloths as a person says ([TableRefine]), in the background, its progress on the row. A cloth's ×
##              takes it off the table.
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
	{"key": "furniture", "label": "The table", "tip": "The table everything stands on and the cloths laid on it. Open one to change what it is made of, its size and shape, or have an agent refine it; open its picture to turn it in 3D."},
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
var _made := {}                   # the table as last read, made safe ([method CardTable.sanitize_table]): its top and cloths as built
var _look := {}                   # the episode's look, as last read with it
var _dresser_key := ""            # the set dresser's last table, made safe, while a hand's version of it stands
var _dresser := {}
var _refine: PropRefine = null    # the table's Refine window, while it has been opened
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
	var out: Array = _furniture_rows()
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
			"verbs": [{"key": "refine", "label": "Refine…", "tip": "Ask its designer for a change: a new version, which every prop wearing it shows.",
				"pressed": OrnamentDesign.open_now(String(e["name"]))},
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


# --- the table itself ([TableProp]) -------------------------------------------------------------------

## The table and each cloth on it, as rows: the table's picture taken as it is built alone ([method TableProp.made]).
func _furniture_rows() -> Array:
	var ep := card._episode
	var t := _read_table()
	if ep == null or t.is_empty() or not (_made.get("top") is Dictionary):
		return []
	var top: Dictionary = _made["top"]
	var refining := TableRefine.name_of(ep.dir)
	var spec := {"top": top, "layers": _made.get("layers", [])}
	var paint := ep.file_of("image:surface") if ep.has("image:surface") else ""
	var h := TableProp.hash_of(spec, ep.seed, ep.digest("image:surface") if not paint.is_empty() else "")
	var verbs: Array = [{"key": "refine", "label": "Refine…", "off": TableRefine.busy(ep.dir),
		"pressed": _refine != null and is_instance_valid(_refine) and RefineDock.is_open(_refine),
		"tip": "Have an agent change the table as you say - its top, what holds it up, the cloths on it. It runs while you work on; the table before is kept a version back." \
			if not TableRefine.busy(ep.dir) else "An agent is refining it now."}]
	if not _dressers_made().is_empty() and not TableProp.same(_dressers_made(), _made):
		verbs.append({"key": "own", "label": "Set dresser's", "tip": "The table and its cloths back as the set dresser laid them, the things on it as they are; the one you changed is kept a version back."})
	var out: Array = [{"key": "furniture:top", "name": "The table", "line": TableProp.line_of(top), "group": "furniture",
		"tip": String(top.get("why", "")) if not String(top.get("why", "")).is_empty() else "The table everything stands on.",
		"picture": library.pictures.of_made(h, func() -> Dictionary: return await TableProp.made_away(spec, ep.seed, paint)),
		"verbs": verbs, "fields": TableProp.top_rows(top), "refining_as": refining,
		"values": _yours(TableProp.top_values(top), TableProp.top_values(_dressers_made().get("top", top))),
		"remove_off": "The table stays: everything stands on it."}]
	var layers: Array = _made.get("layers", []) if _made.get("layers") is Array else []
	for i in layers.size():
		var l: Dictionary = layers[i]
		out.append({"key": "furniture:cloth:%d" % i, "name": String(l.get("name", "a cloth")), "line": TableProp.cloth_line(l),
			"group": "furniture", "tip": String(l.get("what", "")), "verbs": [], "fields": TableProp.cloth_rows(l),
			"values": _yours(TableProp.cloth_values(l), TableProp.cloth_values(_dressers_cloth(String(l.get("name", "")), l))),
			"remove_tip": "Take this cloth off the table: the table is then yours, kept as a version."})
	return out


## What of [param now] a hand changed from [param was] (the set dresser's): those properties alone, so the rest stand dimmed at its.
static func _yours(now: Dictionary, was: Dictionary) -> Dictionary:
	var out := {}
	for k in now:
		var a: Variant = now[k]
		var b: Variant = was.get(k)
		if typeof(a) == TYPE_FLOAT and typeof(b) in [TYPE_FLOAT, TYPE_INT]:
			if not is_equal_approx(float(a), float(b)):
				out[k] = a
		elif str(a) != str(b):
			out[k] = a
	return out


## The table itself as the set dresser laid it ([method TableEpisode.dressed]), made safe with the table's materials, while a
## hand's version of the table stands; {} where it stands as the set dresser made it.
func _dressers_made() -> Dictionary:
	var ep := card._episode
	var d := ep.dressed() if ep != null else {}
	if d.is_empty():
		_dresser_key = ""
		_dresser = {}
		return _dresser
	var key := "%s|%s" % [_table_key, JSON.stringify(d)]
	if key != _dresser_key:
		_dresser_key = key
		var raw := _table.duplicate(true)
		for k in ["top", "layers"]:
			if d.get(k) == null:
				raw.erase(k)
			else:
				raw[k] = d[k]
		_dresser = CardTable.sanitize_table(raw, _look)
	return _dresser


## The set dresser's cloth named [param name] (made safe), or [param fallback] where it laid none of that name.
func _dressers_cloth(name: String, fallback: Dictionary) -> Dictionary:
	for l in (_dressers_made().get("layers", []) as Array):
		if l is Dictionary and String((l as Dictionary).get("name", "")) == name:
			return l
	return fallback


## A property of the table or a cloth on it set, as a hand's version of the table - unset (null), back to the set dresser's. ""
## written, else why not.
func _set_furniture(key: String, field: String, value: Variant) -> String:
	if value == null:
		# ...the set dresser's value of it, where the table is a hand's version of its
		var was := _dressers_made()
		if was.is_empty():
			return ""
		if key == "furniture:top":
			value = TableProp.top_values(was.get("top", {})).get(field)
		else:
			var i := int(key.get_slice(":", 2))
			var l: Dictionary = (_made.get("layers", []) as Array)[i] if i < (_made.get("layers", []) as Array).size() else {}
			value = TableProp.cloth_values(_dressers_cloth(String(l.get("name", "")), l)).get(field)
		if value == null:
			return ""
	var ep := card._episode
	if ep == null or not ep.has("table") or not (_made.get("top") is Dictionary):
		return "this episode has no table yet"
	var err := card._hand_write("table", func() -> String:
		var raw: Variant = ep.read_json("table")
		if not (raw is Dictionary):
			return "the table is not readable"
		ep.keep_dressed()
		var t: Dictionary = (raw as Dictionary).duplicate(true)
		if key == "furniture:top":
			t["top"] = TableProp.set_top(t.get("top", {}) if t.get("top") is Dictionary else {}, _made["top"], field, value)
		else:
			t["layers"] = TableProp.set_cloth(t.get("layers"), _made.get("layers", []), int(key.get_slice(":", 2)), field, value)
		return ep.write_json("table", t))
	card._after_hand("table", err)
	return err


## Cloth [param i] taken off the table, as a hand's version. "" written, else why not.
func _take_cloth(i: int) -> String:
	var ep := card._episode
	if ep == null or not ep.has("table"):
		return "this episode has no table yet"
	var err := card._hand_write("table", func() -> String:
		var raw: Variant = ep.read_json("table")
		if not (raw is Dictionary):
			return "the table is not readable"
		ep.keep_dressed()
		var t: Dictionary = (raw as Dictionary).duplicate(true)
		var ls: Array = (t["layers"] as Array).duplicate(true) if t.get("layers") is Array else (_made.get("layers", []) as Array).duplicate(true)
		if i < 0 or i >= ls.size():
			return "that cloth is not on the table"
		ls.remove_at(i)
		t["layers"] = ls
		return ep.write_json("table", t))
	card._after_hand("table", err)
	return err


## The table's Refine docked beside the Props card in its panel ([RefineDock]), or folded away where it stands open (its verb is a
## toggle): what is asked of it handed to an agent ([TableRefine]), which works on whether or not it stays open.
func _open_refine() -> String:
	if _refine != null and is_instance_valid(_refine) and RefineDock.is_open(_refine):
		_refine.fold()
		return ""
	var ep := card._episode
	if ep == null or not ep.has("table"):
		return "this episode has no table yet"
	if _refine == null or not is_instance_valid(_refine):
		_refine = PropRefine.new("table")
		card.add_child(_refine)
		_refine.asked.connect(func(direction: String, pick: Dictionary) -> void:
			var e := card._episode
			if e == null:
				_refine.say("No episode is open.")
				return
			var err := TableRefine.start(e.dir, direction, pick, _refine)
			if not err.is_empty():
				_refine.say("Not refined: %s." % err)
				return
			_refine.working(true)
			_refine.say("An agent is refining the table: starting."))
		_refine.stopped.connect(func() -> void:
			if card._episode != null:
				TableRefine.stop(card._episode.dir))
	var busy := TableRefine.busy(ep.dir)
	_refine.working(busy)
	if not busy and String(PropRefining.of(TableRefine.name_of(ep.dir)).get("state", "")) == "failed":
		_refine.say("Not refined: %s." % String(PropRefining.of(TableRefine.name_of(ep.dir))["error"]))
		PropRefining.seen(TableRefine.name_of(ep.dir))
	_refine.open_for("The table", card)
	return ""


func refines(key: String) -> bool:
	return key == "furniture:top"


func set_field(key: String, field: String, value: Variant) -> String:
	if key.begins_with("furniture:"):
		return _set_furniture(key, field, value)
	return "nothing here is tuned"


func set_on(key: String, on: bool) -> String:
	var from := "aside" if on else "things"
	var to := "things" if on else "aside"
	var name := key.substr(key.find(":") + 1)
	var err := card._hand_write("table", func() -> String: return move_thing(name, from, to))
	card._after_hand("table", err)
	return err


func remove(key: String) -> String:
	if key.begins_with("furniture:cloth:"):
		return _take_cloth(int(key.get_slice(":", 2)))
	if key == "furniture:top":
		return "the table stays: everything stands on it"
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
	if key == "furniture:top":
		match verb:
			"refine":
				return _open_refine()
			"own":
				var ep := card._episode
				var d := ep.dressed() if ep != null else {}
				if d.is_empty():
					return "the table stands as the set dresser made it"
				var err := card._hand_write("table", func() -> String:
					var raw: Variant = ep.read_json("table")
					if not (raw is Dictionary):
						return "the table is not readable"
					var t: Dictionary = (raw as Dictionary).duplicate(true)
					for k in ["top", "layers"]:
						if d.get(k) == null:
							t.erase(k)
						else:
							t[k] = d[k]
					return ep.write_json("table", t))
				card._after_hand("table", err)
				return err
		return "nothing here does that"
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
			OrnamentDesign.of(name).toggle(card)
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
	if key == "furniture:top" and card._episode != null and _made.get("top") is Dictionary:
		var ep := card._episode
		var made: Dictionary = await TableProp.made_away({"top": _made["top"], "layers": _made.get("layers", [])}, ep.seed,
			ep.file_of("image:surface") if ep.has("image:surface") else "")
		if made.is_empty():
			return {}
		return {"node": made["node"], "box": made["size"], "size": PropStudio.size_text(made["size"])}
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
	# (a table the episode no longer has - its format sets out its own things, [method TableEpisode.own_work] - is not listed)
	if ep == null or not ep.has("table") or ep.own_work():
		_table_key = ""
		_table = {}
		return _table
	var key := "%s|%s" % [ep.dir, ep.digest("table")]
	if key != _table_key:
		_table_key = key
		var raw: Variant = ep.read_json("table")
		_table = raw if raw is Dictionary else {}
		var plan: Variant = ep.read_json("plan")
		_look = (plan as Dictionary).get("look", {}) if plan is Dictionary and (plan as Dictionary).get("look") is Dictionary else {}
		_made = CardTable.sanitize_table(_table, _look) if not _table.is_empty() else {}
		_hashes = {}
		var mats: Dictionary = _table.get("materials", {}) if _table.get("materials") is Dictionary else {}
		for list in ["things", "aside"]:
			for th in (_table.get(list, []) if _table.get(list) is Array else []):
				if th is Dictionary:
					_hashes[String((th as Dictionary).get("name", ""))] = ThingLibrary.hash_of(th, mats)
	return _table
