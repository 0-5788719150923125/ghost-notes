extends PropSection
class_name StudioProps

## StudioProps - the studio's things on a note's Props card ([StudioFormat], next/studio.md "The studio's things"): an entry for each
## thing the studio works - the camera, its tripod, the ring light, the microphone, the blocks, the brush, the green screen - each a
## role ([PropMakes]) whose makes an agent designs ([RoleDesign], from the Pipeline card's rows). Choose… opens the Dex on the makes
## that can play it ([MakeShelf]: every prop kept or seen with what the studio works on it); its picture opens it in 3D, where it is
## refined into versions the studio follows ([method refined]) and kept - or placed: a refine is handed the studio it stands in
## ([method scene_of], [StudioScene]) and may move, turn and size it there, which is no version. Its entry's fields move, turn and size
## it by hand ([constant StudioSet.PLACE_FIELDS]). The choice and the place are the note's, in its Medium block (`makes`, `places`).

## The groups its rows stand under.
const GROUPS := [{"key": "studio", "label": "The studio", "tip": "What the studio works: each designed by an agent, refined and kept like any prop."}]

## Where kept and seen props, and every picture, come from.
var library := LibraryProps.new()
var _format: StudioFormat
var _specs := {}                 # "<role>|<choice key>" -> [hash, thing, materials]
var _lit: Array = []             # [method lit] as worked out for the makes in [member _lit_key]
var _lit_key := "-"


## The studio's things for the Studio format [param format] (its note's Props card).
func _init(format: StudioFormat = null) -> void:
	_format = format


func groups() -> Array:
	return GROUPS


func rows() -> Array:
	if _format == null:
		return []
	var out: Array = []
	var kept := library.kept_by_hash()
	for role in StudioSet.ROLES:
		var row: Dictionary = PropMakes.ROLES[role]
		var choice := _format.make_of(String(role))
		var sp := _spec(String(role), choice)
		var h := String(sp[0])
		var line := PackedStringArray([String(row["label"])])
		if h.is_empty():
			line.append("not designed yet: Generate on the Pipeline card designs it")
		elif not library.pictures.size_of(h).is_empty():
			line.append(library.pictures.size_of(h))
		var as_kept := String(kept.get(h, ""))
		if not as_kept.is_empty():
			line.append("in your library as %s" % as_kept)
		out.append({"key": "role:" + String(role), "name": PropMakes.name_of(String(role), choice) if not h.is_empty() else String(row["label"]),
			"line": " - ".join(line), "tip": String(row["blurb"]), "group": "studio",
			"picture": library.pictures.of(h, sp[1], sp[2]) if not h.is_empty() else null,
			"verbs": _verbs(String(role)),
			"fields": StudioSet.PLACE_FIELDS, "values": _format.place_of(String(role)),
			"remove_off": "The studio works it: Choose… another to play it, or design another on the Pipeline card."})
	return out


## A thing's buttons: Choose… another make, and - where it is moved - put back where the studio stands it.
func _verbs(role: String) -> Array:
	var out: Array = [{"key": "choose", "label": "Choose…", "opens": true,
		"tip": "Pick another to play this part, from your library. Whichever it is, the studio works it the same way."}]
	if _format.can_undo_place(role):
		out.append({"key": "undo", "label": "Undo move", "tip": "Its last move, turn or size taken back, one at a time."})
	if not _format.place_of(role).is_empty():
		out.append({"key": "home", "label": "Studio's place", "tip": "Back where the studio stands it: its move, turn and size undone."})
	return out


func act(key: String, verb: String) -> String:
	var role := _role_of(key)
	if role.is_empty() or _format == null:
		return "nothing here does that"
	if verb == "home":
		return _format.set_place(role, {}, "put back where the studio stands it")
	if verb == "undo":
		return _format.undo_place(role)
	return "nothing here does that"


## A thing moved, turned or sized here by hand: its place in this note, never a version of its prop.
func set_field(key: String, field: String, value: Variant) -> String:
	var role := _role_of(key)
	if role.is_empty() or _format == null or not StudioSet.PLACE_FIELDS.has(field):
		return "nothing here is placed"
	var place := _format.place_of(role)
	if value == null:
		place.erase(field)
	else:
		place[field] = value
	return _format.set_place(role, place, "its %s set on the Props card" % field)


