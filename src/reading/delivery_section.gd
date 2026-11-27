extends PropSection
class_name DeliverySection

## DeliverySection - the deliveries a note says, listed on its Voice card as the Props card lists props (next/delivery.md, "Tuning a
## delivery"; [PropsCard], [EntryCard]): every delivery and act its script says (`[words]{terms}`, `<!-- delivery: -->`), and those
## put on the list by hand from the Dex ("+ Add a delivery", [DeliveryShelf]: the bank, the library, a new one). Each entry's Used
## tick sets it aside (said, it moves nothing, and the agents writing the script are told never to say it), its Strength says it
## stronger or weaker, Lab… opens it whole ([DeliveryLab]: heard, shaped, refined, kept), and its versions are picked here. What it
## says lives in the cast ([member ReadingCast.deliveries]) and reaches the reading as it changes ([method ReadingCast.deliveries_changed]).
##
## A delivery is said, in order: the note's own version where it is tuned, the library's where one is kept under its name, the bank's.
## A name the script defines itself (`<!-- delivery: name = terms -->`) is the script's: it is listed, and changed where it is written.

const GROUPS := [
	{"key": "script", "label": "Said in the script", "tip": "Every delivery and act the note's script says, in `[words]{terms}` and `<!-- delivery: -->` marks."},
	{"key": "listed", "label": "On the list", "tip": "Put here from the Dex: kept to tune before the script says them, or a delivery of the note's own."},
]

## The cast whose deliveries these are.
var cast: ReadingCast

var _shelf: DeliveryShelf
var _labs := {}                  # name -> its DeliveryLab, while one is open
var _said_cache := ["", {}]      # [the script text, what it says] so a look reads the script once a change


func _init(owner: ReadingCast = null) -> void:
	cast = owner
	_shelf = DeliveryShelf.new(func(n: String) -> void: _picked(n))


func title() -> String:
	return "Deliveries"


func category() -> String:
	return "Voices"


func turns() -> bool:
	return false


func file_kind() -> Dictionary:
	return {}


func groups() -> Array:
	return GROUPS


## What the script says now: `{name: {terms: [the marks' terms that say it], defined: terms where the script defines the name}}`.
func said() -> Dictionary:
	var text := cast.panel._cast_text() if cast != null and cast.panel != null else ""
	if text == _said_cache[0]:
		return _said_cache[1]
	var out := {}
	var defined := {}
	var marks: Array = []
	for m in Manuscript._rx(Manuscript.DELIVERED).search_all(text):
		marks.append(m.get_string(2))
	for m in Manuscript._rx(Manuscript.DELIVERY).search_all(text):
		var terms := m.get_string(1)
		var eq := terms.find("=")
		if eq > 0:
			var n := terms.substr(0, eq).strip_edges().to_lower()
			defined[n] = terms.substr(eq + 1).strip_edges()
			marks.append(terms.substr(eq + 1))
		else:
			marks.append(terms)
	for terms in marks:
		for n in DeliveryBank.names_in(String(terms), _own_names().merged(defined)):
			if not out.has(n):
				out[n] = {"terms": []}
			(out[n]["terms"] as Array).append(String(terms))
	for n in defined:
		if not out.has(n):
			out[n] = {"terms": []}
		out[n]["defined"] = defined[n]
	_said_cache = [text, out]
	return out


## The names of the note's own deliveries on the list (none of the bank's or an act's), as [method DeliveryBank.names_in] takes them.
func _own_names() -> Dictionary:
	var out := {}
	if cast == null:
		return out
	for n in cast.deliveries:
		if not DeliveryBank.is_named(String(n)):
			out[String(n)] = true
	for e in DeliveryLibrary.entries():
		if not DeliveryBank.is_named(String((e as Dictionary)["name"])):
			out[String((e as Dictionary)["name"])] = true
	return out


## Delivery [param name] as the note says it now (its version, the library's, the bank's), and where that comes from: `{spec, from}`,
## `from` "tuned", "kept", "bank" or "own" (a name of the note's own nothing has shaped yet).
func said_as(name: String) -> Dictionary:
	var e: Dictionary = cast.deliveries.get(name, {}) if cast != null and cast.deliveries.get(name) is Dictionary else {}
	if bool(e.get("tuned", false)):
		var s := DeliveryVersions.spec(cast.delivery_folder(name))
		if not s.is_empty():
			return {"spec": s, "from": "tuned"}
	var kept := DeliveryLibrary.find(name)
	if not kept.is_empty():
		return {"spec": (kept["spec"] as Dictionary).duplicate(true), "from": "kept"}
	if DeliveryBank.is_named(name):
		return {"spec": DeliveryBank.spec_of_name(name), "from": "bank"}
	return {"spec": {}, "from": "own"}


