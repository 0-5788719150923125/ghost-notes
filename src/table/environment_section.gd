extends PropSection
class_name EnvironmentSection

## EnvironmentSection - what is round a note's scene as a list ([Surroundings], next/environment.md), drawn by the Environment card's
## list ([EnvironmentCard], a [PropsCard]): an entry an element - its picture, its name, a line saying what it is and its × (taken
## away); opened, Used, Roll (every property not set drawn again, [Roll]), Keep (into the library, [EnvironmentLibrary]) and its
## properties - and an entry, always open, for each thing on the Props card that throws light or makes a sound of its own, its share. "+ Add to the environment" opens the Dex on
## its shelves: every light preset, light shafts and their looks, what drifts and what is heard, built in, and what was kept. With no
## card (the Dex opened on its own) it is those shelves alone.

const GROUPS := [
	{"key": "here", "label": "Round the scene", "tip": "What is round the scene: its light, shafts of light, what drifts in its air, what is heard. Roll draws another of one; a property you set stays."},
	{"key": "props", "label": "Its props' lights and sounds", "tip": "How strongly each thing on the Props card that throws light throws it, and how loud each that makes a sound of its own is."},
]
const KEPT_SHELF := {"key": "kept", "label": "Kept", "tip": "What you kept from an environment, to use on any note."}
## How long the library is trusted before it is read again (seconds), and the most pictures held.
const LIBRARY_FRESH := 2.0
const PICTURES_HELD := 96

## The card whose note it lists, null on the Dex alone.
var card: EnvironmentCard = null
var _kept: Array = []
var _kept_t := -INF
var _pictures := {}               # what an element is, under the light it is drawn in -> its picture


func _init(c: EnvironmentCard = null) -> void:
	card = c


func title() -> String:
	return "Environment"


func category() -> String:
	return "Environment"


func turns() -> bool:
	return false


func file_kind() -> Dictionary:
	return {}


func groups() -> Array:
	return GROUPS


func shelves() -> Array:
	var out: Array = []
	for g in Surroundings.GROUPS:
		out.append({"key": g, "label": Registry.label(Surroundings.GROUPS, g), "tip": Registry.blurb(Surroundings.GROUPS, g)})
	out.append(KEPT_SHELF)
	return out


# --- the note's environment ---------------------------------------------------------------------------------------------

func rows() -> Array:
	if card == null:
		return []
	var spec := card.capture()
	var key_color := "#" + Color.html(String(Surroundings.light_of(spec)["key_color"])).to_html(false)
	var kept := _kept_entries()
	var out: Array = []
	var els: Array = spec["elements"]
	for i in els.size():
		var el: Dictionary = els[i]
		var kind := String(el["kind"])
		var as_kept := EnvironmentLibrary.kept_as(el, kept)
		var set := Surroundings.set_of(el)
		out.append({"key": "el:%d" % i, "name": name_of(el), "line": Surroundings.line_of(el), "group": "here",
			"tip": Registry.blurb(Surroundings.KINDS, kind), "picture": _picture(el, spec), "on": el.get("off") != true,
			"on_tip": "Ticked, it is round the scene; unticked, it is set aside, with everything set on it.",
			"remove_tip": "Take it away from round the scene, with everything set on it.",
			"verbs": [{"key": "roll", "label": "Roll", "tip": "Another of it: every property you have not set drawn again, inside its bounds."},
				{"key": "keep", "label": "Kept" if not as_kept.is_empty() else "Keep", "off": not as_kept.is_empty(),
					"tip": ("In your library as %s." % as_kept) if not as_kept.is_empty() else "Keep it in your library, to use on any note."}],
			"fields": Roll.shown(Surroundings.fields_of(kind, key_color), set, int(el["seed"])), "values": set})
	for t in card.things("lit"):
		var name := String((t as Dictionary)["key"])
		out.append(_share_row("lit:" + name, String((t as Dictionary)["name"]), "Its light",
			"How strongly it throws its light: 1 as it is made, 0 dark.", Surroundings.LIGHT_SHARE, spec["lights"], name))
	for t in card.things("heard"):
		var name := String((t as Dictionary)["key"])
		out.append(_share_row("heard:" + name, String((t as Dictionary)["name"]), "How loud",
			"How loud it is in what it makes of its own: 1 as it is made, 0 silent.", Surroundings.HEARD_SHARE, spec["heard"], name))
	return out


## A row tuning one thing's share: always open, its one field the share.
func _share_row(key: String, name: String, label: String, blurb: String, range: Vector2, shares: Dictionary, of: String) -> Dictionary:
	var values := {"share": shares[of]} if shares.has(of) else {}
	return {"key": key, "name": name, "line": "", "group": "props", "open": true, "values": values,
		"fields": {"share": {"label": label, "blurb": blurb, "type": "float", "min": range.x, "max": range.y, "step": 0.05, "default": 1.0}}}


func set_on(key: String, on: bool) -> String:
	var i := _index(key)
	return card.set_off(i, not on) if i >= 0 else "nothing here sets that aside"


