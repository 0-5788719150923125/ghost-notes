extends RefCounted
class_name DioramaTools

## DioramaTools - the model maker's bench (next/tabletop.md, "The diorama"): what it has while it models a game's land
## ([GameDiorama], the `diorama` step) or the night's figures (the `minis` step). Served as tools ([AgentTools]) like the set
## dresser's.
##
##   land     the ground: hills, rivers, lakes, roads, woods, its colors (land only)
##   place    places on the board, each a thing built of parts, or one kept in the Library (land only)
##   figure   figures, each a thing built of parts, or one kept in the Library (figures only)
##   remove   places or figures, by name
##   library  the Library searched: things kept from any table, proven and pictured already
##   look     one place or figure close up, from three sides, on a centimeter grid
##   plan     the board from straight above, as it stands (land only)
##   submit   hand it in
##
## A thing taken from the Library is copied in whole, its materials beside the others, so the episode stands as it was made
## whatever the Library becomes. Figures modeled for this show's earlier nights are handed in already ([member figures]) and may
## be changed.

const SUBMITTED := "submitted.json"
## How many looks it has before it must hand in.
const LOOKS_MOST := 24
## How tall a figure of a person is, on its base (centimeters), and the most any figure may be.
const FIGURE_TALL := 4.0
## The fewest parts a place or a figure is built of before handing in asks once for more: a scale model is never a block.
const PARTS_LEAST := 5
const FIGURE_MOST := 22.0

## "land" or "figures".
var mode := "land"
var dir := ""
var seed_value := 0
## The land as it stands: [GameDiorama]'s spec, raw (sanitized as it is handed in).
var land := {}
## The figures: name -> thing, and the materials every figure and place uses.
var figures := {}
var materials := {}
## What must be modeled (figures mode): `[{name, looks, owner}]`.
var wanted: Array = []
var submitted := false
var _looks := 0
var _released := false
var _plain_told := false


func _init(job_dir: String, seed_of: int, which: String) -> void:
	dir = job_dir
	seed_value = seed_of
	mode = which
	DirAccess.make_dir_recursive_absolute(dir)
	for f in DirAccess.get_files_at(dir):
		if String(f) == SUBMITTED or String(f) == "tools.jsonl":
			DirAccess.remove_absolute(dir.path_join(String(f)))


func release() -> void:
	_released = true


func instructions() -> String:
	return "The model maker's bench: model the board's land and its places, or the night's figures, look at them, and hand them in."


func list_tools() -> Array:
	var thing := {"type": "object", "description": "a thing built of parts, as a prop is: `parts` [...], centimeters, its base on y = 0, its front toward +z"}
	var out: Array = []
	if mode == "land":
		out.append({"name": "land", "description": "The board's ground, whole: each list you give replaces the one there (`hills`, `rivers`, `lakes`, `roads`, `woods`, `colors`); a list you leave out stays as it was. Answered with the board as it stands.",
			"inputSchema": {"type": "object", "properties": {"name": {"type": "string"}, "hills": {"type": "array"}, "rivers": {"type": "array"}, "lakes": {"type": "array"}, "roads": {"type": "array"}, "woods": {"type": "array"}, "colors": {"type": "object"}}}})
		out.append({"name": "place", "description": "Stand places on the board: each `{name, at [x, z], turn, line, thing}` - or `library` with a kept thing's name in place of `thing`. A place of a name already there is replaced. `materials`: the materials their parts use, added to the board's.",
			"inputSchema": {"type": "object", "properties": {"places": {"type": "array", "items": {"type": "object", "properties": {"name": {"type": "string"}, "at": {"type": "array", "items": {"type": "number"}}, "turn": {"type": "number"}, "line": {"type": "string"}, "thing": thing, "library": {"type": "string"}}, "required": ["name", "at"]}}, "materials": {"type": "object"}}, "required": ["places"]}})
		out.append({"name": "plan", "description": "The board from straight above as it stands: its ground's heights shaded, water, roads, woods, each place a red dot, a line every 10 cm.", "inputSchema": {"type": "object", "properties": {}}})
	else:
		out.append({"name": "figure", "description": "Model figures: each `{name, thing}` - or `library` with a kept thing's name in place of `thing`. A figure of a name already there is replaced. `materials`: the materials their parts use.",
			"inputSchema": {"type": "object", "properties": {"figures": {"type": "array", "items": {"type": "object", "properties": {"name": {"type": "string"}, "thing": thing, "library": {"type": "string"}}, "required": ["name"]}}, "materials": {"type": "object"}}, "required": ["figures"]}})
	out.append({"name": "remove", "description": "Take places or figures away, by name.", "inputSchema": {"type": "object", "properties": {"names": {"type": "array", "items": {"type": "string"}}}, "required": ["names"]}})
	out.append({"name": "library", "description": "Search the Library of things kept from earlier tables and nights: each proven, built and pictured already. Say what you need in a few words.", "inputSchema": {"type": "object", "properties": {"words": {"type": "string"}}, "required": ["words"]}})
	out.append({"name": "look", "description": "Look at one place or figure close up: from its front, its side and above, on a centimeter grid. Your looks are few: look at what you are unsure of.", "inputSchema": {"type": "object", "properties": {"name": {"type": "string"}}, "required": ["name"]}})
	out.append({"name": "submit", "description": "Hand in what you have made. Answered with what keeps it from being done, if anything; otherwise your work is done.", "inputSchema": {"type": "object", "properties": {}}})
	return out


