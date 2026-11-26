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
## Above them stand the desk itself ([DispatchDesk]) and the hollow's roots ([DispatchRoots]): each a prop of properties a person sets
## or Roll draws from a number of its own, kept in the block's `desk` and `roots` (Desk's own: back to how the desk's number has it).
## Each is pictured and turned in 3D as it is built - the roots grown round the note's own desk, which stands with them for scale -
## and the desk's Choose… opens the Dex on desks drawn from many numbers ([DeskDraws]). The phones' entry carries their colors the
## same way ([constant ROLE_PARTS], [constant DispatchSet.PHONE_FIELDS]): each its own from a palette, or all the make's; the
## terminal's and the radar's carry the color their glass glows in, and the receiver's its oscilloscope's and its dial lamp's, any
## color picked ([constant DispatchSet.TERMINAL_FIELDS], [constant DispatchSet.RADAR_FIELDS], [constant DispatchSet.RECEIVER_FIELDS]);
## the security monitor's how much static shows over its picture ([constant DispatchSet.FEED_FIELDS]).
##
## A row's make is pictured from what it is written as ([PropPictures], [ThingLibrary.hash_of]), on a worker, as every prop is:
## its faces show their own materials and words, never the program the desk runs on them.

const GROUPS := [
	{"key": "desk", "label": "In the scene", "tip": "The desk, the roots and everything the desk works. Choose… another make to play a part - the desk works it the same way - or open its picture to turn it and refine it."},
]
## A role whose entry also carries properties of its own, kept as a part ([constant DispatchFormat.PARTS]): the phones' colors, the
## terminal's and the radar's glass, the receiver's glows, the security monitor's static.
const ROLE_PARTS := {"phone": "phones", "terminal": "terminal_screen", "radar": "radar_screen", "receiver": "receiver_glow",
	"feed": "feed_screen"}
const SHELVES := [{"key": "dispatch", "label": "Dispatch desk", "tip": "What the Dispatch desk works, each as the first desk draws it."}]
const OFF_SHELF := [{"key": "taken_off", "label": "Taken off", "tip": "What was taken off this desk: Use sets it out again."}]

## Where the kept and seen props, and every picture, come from.
var library := LibraryProps.new()
var _format: DispatchFormat
var _specs := {}                 # "<role>|<choice key>|<seed>" -> [hash, thing, materials]
var _lit_key := ""               # what [method lit] was last worked out for, and what it found
var _lit: Array = []
var _grown_hash := ""            # the roots last grown ([method _roots_grown]), kept to hand out copies of
var _grown: Node3D = null
var _grown_box := AABB()


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
	var out: Array = _part_rows()
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
		# kept from its 3D view (the picture opens it): the row says where it is
		if not as_kept.is_empty():
			line.append("in your library as %s" % as_kept)
		var row := {"key": "role:" + String(role), "name": PropMakes.name_of(String(role), choice), "line": " - ".join(line),
			"tip": String((PropMakes.ROLES[role] as Dictionary)["blurb"]), "group": "desk",
			"picture": library.pictures.of(h, sp[1], sp[2]) if not h.is_empty() else null, "verbs": verbs}
		if ROLE_PARTS.has(role):
			var part := String(ROLE_PARTS[role])
			var spec := _format.part(part)
			row["fields"] = Roll.shown_for(DispatchFormat.PARTS[part], spec)
			row["values"] = _set_of(spec)
			verbs.insert(1, {"key": "roll", "label": "Roll", "tip": "Every property you have not set drawn again."})
			if choice.is_empty() and not spec.is_empty():
				verbs.insert(2, {"key": "own", "label": "Desk's own", "tip": "Back to the desk's own, every property and all."})
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
			"picture": library.pictures.image(String(sp[0]))})
	return out