func rows() -> Array:
	if cast == null:
		return []
	var out: Array = []
	var in_script := said()
	var names: Array = in_script.keys()
	for n in cast.deliveries:
		if not names.has(n):
			names.append(n)
	for n in names:
		var name := String(n)
		var e: Dictionary = cast.deliveries.get(name, {}) if cast.deliveries.get(name) is Dictionary else {}
		var defined := String((in_script.get(name, {}) as Dictionary).get("defined", ""))
		var row := {"key": name, "name": name, "group": "script" if in_script.has(name) else "listed"}
		if not defined.is_empty():
			row["line"] = "defined in the script: " + defined
			row["remove_off"] = "The script defines it: change it where it is written."
			row["verbs"] = []
			out.append(row)
			continue
		var now := said_as(name)
		var from := String(now["from"])
		var line := DeliveryBank.line_of(now["spec"])
		var whence := {"tuned": "tuned here", "kept": "kept in your library", "bank": "", "own": "nothing shaped yet"}[from] as String
		var about := String(e.get("about", "")) if from == "own" or not DeliveryBank.is_named(name) else DeliveryBank.blurb_of(name)
		row["line"] = whence if line.is_empty() else (line if whence.is_empty() else "%s  ·  %s" % [whence, line])
		row["tip"] = about if not about.is_empty() else name
		row["on"] = not bool(e.get("off", false))
		row["on_tip"] = "Ticked, it is said as shaped here; unticked, it is set aside: the words read plain, and the agents writing the script are told never to say it."
		if in_script.has(name):
			row["remove_off"] = "The script says it: take it out of the script to take it off."
		else:
			row["remove_tip"] = "Take it off this note's list (its versions stay beside the note)."
		var verbs: Array = [{"key": "lab", "label": "Lab…", "tip": "Hear it in one of the note's voices against the words read plain, shape it by hand (every axis a curve across the stretch, each act's pitch across its word), refine it with an agent who hears it, and keep it for every note."}]
		var dir := cast.delivery_folder(name)
		var vs := DeliveryVersions.versions(dir)
		if not vs.is_empty():
			var choices: Array = []
			if from != "tuned":
				choices.append({"key": "", "label": "As it comes" if from == "bank" else ("As kept" if from == "kept" else "Nothing shaped")})
			for i in vs.size():
				choices.append({"key": str(i), "label": DeliveryVersions.label_of(dir, i)})
			verbs.append({"key": "version", "label": "Version", "choices": choices,
				"chosen": str(DeliveryVersions.used(dir)) if from == "tuned" else "",
				"tip": "Which of its versions the note says: each made by its Lab's controls or its designer."})
		if from == "tuned" or from == "kept":
			verbs.append({"key": "stock", "label": "As the bank says it" if DeliveryBank.is_named(name) else "Untuned",
				"off": from == "kept" and not DeliveryBank.is_named(name),
				"tip": "Said as it comes again: this note's tuning set by (its versions stay, to pick again)." if from == "tuned" else "Kept in your library under this name: remove it from the Dex to say it as the bank does."})
		row["verbs"] = verbs
		row["fields"] = {"strength": {"label": "Strength", "type": "float", "min": 0.0, "max": 2.0, "step": 0.05, "default": 1.0,
			"blurb": "Said stronger or weaker everywhere the note says it: its degree times this."}}
		row["values"] = {"strength": float(e["strength"])} if e.has("strength") else {}
		out.append(row)
	return out


func set_on(key: String, on: bool) -> String:
	_entry(key)["off"] = not on
	if on:
		(cast.deliveries[key] as Dictionary).erase("off")
	_settle(key)
	return ""


func set_field(key: String, field: String, value: Variant) -> String:
	if field != "strength":
		return "nothing here is tuned so"
	if value == null or is_equal_approx(float(value), 1.0):
		_entry(key).erase("strength")
	else:
		_entry(key)["strength"] = clampf(float(value), 0.0, 2.0)
	_settle(key)
	return ""


func remove(key: String) -> String:
	if said().has(key):
		return "the script says it"
	cast.deliveries.erase(key)
	cast.deliveries_changed()
	return ""


func act(key: String, verb: String) -> String:
	if key.contains(":"):
		return _shelf.act(key, verb)
	if verb == "lab":
		return open_lab(key)
	if verb == "stock":
		_entry(key).erase("tuned")
		_settle(key)
		_reload_lab(key)
		return ""
	if verb.begins_with("version:"):
		var got := DeliveryVersions.use(cast.delivery_folder(key), int(verb.substr(8)))
		if got.is_empty():
			return "that version cannot be used here"
		_entry(key)["tuned"] = true
		_settle(key)
		_reload_lab(key)
		return ""
	return "nothing here does that"


## Delivery [param key]'s entry on the list, made where it has none.
func _entry(key: String) -> Dictionary:
	if not (cast.deliveries.get(key) is Dictionary):
		cast.deliveries[key] = {}
	return cast.deliveries[key]


## Entry [param key] changed: an entry that says nothing but that it is on the list kept as `added`, and the reading told.
func _settle(key: String) -> void:
	var e: Dictionary = cast.deliveries.get(key, {})
	if e.is_empty() and not said().has(key):
		e["added"] = true
	cast.deliveries_changed()


