extends PropSection
class_name DispatchProps

## DispatchProps - the Dispatch desk's things as props ([DispatchSet], next/library.md "Roles"): on a note's Props card, the parts
## that may be chosen - the mug and the cup of pencils, each played by any make ([PropMakes]): Choose… opens the Dex on them
## ([MakeShelf]), Keep puts the one on the desk in the library - and the things the desk builds for what the script works (the
## terminal, the phones, the radar, the screens...), pictured as built. Opened with no note (the Dex on its own), it is a shelf of
## them all, the parts drawn at the first desk's number, to look at in 3D and keep.
##
## What is built is built once, from the note's phones and the desk's number: off the tree on a worker, its faces drawn by a
## [DispatchScreens] of its own, each thing pictured alone at its own turn ([method _made_of]) and kept by a hash of what it is
## built of ([method content_hash]), so a change to how one is built pictures it again. A process that takes no pictures builds none.

## What the desk builds for the script to work: each where its node is in [DispatchSet] (`things` by its key unless `from` says
## `phone` or `chair`) and what it is.
const BUILT := {
	"terminal": {"label": "The terminal", "blurb": "A deep beige CRT on a flat desktop case with a floppy slot."},
	"keyboard": {"label": "The keyboard", "blurb": "A narrow keyboard on a coiled cable, its keys dished."},
	"phone": {"label": "A flip phone", "blurb": "One of the desk's flip phones, its name on masking tape.", "from": "phone"},
	"radar": {"label": "The radar", "blurb": "The round green radar scope and its gain knob."},
	"receiver": {"label": "The receiver", "blurb": "The shortwave receiver: its dial, needle meter, speaker and the small oscilloscope on it."},
	"printer": {"label": "The printer", "blurb": "A dot-matrix printer that feeds its paper off the desk's end."},
	"feed": {"label": "The security monitor", "blurb": "A little black-and-white monitor."},
	"satellite": {"label": "The satellite's monitor", "blurb": "A flat monitor that looks down from orbit."},
	"tv": {"label": "The television", "blurb": "A small old television with rabbit ears."},
	"lamp": {"label": "The lamp", "blurb": "A gooseneck desk lamp, its shade bent over the keyboard."},
	"switch": {"label": "The switch box", "blurb": "GOOD above, BAD below, its toggle between."},
	"handbook": {"label": "The handbook", "blurb": "A fat binder, its spine labeled."},
	"stamp": {"label": "The rubber stamp", "blurb": "A rubber stamp beside its pad."},
	"tracker": {"label": "The GPS tracker", "blurb": "A small black tracker, its light blinking green."},
	"chart": {"label": "The chart", "blurb": "A chart taped down to the desk."},
	"clock": {"label": "The flip clock", "blurb": "A small flip clock, for a script that tells the hour."},
	"tablet": {"label": "The tablet", "blurb": "A tablet lying dark, for a script that reads one."},
	"chair": {"label": "The chair", "blurb": "The empty office chair the viewer sits in.", "from": "chair"},
}
const GROUPS := [
	{"key": "chosen", "label": "Swappable", "tip": "Parts any make can play: Choose… to pick another, from many drawn or from your library."},
	{"key": "built", "label": "Built for the desk", "tip": "What the desk builds for the script to work: the same on every desk."},
]
const SHELVES := [{"key": "dispatch", "label": "Dispatch desk", "tip": "What the Dispatch desk builds, and the parts any make can play there, as the first desk draws them."}]

## Where the kept and seen props, and every picture, come from.
var library := LibraryProps.new()
var _format: DispatchFormat
var _specs := {}                 # "<role>|<choice key>|<seed>" -> [hash, thing, materials]
var _screens: DispatchScreens = null
var _set: DispatchSet = null
var _set_task := -1
var _set_box: Array = [null]
var _hashes := {}                # a built thing -> its content hash, once built
var _set_labels := PackedStringArray()   # the phones' names the desk was built with


## The desk's things for the Dispatch format [param format] (its note's Props card), or with none, the shelf of them all.
func _init(format: DispatchFormat = null) -> void:
	_format = format


func groups() -> Array:
	return GROUPS


func shelves() -> Array:
	return SHELVES


