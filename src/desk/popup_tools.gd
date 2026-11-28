extends RefCounted
class_name PopupTools

## PopupTools - what the paper engineer ([PopupEngineer]) can do while it makes a pop-up book's spreads in layers: read each
## scene (its words and the script's brief for its spread), stand a scene's layers - each a picture of its own words, painted
## as a cut-out, as scenery or as a floor ([PopupDesign]) - wait while new paintings land, look at the spread as the show sees it
## and from above and the side ([PopupStudio]), and refine one layer's painting with only what it asks changed. The design is
## kept at each change and handed to a playing book at once. The script's words are never touched. Served as tools
## ([AgentTools]).

## The studio that photographs a spread, by path: loaded when a look is asked for (it draws through the app's own stage, which
## a bare gate has none of).
const STUDIO := "res://src/desk/popup_studio.gd"
## The views a look may ask for ([PopupStudio]).
const VIEWS := ["front", "above", "side"]
## The longest one wait may be (seconds): an agent's call is given ten minutes.
const WAIT_MOST := 300

## The note's path: its design is kept in its folder.
var note := ""
## The note's words as they stand: `func() -> String`.
var body: Callable
## The reading's document the book draws (its desk, its light), `func() -> Dictionary`; the design is set in it as it changes.
var document: Callable
## A picture asked for: `func(image: Dictionary) -> String` (`{key, prompt, placement}`), "" queued, else why not.
var paint: Callable = Illustrations.generate
## A picture painted again with only [param ask] changed: `func(image: Dictionary, ask: String) -> String`.
var redo: Callable = Illustrations.refine
## Where a picture is: `func(key: String) -> String`, Illustrations' status ("missing", "queued", "running", "ready", "error").
var state: Callable = Illustrations.status
## The design as it stands.
var design := {}
var _shapes := {}                # picture key -> width / height of its painting


func instructions() -> String:
	return ("scenes says every scene's words, brief and layers; stand sets a scene's layers and has new pictures painted; wait "
		+ "lets them land; look renders the spread; refine repaints one layer with only what you ask changed. Look after every change.")


func list_tools() -> Array:
	var layer := {"type": "object", "properties": {
		"picture": {"type": "string"}, "z": {"type": "number"}, "x": {"type": "number"}, "height": {"type": "number"},
		"folds": {"type": "array", "items": {"type": "number"}}, "turns": {"type": "array", "items": {"type": "number"}},
		"at": {"type": "integer"}, "aspect": {"type": "number"}, "hidden": {"type": "boolean"}}}
	return [
		{"name": "scenes", "description": "Every scene: its words, the script's brief for its spread, and its layers as they stand (each one's picture, whether it is painted, and its shape, width over height).",
			"inputSchema": {"type": "object", "properties": {}}},
		{"name": "stand", "description": "Set scene `scene`'s layers: `back` its scenery, `floor` a floor printed flat under everything ({\"picture\": ...} only), `pieces` its cut-outs farthest back first, at most %d. Each layer's `picture` is what is painted for it; a picture not painted yet is painted now (a minute or two each). A layer left out is kept as it was; an empty `pieces` list stands none. Answers with how each layer stands." % PopupDesign.MOST,
			"inputSchema": {"type": "object", "properties": {"scene": {"type": "integer"}, "back": layer, "floor": layer,
				"pieces": {"type": "array", "items": layer}}, "required": ["scene"]}},
		{"name": "wait", "description": "Wait until scene `scene`'s pictures are painted, or `seconds` (at most %d) pass; says what landed and what failed." % WAIT_MOST,
			"inputSchema": {"type": "object", "properties": {"scene": {"type": "integer"}, "seconds": {"type": "number"}},
				"required": ["scene"]}},
		{"name": "look", "description": "Render scene `scene`'s spread open, as the show sees it from in front and above (`front`), from straight above (`above`) and from its right side (`side`). `views` picks which (all three by default). A layer not painted yet stands as a plain card.",
			"inputSchema": {"type": "object", "properties": {"scene": {"type": "integer"},
				"views": {"type": "array", "items": {"type": "string"}}}, "required": ["scene"]}},
		{"name": "refine", "description": "Paint one layer of scene `scene` again with only `ask` changed (its composition kept): `layer` is \"back\", \"floor\" or the number of its cut-out (0 the farthest back). Its place in the design stays.",
			"inputSchema": {"type": "object", "properties": {"scene": {"type": "integer"}, "layer": {"type": "string"},
				"ask": {"type": "string"}}, "required": ["scene", "layer", "ask"]}},
	]