func act(key: String, verb: String) -> String:
	var part := _part_of(key)
	if not part.is_empty() and _format != null:
		match verb:
			"roll":
				var spec := _format.part(part)
				var was := int(spec.get("seed", -1))
				spec["seed"] = Roll.fresh()
				while int(spec["seed"]) == was:
					spec["seed"] = Roll.fresh()
				return _format.set_part(part, spec)
			"own":
				return _format.set_part(part, {})
		return "nothing here does that"
	var role := _role_of(key)
	if role.is_empty():
		return "nothing here does that"
	if ROLE_PARTS.has(role) and _format != null and verb in ["roll", "own"]:
		var part_of := String(ROLE_PARTS[role])
		if verb == "roll":
			var spec := _format.part(part_of)
			var was := int(spec.get("seed", -1))
			spec["seed"] = Roll.fresh()
			while int(spec["seed"]) == was:
				spec["seed"] = Roll.fresh()
			return _format.set_part(part_of, spec)
		var undone := _format.set_part(part_of, {})
		return undone if not undone.is_empty() else _format.choose(role, {})
	match verb:
		"own":
			return _format.choose(role, {}) if _format != null else "nothing here takes it"
	return "nothing here does that"


func set_field(key: String, field: String, value: Variant) -> String:
	var part := _part_of(key)
	if part.is_empty():
		part = String(ROLE_PARTS.get(_role_of(key), ""))
	if part.is_empty() or _format == null:
		return "nothing here is tuned"
	var spec := _format.part(part)
	if value == null:
		spec.erase(field)
	else:
		spec[field] = value
	return _format.set_part(part, spec)


func choices(key: String) -> PropSection:
	if key == "part:desk" and _format != null:
		return DeskDraws.new(self)
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
	if key == "part:roots" and _format != null:
		var grown: Dictionary = await _roots_grown([_format.phones(), _desk_seed(), _format.wants(), _makes()])
		if grown.is_empty():
			return {}
		return {"node": grown["node"], "box": grown["size"], "size": PropStudio.size_text(grown["size"])}
	if key == "part:desk" and _format != null:
		var spec := _format.part("desk")
		var made: Dictionary = await desk_away(DispatchDesk.values_of(spec), _part_seed(spec))
		if made.is_empty():
			return {}
		return {"node": made["node"], "box": made["size"], "size": PropStudio.size_text(made["size"])}
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


## A part's prop is said, kept, to be what the part is.
func keep_line(key: String) -> String:
	var role := _role_of(key)
	return String((PropMakes.ROLES[role] as Dictionary)["blurb"]) if PropMakes.ROLES.has(role) else ""


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
	if what == NOTIFICATION_PREDELETE and _grown != null and is_instance_valid(_grown):
		_grown.free()


# --- the desk and its roots ------------------------------------------------------------------------------------------------

## The desk's and the roots' entries, as the block keeps them.
func _part_rows() -> Array:
	var desk := _format.part("desk")
	var dv := DispatchDesk.values_of(desk)
	var dseed := _part_seed(desk)
	var h := part_hash(dv, dseed)
	var desk_verbs: Array = [{"key": "choose", "label": "Choose…", "opens": true, "tip": "Pick another desk from many drawn, each pictured."},
		{"key": "roll", "label": "Roll", "tip": "Another desk: every property you have not set drawn again."}]
	var roots := _format.part("roots")
	var rv := DispatchRoots.values_of(roots)
	var grow := [_format.phones(), _desk_seed(), _format.wants(), _makes()]
	var root_verbs: Array = [{"key": "roll", "label": "Roll", "tip": "Other roots: grown anew, every property you have not set drawn again."}]
	if not desk.is_empty():
		desk_verbs.append({"key": "own", "label": "Desk's own", "tip": "Back to the desk the hollow has always had."})
	if not roots.is_empty():
		root_verbs.append({"key": "own", "label": "Desk's own", "tip": "Back to the roots the desk's number grows."})
	return [
		{"key": "part:desk", "name": "The desk", "line": DispatchDesk.line_of(dv), "group": "desk",
			"tip": "The desk everything stands on: its wood, its top, its pad and what holds it up.",
			"picture": library.pictures.of_made(h, func() -> Dictionary: return await desk_away(dv, dseed)),
			"verbs": desk_verbs, "fields": Roll.shown_for(DispatchDesk.FIELDS, desk), "values": _set_of(desk),
			"remove_off": "The desk stays: everything stands on it."},
		{"key": "part:roots", "name": "The roots", "line": DispatchRoots.line_of(rv), "group": "desk",
			"tip": "The roots crawling down from the hollow's ceiling, beside the desk and across it.",
			"picture": library.pictures.of_made(roots_hash(grow), func() -> Dictionary: return await _roots_grown(grow)),
			"verbs": root_verbs, "fields": Roll.shown_for(DispatchRoots.FIELDS, roots), "values": _set_of(roots),
			"remove_off": "Set how many hang, cross the desk and stand beside it to 0 for none."},
	]