func rows() -> Array:
	if _format == null:
		return []
	var out: Array = []
	var seed := _desk_seed()
	var kept := library.kept_by_hash()
	for role in DispatchSet.MAKE_SALTS:
		var choice := _choice(String(role))
		var sp := _spec(String(role), choice, seed)
		var h := String(sp[0])
		var as_kept := String(kept.get(h, ""))
		var line := PackedStringArray([String((PropMakes.ROLES[role] as Dictionary)["label"])])
		if not library.pictures.size_of(h).is_empty():
			line.append(library.pictures.size_of(h))
		var verbs: Array = [{"key": "choose", "label": "Choose…", "opens": true,
			"tip": "Pick another to play this part, from many drawn or from your library. Whichever it is, the desk works it the same way."}]
		if not choice.is_empty():
			verbs.append({"key": "own", "label": "Desk's own", "tip": "Back to the one the desk's number draws."})
		verbs.append({"key": "keep", "label": "Kept" if not as_kept.is_empty() else "Keep", "off": not as_kept.is_empty(),
			"tip": ("In your library as %s." % as_kept) if not as_kept.is_empty() else "Keep it in your library, to use on any scene."})
		out.append({"key": "role:" + String(role), "name": PropMakes.name_of(String(role), choice), "line": " - ".join(line),
			"tip": String((PropMakes.ROLES[role] as Dictionary)["blurb"]), "group": "chosen",
			"picture": library.pictures.of(h, sp[1], sp[2]) if not h.is_empty() else null, "verbs": verbs})
	for k in _built_keys():
		var row: Dictionary = BUILT[k]
		out.append({"key": "built:" + String(k), "name": String(row["label"]), "line": library.pictures.size_of(_hashes.get(k, "")),
			"tip": String(row["blurb"]), "group": "built", "picture": _picture_of(String(k), true), "verbs": []})
	return out


func offers() -> Array:
	var out: Array = []
	for role in DispatchSet.MAKE_SALTS:
		var sp := _spec(String(role), {}, _desk_seed())
		out.append({"key": "role:" + String(role), "name": String((PropMakes.ROLES[role] as Dictionary)["label"]),
			"line": library.pictures.size_of(String(sp[0])), "shelf": "dispatch", "tip": String((PropMakes.ROLES[role] as Dictionary)["blurb"]),
			"picture": library.pictures.image(String(sp[0])),
			"verbs": [{"key": "keep", "label": "Keep", "tip": "Keep it in your library, to use on any scene."}]})
	for k in _built_keys():
		var row: Dictionary = BUILT[k]
		out.append({"key": "built:" + String(k), "name": String(row["label"]), "line": library.pictures.size_of(_hashes.get(k, "")),
			"shelf": "dispatch", "tip": String(row["blurb"]), "picture": _picture_of(String(k), false), "verbs": []})
	return out


func act(key: String, verb: String) -> String:
	if not key.begins_with("role:") or not DispatchSet.MAKE_SALTS.has(key.substr(5)):
		return "nothing here does that"
	var role := key.substr(5)
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
	if _format == null or not key.begins_with("role:") or not DispatchSet.MAKE_SALTS.has(key.substr(5)):
		return null
	var role := key.substr(5)
	return MakeShelf.new(role, own_seed(role, _desk_seed()), library, func(choice: Dictionary) -> String: return _format.choose(role, choice),
		func() -> Dictionary: return _choice(role))


func prop_of(key: String) -> Dictionary:
	if not key.begins_with("role:") or not DispatchSet.MAKE_SALTS.has(key.substr(5)):
		return {}
	var role := key.substr(5)
	var choice := _choice(role)
	var sp := _spec(role, choice, _desk_seed())
	if (sp[1] as Dictionary).is_empty():
		return {}
	return {"name": PropMakes.name_of(role, choice), "thing": sp[1], "materials": sp[2], "hash": String(sp[0])}


func model_of(key: String) -> Dictionary:
	if key.begins_with("built:"):
		var k := key.substr(6)
		while not _set_ready():
			if not PropStudio.can_see() and _set_task < 0:
				return {}
			await PropStudio.tree().process_frame
		var made := _made_of(k)
		if made.is_empty():
			return {}
		return {"node": made["node"], "box": made["size"], "size": PropStudio.size_text(made["size"])}
	var p := prop_of(key)
	if p.is_empty():
		return {}
	return await PropStudio.model(p["thing"], p["materials"], String(p["hash"]))