func remove(key: String) -> String:
	var i := _index(key)
	return card.remove(i) if i >= 0 else "nothing here takes that away"


func set_field(key: String, field: String, value: Variant) -> String:
	if card == null:
		return "nothing here is tuned"
	var i := _index(key)
	if i >= 0:
		return card.set_field(i, field, value)
	if key.begins_with("lit:"):
		return card.set_share("lights", key.substr(4), value)
	if key.begins_with("heard:"):
		return card.set_share("heard", key.substr(6), value)
	return "nothing here is tuned"


func act(key: String, verb: String) -> String:
	if verb == "forget" and key.begins_with("kept:"):
		_kept_t = -INF
		return EnvironmentLibrary.remove(key.substr(5))
	var i := _index(key)
	if i < 0:
		return "nothing here does that"
	match verb:
		"roll":
			return card.roll(i)
		"keep":
			var el: Dictionary = (card.capture()["elements"] as Array)[i]
			_kept_t = -INF
			return EnvironmentLibrary.keep(el, String(el.get("name", "%s %d" % [name_of(el), int(el["seed"])])))
	return "nothing here does that"


## The element row [param key] stands for, by its place in the list; -1 for none.
func _index(key: String) -> int:
	if card == null or not key.begins_with("el:") or not key.substr(3).is_valid_int():
		return -1
	var i := int(key.substr(3))
	return i if i >= 0 and i < (card.capture()["elements"] as Array).size() else -1


## What element [param el] is called: the name it was kept as, a light by its preset, else its kind.
static func name_of(el: Dictionary) -> String:
	if el.has("name"):
		return String(el["name"])
	var kind := String(el.get("kind", ""))
	if kind == "light":
		var p := String(Surroundings.values_of(el)["preset"])
		return Registry.label(Surroundings.LIGHTS, p) if Surroundings.LIGHTS.has(p) else "The scene's own light"
	return Registry.label(Surroundings.KINDS, kind)


# --- the Dex's shelves --------------------------------------------------------------------------------------------------

func offers() -> Array:
	var spec := card.capture() if card != null else Surroundings.sanitize({})
	var out: Array = []
	var built := Surroundings.offers()
	for k in built:
		var o: Dictionary = built[k]
		var el := Surroundings.element(o["element"])
		out.append({"key": k, "name": String(o["label"]), "line": Surroundings.line_of(el), "shelf": String(o["group"]),
			"tip": String(o["blurb"]), "picture": _picture(el, spec)})
	for e in _kept_entries():
		var el: Dictionary = (e as Dictionary)["element"]
		out.append({"key": "kept:" + String(e["name"]), "name": String(e["name"]), "shelf": "kept", "named": true,
			"line": "%s - %s" % [Registry.label(Surroundings.KINDS, String(el["kind"])), Surroundings.line_of(el)],
			"tip": Registry.blurb(Surroundings.KINDS, String(el["kind"])), "picture": _picture(el, spec),
			"verbs": [{"key": "forget", "label": "Remove", "tip": "Take it out of your library, to the trash."}]})
	return out


func picture(key: String) -> Variant:
	for o in offers():
		if String((o as Dictionary)["key"]) == key:
			return (o as Dictionary)["picture"]
	return null


func adds() -> Dictionary:
	if card == null:
		return {}
	return {"label": "+ Add to the environment", "verb": "Use",
		"tip": "Put it round the scene. A light takes the place of the one there; a sound already heard, of that sound."}


func add(key: String) -> String:
	if card == null:
		return "nothing here takes it"
	var el := {}
	if key.begins_with("kept:"):
		el = (EnvironmentLibrary.read(key.substr(5)).get("element", {}) as Dictionary).duplicate(true)
	else:
		var o: Dictionary = Surroundings.offers().get(key, {})
		el = Surroundings.element(o.get("element"))
		# the one pictured, unless the scene has it already: then another of it
		for had in (card.capture()["elements"] as Array):
			if not el.is_empty() and String((had as Dictionary)["kind"]) == String(el["kind"]) and int((had as Dictionary)["seed"]) == int(el["seed"]):
				el["seed"] = Roll.fresh()
	if el.is_empty():
		return "there is no such thing to add"
	return card.add(el)


func rename(key: String, name: String) -> String:
	if not key.begins_with("kept:"):
		return "only what you kept can be renamed"
	_kept_t = -INF
	return EnvironmentLibrary.rename(key.substr(5), name)


func _kept_entries() -> Array:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _kept_t > LIBRARY_FRESH:
		_kept = EnvironmentLibrary.entries()
		_kept_t = now
	return _kept


## Element [param el]'s picture under the light [param spec] chooses, drawn once ([method Surroundings.picture]).
func _picture(el: Dictionary, spec: Dictionary) -> Image:
	var safe := el.duplicate()
	safe.erase("off")
	safe.erase("name")
	var key := JSON.stringify([safe, Surroundings.preset_of(spec)], "", true)
	if not _pictures.has(key):
		if _pictures.size() >= PICTURES_HELD:
			_pictures.clear()
		_pictures[key] = Surroundings.picture(el, spec)
	return _pictures[key]
