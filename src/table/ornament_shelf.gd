extends ShelfSection
class_name OrnamentShelf

## OrnamentShelf - the ornaments kept in the library on the Dex's shelves ([DexWindow], [OrnamentLibrary]; next/surfaces.md), under
## Surfaces. A tile makes a new one: Make… opens its Refine… window ([OrnamentDesign]), where the author says what it is and a
## designer writes it, renders it and shows it. Each kept ornament shows its swatch (a turned vase and a plaque wearing it,
## [method OrnamentLibrary.swatch]), its words and which version is used; Refine… asks for a change, ‹ and › step through its versions
## (the one shown is what every prop wearing it draws), its name is changed in place, Remove takes it to the trash. A prop wears one
## by its name ([Props] `ornament`).

const SHELVES := [{"key": "kept", "label": "Ornaments", "tip": "Ornament written by a designer, worn on any prop by its name: relief, and where a color is laid in it."}]

var pictures := PropPictures.new()


func title() -> String:
	return "Ornaments"


func category() -> String:
	return "Surfaces"


func version() -> int:
	return OrnamentLibrary.version


func shelves() -> Array:
	return SHELVES


func offers() -> Array:
	var out: Array = [{"key": "new", "name": "A new ornament", "shelf": "kept",
		"line": "Say what it is: a designer writes it, renders it and shows it to you.",
		"tip": "Make an ornament from your words. Each version the designer makes is kept; the one shown is used.",
		"verbs": [{"key": "make", "label": "Make…", "tip": "Open a conversation with a designer about a new ornament."}]}]
	for e in OrnamentLibrary.entries():
		var ed: Dictionary = e
		var name := String(ed["name"])
		var n := (ed["versions"] as Array).size()
		var used := int(ed["used"])
		var busy := OrnamentDesign._open.has(name) and (OrnamentDesign._open[name] as OrnamentDesign).busy()
		var line := String(ed["words"]).left(80)
		line += ("  ·  " if not line.is_empty() else "") + ("version %d of %d" % [used + 1, n] if n > 0 else "nothing made yet")
		if busy:
			line += "  ·  the designer is at work"
		out.append({"key": "kept:" + name, "name": name, "named": true, "shelf": "kept", "line": line, "tip": String(ed["words"]),
			"picture": _picture(String(ed["code"])),
			"verbs": [{"key": "refine", "label": "Refine…", "tip": "Ask the designer for a change: a new version, kept beside the others."},
				{"key": "older", "label": "‹", "tip": "Use the version before this one.", "off": used <= 0},
				{"key": "newer", "label": "›", "tip": "Use the version after this one.", "off": used >= n - 1},
				{"key": "forget", "label": "Remove", "tip": "Take it out of your library, to the trash. A prop wearing it by its name wears none."}]})
	return out


func act(key: String, verb: String) -> String:
	if key == "new" and verb == "make":
		var name := OrnamentLibrary.make()
		if name.is_empty():
			return "this session cannot write the library"
		OrnamentDesign.of(name).open()
		return ""
	if not key.begins_with("kept:"):
		return "nothing here does that"
	var name := key.substr(5)
	var e := OrnamentLibrary.find(name)
	if e.is_empty():
		return "%s is not in the library" % name
	match verb:
		"refine":
			OrnamentDesign.of(name).open()
			return ""
		"older", "newer":
			var i := int(e["used"]) + (-1 if verb == "older" else 1)
			var err := OrnamentLibrary.use_version(name, i)
			if err.is_empty() and OrnamentDesign._open.has(name) and not (OrnamentDesign._open[name] as OrnamentDesign).busy():
				(OrnamentDesign._open[name] as OrnamentDesign).draft = OrnamentLibrary.code_of(name)
			return err
		"forget":
			OrnamentDesign.forget(name)
			return OrnamentLibrary.remove(name)
	return "nothing here does that"


func rename(key: String, new_name: String) -> String:
	if not key.begins_with("kept:"):
		return "only a kept ornament can be renamed"
	var name := key.substr(5)
	if OrnamentDesign._open.has(name) and (OrnamentDesign._open[name] as OrnamentDesign).busy():
		return "the designer is at work on it: rename it once it is done"
	OrnamentDesign.forget(name)
	return OrnamentLibrary.rename(name, new_name)


func want_pictures(keys: Array) -> void:
	pictures.want(_asked(keys))


func prepare_pictures(keys: Array) -> void:
	pictures.prepare(_asked(keys))


func picture(key: String) -> Variant:
	if not key.begins_with("kept:"):
		return null
	return _picture(OrnamentLibrary.code_of(key.substr(5)))


## The swatch of [param code] once taken, null until then ([PropPictures]; asked for when it is wanted).
func _picture(code: String) -> Variant:
	if code.is_empty():
		return null
	var sw := OrnamentLibrary.swatch(code)
	return pictures.image(ThingLibrary.hash_of(sw["thing"], sw["materials"]))


## The swatches of offers [param keys], as [PropPictures] is asked for them: each `[hash, thing, materials]`.
func _asked(keys: Array) -> Array:
	var out: Array = []
	for k in keys:
		if not String(k).begins_with("kept:"):
			continue
		var code := OrnamentLibrary.code_of(String(k).substr(5))
		if code.is_empty():
			continue
		var sw := OrnamentLibrary.swatch(code)
		out.append([ThingLibrary.hash_of(sw["thing"], sw["materials"]), sw["thing"], sw["materials"]])
	return out