func versions_of() -> PropVersions:
	return library.versions_of()


## A part refined is played by the prop kept from it, every version of which the desk then follows.
func refined(key: String, name: String) -> String:
	if _format == null or not key.begins_with("role:") or not DispatchSet.MAKE_SALTS.has(key.substr(5)):
		return ""
	var role := key.substr(5)
	if _choice(role) == {"kept": name}:
		return ""
	return _format.choose(role, {"kept": name})


func want_pictures(keys: Array) -> void:
	library.pictures.want(_asked(keys))


func prepare_pictures(keys: Array) -> void:
	library.pictures.prepare(_asked(keys))


func picture(key: String) -> Variant:
	if key.begins_with("built:"):
		return library.pictures.image(String(_hashes.get(key.substr(6), "")))
	var p := prop_of(key)
	return library.pictures.image(String(p["hash"])) if not p.is_empty() else null


## The worker building the desk waited for, if one is under way: before what holds this section goes.
func settle() -> void:
	if _set_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_set_task)
		_set_task = -1
		_set = _set_box[0]
	if library != null:
		library.settle()


func _notification(what: int) -> void:
	# (its own methods cannot be called while it goes: what settle() does, done here by hand)
	if what == NOTIFICATION_PREDELETE:
		if _set_task >= 0:
			WorkerThreadPool.wait_for_task_completion(_set_task)
			_set = _set_box[0]
		if library != null:
			library.settle()
		if _set != null and _set.root != null and is_instance_valid(_set.root):
			_set.root.free()
		if _screens != null and is_instance_valid(_screens):
			_screens.queue_free()


# --- the parts that may be chosen ---------------------------------------------------------------------------------------

## Role [param role]'s own number on the desk of [param seed]: the make the desk draws when none is chosen ([constant
## DispatchSet.MAKE_SALTS]).
static func own_seed(role: String, seed: int) -> int:
	return hash([seed, String(DispatchSet.MAKE_SALTS.get(role, role))])


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
		var sp := PropMakes.spec(role, choice, own_seed(role, seed))
		var thing: Dictionary = sp.get("thing", {})
		var mats: Dictionary = sp.get("materials", {})
		_specs[key] = [ThingLibrary.hash_of(thing, mats) if not thing.is_empty() else "", thing, mats]
	return _specs[key]


func _asked(keys: Array) -> Array:
	var out: Array = []
	for k in keys:
		var key := String(k)
		if key.begins_with("built:"):
			var bk := key.substr(6)
			if _set_ready() and _hashes.has(bk):
				out.append([String(_hashes[bk]), func() -> Dictionary: return _made_of(bk), null])
			continue
		var p := prop_of(key)
		if not p.is_empty():
			out.append([String(p["hash"]), p["thing"], p["materials"]])
	return out


# --- what the desk builds ----------------------------------------------------------------------------------------------

## The built things shown: the clock and the tablet only where the note's script uses them, or on the shelf; once the desk is
## built, only what it found room for.
func _built_keys() -> Array:
	var out: Array = []
	var wants := _format.wants() if _format != null else {"clock": true, "tablet": true}
	for k in BUILT:
		if String(k) in ["clock", "tablet"] and not wants.has(k):
			continue
		if _set != null and _node_of(String(k)) == null:
			continue
		out.append(k)
	return out


## Built thing [param k]'s picture once it is to hand: asked for ([param ask]) once the desk is built, the desk started where it is
## not; else only looked for, which never starts it (the Dex counts every shelf's offers).
func _picture_of(k: String, ask: bool) -> Variant:
	var ready := _set_ready() if ask or _set_task >= 0 else _set != null
	if not ready or not _hashes.has(k):
		return null
	var h := String(_hashes[k])
	return library.pictures.of_made(h, func() -> Dictionary: return _made_of(k)) if ask else library.pictures.image(h)