## The studio a thing stands in, for a refine that may place it ([method PropSection.scene_of]): where it is, how to place it and the
## studio's other things with it (by their roles), and how it looks now - measured and pictured from the note's makes and places.
func scene_of(key: String) -> Dictionary:
	var role := _role_of(key)
	if role.is_empty() or _format == null:
		return {}
	var fmt := _format
	var roles: Array = []
	for r in StudioSet.ROLES:
		roles.append({"role": String(r), "label": String((PropMakes.ROLES[r] as Dictionary)["label"]).to_lower(), "now": fmt.place_of(String(r))})
	return {"role": role, "now": fmt.place_of(role), "fields": StudioSet.PLACE_FIELDS, "roles": roles, "needs": RoleDesign.needs_text(role),
		"lacks": func(thing: Dictionary) -> PackedStringArray: return PropMakes.missing(role, thing, true),
		"place": func(place: Dictionary) -> String: return fmt.set_place(role, place, "by a refine of the %s" % role),
		"place_role": func(other: String, place: Dictionary) -> String: return fmt.set_place(other, place, "by a refine of the %s" % role),
		"look": func(dir: String) -> Dictionary: return await StudioScene.look(fmt.make_of_all(), fmt.places_all(), role, dir)}


func choices(key: String) -> PropSection:
	var role := _role_of(key)
	if _format == null or role.is_empty():
		return null
	return MakeShelf.new(role, 1, library, func(choice: Dictionary) -> String: return _format.choose(role, choice),
		func() -> Dictionary: return _format.make_of(role))


func prop_of(key: String) -> Dictionary:
	var role := _role_of(key)
	if role.is_empty() or _format == null:
		return {}
	var choice := _format.make_of(role)
	var sp := _spec(role, choice)
	if (sp[1] as Dictionary).is_empty():
		return {}
	return {"name": PropMakes.name_of(role, choice), "thing": sp[1], "materials": sp[2], "hash": String(sp[0])}


func model_of(key: String) -> Dictionary:
	var p := prop_of(key)
	if p.is_empty():
		return {}
	return await PropStudio.model(p["thing"], p["materials"], String(p["hash"]))


## A thing's prop is said, kept, to be what the part is.
func keep_line(key: String) -> String:
	var role := _role_of(key)
	return String((PropMakes.ROLES[role] as Dictionary)["blurb"]) if PropMakes.ROLES.has(role) else ""


func versions_of() -> PropVersions:
	return library.versions_of()


## A thing refined is played by the prop kept from it, every version of which the studio then follows - where the version used still
## has what the studio works on it ([method PropMakes.fits]).
func refined(key: String, name: String) -> String:
	var role := _role_of(key)
	if _format == null or role.is_empty():
		return ""
	var e := ThingLibrary.read(name)
	if not e.is_empty() and not PropMakes.fits(role, e["thing"]):
		return "the version used lacks %s, so the studio cannot work it" % ", ".join(PropMakes.missing(role, e["thing"]))
	if _format.make_of(role) == PropMakes.chosen({"kept": name}):
		return ""
	return _format.choose(role, {"kept": name})


func want_pictures(keys: Array) -> void:
	library.pictures.want(_asked(keys))


func prepare_pictures(keys: Array) -> void:
	library.pictures.prepare(_asked(keys))


func picture(key: String) -> Variant:
	var p := prop_of(key)
	return library.pictures.image(String(p["hash"])) if not p.is_empty() else null


## The studio's things whose make throws light - the ring light's, any other with a `light` - each tuned on the Environment card by its
## role ([method Surroundings.share_of], [StudioMedium]). Worked out again only when the makes change (the Environment card asks every
## second; a kept make carries its version, [method PropMakes.chosen]).
func lit() -> Array:
	if _format == null:
		return []
	var key := str(_format.make_of_all())
	if key == _lit_key:
		return _lit
	var out: Array = []
	for role in StudioSet.ROLES:
		var sp := _spec(String(role), _format.make_of(String(role)))
		if not (sp[1] as Dictionary).is_empty() and Props.has_light(((sp[1] as Dictionary).get("parts", [])) as Array):
			out.append({"key": String(role), "name": String((PropMakes.ROLES[role] as Dictionary)["label"])})
	_lit_key = key
	_lit = out
	return out


## The pictures being taken waited for: before what holds this section goes.
func settle() -> void:
	if library != null:
		library.settle()


func _notification(what: int) -> void:
	# (its own methods cannot be called while it goes: what settle() does, done here by hand)
	if what == NOTIFICATION_PREDELETE and library != null:
		library.settle()


## The role row [param key] stands for, "" for none.
static func _role_of(key: String) -> String:
	return key.substr(5) if key.begins_with("role:") and StudioSet.ROLES.has(key.substr(5)) else ""


## Role [param role]'s make for [param choice] as written, worked out once (a kept one each time it is asked: the library may have
## changed it): `[hash, thing, materials]`.
func _spec(role: String, choice: Dictionary) -> Array:
	var key := "%s|%s" % [role, MakeShelf.key_of(choice)]
	if choice.has("kept"):
		_specs.erase(key)
	if not _specs.has(key):
		var sp := PropMakes.spec(role, choice, 1)
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
