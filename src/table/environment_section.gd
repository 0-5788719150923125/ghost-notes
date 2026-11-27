extends PropSection
class_name EnvironmentSection

## EnvironmentSection - what is round a note's scene as a list ([Surroundings], next/environment.md), drawn by the Environment card's
## list ([EnvironmentCard], a [PropsCard]): an entry an element - its picture, its name, a line saying what it is and its × (taken
## away); opened, Used, Roll (every property not set drawn again, [Roll]), Keep (into the library, [EnvironmentLibrary]) and its
## properties - and an entry, always open, for each thing on the Props card that throws light or makes a sound of its own, its share. "+ Add to the environment" opens the Dex on
## its shelves: every light preset, light shafts and their looks, what drifts and what is heard, built in, and what was kept. With no
## card (the Dex opened on its own) it is those shelves alone.
##
## A HEARD ELEMENT IS REFINED (next/environment.md, "Refining a sound"): Refine… opens a conversation with a designer who hears it and
## changes it ([EnvironmentSoundDesign], [TextRefine]), each change a version ([ElementVersions]) - and once it has versions, its
## Version picker makes any of them the element again. Both are kept in a folder of the element's own under the section's home
## ([method home]), named by its kind and its count among its kind ([method sound_key]), so a sound keeps its history however the
## list round it changes. A list with another home or another way of hearing and changing its elements (an episode's) says so in
## [method home], [method elements], [method heard_of], [method put_at] and [method window_host].

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
var _refines := {}                # a sound's folder -> its Refine… window


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
		var heard := String((Surroundings.KINDS.get(kind, {}) as Dictionary).get("group", "")) == "sound"
		out.append({"key": "el:%d" % i, "name": name_of(el), "line": refining_line(els, i, Surroundings.line_of(el)), "group": "here",
			"tip": Registry.blurb(Surroundings.KINDS, kind), "picture": _picture(el, spec), "on": el.get("off") != true,
			"on_tip": "Ticked, it is round the scene; unticked, it is set aside, with everything set on it.",
			"remove_tip": "Take it away from round the scene, with everything set on it.",
			"verbs": ([{"key": "test", "label": "Test ■" if card.testing(i) else "Test",
					"tip": "Hear it alone, as it sounds under the voice; it follows what you change. Press again to stop."}]
					if heard else [])
				+ ([] if el.has("own") else [{"key": "roll", "label": "Roll", "tip": "Another of it: every property you have not set drawn again, inside its bounds."}])
				+ [{"key": "keep", "label": "Kept" if not as_kept.is_empty() else "Keep", "off": not as_kept.is_empty(),
					"tip": ("In your library as %s." % as_kept) if not as_kept.is_empty() else "Keep it in your library, to use on any note."}]
				+ (refine_verbs(els, i) if heard else []),
			"fields": Surroundings.shown_of(el, key_color), "values": set})
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
	if verb == "refine" or verb.begins_with("version:"):
		return refine_act(i, verb)
	match verb:
		"test":
			return card.test(i)
		"roll":
			return card.roll(i)
		"keep":
			var el: Dictionary = (card.capture()["elements"] as Array)[i]
			_kept_t = -INF
			return EnvironmentLibrary.keep(el, String(el.get("name", "%s %d" % [name_of(el), int(el["seed"])])))
	return "nothing here does that"


# --- refining a sound ----------------------------------------------------------------------------------------------------

## Where its sounds' conversations and versions are kept: the note's folder ("" none: [member TextRefine.root]).
func home() -> String:
	return card.folder if card != null and is_instance_valid(card) else ""


## Its elements as they stand, in the list's order.
func elements() -> Array:
	return (card.capture()["elements"] as Array) if card != null and is_instance_valid(card) else []


## How element [param el] is heard where it is: `{sound, wind, ride, seed}` ([method EnvironmentCard.heard]).
func heard_of(el: Dictionary) -> Dictionary:
	var one := el.duplicate(true)
	one.erase("off")
	return EnvironmentCard.heard({"elements": [one]})


## Element [param i] replaced by [param el]. "" done, else why not.
func put_at(i: int, el: Dictionary) -> String:
	return card.replace(i, el) if card != null and is_instance_valid(card) else "the note was left"


## The node a Refine… window stands under, null where none can.
func window_host() -> Node:
	return card if card != null and is_instance_valid(card) and card.is_inside_tree() else null


## The note's title, for what a designer is told.
func note_title() -> String:
	var path := card.note_path if card != null and is_instance_valid(card) else ""
	if path.is_empty() or not FileAccess.file_exists(path):
		return ""
	var t := String(FrontMatter.field_of(FileAccess.get_file_as_string(path), "title")).strip_edges()
	return t if not t.is_empty() else path.get_file().get_basename()


## What element [param i] of [param els] is called where its history is kept: its kind and how many of its kind stand before it,
## counted from 1 ("wind-1", "creature-2").
static func sound_key(els: Array, i: int) -> String:
	var kind := String((els[i] as Dictionary).get("kind", ""))
	var n := 1
	for j in i:
		if String((els[j] as Dictionary).get("kind", "")) == kind:
			n += 1
	return "%s-%d" % [kind, n]