## The part row [param key] stands for (`desk`, `roots`), "" for none.
static func _part_of(key: String) -> String:
	return key.substr(5) if key in ["part:desk", "part:roots"] else ""


## The number part [param spec] is drawn from: its own where it was rolled, else the desk's.
func _part_seed(spec: Dictionary) -> int:
	return int(spec["seed"]) if typeof(spec.get("seed")) in [TYPE_INT, TYPE_FLOAT] else _desk_seed()


## What part [param spec] sets of its fields: the spec without its number.
static func _set_of(spec: Dictionary) -> Dictionary:
	var out := spec.duplicate()
	out.erase("seed")
	return out


## What a desk of [param v] drawn from [param seed] is, as a short hash: its picture's name.
static func part_hash(v: Dictionary, seed: int) -> String:
	return ("dispatch desk " + JSON.stringify([v, seed], "", true)).sha256_text().left(16)


## The desk of [param v] drawn from [param seed] built alone on a worker ([method DispatchDesk.made]): `{node, size}`.
static func desk_away(v: Dictionary, seed: int) -> Dictionary:
	var out := [{}]
	var task := WorkerThreadPool.add_task(func() -> void: out[0] = DispatchDesk.made(v, seed), false, "a desk pictured")
	var tree := Engine.get_main_loop() as SceneTree
	while not WorkerThreadPool.is_task_completed(task):
		await tree.process_frame
	WorkerThreadPool.wait_for_task_completion(task)
	return out[0]


## The roots of a desk of [param grow] ([method roots_away]), grown once for as long as nothing changes them: a copy each time
## asked (its picture, its 3D view), `{node, size}`.
func _roots_grown(grow: Array) -> Dictionary:
	var h := roots_hash(grow)
	if h != _grown_hash or _grown == null or not is_instance_valid(_grown):
		var made: Dictionary = await roots_away(grow[0], grow[1], grow[2], grow[3])
		if made.is_empty():
			return {}
		if _grown != null and is_instance_valid(_grown):
			_grown.free()
		_grown = made["node"]
		_grown_box = made["size"]
		_grown_hash = h
	return {"node": _grown.duplicate(), "size": _grown_box}


## The makes the note's desk is built with, as the medium reads them ([method DispatchMedium.makes_of]).
func _makes() -> Dictionary:
	return DispatchMedium.makes_of({"things": _format.things(), "desk": _format.part("desk"), "roots": _format.part("roots"),
		"phones": _format.part("phones")})


## What the roots grown round a desk of [param grow] (`[labels, seed, wants, makes]`, [method roots_away]) are, as a short hash: their
## picture's name.
static func roots_hash(grow: Array) -> String:
	return ("dispatch roots " + JSON.stringify([Array(grow[0]), grow[1], (grow[2] as Dictionary).keys(), grow[3]], "", true)).sha256_text().left(16)


## The roots of the desk built from [param labels] (the phones), [param seed], [param wants] and [param makes], grown on a worker as
## the medium grows them (round the set, which is then let go), the desk standing with them for scale: `{node, size}` (the roots' box).
static func roots_away(labels: PackedStringArray, seed: int, wants: Dictionary, makes: Dictionary) -> Dictionary:
	var out := [{}]
	var task := WorkerThreadPool.add_task(func() -> void: out[0] = _roots_made(labels, seed, wants, makes), false, "the roots pictured")
	var tree := Engine.get_main_loop() as SceneTree
	while not WorkerThreadPool.is_task_completed(task):
		await tree.process_frame
	WorkerThreadPool.wait_for_task_completion(task)
	return out[0]


