extends RefCounted
class_name TableProp

## TableProp - the table itself as a prop: its top, what holds it up and the cloths laid on it, as a person tunes them on a table
## show's Props card ([EpisodeProps]) and an agent refines them ([TableRefine]). Each property reads the table as it is made safe
## ([Tables]) and writes what the set dresser wrote (`table.json`'s `top` and `layers`), so the table stands as it did but for what
## was changed: its size, shape, corners, edge and thickness, what holds it up, what its top is made of and its finish; a cloth's
## fabric, pattern, colors, size and lie.
##
## Built alone for its picture and its 3D view ([method made]): the table whole on its base, the painting laid where it takes it.

## What a top can be told. Each row's `default` is replaced by what the table is now when it is shown ([method shown]).
const FIELDS := {
	"width": {"label": "Width (cm)", "blurb": "How wide the top is, side to side. A top too small to hold the cards is made larger.",
		"type": "float", "min": 60.0, "max": 360.0, "step": 1.0, "default": 190.0},
	"depth": {"label": "Depth (cm)", "blurb": "How deep the top is, front to back.", "type": "float", "min": 50.0, "max": 260.0,
		"step": 1.0, "default": 85.0},
	"shape": {"label": "Shape", "blurb": "The top's outline.", "type": "enum", "options": ["rect", "round", "oval", "polygon"],
		"labels": {"rect": "Rectangle", "round": "Round", "oval": "Oval", "polygon": "Many-sided"}, "default": "rect"},
	"corner": {"label": "Corners (cm)", "blurb": "How far a rectangle's corners are rounded.", "type": "float", "min": 0.0, "max": 60.0,
		"step": 0.5, "default": 0.0},
	"edge": {"label": "Edge", "blurb": "The profile its edge is cut to.", "type": "enum",
		"options": ["square", "eased", "bevel", "bullnose", "ogee", "bead"], "default": "eased"},
	"thickness": {"label": "Top (cm)", "blurb": "How thick the top is.", "type": "float", "min": 1.5, "max": 9.0, "step": 0.5,
		"default": 4.0},
	"base": {"label": "Base", "blurb": "What holds it up.", "type": "enum", "options": ["legs", "pedestal", "trestle", "none"],
		"labels": {"legs": "Four legs", "pedestal": "A pedestal", "trestle": "Trestles", "none": "None seen"}, "default": "legs"},
	"made": {"label": "Made of", "blurb": "What the top is made of: a material of its own, or the episode's painting.", "type": "enum",
		"options": ["wood", "stone", "metal", "ceramic", "leather", "fabric", "painted", "painting"],
		"labels": {"fabric": "Baize", "painted": "Lacquer", "painting": "The painting"}, "default": "wood"},
	"color": {"label": "Color", "blurb": "The top's color.", "type": "color", "default": "#5c3821"},
	"polish": {"label": "Polish", "blurb": "How much the top shines.", "type": "float", "min": 0.0, "max": 1.0, "step": 0.05,
		"default": 0.45},
	"wear": {"label": "Wear", "blurb": "How worn the top is.", "type": "float", "min": 0.0, "max": 1.0, "step": 0.05, "default": 0.0},
	"boards": {"label": "Boards (cm)", "blurb": "How wide a wooden top's boards are; 0 one slab.", "type": "float", "min": 0.0,
		"max": 60.0, "step": 1.0, "default": 0.0},
}
## What a cloth laid on the table can be told.
const CLOTH_FIELDS := {
	"fabric": {"label": "Fabric", "blurb": "What it is woven of.", "type": "enum",
		"options": ["linen", "cotton", "wool", "felt", "velvet", "silk", "brocade", "lace", "burlap"], "default": "cotton"},
	"pattern": {"label": "Pattern", "blurb": "What it is woven or dyed in.", "type": "enum",
		"options": ["plain", "stripes", "checks", "plaid", "diamonds", "dots", "medallion", "clouds", "ikat", "painting"],
		"labels": {"painting": "The painting"}, "default": "plain"},
	"color": {"label": "Color", "blurb": "Its first color: a plain cloth's only one.", "type": "color", "default": "#e8dcc0"},
	"color2": {"label": "Second color", "blurb": "The pattern's second color.", "type": "color", "default": "#3a2a20"},
	"scale": {"label": "Pattern size (cm)", "blurb": "How big the pattern is.", "type": "float", "min": 0.3, "max": 120.0, "step": 0.5,
		"default": 8.0},
	"width": {"label": "Width (cm)", "blurb": "How wide it is, before it is turned.", "type": "float", "min": 10.0, "max": 320.0,
		"step": 1.0, "default": 120.0},
	"depth": {"label": "Depth (cm)", "blurb": "How deep it is, before it is turned.", "type": "float", "min": 10.0, "max": 260.0,
		"step": 1.0, "default": 72.0},
	"turn": {"label": "Turn (°)", "blurb": "How far it is turned on the table: 45 a square laid as a diamond.", "type": "float",
		"min": -180.0, "max": 180.0, "step": 1.0, "default": 0.0},
	"fringe": {"label": "Fringe (cm)", "blurb": "Tassels on its two ends.", "type": "float", "min": 0.0, "max": 15.0, "step": 0.5,
		"default": 0.0},
	"sheen": {"label": "Sheen", "blurb": "How much light its threads draw out: velvet's, silk's.", "type": "float", "min": 0.0,
		"max": 1.0, "step": 0.05, "default": 0.5},
}