## The folder element [param i] of [param els] keeps its conversation and versions in.
func sound_folder(els: Array, i: int) -> String:
	return TextRefine.folder_for(home(), "environment-" + sound_key(els, i))


## The place in the list of the element called [param key] ([method sound_key]) now, -1 for none.
func _find(key: String) -> int:
	var els := elements()
	for i in els.size():
		if sound_key(els, i) == key:
			return i
	return -1


## Element [param i]'s line [param line], or what its designer is doing while it works on it.
func refining_line(els: Array, i: int, line: String) -> String:
	var d := EnvironmentSoundDesign.live(sound_folder(els, i))
	if d == null:
		return line
	_bind(d, sound_key(els, i))
	if d.busy():
		return "the designer is at work on it"
	return line if d.error.is_empty() else "%s - not refined: %s" % [line, d.error]


## Element [param i]'s Refine… and, once it has versions, its Version picker (each version, and the element as it is now where a
## hand changed it since).
func refine_verbs(els: Array, i: int) -> Array:
	var refining: TextRefine = _refines.get(sound_folder(els, i))
	var out: Array = [{"key": "refine", "label": "Refine…",
		"pressed": refining != null and is_instance_valid(refining) and RefineDock.is_open(refining),
		"tip": "Talk the sound over with a designer who hears it: say what to change (softer, further off, less hiss, slower), and each change is a version you can go back from."}]
	var dir := sound_folder(els, i)
	var n := ElementVersions.versions(dir).size()
	if n == 0:
		return out
	var now := ElementVersions.of(dir, els[i])
	var choices: Array = []
	for v in n:
		choices.append({"key": str(v), "label": ElementVersions.label_of(dir, v)})
	if now < 0:
		choices.append({"key": "", "label": "As it is now (changed since)"})
	out.append({"key": "version", "label": "Version", "choices": choices, "chosen": str(now) if now >= 0 else "",
		"tip": "Which version it is: every version a designer made, and how it was before, is kept. Pick one to make it that again."})
	return out


## Element [param i]'s Refine… opened ([param verb] `refine`), or version N made the element again (`version:N`). "" done, else
## why not.
func refine_act(i: int, verb: String) -> String:
	var els := elements()
	if i < 0 or i >= els.size():
		return "nothing here does that"
	var el: Dictionary = els[i]
	if String((Surroundings.KINDS.get(String(el.get("kind", "")), {}) as Dictionary).get("group", "")) != "sound":
		return "only what is heard is refined here"
	var dir := sound_folder(els, i)
	if verb.begins_with("version:"):
		var v := verb.substr(8)
		if not v.is_valid_int():
			return ""
		if not ElementVersions.writable(dir):
			return "this session cannot change its versions"
		var got := ElementVersions.use(dir, int(v))
		if got.is_empty():
			return "there is no version %s to use" % v
		if el.get("off") == true:
			got["off"] = true
		if el.has("name"):
			got["name"] = el["name"]
		return put_at(i, got)
	var host := window_host()
	if host == null:
		return "nothing here can open it"
	var d := EnvironmentSoundDesign.at(dir)
	_bind(d, sound_key(els, i))
	var w: TextRefine = _refines.get(dir)
	if w == null or not is_instance_valid(w):
		w = TextRefine.new(d.chat, name_of(el))
		host.add_child(w)
		_refines[dir] = w
	# a toggle, docked beside the card in its panel
	w.toggle(host)
	return ""


## Design [param d] bound to the element called [param key] in this list: what it stands for, how it is heard and where it lands.
## The section is held weakly, so a list let go is never kept alive by a design.
func _bind(d: EnvironmentSoundDesign, key: String) -> void:
	var me: WeakRef = weakref(self)
	d.element_of = func() -> Dictionary:
		var s: EnvironmentSection = me.get_ref()
		var j := s._find(key) if s != null else -1
		return (s.elements()[j] as Dictionary).duplicate(true) if j >= 0 else {}
	d.heard_by = func(el: Dictionary) -> Dictionary:
		var s: EnvironmentSection = me.get_ref()
		return s.heard_of(el) if s != null else {"sound": {}}
	d.put = func(el: Dictionary) -> String:
		var s: EnvironmentSection = me.get_ref()
		var j := s._find(key) if s != null else -1
		return s.put_at(j, el) if j >= 0 else "it is no longer round the scene"
	if d.title.is_empty():
		d.title = note_title()


## The element row [param key] stands for, by its place in the list; -1 for none.
func _index(key: String) -> int:
	if card == null or not key.begins_with("el:") or not key.substr(3).is_valid_int():
		return -1
	var i := int(key.substr(3))
	return i if i >= 0 and i < (card.capture()["elements"] as Array).size() else -1


## What element [param el] is called: the name it was kept as, a light by its preset, a creature by its own name, else its kind.
static func name_of(el: Dictionary) -> String:
	if el.has("name"):
		return String(el["name"])
	var kind := String(el.get("kind", ""))
	var own_name := String((el.get("own", {}) as Dictionary).get("name", "")) if kind == "creature" else ""
	if not own_name.is_empty():
		return own_name.left(1).to_upper() + own_name.substr(1)
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