func call_tool(tool: String, args: Dictionary) -> Dictionary:
	var words := String(body.call()) if body.is_valid() else ""
	if words.is_empty():
		return {"error": "The note is closed: the author has left it. Stop here."}
	match tool:
		"scenes":
			return {"text": scenes_text(words)}
		"stand":
			return _stand(words, args)
		"wait":
			return await _wait(words, args)
		"look":
			return await _look(words, args)
		"refine":
			return _refine(words, args)
	return {"error": "no tool '%s'" % tool}


## Every scene of [param words] as the engineer is told it: its words, its brief and its layers as they stand.
func scenes_text(words: String) -> String:
	var out := PackedStringArray()
	for sc in _scenes(words):
		var d: Dictionary = sc
		var n := int(d["index"])
		out.append("SCENE %d" % n)
		out.append("Words: %s" % String(d["words"]))
		if not String(d["brief"]).is_empty():
			out.append("Brief: %s" % String(d["brief"]))
		for m in d["marks"]:
			out.append("The script's own picture (%s): \"%s\"" % [String(m["role"]), String(m["prompt"])])
		var entry := PopupDesign.scene_of(design, n)
		if not PopupDesign.layered(entry):
			out.append("Layers: none yet.")
		else:
			for l in _layers(n):
				out.append("Layer %s: \"%s\" (%s) %s" % [String(l["layer"]), String(l["prompt"]), _painted_said(String(l["key"])),
					JSON.stringify(_geometry(l["piece"]))])
		out.append("")
	return "\n".join(out)


func _painted_said(key: String) -> String:
	var st := String(state.call(key)) if state.is_valid() else "missing"
	var shape := _shape_of(key)
	if st == "ready" and shape > 0.0:
		return "painted, %.2f wide for each of its tall" % shape
	return {"queued": "waiting to be painted", "running": "being painted", "error": "its painting failed"}.get(st, "not painted")


## A layer's design without its picture's words, for the listing.
static func _geometry(piece: Dictionary) -> Dictionary:
	var g := piece.duplicate()
	g.erase("picture")
	return g


## The scenes of [param words]: `[{index, words, brief, marks}]` - `marks` the script's own pictures, `{role, prompt}`.
func _scenes(words: String) -> Array:
	var blocks := Manuscript.blocks(Manuscript.read_part(words)).filter(func(b: Dictionary) -> bool:
		return String(b.get("placement", "")) != "cover")
	var out: Array = []
	var i := 0
	for sc in PopupLayout.scenes_of(blocks):
		var said := PackedStringArray()
		for b in sc["text"]:
			said.append(String((b as Dictionary).get("text", "")))
		var brief: Array = sc.get("brief", [])
		var marks: Array = []
		for b in sc["art"]:
			marks.append({"role": "floor" if String(b.get("placement", "")) == "floor" else "scenery", "prompt": String(b["prompt"])})
		for b in sc["pops"]:
			marks.append({"role": "cut-out", "prompt": String(b["prompt"])})
		out.append({"index": i, "words": " ".join(said), "brief": String((brief[0] as Dictionary)["prompt"]) if not brief.is_empty() else "",
			"marks": marks})
		i += 1
	return out