## What made-safe top [param top] ([method Tables.sanitize]) is, as [constant FIELDS] say it.
static func top_values(top: Dictionary) -> Dictionary:
	var look: Dictionary = top.get("look", {}) if top.get("look") is Dictionary else {}
	var size: Array = top.get("size", [190.0, 85.0])
	var painting := String(top.get("material", "")) == "painting"
	var kind := String(look.get("kind", "wood"))
	var boards: Dictionary = top.get("boards", {}) if top.get("boards") is Dictionary else {}
	return {"width": float(size[0]), "depth": float(size[1]), "shape": String(top.get("shape", "rect")),
		"corner": float(top.get("corner", 0.0)), "edge": String(top.get("edge", "eased")), "thickness": float(top.get("thickness", 4.0)),
		"base": String(top.get("base", "legs")),
		"made": "painting" if painting else (kind if (FIELDS["made"]["options"] as Array).has(kind) else "painted"),
		"color": String(look.get("color", FIELDS["color"]["default"])), "polish": float(look.get("polish", 0.45)),
		"wear": float(look.get("wear", 0.0)), "boards": float(boards.get("width", 0.0))}


## What made-safe cloth [param layer] is, as [constant CLOTH_FIELDS] say it.
static func cloth_values(layer: Dictionary) -> Dictionary:
	var p: Dictionary = layer.get("pattern", {}) if layer.get("pattern") is Dictionary else {}
	var colors: Array = p.get("colors", []) if p.get("colors") is Array else []
	var size: Array = layer.get("size", [120.0, 72.0])
	return {"fabric": String(layer.get("fabric", "cotton")), "pattern": String(p.get("kind", "plain")),
		"color": String(colors[0]) if colors.size() > 0 else String(CLOTH_FIELDS["color"]["default"]),
		"color2": String(colors[1]) if colors.size() > 1 else String(CLOTH_FIELDS["color2"]["default"]),
		"scale": float(p.get("scale", 8.0)), "width": float(size[0]), "depth": float(size[1]), "turn": float(layer.get("turn", 0.0)),
		"fringe": float(layer.get("fringe", 0.0)), "sheen": float(layer.get("sheen", 0.5))}


## The rows a person tunes top [param top] by: those that apply to it (a round top has no depth or corners, the painting no color
## or finish, a top of anything but wood no boards), each standing at what it is now.
static func top_rows(top: Dictionary) -> Dictionary:
	var now := top_values(top)
	var skip: Array = []
	if String(now["shape"]) == "round":
		skip.append("depth")
	if String(now["shape"]) != "rect":
		skip.append("corner")
	if String(now["made"]) == "painting":
		skip.append_array(["color", "polish", "wear"])
	if String(now["made"]) != "wood" and String(now["made"]) != "painting":
		skip.append("boards")
	return shown(FIELDS, now, skip)