func call_tool(name: String, args: Dictionary) -> Dictionary:
	if _released or submitted:
		return {"text": "This is handed in, and the bench is closed.", "error": true}
	match name:
		"land":
			for k in ["name", "hills", "rivers", "lakes", "roads", "woods", "colors"]:
				if args.has(k):
					land[k] = args[k]
			return {"text": told()}
		"place":
			return _put("places", args.get("places", []), args.get("materials", {}))
		"figure":
			return _put("figures", args.get("figures", []), args.get("materials", {}))
		"remove":
			var gone := PackedStringArray()
			for n in (args.get("names", []) if args.get("names") is Array else []):
				if _drop(String(n)):
					gone.append(String(n))
			return {"text": ("Taken away: %s." % ", ".join(gone)) if not gone.is_empty() else "Nothing of those names is here."}
		"library":
			var found := ThingLibrary.search(String(args.get("words", "")))
			if found.is_empty():
				return {"text": "Nothing in the Library is like that: model it."}
			var lines := PackedStringArray()
			for e in found:
				lines.append("- %s: %s" % [String(e["name"]), String(e.get("line", ""))])
			return {"text": "Kept, and yours to use by name (`library`):\n" + "\n".join(lines)}
		"look":
			return await _look(String(args.get("name", "")))
		"plan":
			return await _plan()
		"submit":
			return _submit()
	return {"text": "No tool called %s." % name, "error": true}


# --- making -------------------------------------------------------------------------------------------------------------

## Places or figures put: each named, its thing its own or the Library's; a name already there replaced.
func _put(list_key: String, raw: Variant, mats: Variant) -> Dictionary:
	if mats is Dictionary:
		for k in mats:
			materials[String(k)] = mats[k]
	var said := PackedStringArray()
	for v in (raw if raw is Array else []):
		if not (v is Dictionary) or String((v as Dictionary).get("name", "")).strip_edges().is_empty():
			continue
		var d: Dictionary = (v as Dictionary).duplicate(true)
		var nm := String(d["name"]).strip_edges()
		if not String(d.get("library", "")).is_empty():
			var e := ThingLibrary.read(String(d["library"]))
			if e.is_empty():
				return {"text": "Nothing called \"%s\" is kept in the Library: search it with `library`." % String(d["library"]), "error": true}
			var placed := ThingLibrary.put_on({"things": [], "materials": materials}, e, null)
			materials = placed["materials"]
			d["thing"] = (placed["things"] as Array)[0]
		if not (d.get("thing") is Dictionary):
			return {"text": "%s has no `thing` and no `library`." % nm, "error": true}
		# ...the thing keeps its own name, what it is (a kept model stands on other boards); the game's name is the place's or figure's
		if String((d["thing"] as Dictionary).get("name", "")).strip_edges().is_empty():
			(d["thing"] as Dictionary)["name"] = String(d.get("line", "")).strip_edges() if not String(d.get("line", "")).strip_edges().is_empty() else nm
		var safe := Props.sanitize({"things": [d["thing"]], "materials": materials}, [])
		if (safe["things"] as Array).is_empty():
			return {"text": "%s has nothing that can be built: give it parts." % nm, "error": true}
		if list_key == "figures":
			figures[nm] = d["thing"]
		else:
			var places: Array = land.get("places", [])
			for i in range(places.size() - 1, -1, -1):
				if String((places[i] as Dictionary).get("name", "")) == nm:
					places.remove_at(i)
			places.append(d)
			land["places"] = places
		said.append(nm)
	if said.is_empty():
		return {"text": "Nothing was put: each needs a `name` and a `thing` or `library`.", "error": true}
	return {"text": "Put: %s.\n\n%s" % [", ".join(said), told()]}


func _drop(nm: String) -> bool:
	if figures.erase(nm):
		return true
	var places: Array = land.get("places", [])
	for i in places.size():
		if String((places[i] as Dictionary).get("name", "")) == nm:
			places.remove_at(i)
			return true
	return false