static func _roots_made(labels: PackedStringArray, seed: int, wants: Dictionary, makes: Dictionary) -> Dictionary:
	var s := DispatchSet.new()
	s.makes = makes
	s.desk = makes.get("desk", {})
	var set_node := s.build(labels, seed, {}, wants)
	var r := DispatchRoots.new()
	var grown := r.build(seed, s.footprints, s.held_rect(), s.clear, makes.get("roots", {}))
	set_node.free()
	var box := _bounds(grown, grown.transform, AABB())
	if not box.has_volume():
		grown.free()
		return {}
	var node := Node3D.new()
	node.add_child(grown)
	var desk: Dictionary = makes.get("desk", {})
	var own := typeof(desk.get("seed")) in [TYPE_INT, TYPE_FLOAT]
	node.add_child(DispatchDesk.build(DispatchDesk.values_of(desk), int(desk["seed"]) if own else seed))
	return {"node": node, "size": box}


## The box every mesh under [param n] fills, [param xf] its place, merged into [param box].
static func _bounds(n: Node, xf: Transform3D, box: AABB) -> AABB:
	var mi := n as MeshInstance3D
	if mi != null and mi.mesh != null:
		var b := xf * mi.mesh.get_aabb()
		box = b if not box.has_volume() else box.merge(b)
	for c in n.get_children():
		var c3 := c as Node3D
		if c3 != null:
			box = _bounds(c3, xf * c3.transform, box)
	return box


## Desks drawn from many numbers, on the Dex ([DispatchDesk]): the desk's own first, then [constant DRAWS] others, each pictured as it
## is built; Use keeps the one picked as the desk. The one in use says so.
class DeskDraws extends PropSection:
	const DRAWS := 23
	var owner: DispatchProps

	func _init(o: DispatchProps) -> void:
		owner = o

	func title() -> String:
		return "The desk"

	func turns() -> bool:
		return true

	func file_kind() -> Dictionary:
		return {}

	func shelves() -> Array:
		return [{"key": "desks", "label": "Desks", "tip": "The desk's own, and desks drawn from other numbers."}]

	## Each offer's number: -1 the desk's own, else a draw.
	func _seeds() -> Array:
		var out: Array = [-1]
		for i in DRAWS:
			out.append(absi(hash([owner._desk_seed(), "desk draw", i])) % 1000000)
		return out

	func offers() -> Array:
		var now := owner._format.part("desk") if owner._format != null else {}
		var out: Array = []
		for sd in _seeds():
			var spec := {} if int(sd) < 0 else {"seed": int(sd)}
			var v := DispatchDesk.values_of(spec)
			var seed := owner._part_seed(spec)
			var in_use := now == spec
			out.append({"key": "desk:%d" % int(sd), "name": "The desk's own" if int(sd) < 0 else "Desk no. %d" % int(sd),
				"line": DispatchDesk.line_of(v), "shelf": "desks", "tip": DispatchDesk.line_of(v),
				"picture": owner.library.pictures.of_made(DispatchProps.part_hash(v, seed), func() -> Dictionary: return await DispatchProps.desk_away(v, seed)),
				"verbs": [{"key": "now", "label": "In use", "off": true, "tip": "The desk in use."}] if in_use else []})
		return out

	func picture(key: String) -> Variant:
		for o in offers():
			if String((o as Dictionary)["key"]) == key:
				return (o as Dictionary)["picture"]
		return null

	func model_of(key: String) -> Dictionary:
		var sd := int(key.substr(5)) if key.begins_with("desk:") else -1
		var spec := {} if sd < 0 else {"seed": sd}
		var made: Dictionary = await DispatchProps.desk_away(DispatchDesk.values_of(spec), owner._part_seed(spec))
		return {} if made.is_empty() else {"node": made["node"], "box": made["size"], "size": PropStudio.size_text(made["size"])}

	func adds() -> Dictionary:
		return {"label": "Use", "verb": "Use", "tip": "Use it as the desk."}

	func add(key: String) -> String:
		if not key.begins_with("desk:") or owner._format == null:
			return "there is no such desk"
		var sd := int(key.substr(5))
		return owner._format.set_part("desk", {} if sd < 0 else {"seed": sd})


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