## Scene [param n]'s layers as the design has them: `[{layer, role, key, prompt, placement, piece}]`, scenery and floor first.
func _layers(n: int) -> Array:
	var entry := PopupDesign.scene_of(design, n)
	var out: Array = []
	for role in ["back", "floor"]:
		if entry.get(role) is Dictionary and not String((entry[role] as Dictionary).get("picture", "")).is_empty():
			out.append(_layer(role, role, entry[role]))
	var pieces: Array = entry.get("pieces", []) if entry.get("pieces") is Array else []
	for i in mini(pieces.size(), PopupDesign.MOST):
		if pieces[i] is Dictionary and not String((pieces[i] as Dictionary).get("picture", "")).is_empty():
			out.append(_layer("piece", str(i), pieces[i]))
	return out


static func _layer(role: String, name: String, piece: Dictionary) -> Dictionary:
	var words := String(piece["picture"]).strip_edges()
	return {"layer": name, "role": role, "key": PopupDesign.key_of(role, words), "prompt": words,
		"placement": PopupDesign.placement_of(role), "piece": piece}


## Width over height of the painting [param key] is, 0 for none painted.
func _shape_of(key: String) -> float:
	if _shapes.has(key):
		return float(_shapes[key])
	var path := Illustrations.path_for(key)
	if path.is_empty():
		return 0.0
	var img := Image.load_from_file(path)
	if img == null or img.is_empty():
		return 0.0
	_shapes[key] = float(img.get_width()) / float(maxi(img.get_height(), 1))
	return float(_shapes[key])


func _stand(words: String, args: Dictionary) -> Dictionary:
	var count := _scenes(words).size()
	var n := int(args.get("scene", -1))
	if n < 0 or n >= count:
		return {"error": "There is no scene %d: they run 0 to %d." % [n, count - 1]}
	var spreads: Array = design.get("spreads", []) if design.get("spreads") is Array else []
	while spreads.size() <= n:
		spreads.append({})
	var entry: Dictionary = (spreads[n] as Dictionary).duplicate(true) if spreads[n] is Dictionary else {}
	for role in ["back", "floor"]:
		if args.get(role) is Dictionary:
			entry[role] = args[role]
	if args.get("pieces") is Array:
		var pieces: Array = (args["pieces"] as Array).filter(func(p: Variant) -> bool: return p is Dictionary)
		if pieces.size() > PopupDesign.MOST:
			return {"error": "A spread stands at most %d cut-outs; %d were given." % [PopupDesign.MOST, pieces.size()]}
		entry["pieces"] = pieces
	spreads[n] = entry
	design["spreads"] = spreads
	_keep()
	var asked := 0
	var said := PackedStringArray()
	var words_z := (PopupLayout.TEXT_TOP - 0.5) * BookMedium.PAGE_H - 0.02
	for l in _layers(n):
		var key := String(l["key"])
		var st := String(state.call(key)) if state.is_valid() else "missing"
		if st == "missing" or st == "error":
			var why := String(paint.call({"key": key, "prompt": l["prompt"], "placement": l["placement"]})) if paint.is_valid() else "nothing paints here"
			if why.is_empty():
				asked += 1
			else:
				said.append("Layer %s's picture was not asked for: %s" % [String(l["layer"]), why])
		if String(l["role"]) == "floor":
			said.append("Layer floor: printed flat across the band above the words")
			continue
		var shape := _shape_of(key)
		var p: Dictionary = l["piece"]
		var aspect := maxf(float(p.get("aspect", PopupMedium.SCENERY["aspect"])), 0.3) if String(l["role"]) == "back" else (shape if shape > 0.0 else 0.8)
		said.append("Layer %s: %s" % [String(l["layer"]), _stood(p, aspect, words_z, shape <= 0.0 and String(l["role"]) != "back")])
	var head := "Scene %d stands so (kept)" % n
	if asked > 0:
		head += "; %d new picture%s being painted - wait, then look" % [asked, "" if asked == 1 else "s"]
	return {"text": "%s:\n%s" % [head, "\n".join(said)]}


