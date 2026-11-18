extends PropSection
class_name DispatchProps

## DispatchProps - the Dispatch desk's things as props ([DispatchSet], next/working_props.md): on a note's Props card, an entry for
## every thing the desk works - the terminal, the phones, the radar, the mug... - each a role any make can play ([PropMakes]):
## Choose… opens the Dex on its makes ([MakeShelf]), Desk's own puts the desk's back, Keep puts the one on the desk in the library,
## and its picture opens it in 3D, where it is refined into versions the desk follows ([method refined]). A spare thing's × takes it
## off the desk ([constant DispatchSet.SPARE], unless the script works it); "+ Add a prop" opens the Dex on what was taken off, Use
## setting it out again. Every other thing's × stands grayed: the desk works it. Opened with no note (the Dex on its own), it is a
## shelf of them all as the first desk draws them, to look at in 3D and keep.
##
## A row's make is pictured from what it is written as ([PropPictures], [ThingLibrary.hash_of]), on a worker, as every prop is:
## its faces show their own materials and words, never the program the desk runs on them.

const GROUPS := [
	{"key": "desk", "label": "On the desk", "tip": "What the desk works. Choose… another make to play a part - the desk works it the same way - or open its picture to turn it and refine it."},
]
const SHELVES := [{"key": "dispatch", "label": "Dispatch desk", "tip": "What the Dispatch desk works, each as the first desk draws it."}]
const OFF_SHELF := [{"key": "taken_off", "label": "Taken off", "tip": "What was taken off this desk: Use sets it out again."}]

## Where the kept and seen props, and every picture, come from.
var library := LibraryProps.new()
var _format: DispatchFormat
var _specs := {}                 # "<role>|<choice key>|<seed>" -> [hash, thing, materials]
var _lit_key := ""               # what [method lit] was last worked out for, and what it found
var _lit: Array = []


## The desk's things for the Dispatch format [param format] (its note's Props card), or with none, the shelf of them all.
func _init(format: DispatchFormat = null) -> void:
	_format = format


func groups() -> Array:
	return GROUPS


func shelves() -> Array:
	return SHELVES if _format == null else OFF_SHELF


func rows() -> Array:
	if _format == null:
		return []
	var out: Array = []
	var seed := _desk_seed()
	var kept := library.kept_by_hash()
	for role in _roles():
		var choice := _choice(String(role))
		if choice.has("aside"):
			continue
		var sp := _spec(String(role), choice, seed)
		var h := String(sp[0])
		var as_kept := String(kept.get(h, ""))
		var line := PackedStringArray([String((PropMakes.ROLES[role] as Dictionary)["label"])])
		if not library.pictures.size_of(h).is_empty():
			line.append(library.pictures.size_of(h))
		var verbs: Array = [{"key": "choose", "label": "Choose…", "opens": true,
			"tip": "Pick another to play this part, from your library or the desk's own. Whichever it is, the desk works it the same way."}]
		if not choice.is_empty():
			verbs.append({"key": "own", "label": "Desk's own", "tip": "Back to the desk's own."})
		verbs.append({"key": "keep", "label": "Kept" if not as_kept.is_empty() else "Keep", "off": not as_kept.is_empty(),
			"tip": ("In your library as %s." % as_kept) if not as_kept.is_empty() else "Keep it in your library, to use on any scene."})
		var row := {"key": "role:" + String(role), "name": PropMakes.name_of(String(role), choice), "line": " - ".join(line),
			"tip": String((PropMakes.ROLES[role] as Dictionary)["blurb"]), "group": "desk",
			"picture": library.pictures.of(h, sp[1], sp[2]) if not h.is_empty() else null, "verbs": verbs}
		if not String(role) in DispatchSet.SPARE:
			row["remove_off"] = "The desk works it: Choose… another make to play it."
		elif _format.works().has(role):
			row["remove_off"] = "The script works it: it stays on the desk while the script does."
		else:
			row["remove_tip"] = "Take it off the desk. \"+ Add a prop\" sets it out again."
		out.append(row)
	return out


