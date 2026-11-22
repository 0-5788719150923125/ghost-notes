extends ShelfSection
class_name SoundShelf

## SoundShelf - the sound effects kept for every note on the Dex's shelves ([DexWindow], [SoundLibrary]): each heard from its
## sound, or removed to the trash. Opened from a sound on the Sound card, "Use it" puts a kept sound's patch on that sound as a
## new version ([member picked]).

const SHELVES := [{"key": "kept", "label": "Kept sounds", "tip": "The sound effects in your library, kept from any note's Sound card: any sound a note asks for can use one."}]

## (name: String) -> void: the kept sound used where the Dex was opened from; unset, the Dex was opened on its own.
var picked: Callable = Callable()


func _init(on_pick: Callable = Callable()) -> void:
	picked = on_pick


func title() -> String:
	return "Sounds"


func version() -> int:
	return SoundLibrary.version


func shelves() -> Array:
	return SHELVES


func offers() -> Array:
	var out: Array = []
	for e in SoundLibrary.entries():
		var ed: Dictionary = e
		var name := String(ed.get("name", ""))
		var p: Dictionary = ed["patch"]
		var secs := float(p.get("secs", 0.0)) + float(p.get("tail", 0.0))
		out.append({"key": "kept:" + name, "name": name, "line": "%s  ·  %.1f s" % [String(ed.get("words", "")).left(60), secs],
			"tip": String(ed.get("words", "")), "shelf": "kept", "named": false,
			"sound": String(ed["wav"]) if FileAccess.file_exists(String(ed["wav"])) else "",
			"verbs": [{"key": "forget", "label": "Remove", "tip": "Take it out of your library, to the trash. Notes that use it keep their copy."}]})
	return out


func act(key: String, verb: String) -> String:
	if not key.begins_with("kept:") or verb != "forget":
		return "nothing here does that"
	return SoundLibrary.remove(key.substr(5))


func adds() -> Dictionary:
	if not picked.is_valid():
		return {}
	return {"label": "Use it", "verb": "Use it", "tip": "This kept sound is this sound's new version, heard from now on (the versions before it stay)."}


func add(key: String) -> String:
	if not key.begins_with("kept:"):
		return "only a kept sound can be used"
	if not picked.is_valid():
		return "no sound to use it on"
	picked.call(key.substr(5))
	return ""