## What stands, in words.
func told() -> String:
	if mode == "figures":
		var lines := PackedStringArray()
		for w in wanted:
			var nm := String((w as Dictionary)["name"])
			lines.append("- %s: %s" % [nm, "modeled" if figures.has(nm) else "NOT YET"])
		return "The figures:\n" + "\n".join(lines)
	var spec := _spec()
	return GameDiorama.told(spec) + "\n(%d hills, %d rivers, %d roads, %d woods)" % [(spec["hills"] as Array).size(), (spec["rivers"] as Array).size(), (spec["roads"] as Array).size(), (spec["woods"] as Array).size()]


func _spec() -> Dictionary:
	var raw := land.duplicate(true)
	raw["materials"] = materials
	return GameDiorama.sanitize(raw)


## The thing of place or figure [param nm], {} for none.
func _thing(nm: String) -> Dictionary:
	if figures.has(nm):
		return figures[nm]
	for p in land.get("places", []):
		if String((p as Dictionary).get("name", "")) == nm and (p as Dictionary).get("thing") is Dictionary:
			return p["thing"]
	return {}


func _look(nm: String) -> Dictionary:
	var th := _thing(nm)
	if th.is_empty():
		return {"text": "Nothing called \"%s\" is here." % nm, "error": true}
	if not PropStudio.can_see():
		return {"text": "This run has no renderer, so there is no picture: judge it by its numbers."}
	if _looks >= LOOKS_MOST:
		return {"text": "No looks left: hand it in.", "error": true}
	_looks += 1
	var safe := Props.sanitize({"things": [th], "materials": materials}, [])
	var t: Dictionary = (safe["things"] as Array)[0]
	var paths: Array = await PropStudio.views(t, safe["materials"], ThingLibrary.hash_of(t, safe["materials"]), dir.path_join("look_%d" % _looks))
	var images: Array = []
	for p in paths:
		var img := Image.load_from_file(String(p))
		if img != null:
			images.append(img)
	return {"text": "%s, from its front, its side and above (%d looks left)." % [nm, LOOKS_MOST - _looks], "images": images}


func _plan() -> Dictionary:
	var spec := _spec()
	var task := {"img": null}
	var id := WorkerThreadPool.add_task(func() -> void: task["img"] = GameDiorama.new(spec, seed_value).plan_image())
	while not WorkerThreadPool.is_task_completed(id):
		await PropStudio.tree().process_frame
	WorkerThreadPool.wait_for_task_completion(id)
	return {"text": told(), "images": [task["img"]] if task["img"] != null else []}


## How many parts [param thing] is built of, a group's own counted and each part copied once.
static func _parts_in(thing: Dictionary) -> int:
	var n := 0
	for p in thing.get("parts", []) if thing.get("parts") is Array else []:
		if p is Dictionary:
			n += maxi(1, _parts_in(p)) if (p as Dictionary).get("parts") is Array else 1
	return n


func _submit() -> Dictionary:
	# ...a place or a figure of a block or two is sent back once: what is seen close is its detail
	var plain := PackedStringArray()
	var all := figures.duplicate() if mode == "figures" else {}
	if mode == "land":
		for p in land.get("places", []):
			if (p as Dictionary).get("thing") is Dictionary:
				all[String(p["name"])] = p["thing"]
	for nm in all:
		if _parts_in(all[nm]) < PARTS_LEAST:
			plain.append(String(nm))
	if not plain.is_empty() and not _plain_told:
		_plain_told = true
		return {"text": "These are a block or two, and the camera goes close: %s. A scale model is built up - walls, a roof with its ridge and eaves, a door, windows, a chimney, steps, a fence, a cart, barrels, what is lying round it; a figure its body, limbs, head, clothes and what it carries. Build them out, then hand in again (handing in again as they are keeps them)." % ", ".join(plain.slice(0, 12)), "error": true}
	var out := {}
	if mode == "figures":
		var missing := PackedStringArray()
		for w in wanted:
			if not figures.has(String((w as Dictionary)["name"])):
				missing.append(String((w as Dictionary)["name"]))
		if not missing.is_empty():
			return {"text": "Not modeled yet: %s." % ", ".join(missing), "error": true}
		# ...as written: a thing or material made safe does not survive JSON, so each is made safe where it is built
		out = {"figures": figures, "materials": materials}
	else:
		var spec := _spec()
		var built := 0
		for p in spec["places"]:
			if (p as Dictionary).get("thing") is Dictionary:
				built += 1
		if built < 2:
			return {"text": "The board has %d places modeled: the adventure's places stand on it, each a thing." % built, "error": true}
		out = spec
	var path := dir.path_join(SUBMITTED)
	var f := FileAccess.open(path + ".part", FileAccess.WRITE)
	if f == null:
		return {"text": "could not write it", "error": true}
	f.store_string(JSON.stringify(out))
	f.close()
	DirAccess.rename_absolute(path + ".part", path)
	submitted = true
	return {"text": "Handed in. Your work is done."}