## Whether the desk the pictures are taken of is built, starting it where it is not: its faces drawn here, the set built on a
## worker with every thing the script may use.
func _set_ready() -> bool:
	if _set != null:
		return true
	if not PropStudio.can_see():
		return false
	if _set_task < 0:
		var labels := _labels()
		_set_labels = labels
		_screens = DispatchScreens.new()
		PropStudio.tree().root.add_child(_screens)
		_screens.build(labels)
		var tex := _screens.textures()
		var seed := _desk_seed()
		var box := _set_box
		_set_task = WorkerThreadPool.add_task(func() -> void:
			var s := DispatchSet.new()
			s.build(labels, seed, tex, {"clock": true, "tablet": true})
			box[0] = s, false, "the dispatch desk's props")
		return false
	if not WorkerThreadPool.is_task_completed(_set_task):
		return false
	WorkerThreadPool.wait_for_task_completion(_set_task)
	_set_task = -1
	_set = _set_box[0]
	for k in BUILT:
		var n := _node_of(String(k))
		if n != null:
			# a phone's picture shows the name on its tape
			_hashes[k] = "dispatch-%s-%d" % [k, hash([content_hash(n, String(k)), _set_labels[0] if k == "phone" else ""])]
	return true


## The phones' names the desk is built with: the note's, or one for the shelf.
func _labels() -> PackedStringArray:
	if _format != null:
		var p: PackedStringArray = DispatchScript.parse(_format.note())["phones"]
		if not p.is_empty():
			return p
	return PackedStringArray(["DESK"])


## Built thing [param k]'s node in the desk built, null where it has none.
func _node_of(k: String) -> Node3D:
	if _set == null:
		return null
	match String((BUILT.get(k, {}) as Dictionary).get("from", "")):
		"phone":
			return (_set.phones[0] as Dictionary).get("node") as Node3D if not _set.phones.is_empty() else null
		"chair":
			return _set.chair
	return _set.things.get(k) as Node3D


## Built thing [param k] alone, to be pictured or turned: `{node, size}` - a copy of its node at its own turn, standing on y = 0,
## what is a cable or a strip of paper hidden ([constant DispatchSet.THIN]) - or {} where the desk has none.
func _made_of(k: String) -> Dictionary:
	var n := _node_of(k)
	if n == null:
		return {}
	var copy := n.duplicate() as Node3D
	copy.transform = Transform3D.IDENTITY
	var box := AABB()
	var first := true
	for mi in _meshes(copy, Transform3D.IDENTITY):
		var m: MeshInstance3D = mi[0]
		if m.mesh.has_meta(DispatchSet.THIN):
			m.visible = false
			continue
		var b: AABB = (mi[1] as Transform3D) * m.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	if first:
		copy.free()
		return {}
	# standing on the ground, centered over it
	copy.position = Vector3(-box.get_center().x, -box.position.y, -box.get_center().z)
	box.position += copy.position
	return {"node": copy, "size": box}


## Every mesh under [param n], each `[MeshInstance3D, its transform from n]`.
static func _meshes(n: Node, xf: Transform3D) -> Array:
	var out: Array = []
	for c in n.get_children():
		if not (c is Node3D):
			continue
		var cx := xf * (c as Node3D).transform
		if c is MeshInstance3D and (c as MeshInstance3D).mesh != null:
			out.append([c, cx])
		out.append_array(_meshes(c, cx))
	return out


## What thing [param n] (called [param k]) is built of, as one number: each mesh's place, bounds and size, and its material's color
## and kind - so its picture is taken again when how it is built changes, and kept while it does not.
static func content_hash(n: Node3D, k: String) -> int:
	var parts: Array = [k]
	for mi in _meshes(n, Transform3D.IDENTITY):
		var m: MeshInstance3D = mi[0]
		var bits: Array = [str(mi[1]), str(m.mesh.get_aabb()), m.mesh.get_surface_count(), m.visible, m.mesh.get_class()]
		for i in m.mesh.get_surface_count():
			if m.mesh is ArrayMesh:
				bits.append((m.mesh as ArrayMesh).surface_get_array_len(i))
			var mat: Material = m.material_override if m.material_override != null else m.mesh.surface_get_material(i)
			if mat is StandardMaterial3D:
				bits.append(str((mat as StandardMaterial3D).albedo_color))
			elif mat != null:
				bits.append(mat.get_class())
		parts.append(bits)
	return hash(parts)