## The rows a person tunes cloth [param layer] by: a cloth that is the top's own outline has no size of its own, a plain one no
## second color or pattern size, the painting no colors.
static func cloth_rows(layer: Dictionary) -> Dictionary:
	var now := cloth_values(layer)
	var skip: Array = []
	if String(layer.get("outline", "rect")) == "top":
		skip.append_array(["width", "depth"])
	if String(layer.get("outline", "rect")) != "rect":
		skip.append("fringe")
	if String(now["pattern"]) in ["plain", "painting"]:
		skip.append_array(["color2", "scale"])
	if String(now["pattern"]) == "painting":
		skip.append("color")
	return shown(CLOTH_FIELDS, now, skip)


## [param fields] but [param skip], each row's `default` what [param now] says it is.
static func shown(fields: Dictionary, now: Dictionary, skip: Array = []) -> Dictionary:
	var out := {}
	for k in fields:
		if skip.has(k):
			continue
		var row: Dictionary = (fields[k] as Dictionary).duplicate()
		row["default"] = now.get(k, row["default"])
		out[k] = row
	return out


## The top as written ([param raw], `table.json`'s; empty for the default) with property [param field] set to [param value] - read
## against what it is made safe now ([param made]) - as it is then written. A value of null leaves it as it is.
static func set_top(raw: Dictionary, made: Dictionary, field: String, value: Variant) -> Dictionary:
	var t: Dictionary = (raw if not raw.is_empty() else Tables.DEFAULT_TOP).duplicate(true)
	if value == null or not FIELDS.has(field):
		return t
	var now := top_values(made)
	match field:
		"width", "depth":
			var size := [float(now["width"]), float(now["depth"])]
			size[0 if field == "width" else 1] = float(value)
			if String(now["shape"]) == "round":
				size = [float(value), float(value)]
			t["size"] = size
		"shape", "edge", "base":
			t[field] = String(value)
		"corner", "thickness":
			t[field] = float(value)
		"boards":
			var b: Dictionary = made.get("boards", {}) if made.get("boards") is Dictionary else {}
			t["boards"] = {"width": float(value), "turn": float(b.get("turn", 0.0))}
		"made":
			# ...a material of its own, in the color it has now and its kind's own finish; or the painting
			t["material"] = "painting" if String(value) == "painting" else {"kind": String(value), "color": String(now["color"])}
		"color", "polish", "wear":
			var look: Dictionary = (made.get("look", {}) as Dictionary).duplicate(true) if made.get("look") is Dictionary else {}
			if String(made.get("material", "")) == "painting" or look.is_empty():
				look = {"kind": "painted", "color": String(now["color"])}
			look[field] = value
			if field == "color":
				look["color2"] = "#" + Color.html(String(value)).darkened(0.45).to_html(false)
			for k in ["density", "dissolves"]:
				look.erase(k)
			t["material"] = look
	return t


## The cloths as written ([param raw], `table.json`'s `layers`; null for the default cloth) with cloth [param i]'s property
## [param field] set to [param value] - read against the cloths made safe now ([param made]) - as they are then written.
static func set_cloth(raw: Variant, made: Array, i: int, field: String, value: Variant) -> Array:
	var ls: Array = (raw as Array).duplicate(true) if raw is Array else made.duplicate(true)
	if i < 0 or i >= ls.size() or i >= made.size() or value == null or not CLOTH_FIELDS.has(field) or not (ls[i] is Dictionary):
		return ls
	var l: Dictionary = ls[i]
	var now := cloth_values(made[i])
	var p: Dictionary = (l.get("pattern", {}) as Dictionary).duplicate(true) if l.get("pattern") is Dictionary else {}
	match field:
		"fabric":
			l["fabric"] = String(value)
		"pattern":
			p["kind"] = String(value)
			l["pattern"] = p
		"color", "color2":
			var colors: Array = [String(now["color"]), String(now["color2"])]
			var was: Array = ((made[i] as Dictionary).get("pattern", {}) as Dictionary).get("colors", [])
			for k in range(2, was.size()):
				colors.append(String(was[k]))
			colors[0 if field == "color" else 1] = String(value)
			p["colors"] = colors
			l["pattern"] = p
		"scale":
			p["scale"] = float(value)
			l["pattern"] = p
		"width", "depth":
			var size := [float(now["width"]), float(now["depth"])]
			size[0 if field == "width" else 1] = float(value)
			l["size"] = size
		"turn", "fringe", "sheen":
			l[field] = float(value)
	ls[i] = l
	return ls


