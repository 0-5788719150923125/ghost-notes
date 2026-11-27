extends PropSection
class_name MakeShelf

## MakeShelf - the makes that may play one role on the Dex ([PropMakes]): the role's own (its recipe drawn from many numbers, or the
## prop it is shipped as), and every prop kept or seen ([LibraryProps]) that has the faces the scene shows something on, the Dex first
## filtered by the role's words. Use hands the one picked to the scene, which keeps the choice; a seen prop is held as a draft first,
## so the choice can name it - kept only by a person's Keep in the 3D view. The one chosen now says so.

const SHELVES := [
	{"key": "drawn", "label": "Its own", "tip": "The part's own make: its recipe drawn from many numbers, or the one the scene comes with."},
	{"key": "kept_makes", "label": "Kept props", "tip": "The props in your library: any can play the part, made the size it wants."},
	{"key": "seen_makes", "label": "Seen props", "tip": "Every prop a set dresser has made: any can play the part. Keep one in its 3D view to have it in your library."},
]

## The role chosen for ([constant PropMakes.ROLES]).
var role: String
## Where the kept and seen props, and every picture, come from.
var library: LibraryProps
var _seed: int
var _chosen: Callable            # (choice: Dictionary) -> String: "" done, else why not
var _current: Callable           # () -> Dictionary: the choice as it stands
var _drawn := {}                 # draw key -> [hash, thing, materials]


## The makes of [param r] for a scene whose own number for it is [param seed], from [param lib]: [param chosen] takes the one
## picked, [param current] says the one chosen now.
func _init(r: String, seed: int, lib: LibraryProps, chosen: Callable, current: Callable) -> void:
	role = r
	_seed = seed
	library = lib
	_chosen = chosen
	_current = current


func title() -> String:
	return String((PropMakes.ROLES.get(role, {}) as Dictionary).get("label", role))


func find() -> String:
	return String((PropMakes.ROLES.get(role, {}) as Dictionary).get("find", ""))


func file_kind() -> Dictionary:
	return {}


func shelves() -> Array:
	return SHELVES


func offers() -> Array:
	var now := key_of(_current.call() as Dictionary)
	var out: Array = []
	var tip := String((PropMakes.ROLES.get(role, {}) as Dictionary).get("blurb", ""))
	for k in _draw_keys():
		var d := _draw(String(k))
		out.append({"key": k, "name": PropMakes.name_of(role, choice_of(String(k))), "line": library.pictures.size_of(String(d[0])),
			"shelf": "drawn", "tip": tip, "picture": library.pictures.image(String(d[0])), "verbs": _now(now == k)})
	var held := library.held_by_hash()
	for o in library.offers():
		var od: Dictionary = o
		var shelf := String(od["shelf"])
		if shelf != "kept" and shelf != "seen":
			continue
		# a make the scene could not work - its faces, its named parts and points - is never offered
		var row: Dictionary = PropMakes.ROLES.get(role, {})
		if not ((row.get("faces", []) as Array).is_empty() and (row.get("needs", {}) as Dictionary).is_empty()) \
				and not PropMakes.fits(role, library.prop_of(String(od["key"])).get("thing", {})):
			continue
		var as_kept := String(od["key"]).substr(5) if shelf == "kept" else String(held.get(String(library.prop_of(String(od["key"])).get("hash", "")), ""))
		var m := od.duplicate()
		m["shelf"] = "kept_makes" if shelf == "kept" else "seen_makes"
		m["named"] = false
		m["verbs"] = _now(not as_kept.is_empty() and now == "kept:" + as_kept)
		out.append(m)
	return out


func adds() -> Dictionary:
	var noun := title().to_lower()
	return {"label": "Use", "verb": "Use", "tip": "Use it as %s here." % noun}


func add(key: String) -> String:
	if key.begins_with("seen:"):
		var p := library.prop_of(key)
		if p.is_empty():
			return "that prop is gone"
		# a seen one plays the part as a draft: chosen is not kept, which is a person's Keep in the 3D view
		var name := String(library.held_by_hash().get(String(p["hash"]), ""))
		if name.is_empty():
			var err := library.keep(p["thing"], p["materials"], "", true)
			if not err.is_empty():
				return err
			name = String(library.held_by_hash().get(String(p["hash"]), ""))
		if name.is_empty():
			return "it could not be held"
		return _chosen.call({"kept": name})
	if not key.begins_with("kept:") and not _drawn.has(key) and not _draw_keys().has(key):
		return "nothing here is called that"
	return _chosen.call(choice_of(key))


func prop_of(key: String) -> Dictionary:
	if key == "own" or key.begins_with("draw:"):
		var d := _draw(key)
		if (d[1] as Dictionary).is_empty():
			return {}
		return {"name": PropMakes.name_of(role, choice_of(key)), "thing": d[1], "materials": d[2], "hash": String(d[0])}
	return library.prop_of(key)


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


## The choice offer [param key] stands for: the scene's own, a draw of the role's recipe, or a kept prop.
func choice_of(key: String) -> Dictionary:
	if key.begins_with("draw:"):
		return {"recipe": String((PropMakes.ROLES.get(role, {}) as Dictionary).get("recipe", role)), "seed": int(key.substr(5))}
	if key.begins_with("kept:"):
		return {"kept": key.substr(5)}
	return {}


## The offer that stands for [param choice] ([method choice_of] the other way).
static func key_of(choice: Dictionary) -> String:
	if choice.has("kept"):
		return "kept:" + String(choice["kept"])
	if choice.has("recipe"):
		return "draw:%d" % int(choice.get("seed", 0))
	return "own"


func _draw_keys() -> Array:
	# (a role whose makes are all designed has no own to offer)
	var out: Array = [] if bool((PropMakes.ROLES.get(role, {}) as Dictionary).get("designed", false)) and PropMakes.own_of(role).is_empty() else ["own"]
	if PropMakes.drawn(role):
		for n in PropMakes.DRAWS:
			out.append("draw:%d" % (n + 1))
	return out


## Draw [param key] as written, worked out once: `[hash, thing, materials]`.
func _draw(key: String) -> Array:
	if not _drawn.has(key):
		var sp := PropMakes.spec(role, choice_of(key), _seed)
		var thing: Dictionary = sp.get("thing", {})
		var mats: Dictionary = sp.get("materials", {})
		_drawn[key] = [ThingLibrary.hash_of(thing, mats) if not thing.is_empty() else "", thing, mats]
	return _drawn[key]


func _asked(keys: Array) -> Array:
	var out: Array = []
	for k in keys:
		var p := prop_of(String(k))
		if not p.is_empty():
			out.append([String(p["hash"]), p["thing"], p["materials"]])
	return out


## The verbs of an offer: the one chosen now says so.
static func _now(chosen: bool) -> Array:
	return [{"key": "chosen", "label": "Chosen", "off": true, "tip": "Chosen now."}] if chosen else []
