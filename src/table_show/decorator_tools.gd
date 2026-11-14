extends RefCounted
class_name DecoratorTools

## DecoratorTools - the decorator's tools (next/painted_surface.md): what is painted at the table this episode, designed as
## elements on the surface it goes on - written, seen there, and handed in. Served over ghost's MCP server ([AgentTools]) to a
## writer that takes tools; one that cannot hands the design in in one reply ([TableProducer]).
##
## A design is seen before it is handed in: `look` draws it on the processor ([method Skins.look]: the bare surface shaded, every
## element in its paint, a millimeter grid, the outline and the landmarks).

const SUBMITTED := "submitted.json"
const LOOKS := 24
const JUDGE := "Say what the picture actually shows: does each shape sit where you meant it on the surface - against the grid (a line every 10 mm, brighter every 50) and the landmarks (red rings) - are the two sides alike where they should be, does it read from across a room, and is it as elaborate and as beautiful as the plan asks? Write again what does not."
## How much of an element may lie off the surface before `submit` asks once.
const OFF_MOST := 0.35
## How little an element may differ from what it is laid over, in any of red, green and blue (0-1), in the same finish, before it is
## said to be hardly seen (a base nearly the color of the bare mask shows nothing).
const UNSEEN := 0.08

const RESUME_FIELDS := ["_raw", "_looks", "_warned", "reference", "submitted"]

var dir := ""
var submitted := false
## The face painted first that the first surface's design copies (`face_ref.png`, [method Skins.face_reference]; "" none): each look of it
## shows the painting beside it.
var reference := ""
## The skins the table has ([method Skins.skins_of]).
var skins: Array = []

var _raw := {}               # skin index -> {name, elements: [...]} as written
var _looks := 0
var _busy := false
var _released := false
var _warned := false


func _init(job_dir: String, table_skins: Array, keep := false) -> void:
	dir = job_dir
	skins = table_skins
	DirAccess.make_dir_recursive_absolute(dir)
	if keep:
		return
	for f in DirAccess.get_files_at(dir):
		var fs := String(f)
		if fs == SUBMITTED or fs == "tools.jsonl" or (fs.begins_with("look_") and fs.ends_with(".jpg")):
			DirAccess.remove_absolute(dir.path_join(fs))


func release() -> void:
	_released = true


func looks_used() -> int:
	return _looks


func instructions() -> String:
	return "Tools for designing what is painted at the table this episode: write its elements, see them on the surface they go on, and hand the design in."


func list_tools() -> Array:
	return [
		{"name": "design", "description": "Write the design, or any of its elements: give `elements` (each {id, stage, paint, finish, opacity, soft, and one of fill, line + width, dots, stones}); one with the id of an element already there replaces it where it stands, a new one goes at the end - the order is the order they go on. `name` names the design; `remove` takes elements out by id; `on` says which surface, where the table has more than one. Answers with the design as it now stands, element by element, and what was wrong with what you wrote.",
			"inputSchema": {"type": "object", "properties": {
				"name": {"type": "string"}, "on": {"type": "string"},
				"elements": {"type": "array", "items": {"type": "object"}, "description": "each {id, stage, paint, finish, opacity, soft, fill | line + width | dots | stones}"},
				"remove": {"type": "array", "items": {"type": "string"}}}}},
		{"name": "look", "description": "See the design painted on its surface, seen straight from the front, with a millimeter grid, the surface's outline and its landmarks over it: all of it, or as it stands once `stage` is done.",
			"inputSchema": {"type": "object", "properties": {"stage": {"type": "string", "description": "the last stage to show (left out: all of them)"}, "on": {"type": "string"}}}},
		{"name": "submit", "description": "Hand the design in as it now stands. Answers with what keeps it from being handed in, if anything; otherwise the design is done, and so is your work.", "inputSchema": {"type": "object", "properties": {}}},
	]


func call_tool(name: String, args: Dictionary) -> Dictionary:
	while _busy and not _released:
		await TablePreview._tree().process_frame
	if _released:
		return {"text": "The design has been handed in and its tools are closed.", "error": true}
	_busy = true
	var out: Dictionary = _call(name, args)
	_busy = false
	return out


func _call(name: String, args: Dictionary) -> Dictionary:
	match name:
		"design":
			return _design(args)
		"look":
			return _look(args)
		"submit":
			return _submit()
	return {"text": "There is no tool called \"%s\": design, look and submit are the tools." % name, "error": true}


## The surface [param on] names (a thing, or "thing/part"), or the first - -1 for none.
func _skin_of(on: Variant) -> int:
	if skins.is_empty():
		return -1
	if not (on is String) or String(on).strip_edges().is_empty():
		return 0
	var name := String(on).strip_edges().to_lower()
	for k in skins.size():
		var s: Dictionary = skins[k]
		if name == String(s["thing"]).to_lower() or name == ("%s/%s" % [s["thing"], s["part"]]).to_lower():
			return k
	return -1


