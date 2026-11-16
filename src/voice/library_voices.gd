extends ShelfSection
class_name LibraryVoices

## LibraryVoices - the voices kept for every note on the Dex's shelves ([DexWindow], [VoiceLibrary]): each heard from its sample
## (the opening of the Test passage said once in it), renamed in place, exported to a `.voice.json` to hand on, or removed to the
## trash; Import takes such a file in. A voice with no sample yet is said once on asking, by whatever can say it ([member
## VoiceLibrary.maker], the Voice card). Its shelf is read again when the library is written ([member VoiceLibrary.version]).

const SHELVES := [{"key": "kept", "label": "Kept voices", "tip": "The voices in your library, kept from any note's Voice card: every note can read in one by name."}]

var _entries: Array = []
var _version := -1


func title() -> String:
	return "Voices"


func version() -> int:
	return VoiceLibrary.version


func shelves() -> Array:
	return SHELVES


func file_kind() -> Dictionary:
	return {"ext": VoiceLibrary.EXPORT, "label": "Voices"}


func offers() -> Array:
	var out: Array = []
	for e in _read():
		var ed: Dictionary = e
		var name := String(ed["name"])
		var voice: Dictionary = ed["voice"]
		var path := VoiceLibrary.sample_path(voice)
		var heard := FileAccess.file_exists(path)
		var verbs: Array = []
		if not heard:
			verbs.append({"key": "say", "label": "Say it", "tip": "Have it say a few lines once, to hear it from here on."})
		verbs.append({"key": "forget", "label": "Remove", "tip": "Take it out of your library, to the trash. Notes that read in it keep their copy."})
		out.append({"key": "kept:" + name, "name": name, "line": String(ed.get("line", "")) if not String(ed.get("line", "")).is_empty() else _said(voice),
			"tip": _said(voice), "shelf": "kept", "named": true, "sound": path if heard else "", "verbs": verbs})
	return out


func act(key: String, verb: String) -> String:
	if not key.begins_with("kept:"):
		return "nothing here does that"
	var name := key.substr(5)
	match verb:
		"forget":
			if not Library.writable():
				return "this session is read-only"
			return VoiceLibrary.remove(name)
		"say":
			if not VoiceLibrary.maker.is_valid():
				return "open a note's Voice card to have it said"
			VoiceLibrary.sample(name)
			return "saying it - Hear is ready once it has been said"
	return "nothing here does that"


func rename(key: String, name: String) -> String:
	if not key.begins_with("kept:"):
		return "only a kept voice can be renamed"
	if not Library.writable():
		return "this session is read-only"
	var was := key.substr(5)
	return VoiceLibrary.rename(was, name, String(VoiceLibrary.read(was).get("line", "")))


func exportable(key: String) -> bool:
	return key.begins_with("kept:")


func export_to(key: String, path: String) -> String:
	return VoiceLibrary.export_to(key.substr(5), path) if key.begins_with("kept:") else "only a kept voice can be exported"


func import_from(path: String) -> String:
	if not Library.writable():
		return "this session is read-only"
	var why: Array = []
	var name := VoiceLibrary.import_from(path, why)
	return "" if not name.is_empty() else "; ".join(PackedStringArray(why))


## The voices kept, read again when the library has been written since.
func _read() -> Array:
	if _version != VoiceLibrary.version or _entries.is_empty():
		_entries = VoiceLibrary.entries()
		_version = VoiceLibrary.version
	return _entries


## What [param voice] is, in a few words: its model and reader, and its pace where it is not even.
static func _said(voice: Dictionary) -> String:
	var bits := PackedStringArray()
	var model := String(voice.get("voice", ""))
	if not model.is_empty():
		bits.append(model)
	if String(voice.get("blend", "")).length() > 0:
		bits.append("blended")
	if voice.get("formant") is Dictionary and not (voice["formant"] as Dictionary).is_empty():
		bits.append("formant")
	var pace := float(voice.get("pace", 1.0))
	if absf(pace - 1.0) > 0.02:
		bits.append("pace %.2f" % pace)
	return ", ".join(bits)
