extends ShelfSection
class_name DeliveryShelf

## DeliveryShelf - the deliveries on the Dex's shelves ([DexWindow]): those kept in the library ([DeliveryLibrary]), each heard from
## its last test, renamed in place or removed to the trash, and the bank's own ([DeliveryBank]) by family, and the acts a word can
## take. Opened from a note's Voice card, "Add it" puts the one picked on the note's list of deliveries to tune ([member picked]).

const SHELVES := [
	{"key": "kept", "label": "Kept deliveries", "tip": "The deliveries in your library, kept from any note's Voice card: one kept under a bank name is said that way in every note, one under a name of its own is a word every script may say."},
	{"key": "bank", "label": "The bank", "tip": "Every delivery Ghost Notes knows, as it comes: expressions, ways of telling, ramps over a stretch."},
	{"key": "acts", "label": "On a word", "tip": "What one word can do: a pitch shape, drawn out, clipped, cut off, stressed."},
	{"key": "new", "label": "New", "tip": "A delivery that moves nothing yet, named by you and shaped in its Lab."},
]

## (name: String) -> void: the delivery added where the Dex was opened from; unset, the Dex was opened on its own.
var picked: Callable = Callable()


func _init(on_pick: Callable = Callable()) -> void:
	picked = on_pick


func title() -> String:
	return "Deliveries"


func category() -> String:
	return "Voices"


func version() -> int:
	return DeliveryLibrary.version


func shelves() -> Array:
	return SHELVES if picked.is_valid() else SHELVES.slice(0, 3)


func offers() -> Array:
	var out: Array = []
	for e in DeliveryLibrary.entries():
		var ed: Dictionary = e
		var name := String(ed["name"])
		var line := DeliveryBank.line_of(ed["spec"])
		out.append({"key": "kept:" + name, "name": name, "line": line, "shelf": "kept", "named": true,
			"tip": String(ed.get("about", "")) if not String(ed.get("about", "")).is_empty() else line,
			"sound": String(ed["wav"]) if FileAccess.file_exists(String(ed["wav"])) else "",
			"verbs": [{"key": "forget", "label": "Remove", "tip": "Take it out of your library, to the trash. A note that tuned its own keeps it."}]})
	for k in DeliveryBank.BANK:
		var row: Dictionary = DeliveryBank.BANK[k]
		out.append({"key": "bank:" + String(k), "name": String(k), "line": String(row["blurb"]), "shelf": "bank", "named": false,
			"tip": "%s - %s" % [Registry.label(DeliveryBank.FAMILIES, String(row["family"])), String(row["terms"])], "verbs": []})
	for k in DeliveryBank.ACTS:
		out.append({"key": "bank:" + String(k), "name": String(k), "line": String(DeliveryBank.ACTS[k]["blurb"]), "shelf": "acts",
			"named": false, "tip": String(DeliveryBank.ACTS[k]["blurb"]), "verbs": []})
	if picked.is_valid():
		out.append({"key": "new:", "name": "A new delivery", "line": "Moves nothing yet: name it and shape it in its Lab.", "shelf": "new",
			"named": false, "tip": "A delivery of this note's own, said in its script by the name you give it.", "verbs": []})
	return out


func act(key: String, verb: String) -> String:
	if not key.begins_with("kept:") or verb != "forget":
		return "nothing here does that"
	return DeliveryLibrary.remove(key.substr(5))


func rename(key: String, name: String) -> String:
	if not key.begins_with("kept:"):
		return "only a kept delivery can be renamed"
	return DeliveryLibrary.rename(key.substr(5), name)


func adds() -> Dictionary:
	if not picked.is_valid():
		return {}
	return {"label": "Add it", "verb": "Add it", "tip": "Put it on this note's list of deliveries, to hear and tune in its Lab."}


func add(key: String) -> String:
	if not picked.is_valid():
		return "no note to add it to"
	if key == "new:":
		picked.call("")
		return ""
	var i := key.find(":")
	if i < 0:
		return "nothing here takes it"
	picked.call(key.substr(i + 1))
	return ""