func _design(args: Dictionary) -> Dictionary:
	var si := _skin_of(args.get("on"))
	if si < 0:
		return {"text": "There is no surface to paint called \"%s\": %s." % [str(args.get("on", "")), ", ".join(_names())], "error": true}
	var raw: Dictionary = _raw.get(si, {"name": "", "elements": []})
	if args.get("name") is String:
		raw["name"] = args["name"]
	var list: Array = raw["elements"]
	var gone: Array = (args.get("remove") as Array).map(func(x: Variant) -> String: return str(x).strip_edges().to_lower()) if args.get("remove") is Array else []
	list = list.filter(func(e: Dictionary) -> bool: return not gone.has(str(e.get("id", "")).strip_edges().to_lower()))
	for e in (args.get("elements") if args.get("elements") is Array else []):
		if not (e is Dictionary):
			continue
		var id := str((e as Dictionary).get("id", "")).strip_edges().to_lower()
		var at := -1
		for i in list.size():
			if str((list[i] as Dictionary).get("id", "")).strip_edges().to_lower() == id and not id.is_empty():
				at = i
		if at >= 0:
			list[at] = e
		else:
			list.append(e)
	raw["elements"] = list
	_raw[si] = raw
	return {"text": _said(si)}


func _names() -> PackedStringArray:
	var out := PackedStringArray()
	for s in skins:
		out.append(String((s as Dictionary)["thing"]) + ("/" + String((s as Dictionary)["part"]) if not String((s as Dictionary)["part"]).is_empty() else ""))
	return out


## The design on skin [param si] as it now stands, in words, and what was wrong with what was written.
func _said(si: int) -> String:
	var skin: Dictionary = skins[si]
	var made := Skins.sanitize(_raw.get(si, {}), skin["frame"], String(skin.get("outline", "")))
	var lines := PackedStringArray()
	lines.append("\"%s\" on %s, %d elements in the order they go on:" % [made["name"], _names()[si], (made["elements"] as Array).size()])
	lines.append_array(Skins.summary(made, skin["frame"]))
	for n in made["notes"]:
		lines.append("NOTE: %s" % n)
	var off := _off(si, made)
	if not off.is_empty():
		lines.append("MOSTLY OFF THE SURFACE (painted on nothing): %s" % ", ".join(off))
	var unseen := _unseen(si, made)
	if not unseen.is_empty():
		lines.append("HARDLY SEEN (nearly the color of what it is laid over, in its finish - nothing shows it going on): %s" % ", ".join(unseen))
	return "\n".join(lines)