func remove(key: String) -> String:
	var role := _role_of(key)
	if _format == null or not role in DispatchSet.SPARE:
		return "the desk works it: it cannot be taken off"
	if _format.works().has(role):
		return "the script works it: it stays on the desk while the script does"
	return _format.choose(role, {"aside": true})


func adds() -> Dictionary:
	if _format == null or not _roles().any(func(r: String) -> bool: return _choice(r).has("aside")):
		return {}
	return {"label": "+ Add a prop", "verb": "Use", "tip": "Set it out on the desk again."}


func add(key: String) -> String:
	var role := _role_of(key)
	if _format == null or role.is_empty():
		return "nothing here takes it"
	return _format.choose(role, {})


func offers() -> Array:
	var out: Array = []
	if _format != null:
		# what was taken off this desk, each as its own make
		for role in _roles():
			if not _choice(String(role)).has("aside"):
				continue
			var sp := _spec(String(role), {}, _desk_seed())
			out.append({"key": "role:" + String(role), "name": String((PropMakes.ROLES[role] as Dictionary)["label"]),
				"line": library.pictures.size_of(String(sp[0])), "shelf": "taken_off", "tip": String((PropMakes.ROLES[role] as Dictionary)["blurb"]),
				"picture": library.pictures.image(String(sp[0]))})
		return out
	for role in _roles():
		var sp := _spec(String(role), {}, _desk_seed())
		out.append({"key": "role:" + String(role), "name": String((PropMakes.ROLES[role] as Dictionary)["label"]),
			"line": library.pictures.size_of(String(sp[0])), "shelf": "dispatch", "tip": String((PropMakes.ROLES[role] as Dictionary)["blurb"]),
			"picture": library.pictures.image(String(sp[0])),
			"verbs": [{"key": "keep", "label": "Keep", "tip": "Keep it in your library, to use on any scene."}]})
	return out


func act(key: String, verb: String) -> String:
	var role := _role_of(key)
	if role.is_empty():
		return "nothing here does that"
	match verb:
		"keep":
			var p := prop_of(key)
			if p.is_empty():
				return "there is nothing to keep"
			return library.keep(p["thing"], p["materials"], String((PropMakes.ROLES[role] as Dictionary)["blurb"]))
		"own":
			return _format.choose(role, {}) if _format != null else "nothing here takes it"
	return "nothing here does that"


func choices(key: String) -> PropSection:
	var role := _role_of(key)
	if _format == null or role.is_empty():
		return null
	return MakeShelf.new(role, DispatchSet.own_seed(role, _desk_seed()), library, func(choice: Dictionary) -> String: return _format.choose(role, choice),
		func() -> Dictionary: return _choice(role))


func prop_of(key: String) -> Dictionary:
	var role := _role_of(key)
	if role.is_empty():
		return {}
	var choice := _choice(role)
	var sp := _spec(role, choice, _desk_seed())
	if (sp[1] as Dictionary).is_empty():
		return {}
	return {"name": PropMakes.name_of(role, choice), "thing": sp[1], "materials": sp[2], "hash": String(sp[0])}


func model_of(key: String) -> Dictionary:
	var p := prop_of(key)
	if p.is_empty():
		return {}
	return await PropStudio.model(p["thing"], p["materials"], String(p["hash"]))


## The desk's things whose make throws light - its lamp, its screens - each by its role ([DispatchMedium] reads their shares).
## Worked out again only when the desk's makes or number change (the Environment card asks every second; a kept make is read
## from the library).
func lit() -> Array:
	var key := "%d|%s|%s" % [_desk_seed(), str(_format.things() if _format != null else {}), str(_roles())]
	if key == _lit_key:
		return _lit
	var out: Array = []
	for role in _roles():
		if _choice(String(role)).has("aside"):
			continue
		var p := prop_of("role:" + String(role))
		if not p.is_empty() and Props.has_light((p["thing"] as Dictionary).get("parts", [])):
			out.append({"key": String(role), "name": String((PropMakes.ROLES[role] as Dictionary)["label"])})
	_lit_key = key
	_lit = out
	return out