## Whether two tables made safe have the same top and cloths.
static func same(a: Dictionary, b: Dictionary) -> bool:
	return JSON.stringify([a.get("top"), a.get("layers")], "", true) == JSON.stringify([b.get("top"), b.get("layers")], "", true)


## What made-safe top [param top] is, in a line.
static func line_of(top: Dictionary) -> String:
	var now := top_values(top)
	var shape := String((FIELDS["shape"]["labels"] as Dictionary).get(String(now["shape"]), now["shape"])).to_lower()
	var size := "%d cm" % roundi(float(now["width"])) if String(now["shape"]) == "round" \
		else "%d x %d cm" % [roundi(float(now["width"])), roundi(float(now["depth"]))]
	var made := String(now["made"])
	var of := "the painting" if made == "painting" else String((FIELDS["made"]["labels"] as Dictionary).get(made, made)).to_lower()
	var base := String((FIELDS["base"]["labels"] as Dictionary).get(String(now["base"]), now["base"])).to_lower()
	return "a %s %s of %s, on %s" % [size, shape, of, base] if String(now["base"]) != "none" else "a %s %s of %s" % [size, shape, of]


## What made-safe cloth [param layer] is, in a line: what the set dresser said it is, or its fabric and pattern.
static func cloth_line(layer: Dictionary) -> String:
	var what := String(layer.get("what", "")).strip_edges()
	if not what.is_empty():
		return what
	var now := cloth_values(layer)
	return "%s, %s" % [now["fabric"], now["pattern"]]


## The table made safe as [param spec] (`{top, layers}`), built alone on its base for a picture and the 3D view, its grain drawn
## from [param seed], the painting at [param painting] laid where it takes it: `{node, size}`, standing on the floor at y 0 (a
## top with no base, its lowest point there). Built out of any tree: a worker's.
static func made(spec: Dictionary, seed: int, painting := "") -> Dictionary:
	var built := Tables.build(spec, seed)
	if not painting.is_empty() and FileAccess.file_exists(painting) and not (built["painted"] as Array).is_empty():
		var img := Image.load_from_file(painting)
		if img != null and not img.is_empty():
			img.generate_mipmaps()
			Tables.apply_painting(built, ImageTexture.create_from_image(img))
	var b: AABB = built["bounds"]
	var top: Dictionary = spec.get("top", {})
	var ground := -Tables.HIGH if String(top.get("base", "legs")) != "none" else minf(b.position.y, 0.0)
	var box := b.merge(AABB(Vector3(b.position.x, ground, b.position.z), Vector3(b.size.x, 0.001, b.size.z)))
	var node: Node3D = built["node"]
	node.position.y = -ground
	return {"node": node, "size": AABB(box.position - Vector3(0.0, ground, 0.0), box.size)}


## What a table made safe as [param spec] drawn from [param seed], with the painting whose digest is [param painting], is - as a
## short hash: its picture's name.
static func hash_of(spec: Dictionary, seed: int, painting := "") -> String:
	return ("table prop " + JSON.stringify([spec.get("top", {}), spec.get("layers", []), seed, painting], "", true)).sha256_text().left(16)


## The table [param spec] built on a worker ([method made]), waited for: `{node, size}`.
static func made_away(spec: Dictionary, seed: int, painting := "") -> Dictionary:
	var out := [{}]
	var task := WorkerThreadPool.add_task(func() -> void: out[0] = made(spec, seed, painting), false, "a table pictured")
	var tree := Engine.get_main_loop() as SceneTree
	while not WorkerThreadPool.is_task_completed(task):
		await tree.process_frame
	WorkerThreadPool.wait_for_task_completion(task)
	return out[0]