## Delivery [param name]'s Lab opened ([DeliveryLab]).
func open_lab(name: String) -> String:
	var lab: DeliveryLab = _labs.get(name)
	if lab == null or not is_instance_valid(lab):
		lab = DeliveryLab.new(self, name)
		_labs[name] = lab
		# hung on the panel's own column, which is in the tree wherever the card is
		var host: Node = cast.panel._panel if cast != null and cast.panel != null and cast.panel._panel != null else null
		if host == null or not host.is_inside_tree():
			return "the Lab opens on a note's panel"
		host.add_child(lab)
	lab.open()
	return ""


func _reload_lab(name: String) -> void:
	var lab: DeliveryLab = _labs.get(name)
	if lab != null and is_instance_valid(lab) and lab.visible:
		lab.load_spec()


# --- the shelf the Dex opens on ---------------------------------------------------------------------------------------


func shelves() -> Array:
	return _shelf.shelves()


func offers() -> Array:
	return _shelf.offers()


func version() -> int:
	return _shelf.version()


func rename(key: String, new_name: String) -> String:
	return _shelf.rename(key, new_name)


func adds() -> Dictionary:
	if cast == null:
		return {}
	return {"label": "+ Add a delivery", "verb": "Add it", "tip": "Put a delivery on this note's list - the bank's, one kept in your library, or a new one of the note's own - to hear and tune in its Lab."}


func add(key: String) -> String:
	return _shelf.add(key)


## A delivery picked on the Dex put on the list ("" a new one of the note's own, named "new delivery" and a number), and its Lab opened.
func _picked(name: String) -> void:
	if cast == null:
		return
	var n := name
	if n.is_empty():
		n = "new delivery"
		var k := 2
		while cast.deliveries.has(n) or not DeliveryLibrary.find(n).is_empty():
			n = "new delivery %d" % k
			k += 1
	if not cast.deliveries.has(n):
		cast.deliveries[n] = {"added": true}
		cast.deliveries_changed()
	open_lab(n)


## Delivery [param old] renamed [param new_name] (a name of the note's own): its entry and its version used carried over. "" done,
## else why not.
func rename_own(old: String, new_name: String) -> String:
	var n := DeliveryLibrary.clean_name(new_name)
	if n.is_empty():
		return "a delivery is named in lowercase words a script can say (not a degree, an axis or a shape)"
	if DeliveryBank.is_named(n) or DeliveryBank.names().has(n):
		return "%s is the bank's own: add it from the Dex to tune it" % n
	if n == old:
		return ""
	if cast.deliveries.has(n):
		return "the note has a delivery called %s already" % n
	var e: Dictionary = (cast.deliveries.get(old, {}) as Dictionary).duplicate(true)
	var spec := said_as(old)["spec"] as Dictionary
	if not spec.is_empty() and DeliveryVersions.add(cast.delivery_folder(n), spec, "", "") >= 0:
		e["tuned"] = true
	cast.deliveries.erase(old)
	cast.deliveries[n] = e
	if _labs.has(old):
		_labs[n] = _labs[old]
		_labs.erase(old)
	cast.deliveries_changed()
	return ""


## The words the script says delivery [param name] on, as a Lab first tests it: the first line whose mark says it, "" for none.
func words_for(name: String) -> String:
	var lines := lines_for(name, 1)
	return String(lines[0]) if not lines.is_empty() else ""


## The lines of the script whose marks say delivery [param name], at most [param most], as a Lab offers them to hear it on: a line
## with `[words]{terms}` as it is, and a `<!-- delivery: -->` mark with the words after it (on its line, else the next line's)
## closed round them.
func lines_for(name: String, most := 3) -> Array:
	var out: Array = []
	var text := cast.panel._cast_text() if cast != null and cast.panel != null else ""
	var lines := text.split("\n")
	for i in lines.size():
		if out.size() >= most:
			break
		var l := String(lines[i])
		if not (l.contains("]{") or l.contains("delivery:")):
			continue
		var said_here := ""
		for m in Manuscript._rx(Manuscript.DELIVERED).search_all(l):
			if DeliveryBank.names_in(m.get_string(2), _own_names()).has(name):
				said_here = l.strip_edges()
		var dm := Manuscript._rx(Manuscript.DELIVERY).search(l)
		if said_here.is_empty() and dm != null and not dm.get_string(1).contains("=") \
				and DeliveryBank.names_in(dm.get_string(1), _own_names()).has(name):
			var rest := l.substr(dm.get_end()).strip_edges()
			var j := i + 1
			while rest.is_empty() and j < lines.size() and j <= i + 2:
				rest = String(lines[j]).strip_edges()
				j += 1
			rest = Manuscript.plain(rest)
			if not rest.is_empty() and not rest.begins_with("<!--"):
				said_here = "<!-- delivery: %s -->%s<!-- /delivery -->" % [dm.get_string(1).strip_edges(), rest]
		if not said_here.is_empty() and not out.has(said_here):
			out.append(said_here)
	return out