## The elements of [param made] that hardly show against what they are laid over on skin [param si] ([constant UNSEEN]):
## the bare surface (matte), or the last fill laid before them under their middle, in nearly its color and finish.
## A change of finish (powder over satin) shows.
func _unseen(si: int, made: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	var skin: Dictionary = skins[si]
	var bare_s := String(skin.get("color", ""))
	var bare := Color.html(bare_s) if Color.html_is_valid(bare_s) else Color.WHITE
	var laid: Array = []          # [its extent, its color, its finish]: the fills laid so far
	for e in made["elements"]:
		var ed: Dictionary = e
		var kind := String(ed["kind"])
		if kind in ["mist", "stones"] or not Color.html_is_valid(String(ed["paint"])):
			continue
		var r := Skins.bounds(ed, skin["frame"])
		var under := bare
		var under_finish := "matte"
		for k in range(laid.size() - 1, -1, -1):
			if ((laid[k] as Array)[0] as Rect2).has_point(r.get_center()):
				under = (laid[k] as Array)[1]
				under_finish = (laid[k] as Array)[2]
				break
		var c := Color.html(String(ed["paint"]))
		if maxf(absf(c.r - under.r), maxf(absf(c.g - under.g), absf(c.b - under.b))) < UNSEEN and String(ed["finish"]) == under_finish:
			out.append("\"%s\" (%s over %s)" % [ed["id"], ed["paint"], "#" + under.to_html(false)])
		if kind == "fill":
			laid.append([r, c, String(ed["finish"])])
	return out


## The elements of [param made] that lie mostly off skin [param si]'s surface (outside its outline).
func _off(si: int, made: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	var skin: Dictionary = skins[si]
	var outline := String(skin.get("outline", ""))
	if outline.is_empty():
		return out
	for e in made["elements"]:
		var ed: Dictionary = e
		if String(ed["kind"]) == "stones" or String(ed.get("d", "")) == "all":
			continue
		# (its whole extent, never cut to the surface's frame: one drawn wholly past it is the most off)
		var b0 := Skins.bounds(ed, skin["frame"]).grow(1.0)
		var rect := Rect2(b0.position.floor(), (b0.end.ceil() - b0.position.floor()).max(Vector2(1.0, 1.0)))
		var inside := Skins.cover(ed, rect, 1.0, outline, skin["frame"])
		var all := Skins.cover(ed, rect, 1.0, "", skin["frame"])
		if inside == null or all == null:
			continue
		var a := 0.0
		var b := 0.0
		for y in all.get_height():
			for x in all.get_width():
				b += all.get_pixel(x, y).a
				a += inside.get_pixel(x, y).a
		if b > 1.0 and a < b * (1.0 - OFF_MOST):
			out.append("\"%s\" (%d%% off)" % [ed["id"], roundi((1.0 - a / b) * 100.0)])
	return out


func _look(args: Dictionary) -> Dictionary:
	if _looks >= LOOKS:
		return {"text": "No looks left: submit the design.", "error": true}
	var si := _skin_of(args.get("on"))
	if si < 0:
		return {"text": "There is no surface to paint called \"%s\": %s." % [str(args.get("on", "")), ", ".join(_names())], "error": true}
	var made := Skins.sanitize(_raw.get(si, {}), (skins[si] as Dictionary)["frame"], String((skins[si] as Dictionary).get("outline", "")))
	var img := Skins.look(skins[si], made, String(args.get("stage", "")) if args.get("stage") is String else "")
	if si == 0 and not reference.is_empty():
		img = _beside(img, Image.load_from_file(reference))
	_looks += 1
	var path := dir.path_join("look_%02d.jpg" % _looks)
	if img.save_jpg(path, 0.9) != OK:
		return {"text": "It could not be shown.", "error": true}
	# the picture itself is handed back: AgentTools sends only an Image, not a path
	return {"text": "%s Looks left: %d." % [JUDGE, LOOKS - _looks], "images": [img]}


## [param look] with [param painting] to its right, as tall as it ([param look] alone where the painting cannot be read).
static func _beside(look: Image, painting: Image) -> Image:
	if painting == null or painting.is_empty():
		return look
	var p := painting.duplicate() as Image
	p.convert(look.get_format())
	p.resize(maxi(roundi(float(p.get_width()) * float(look.get_height()) / float(p.get_height())), 1), look.get_height(), Image.INTERPOLATE_BILINEAR)
	var out := Image.create(look.get_width() + p.get_width() + 8, look.get_height(), false, look.get_format())
	out.fill(Color.BLACK)
	out.blit_rect(look, Rect2i(Vector2i.ZERO, look.get_size()), Vector2i.ZERO)
	out.blit_rect(p, Rect2i(Vector2i.ZERO, p.get_size()), Vector2i(look.get_width() + 8, 0))
	return out


## The designs as a file holds them ([TablePaint] reads `skin.json`): each surface's, with where it is and what it is in.
func designs() -> Dictionary:
	var out: Array = []
	for si in _raw:
		var skin: Dictionary = skins[int(si)]
		var raw: Dictionary = _raw[si]
		out.append({"thing": skin["thing"], "part": skin["part"], "frame": [(skin["frame"] as Vector2).x, (skin["frame"] as Vector2).y],
			"outline": skin["outline"], "name": raw.get("name", ""), "elements": raw.get("elements", [])})
	return {"designs": out}


func _submit() -> Dictionary:
	if _raw.is_empty():
		return {"text": "Nothing is designed yet: write elements with `design`.", "error": true}
	for si in _raw:
		var made := Skins.sanitize(_raw[si], (skins[int(si)] as Dictionary)["frame"], String((skins[int(si)] as Dictionary).get("outline", "")))
		if (made["elements"] as Array).is_empty():
			return {"text": "The design on %s has no element that can be painted:\n%s" % [_names()[int(si)], _said(int(si))], "error": true}
		if String(made["name"]).is_empty():
			return {"text": "Name the design (`design` with `name`): what it is, in a few plain words.", "error": true}
		var off := _off(int(si), made)
		if not off.is_empty() and not _warned:
			_warned = true
			return {"text": "These lie mostly off the surface, painted on nothing: %s. Bring them onto it. (Submit again to hand the design in as it is.)" % ", ".join(off), "error": true}
	var err := TextGen.put(dir.path_join(SUBMITTED) + ".part", JSON.stringify(designs(), "\t"))
	if err.is_empty() and DirAccess.rename_absolute(dir.path_join(SUBMITTED) + ".part", dir.path_join(SUBMITTED)) != OK:
		err = "could not move the design into place"
	if not err.is_empty():
		return {"text": "The design could not be handed in: %s" % err, "error": true}
	submitted = true
	return {"text": "Handed in. The design is done - your work is done; end with one short line."}
