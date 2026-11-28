extends RefCounted
class_name PopupDesign

## PopupDesign - how a pop-up book's spreads are made, layer by layer ([PopupMedium]): the note's own, kept in its folder as JSON
## ([constant FILE], [method folder_of]) and carried to the book in the reading's document (`popup`). Written by the paper
## engineer ([PopupEngineer]), who makes each scene from the script's brief for it (`<!-- spread: -->`) in layers of its own:
## each layer is a picture of its own words (painted as [method pictures_of] says) standing as a piece of card does.
##
##     {"spreads": [                                one a scene, in order
##         {"back": LAYER,                          the scenery, standing whole behind everything (a theater's flat)
##          "floor": {"picture": "..."},            printed flat on both pages under the pieces, seen from above
##          "pieces": [LAYER, ...]}]}               cut-outs, farthest back first (at most [constant MOST])
##
##     LAYER  {"picture": "a crowd, seen ...",      what is painted for it: a cut-out on magenta, the scenery whole
##             "z": -0.2,                           depth of the crease on the spine (page units; + toward the reader)
##             "x": 0.0,                            ...and across from it (0: on the spine)
##             "height": 0.45,                      how tall it stands at most (a page is 1 wide, 1.5 deep)
##             "folds": [0.5],                      where the picture is creased, as fractions across it
##             "turns": [-18, 18],                  each panel turned from facing the reader (degrees; + its right end back)
##             "at": 1,                             which crease (0 the left edge, folds.size() + 1 the right) is on the spine
##             "aspect": 2.4}                       the scenery's shape (width / height), its picture cropped to it
##
## A scene the design says nothing of stands what the script's own picture marks say, if any (`<!-- image: -->` its scenery,
## `<!-- popup: -->` its cut-outs).

## The most cut-outs a designed spread stands (beside its scenery and floor).
const MOST := 5
const FILE := "popup.json"


## Where note [param note]'s design is kept ("" for a note with no file).
static func path_of(note: String) -> String:
	var dir := folder_of(note)
	return "" if dir.is_empty() else dir.path_join(FILE)


## Note [param note]'s own folder ([method NoteUpload.folder_of], reached by path: what it compiles with reads the show,
## which a bare gate has none of).
static func folder_of(note: String) -> String:
	if note.is_empty():
		return ""
	return String((load("res://src/reading/note_upload.gd") as GDScript).call("folder_of", note))


## Note [param note]'s design, {} where it has none (or none that reads).
static func load_of(note: String) -> Dictionary:
	var p := path_of(note)
	if p.is_empty() or not FileAccess.file_exists(p):
		return {}
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(p))
	return v if v is Dictionary else {}


## [param design] kept as note [param note]'s. "" done, else why not. Never from a process that may not write the author's things.
static func save(note: String, design: Dictionary) -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var st: Node = tree.root.get_node_or_null("Settings") if tree != null else null
	# Settings by name, so this loads in a bare gate where no autoload is; with none, nothing may be written
	if st == null or bool(st.call("is_read_only")):
		return "this process may not write the author's things"
	var p := path_of(note)
	if p.is_empty():
		return "the note has no file"
	DirAccess.make_dir_recursive_absolute(p.get_base_dir())
	var f := FileAccess.open(p, FileAccess.WRITE)
	if f == null:
		return "could not write %s" % p
	f.store_string(JSON.stringify(design, "\t"))
	f.close()
	return ""


## The scene [param scene]'s entry in [param design], {} for none.
static func scene_of(design: Dictionary, scene: int) -> Dictionary:
	var spreads: Variant = design.get("spreads")
	if not (spreads is Array) or scene < 0 or scene >= (spreads as Array).size() or not ((spreads as Array)[scene] is Dictionary):
		return {}
	return (spreads as Array)[scene]


## Whether scene entry [param entry] makes its own layers (any of them a picture of its own words).
static func layered(entry: Dictionary) -> bool:
	if entry.get("back") is Dictionary and not String((entry["back"] as Dictionary).get("picture", "")).is_empty():
		return true
	if entry.get("floor") is Dictionary and not String((entry["floor"] as Dictionary).get("picture", "")).is_empty():
		return true
	for p in (entry.get("pieces", []) if entry.get("pieces") is Array else []):
		if p is Dictionary and not String((p as Dictionary).get("picture", "")).is_empty():
			return true
	return false


## A layer's picture, as the library keys it: [param role] "back", "floor" or "piece", painted from [param words].
static func key_of(role: String, words: String) -> String:
	return Manuscript.image_key({"back": "scenery: ", "floor": "floor: "}.get(role, "popup: ") + words.strip_edges())


## What a layer of [param role] is painted as ([method Illustrations.placement_guide]).
static func placement_of(role: String) -> String:
	return {"back": Illustrations.SPREAD, "floor": Illustrations.FLOOR}.get(role, Illustrations.POPUP)


## Every picture [param design]'s layers are painted from: `[{key, prompt, placement, scene, layer}]` (`layer` "back",
## "floor" or "piece N"), each picture once.
static func pictures_of(design: Dictionary) -> Array:
	var out: Array = []
	var seen := {}
	var spreads: Array = design.get("spreads", []) if design.get("spreads") is Array else []
	for n in spreads.size():
		var entry: Dictionary = spreads[n] if spreads[n] is Dictionary else {}
		var layers: Array = []
		for role in ["back", "floor"]:
			if entry.get(role) is Dictionary:
				layers.append([role, role, entry[role]])
		var pieces: Array = entry.get("pieces", []) if entry.get("pieces") is Array else []
		for i in mini(pieces.size(), MOST):
			if pieces[i] is Dictionary:
				layers.append(["piece", "piece %d" % i, pieces[i]])
		for l in layers:
			var words := String((l[2] as Dictionary).get("picture", "")).strip_edges()
			if words.is_empty():
				continue
			var key := key_of(String(l[0]), words)
			if seen.has(key):
				continue
			seen[key] = true
			out.append({"key": key, "prompt": words, "placement": placement_of(String(l[0])), "scene": n, "layer": l[1]})
	return out