## How piece [param p] stands for a picture [param shape] wide for each of its tall, in words.
func _stood(p: Dictionary, shape: float, words_z: float, guessed: bool) -> String:
	if bool(p.get("hidden", false)):
		return "lying flat, unseen"
	if not p.has("z") or not p.has("height"):
		return "where the book puts it (give z and height to place it)"
	var fp := PopupMedium.footprint(p, shape, words_z)
	var h := float(fp["height"])
	var asked := float(p.get("height", 0.4))
	var feet := PackedStringArray()
	for f in (fp["feet"] as PackedVector2Array):
		feet.append("(%.2f, %.2f)" % [f.x, f.y])
	var line := "%.2f tall, its creases' feet at %s" % [h, ", ".join(feet)]
	if guessed:
		line += " (its painting's shape guessed until it is painted)"
	if h < asked - 0.005:
		line += " - made smaller than the %.2f asked, to stay inside the page, off the words and fold flat" % asked
	return line


func _wait(words: String, args: Dictionary) -> Dictionary:
	var n := int(args.get("scene", -1))
	if n < 0 or n >= _scenes(words).size():
		return {"error": "There is no scene %d." % n}
	var until := Time.get_ticks_msec() + int(clampf(float(args.get("seconds", 120.0)), 1.0, float(WAIT_MOST)) * 1000.0)
	var tree := Engine.get_main_loop() as SceneTree
	while Time.get_ticks_msec() < until:
		var waiting := false
		for l in _layers(n):
			var st := String(state.call(String(l["key"]))) if state.is_valid() else "ready"
			if st == "queued" or st == "running":
				waiting = true
		if not waiting:
			break
		await tree.process_frame
	var said := PackedStringArray()
	for l in _layers(n):
		var key := String(l["key"])
		var st := String(state.call(key)) if state.is_valid() else "ready"
		var line := "Layer %s: %s" % [String(l["layer"]), _painted_said(key)]
		if st == "error":
			line += " - %s" % Illustrations.error_of(key)
		said.append(line)
	return {"text": "\n".join(said)}


func _look(words: String, args: Dictionary) -> Dictionary:
	var n := int(args.get("scene", -1))
	if n < 0 or n >= _scenes(words).size():
		return {"error": "There is no scene %d." % n}
	if DisplayServer.get_name() == "headless":
		return {"text": "This session can take no pictures."}
	var views: Array = []
	for v in (args.get("views", VIEWS) as Array):
		if VIEWS.has(String(v)):
			views.append(String(v))
	if views.is_empty():
		views = VIEWS.duplicate()
	var doc: Dictionary = (document.call() as Dictionary).duplicate() if document.is_valid() else {}
	doc["source"] = words
	doc["title"] = FrontMatter.field_of(words, "title")
	doc["popup"] = design
	var images: Array = await (load(STUDIO) as GDScript).call("look", doc, n, views)
	return {"text": "Scene %d's spread, from %s." % [n, ", ".join(views)], "images": images}


func _refine(words: String, args: Dictionary) -> Dictionary:
	var n := int(args.get("scene", -1))
	if n < 0 or n >= _scenes(words).size():
		return {"error": "There is no scene %d." % n}
	var which := String(args.get("layer", "")).strip_edges()
	var found: Dictionary = {}
	for l in _layers(n):
		if String(l["layer"]) == which:
			found = l
	if found.is_empty():
		return {"error": "Scene %d has no layer \"%s\"." % [n, which]}
	if String(state.call(String(found["key"]))) != "ready":
		return {"error": "Layer %s is not painted yet: wait for it first." % which}
	var ask := String(args.get("ask", "")).strip_edges()
	if ask.is_empty():
		return {"error": "Say what to change."}
	var why := String(redo.call({"key": found["key"], "prompt": found["prompt"], "placement": found["placement"]}, ask)) if redo.is_valid() else "nothing paints here"
	if not why.is_empty():
		return {"error": why}
	return {"text": "Layer %s is being painted again with that changed - wait, then look." % which}


## The design kept as the note's, and handed to a playing book.
func _keep() -> void:
	if not note.is_empty():
		var err := PopupDesign.save(note, design)
		if not err.is_empty():
			push_warning("ghost: popup design - %s" % err)
	if document.is_valid():
		var doc: Variant = document.call()
		if doc is Dictionary:
			(doc as Dictionary)["popup"] = design