## The desk's things that make a sound of their own: the receiver, its hiss and storms ([DispatchSounds]).
func heard() -> Array:
	return [{"key": "receiver", "name": String((PropMakes.ROLES["receiver"] as Dictionary)["label"])}] if _format != null else []


func versions_of() -> PropVersions:
	return library.versions_of()


## A part refined is played by the prop kept from it, every version of which the desk then follows - where the version used still
## has the faces the desk shows its pictures on ([method PropMakes.fits]).
func refined(key: String, name: String) -> String:
	var role := _role_of(key)
	if _format == null or role.is_empty():
		return ""
	var e := ThingLibrary.read(name)
	if not e.is_empty() and not PropMakes.fits(role, e["thing"]):
		return "the version used has no %s, so the desk's own plays it" % ", ".join(PackedStringArray((PropMakes.ROLES[role] as Dictionary)["faces"]))
	if _choice(role) == {"kept": name}:
		return ""
	return _format.choose(role, {"kept": name})


func want_pictures(keys: Array) -> void:
	library.pictures.want(_asked(keys))


func prepare_pictures(keys: Array) -> void:
	library.pictures.prepare(_asked(keys))


func picture(key: String) -> Variant:
	var p := prop_of(key)
	return library.pictures.image(String(p["hash"])) if not p.is_empty() else null


## The pictures being taken waited for: before what holds this section goes.
func settle() -> void:
	if library != null:
		library.settle()


func _notification(what: int) -> void:
	# (its own methods cannot be called while it goes: what settle() does, done here by hand)
	if what == NOTIFICATION_PREDELETE and library != null:
		library.settle()


# --- the roles -----------------------------------------------------------------------------------------------------------

## The desk's roles shown ([constant DispatchSet.MAKE_SALTS]): the clock and the tablet only where the note's script uses them, or
## on the shelf.
func _roles() -> Array:
	var out: Array = []
	var wants := _format.wants() if _format != null else {"clock": true, "tablet": true}
	for role in DispatchSet.MAKE_SALTS:
		if String(role) in ["clock", "tablet"] and not wants.has(role):
			continue
		out.append(role)
	return out


## The role row or offer [param key] stands for, "" for none.
static func _role_of(key: String) -> String:
	if not key.begins_with("role:") or not DispatchSet.MAKE_SALTS.has(key.substr(5)):
		return ""
	return key.substr(5)


## Role [param role]'s own number on the desk of [param seed]: the make the desk draws when none is chosen.
static func own_seed(role: String, seed: int) -> int:
	return DispatchSet.own_seed(role, seed)


func _choice(role: String) -> Dictionary:
	var c: Variant = _format.things().get(role, {}) if _format != null else {}
	return c if PropMakes.valid(c) else {}


func _desk_seed() -> int:
	return _format.desk_seed() if _format != null else 1


## Role [param role]'s make for [param choice] on the desk of [param seed] as written, worked out once (a kept one each time it
## is asked: the library may have changed it): `[hash, thing, materials]`.
func _spec(role: String, choice: Dictionary, seed: int) -> Array:
	var key := "%s|%s|%d" % [role, MakeShelf.key_of(choice), seed]
	if choice.has("kept"):
		_specs.erase(key)
	if not _specs.has(key):
		var sp := PropMakes.spec(role, choice, DispatchSet.own_seed(role, seed))
		var thing: Dictionary = sp.get("thing", {})
		var mats: Dictionary = sp.get("materials", {})
		_specs[key] = [ThingLibrary.hash_of(thing, mats) if not thing.is_empty() else "", thing, mats]
	return _specs[key]


func _asked(keys: Array) -> Array:
	var out: Array = []
	for k in keys:
		var p := prop_of(String(k))
		if not p.is_empty():
			out.append([String(p["hash"]), p["thing"], p["materials"]])
	return out
