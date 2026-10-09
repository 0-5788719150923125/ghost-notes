extends RefCounted
class_name SetDresserTools

## SetDresserTools - what the set dresser can do while it sets a tarot reader's table: MAKE a thing,
## LOOK at it, FIX it, and see the whole table as the camera will before handing it in.
##
## Written as one reply, a table was ~5,000 tokens of geometry its author never saw: a squid of balls
## and rods that read as a giant bug, stones perched on stones, things left off the table for want of
## room with nobody told. Served as tools ([AgentTools]) instead, the set dresser keeps a DRAFT here
## and works on it:
##
##   put     things (and their materials) onto the draft - a thing of the same name is replaced -
##           answered with what was built: each thing's size, anything the builder had to leave out or
##           guess, whether it is taller than its place can show, and a picture of what was put; and
##           THE TABLE ITSELF ([Tables]): its `top`, and its `layers` (each replacing one of the same
##           name), answered with the table in words and whatever had to change (a top made larger to
##           hold the cards, a pattern it does not know); and THE LIGHT ([Lights]), part by part - its
##           sky, sun, clouds and birds each replacing the last, what the sun falls through and the lamps
##           by name - answered with where the sun falls (how much of the table, and of where the cards
##           lie) and how the weather runs
##   remove  things off it, by name
##   look    one thing close up from four sides ([method TablePreview.thing])
##   overhead  the table from straight above - top, edge, layers, things, the cards' spread - with the
##           stretch the camera sees outlined ([method TablePreview.overhead]): a plan
##   set     the whole draft standing on the episode's own table, photographed from the camera's
##           place, with where each thing stood, what was made smaller or left off, which light leads
##           ([method TablePreview.table]) - and its AIR as it is some way into the reading
##   watch   one effect of the air ([Effects]) in motion: a burst at the moment it marks, fog or
##           motes a few seconds apart ([method TablePreview.watch]); or a moving part of the LIGHT
##           ([Lights]): a cloud passing over the sun, a bird's shadow crossing, leaves stirring, a lamp's
##           flicker, a flash ([method TablePreview.watch_light])
##   title   the color the show's name is printed in over this table at the opening, and a picture
##           of that opening - the table thrown out of focus, the name over it - with how far the
##           color stands out from what is behind it ([method TablePreview.opening])
##   submit  hand the draft in: written beside the job ([constant SUBMITTED]) for the producer to land
##           exactly as an answer in words would have landed ([method CardProducer._land_table])
##
## Every picture counts against [constant LOOKS]; words cost nothing. A picture comes with the
## question to ask of it ([constant JUDGE_THING], [constant JUDGE_TABLE], [constant JUDGE_SET]): told only to fix what was
## wrong, a model looked at a 1 cm disc it had named an oil lamp and called it perfect. Before it is handed in the
## table is SET at least once since its last change, wherever a table can be stood - the one look the
## old single reply never had.
##
## IT KNOWS NO CARD, as the set dresser never did: the table it sets is photographed with the cards
## face down, and nothing here reads the draw.

## The file a handed-in table is written to, in the job's folder.
const SUBMITTED := "submitted.json"
## What to ask of a picture before going on: say what it shows, then judge it against what was meant.
const JUDGE_THING := "Before you go on, say what each picture actually shows - its shape and proportions against the grid (1 cm squares, a brighter line every 5), its material - and whether a stranger would name it as you did. Put again what does not read: a part floating or sunk, a thing too flat or too small to read, a vessel that reads as a plate, a bundle that reads as a stick."
const JUDGE_TABLE := "Before you submit, say what the frame actually shows: can each thing be told for what it is at this size, is any hidden, crowded or left off, and does the light come from where you meant? Fix what does not, and set the table again."
## ...and when every thing stood in the shot: THE TABLE IS SET, and it is told so. Told only to fix what was
## wrong, a set dresser read a thing made 88% of its size as a fault and set the table round after round
## chasing it, the shot holding no layout where nothing is made smaller. The table makes a thing smaller
## only as far as it still reads (see TableMedium._stand), and leaves off what will not fit even so.
const JUDGE_SET := "Every thing stands in the shot. Say what the frame actually shows: can each thing be told for what it is, and does the light come from where you meant? If so, the table is set - %s. Set it again only to fix what is plainly wrong."
const JUDGE_AIR := "Say what the pictures show of it: is it where you meant, as thick or as bright as you meant, in colors that belong to this table - and can every card still be seen through it? Put it again to change it."
const JUDGE_OVERHEAD := "Say what the plan shows: the top's shape and edge, each layer where you meant it and turned as you meant, what hangs over the edge, and whether the cloths, the things and the cards sit together as one table. Put again what does not."
const JUDGE_TITLE := "Say what the picture shows: can the name be read at a glance - and would it still be, shrunk to a thumbnail the size of a stamp? Does its color stand clear of every part of the table behind it, and belong to this table's world? Choose again if not."
const JUDGE_LIGHT := "Say what the pictures show of the light: where it comes from, what it falls through and where its shade lies, whether it moves as you meant - and whether it is the light of this episode's world and hour, with every card still readable in it. Put it again to change it."
## How many pictures one set dresser may take. Its run has no time limit (see AgentJobs).
const LOOKS := 40

var episode: CardEpisode
var plan: Dictionary
var dir := ""                    # the job's folder: its prompt, its reply, its tool log
var submitted := false

var _look := {}
var _things: Array = []          # the draft, in the order put
var _effects: Array = []         # ...its air, by name
var _materials := {}
var _top := {}                   # the table's top as written, once put
var _layers: Array = []          # ...and its layers, once any is put or taken off
var _top_put := false
var _layers_put := false
var _idea := ""
var _title := {}                 # the name's color over this table: {color, why}
var _light := {}                 # the table's light as written, part by part, once put
var _light_put := false
var _sound := {}                 # what the place sounds like ([Soundscape]), part by part, once put
var _sound_put := false
var _looks := 0
var _busy := false               # a call is in hand ([method call_tool])
var _released := false
var _set_since_change := false
var _warned := false
var _warned_title := false
var _preview: TablePreview


## [param name] and [param byline]: the show's, set over the table at the opening.
func _init(ep: CardEpisode, episode_plan: Dictionary, job_dir: String, name := "", byline := "") -> void:
	episode = ep
	plan = episode_plan
	dir = job_dir
	_look = CardTable.sanitize_look(plan.get("look", {}) if plan.get("look") is Dictionary else {})
	_preview = TablePreview.new(ep, plan, dir.path_join("preview"), name, byline)
	# A RUN STARTS CLEAN: a rerun works in the folder the last run left, and its handed-in table or
	# its pictures must not pass for this run's
	DirAccess.make_dir_recursive_absolute(dir)
	for f in DirAccess.get_files_at(dir):
		var fs := String(f)
		if fs == SUBMITTED or fs == "tools.jsonl" or (fs.begins_with("look_") and fs.ends_with(".jpg")):
			DirAccess.remove_absolute(dir.path_join(fs))


## Give back the pictures' stages - once the call in hand, if any, has finished with them ([method call_tool]).
func release() -> void:
	_released = true
	if not _busy:
		_preview.release()


func instructions() -> String:
	return "Tools for setting a tarot reader's table: build the table itself and lay its cloths, put things on it, light it, look at them, see it from above and as the camera will film it, watch what moves, and submit it."


func list_tools() -> Array:
	return [
		{"name": "put", "description": "Put things on the table you are setting: each new thing is added, and a thing with the same name as one already there is replaced. Give the materials they use (added to the table's, or replacing one of the same name), the table's air (`effects`, each replacing one of the same name), its light (`light`, part by part) and, if you like, the table's idea. Things, materials, effects and the light are written exactly as in the format you were shown. Answers with what was built - each thing's size, anything the builder had to leave out or guess, whether it is taller than its place can show, where the sun falls - and a picture of the things you put, each on its own tile on a centimeter grid.",
			"inputSchema": {"type": "object", "properties": {
				"things": {"type": "array", "items": {"type": "object"}, "description": "things, each {name, why, place, group, turn, parts}"},
				"materials": {"type": "object", "description": "materials by name, each {kind, color, ...}"},
				"effects": {"type": "array", "items": {"type": "object"}, "description": "the air: fog, motes, bursts and drifts, each {name, kind, ...}"},
				"idea": {"type": "string", "description": "two or three sentences: this table, and the reader who set it"},
				"top": {"type": "object", "description": "the table's top: {shape, size, corner, sides, scallops, thickness, edge, material, boards, tiles, pattern, inlay, relief, why} - replaces the top before"},
				"layers": {"type": "array", "items": {"type": "object"}, "description": "cloths laid on the top, bottom first: each {name, what, outline, size, drop, at, turn, fabric, pattern, border, fringe, relief, sheen}, replacing a layer of the same name (a new one goes on top)"},
				"light": {"type": "object", "description": "the table's light, {why, sky, sun, through, clouds, wind, birds, lamps, shadows}: each part given replaces that part (null takes it away); in `through`, `lamps` and `shadows` an entry replaces the one of the same name (an empty list takes them all away)"},
				"sound": {"type": "object", "description": "what the place sounds like behind the reader, {why, wind, water, rain, fire, stream, insects}: each part given replaces that part (null takes it away)"}}}},
		{"name": "remove", "description": "Take things - or effects of its air, layers, or parts of its light (what the sun falls through, a lamp or a shadow, by name; or \"sun\", \"clouds\", \"wind\", \"birds\", or \"light\" for all of it), or its sound (\"sound\") - off the table you are setting, by name.",
			"inputSchema": {"type": "object", "properties": {"names": {"type": "array", "items": {"type": "string"}}}, "required": ["names"]}},
		{"name": "look", "description": "Look at one thing close up, from four sides - its front, its right side, from above, and as the camera at the reader's chair sees it - on a centimeter grid (a brighter line every 5 cm).",
			"inputSchema": {"type": "object", "properties": {"name": {"type": "string"}}, "required": ["name"]}},
		{"name": "set", "description": "Stand everything on this episode's own table as the show will - its cloth, its room, its lights, the deck at its side and the cards laid face down where the reading lays them - and photograph it from the camera's place: what the viewer will see. Answers with the picture, where each thing stood, what was made smaller or left off for want of room, and which light leads.",
			"inputSchema": {"type": "object", "properties": {}}},
		{"name": "overhead", "description": "Photograph the table from straight above, lit as the show lights it: the top, its edge and its layers as laid, the things on it and the cards face down in their spread, the reader's side at the bottom, and a yellow line round the stretch the camera sees. A plan, for laying cloths square or as a diamond and seeing what hangs over the edge.",
			"inputSchema": {"type": "object", "properties": {}}},
		{"name": "watch", "description": "Watch something on this episode's own table in motion - one effect of its air, or a moving part of its light: a burst photographed four times in the second after the moment it marks (a card leaping from the deck, one held up and twirled...), fog or motes four times a few seconds apart, a drift through a gust; \"clouds\" as one passes over the sun, \"wind\" through its strongest gust, \"birds\" as a shadow crosses, what the sun falls through as it stirs, a lamp as it flickers, flashes or passes, a shadow as it swings, turns or ripples (by name). A sheet of four pictures.",
			"inputSchema": {"type": "object", "properties": {"name": {"type": "string"}}, "required": ["name"]}},
		{"name": "title", "description": "Choose the color the show's name is printed in at the opening, over this table thrown far out of focus - the video's first seconds, and its thumbnail. Answers with a picture of that opening and how far the color stands out from the table behind the name.",
			"inputSchema": {"type": "object", "properties": {
				"color": {"type": "string", "description": "#rrggbb"},
				"why": {"type": "string", "description": "a few words: what it stands out against, and why it belongs to this table"}}, "required": ["color"]}},
		{"name": "submit", "description": "Hand in the table as it now stands. Answers with what keeps it from being set, if anything; otherwise the table is done, and so is your work.",
			"inputSchema": {"type": "object", "properties": {}}},
	]


## ONE CALL AT A TIME, and none once the tools are closed. Reported 2026-10-07: the table's job ended while a
## call was photographing (an agent's last `title`), its stages were freed under it, and every picture after
## that was "a previously freed instance"; two calls at once share one studio and its camera. So a call waits
## for the one before it, a call after [method release] is turned away, and a release during a call gives the
## stages back when the call is done.
func call_tool(name: String, args: Dictionary) -> Dictionary:
	while _busy and not _released:
		await TablePreview._tree().process_frame
	if _released:
		return {"text": "The table has been handed in and its tools are closed.", "error": true}
	_busy = true
	var out: Dictionary = await _call(name, args)
	_busy = false
	if _released:
		_preview.release()
	return out


func _call(name: String, args: Dictionary) -> Dictionary:
	match name:
		"put":
			return await _put(args)
		"remove":
			return _remove(args)
		"look":
			return await _look_at(args)
		"set":
			return await _set_table()
		"overhead":
			return await _overhead()
		"watch":
			return await _watch(args)
		"title":
			return await _choose_title(args)
		"submit":
			return _submit()
	return {"text": "There is no tool called \"%s\": put, remove, look, overhead, set, watch, title and submit are the tools." % name, "error": true}


## The draft as the set dresser has written it - the shape a one-reply table had.
func draft() -> Dictionary:
	var out := {"idea": _idea, "things": _things.duplicate(true), "materials": _materials.duplicate(true)}
	if not _effects.is_empty():
		out["effects"] = _effects.duplicate(true)
	if not _title.is_empty():
		out["title"] = _title.duplicate()
	if _top_put:
		out["top"] = _top.duplicate(true)
	if _layers_put:
		out["layers"] = _layers.duplicate(true)
	if _light_put:
		out["light"] = _light.duplicate(true)
	if _sound_put:
		out["sound"] = _sound.duplicate(true)
	return out


# --- the tools ----------------------------------------------------------------------------------------

func _put(args: Dictionary) -> Dictionary:
	var raw: Variant = args.get("things", [])
	if raw is Dictionary:
		raw = [raw]
	var mats: Dictionary = args.get("materials", {}) if args.get("materials") is Dictionary else {}
	var air: Variant = args.get("effects", [])
	if air is Dictionary:
		air = [air]
	var any_air: bool = air is Array and not (air as Array).is_empty()
	var new_top: Variant = args.get("top")
	var new_layers: Variant = args.get("layers")
	if new_layers is Dictionary:
		new_layers = [new_layers]
	# `layers: []` is a bare top: the cloth every table had before taken off
	var any_table: bool = new_top is Dictionary or new_layers is Array
	var any_light: bool = args.get("light") is Dictionary
	var any_sound: bool = args.get("sound") is Dictionary
	if not (raw is Array) or ((raw as Array).is_empty() and mats.is_empty() and not any_air and not any_table and not any_light
			and not any_sound and not (args.get("idea") is String)):
		return {"text": "Nothing was put: give `things` (a list of things), `materials`, `effects`, the table's `top` or `layers`, its `light`, its `sound`, or an `idea`.", "error": true}
	if any_light:
		_merge_light(args["light"] as Dictionary)
	if any_sound:
		_sound_put = true
		for k in args["sound"]:
			var v: Variant = (args["sound"] as Dictionary)[k]
			if v == null:
				_sound.erase(String(k))
			else:
				_sound[String(k)] = (v as Dictionary).duplicate(true) if v is Dictionary else v
	if new_top is Dictionary:
		_top = (new_top as Dictionary).duplicate(true)
		_top_put = true
	var laid: Array = []
	if new_layers is Array:
		if not _layers_put or (new_layers as Array).is_empty():
			_layers = []
		_layers_put = true
		for l in new_layers:
			if not (l is Dictionary):
				continue
			var layer := (l as Dictionary).duplicate(true)
			var ln := String(layer.get("name", "")).strip_edges()
			if ln.is_empty():
				ln = "layer %d" % (_layers.size() + 1)
			layer["name"] = ln
			var li := _layer_of(ln)
			if li >= 0:
				_layers[li] = layer
			else:
				_layers.append(layer)
			laid.append(ln)
	var notes := PackedStringArray()
	for k in mats:
		_materials[String(k).strip_edges()] = mats[k]
		notes.append_array(_material_troubles(String(k).strip_edges(), mats[k]))
	if args.get("idea") is String:
		_idea = String(args["idea"]).strip_edges()
	var put: Array = []
	var junk := 0
	for t in raw:
		if not (t is Dictionary):
			junk += 1
			continue
		var thing := (t as Dictionary).duplicate(true)
		var nm := String(thing.get("name", "")).strip_edges()
		if nm.is_empty():
			nm = "thing %d" % (_things.size() + 1)
		thing["name"] = nm
		var at := _index_of(nm)
		if at >= 0:
			_things[at] = thing
		else:
			_things.append(thing)
		if not put.has(nm):
			put.append(nm)
	var aired: Array = []
	if any_air:
		for e in air:
			if not (e is Dictionary):
				continue
			var fx := (e as Dictionary).duplicate(true)
			var en := String(fx.get("name", "")).strip_edges()
			if en.is_empty():
				en = "%s %d" % [String(fx.get("kind", "effect")), _effects.size() + 1]
			fx["name"] = en
			var at := _effect_of(en)
			if at >= 0:
				_effects[at] = fx
			else:
				_effects.append(fx)
			aired.append(en)
	_set_since_change = false
	var lines := PackedStringArray()
	if not put.is_empty():
		lines.append("Put %d thing%s (the table now holds %d):" % [put.size(), "" if put.size() == 1 else "s", _things.size()])
		lines.append_array(_describe(put))
	if not aired.is_empty():
		lines.append("The air (%d effect%s in all):" % [_effects.size(), "" if _effects.size() == 1 else "s"])
		lines.append_array(_describe_air(aired))
	if any_table:
		lines.append_array(_describe_table())
	if any_light:
		lines.append_array(_describe_light())
	if any_sound or (any_light and _sound_put):
		lines.append_array(_describe_sound())
	if junk > 0:
		lines.append("%d of the things given %s not an object {name, parts, ...} - left out." % [junk, "was" if junk == 1 else "were"])
	if not notes.is_empty():
		lines.append("Materials:")
		for n in notes:
			lines.append("  - " + n)
	lines.append(_tally())
	var images: Array = []
	if not put.is_empty():
		var numbers := {}
		for i in _things.size():
			numbers[String((_things[i] as Dictionary).get("name", ""))] = i + 1
		var img: Image = await _picture(func() -> Image: return await _preview.things(_safe(), put, numbers))
		if img != null:
			images.append(img)
			lines.append(JUDGE_THING)
	lines.append(_looks_line(not images.is_empty()))
	return {"text": "\n".join(lines), "images": images}


func _remove(args: Dictionary) -> Dictionary:
	var names: Array = args.get("names", []) if args.get("names") is Array else ([args["names"]] if args.get("names") is String else [])
	var gone := PackedStringArray()
	var missing := PackedStringArray()
	for n in names:
		var at := _index_of(String(n).strip_edges())
		var fx := _effect_of(String(n).strip_edges())
		var li := _layer_of(String(n).strip_edges()) if _layers_put else -1
		if at >= 0:
			_things.remove_at(at)
			gone.append(String(n))
		elif fx >= 0:
			_effects.remove_at(fx)
			gone.append(String(n))
		elif li >= 0:
			_layers.remove_at(li)
			gone.append(String(n))
		elif _unlight(String(n).strip_edges()):
			gone.append(String(n))
		elif String(n).strip_edges().to_lower() == "sound" and not _sound.is_empty():
			_sound = {}
			gone.append(String(n))
		else:
			missing.append(String(n))
	if not gone.is_empty():
		_set_since_change = false
	var lines := PackedStringArray()
	if not gone.is_empty():
		lines.append("Taken off: %s." % ", ".join(gone))
	if not missing.is_empty():
		lines.append("Not on the table: %s. On it: %s." % [", ".join(missing), _names()])
	lines.append(_tally())
	return {"text": "\n".join(lines), "error": gone.is_empty()}


func _look_at(args: Dictionary) -> Dictionary:
	var nm := String(args.get("name", "")).strip_edges()
	if _index_of(nm) < 0:
		return {"text": "No thing called \"%s\" is on the table. On it: %s." % [nm, _names()], "error": true}
	var safe := _safe()
	var built := false
	for t in safe["things"]:
		built = built or String((t as Dictionary).get("name", "")) == nm
	if not built:
		return {"text": "\"%s\" has nothing the builder can make: %s" % [nm, "; ".join(_troubles(_things[_index_of(nm)]))], "error": true}
	var img: Image = await _picture(func() -> Image: return await _preview.thing(safe, nm))
	var lines := PackedStringArray(_describe([nm]))
	if img != null:
		lines.append(JUDGE_THING)
	lines.append(_looks_line(img != null))
	return {"text": "\n".join(lines), "images": [img] if img != null else []}


func _set_table() -> Dictionary:
	var safe := _safe()
	if (safe["things"] as Array).is_empty():
		return {"text": "Nothing on the table can be built yet - put things first.", "error": true}
	if _looks >= LOOKS:
		return {"text": _looks_line(false), "error": true}
	if not _can_stand():
		_set_since_change = true
		return {"text": "The table cannot be stood in this run (%s), so there is no picture of it: judge it by what put told you." %
			("no renderer" if not _can_see() else "no ghost session")}
	var got: Dictionary = await _preview.table(draft())
	if got.has("error"):
		return {"text": "The table could not be stood: %s" % String(got["error"]), "error": true}
	_looks += 1
	_set_since_change = true
	var lines := PackedStringArray(["The table, from the camera's place - the deck at the %s, %d cards face down in their spread:" %
		[String(got["deck"]), int(got["cards"])]])
	var stood := stood_lines(got)
	lines.append_array(stood["lines"])
	lines.append("The light is led by %s." % String(got["key"]) + (" Held down by pale cloth near it: %s." % ", ".join(PackedStringArray(got["held_down"])) if not (got["held_down"] as Array).is_empty() else ""))
	var lit := _light_line(safe)
	if not lit.is_empty():
		lines.append(lit)
	var air := _air_line(safe)
	if not air.is_empty():
		lines.append(air)
	lines.append("The table: %s." % Tables.summary(safe))
	if got.get("image") != null:
		lines.append(judge_of(int(stood["faults"]), not _title.is_empty()))
	lines.append(_looks_line(got.get("image") != null))
	return {"text": "\n".join(lines), "images": [got["image"]] if got.get("image") != null else []}


## Where each thing [param got] ([method TablePreview.table]) stood, and what was left off: `lines`, and `faults` -
## how many were left off. A thing made smaller to fit is said at the size it is shown, not as a fault.
static func stood_lines(got: Dictionary) -> Dictionary:
	var lines := PackedStringArray()
	for s in got["stood"]:
		var d: Dictionary = s
		var at: Vector2 = d["at"]
		var where := "%d cm %s of the middle, %d cm %s" % [roundi(absf(at.x)), "right" if at.x >= 0.0 else "left",
			roundi(absf(at.y)), "toward the camera" if at.y >= 0.0 else "back"]
		var k := float(d["k"])
		var small := (" - shown at %d%% of its size, to fit (as it may be)" % roundi(k * 100.0)) if k < 0.995 else ""
		lines.append("- %s (%s): %s; %d%% of the picture's height%s" % [String(d["name"]), String(d["place"]), where,
			roundi(float(d["tall"]) * 100.0), small])
	for n in got["left_off"]:
		lines.append("- %s: LEFT OFF - no room for it in its place, clear of the cards, in the shot and not in front of another group" % String(n))
	return {"lines": lines, "faults": (got["left_off"] as Array).size()}


## What to ask of a set table's picture: to fix what is wrong while [param faults] remain ([method
## stood_lines]), else that THE TABLE IS SET - and what is left to do: the title's color, unless
## [param titled], then submit.
static func judge_of(faults: int, titled: bool) -> String:
	if faults > 0:
		return JUDGE_TABLE
	return JUDGE_SET % ("submit it" if titled else "choose the title's color and look at the opening, then submit")


## How many pictures this set dresser has taken, of [constant LOOKS].
func looks_used() -> int:
	return _looks


## THE TABLE FROM ABOVE: a plan of the draft on the episode's own table.
func _overhead() -> Dictionary:
	if _looks >= LOOKS:
		return {"text": _looks_line(false), "error": true}
	if not _can_stand():
		return {"text": "The table cannot be stood in this run (%s), so there is no picture of it: judge it by what put told you." %
			("no renderer" if not _can_see() else "no ghost session")}
	var got: Dictionary = await _preview.overhead(draft())
	if got.has("error"):
		return {"text": "The table could not be seen from above: %s" % String(got["error"]), "error": true}
	_looks += 1
	var lines := PackedStringArray(["The table from straight above, the reader's side at the bottom; the yellow line is the edge of what the camera sees."])
	lines.append_array(_describe_table())
	lines.append(JUDGE_OVERHEAD)
	lines.append(_looks_line(true))
	return {"text": "\n".join(lines), "images": [got["image"]]}


## THE TABLE ITSELF in words, as it will be built - and whatever had to change on the way.
func _describe_table() -> PackedStringArray:
	var notes := PackedStringArray()
	var raw := draft()
	var mats := Props.sanitize(raw, _look.get("palette", CardTable.FALLBACK_PALETTE))["materials"] as Dictionary
	var safe := Tables.sanitize(raw.get("top"), raw.get("layers"), mats, _look.get("palette", CardTable.FALLBACK_PALETTE), notes)
	var out := PackedStringArray(["The table: %s." % Tables.summary(safe)])
	if not _layers_put:
		out.append("(No layers are put yet, so the painting lies on it as a 120 x 72 cm cloth, as on every table before. Put `layers` to lay your own, or `layers: []` for a bare top.)")
	for n in notes:
		out.append("  - " + n)
	return out


func _layer_of(name: String) -> int:
	for i in _layers.size():
		if String((_layers[i] as Dictionary).get("name", "")) == name:
			return i
	return -1


func _watch(args: Dictionary) -> Dictionary:
	var nm := String(args.get("name", "")).strip_edges()
	if _effect_of(nm) < 0:
		if _light_part(nm):
			return await _watch_light(nm)
		return {"text": "Nothing called \"%s\" moves on this table. In its air: %s. In its light: %s." % [nm, _effect_names(), _light_names()], "error": true}
	var safe := _safe()
	var built := {}
	for e in safe.get("effects", []):
		if String((e as Dictionary).get("name", "")) == nm:
			built = e
	if built.is_empty():
		return {"text": "\"%s\" cannot be built: %s" % [nm, "; ".join(_air_troubles(_effects[_effect_of(nm)]))], "error": true}
	if _looks >= LOOKS:
		return {"text": _looks_line(false), "error": true}
	if not _can_stand():
		return {"text": "The table cannot be stood in this run (%s), so its air cannot be watched: judge it by what put told you." %
			("no renderer" if not _can_see() else "no ghost session")}
	var got: Dictionary = await _preview.watch(draft(), nm)
	if got.has("error"):
		return {"text": "\"%s\" could not be watched: %s" % [nm, String(got["error"])], "error": true}
	_looks += 1
	var frames := PackedStringArray()
	for f in got.get("frames", []):
		frames.append(("%.2f s after" % float(f)) if bool(got.get("burst", false)) else ("%d s on" % roundi(float(f))))
	var lines := PackedStringArray(_describe_air([nm]))
	lines.append("Four pictures, left to right and down: %s%s." % [", ".join(frames),
		(" the moment it marks, as the table stages it") if bool(got.get("burst", false)) else ""])
	lines.append(JUDGE_AIR)
	lines.append(_looks_line(true))
	return {"text": "\n".join(lines), "images": [got["image"]]}


## THE NAME'S COLOR over this table: kept in the draft, and - where a table can be stood - the
## opening photographed with it, and how far it stands out from what is behind it.
func _choose_title(args: Dictionary) -> Dictionary:
	var c := String(args["color"]).strip_edges() if args.get("color") is String else ""
	if not CardTable._is_color(c):
		return {"text": "\"%s\" is not a color: give `color` as #rrggbb." % str(args.get("color", "")), "error": true}
	_title = {"color": c, "why": String(args["why"]).strip_edges() if args.get("why") is String else ""}
	var lines := PackedStringArray(["The show's name is printed in %s." % c])
	if _looks >= LOOKS:
		lines.append(_looks_line(false))
		return {"text": "\n".join(lines)}
	if not _can_stand():
		lines.append("The opening cannot be shown in this run (%s): judge the color against the cloth you were shown." %
			("no renderer" if not _can_see() else "no ghost session"))
		return {"text": "\n".join(lines)}
	var got: Dictionary = await _preview.opening(draft())
	if got.has("error"):
		return {"text": "The opening could not be shown: %s" % String(got["error"]), "error": true}
	_looks += 1
	lines.append("The opening - the video's first seconds, and its thumbnail - with the name over this table thrown out of focus. Against the table behind it, the name's color stands at a contrast of %.1f where it is weakest (1 is the same color; 3 reads at a glance; 4.5 and up stands out even as a small thumbnail)." %
		float(got["contrast"]))
	lines.append(JUDGE_TITLE)
	lines.append(_looks_line(true))
	return {"text": "\n".join(lines), "images": [got["image"]]}


func _submit() -> Dictionary:
	var safe := _safe()
	if (safe["things"] as Array).is_empty():
		return {"text": "Nothing on the table can be built yet - put things first.", "error": true}
	# SEEN BEFORE IT IS HANDED IN: once, where a table can be stood at all
	if not _set_since_change and not _warned and _can_stand() and _looks < LOOKS:
		_warned = true
		return {"text": "You have not seen the table as it now stands: call set, look at the frame, fix what it shows, then submit. (Submit again unchanged to hand it in as it is.)", "error": true}
	# ...AND ITS NAME GIVEN A COLOR, once asked
	if _title.is_empty() and not _warned_title:
		_warned_title = true
		return {"text": "You have not chosen the color the show's name is printed in over this table: call title and look at the opening. (Submit again to hand the table in with the name in its usual cream.)", "error": true}
	var raw := draft()
	var path := dir.path_join(SUBMITTED)
	var err := TextGen.put(path + ".part", JSON.stringify(raw, "\t"))
	if err.is_empty() and DirAccess.rename_absolute(path + ".part", path) != OK:
		err = "could not move the table into place"
	if not err.is_empty():
		return {"text": "The table could not be handed in: %s" % err, "error": true}
	submitted = true
	return {"text": "Handed in: %d thing%s. The table is set - your work is done; end with one short line." %
		[(safe["things"] as Array).size(), "" if (safe["things"] as Array).size() == 1 else "s"]}


# --- the light ----------------------------------------------------------------------------------------

## THE LIGHT PUT, part by part ([Lights]): each part given replaces the last, and null takes it away;
## what the sun falls through, the lamps and the shadows go in by name - an entry replaces the one of its
## name - and an empty list takes them all away.
func _merge_light(d: Dictionary) -> void:
	_light_put = true
	for k in d:
		var key := String(k)
		var v: Variant = d[k]
		if v == null:
			_light.erase(key)
		elif key in ["through", "lamps", "shadows"] and v is Array:
			if (v as Array).is_empty():
				_light[key] = []
				continue
			var list: Array = (_light.get(key, []) as Array).duplicate(true) if _light.get(key) is Array else []
			for e in v:
				var nm := String((e as Dictionary).get("name", "")).strip_edges() if e is Dictionary else ""
				var at := -1
				for i in list.size():
					if not nm.is_empty() and list[i] is Dictionary and String((list[i] as Dictionary).get("name", "")).strip_edges() == nm:
						at = i
				var entry: Variant = (e as Dictionary).duplicate(true) if e is Dictionary else e
				if at >= 0:
					list[at] = entry
				else:
					list.append(entry)
			_light[key] = list
		else:
			_light[key] = (v as Dictionary).duplicate(true) if v is Dictionary else v


## THE SOUND IN WORDS, as it will be heard: what it is, everything that had to change, and the wind it
## follows - the light's, heard in open air when the sound says nothing of it.
func _describe_sound() -> PackedStringArray:
	var notes := PackedStringArray()
	Soundscape.sanitize(_sound, notes)
	var light: Dictionary = _light.duplicate(true) if _light_put else {}
	var made := Soundscape.of_table({"sound": _sound, "light": light}, episode.seed)
	var out := PackedStringArray()
	if (made["sound"] as Dictionary).is_empty():
		out.append("The sound: none - the reader alone, in a quiet room.")
	else:
		out.append("The sound: %s." % Soundscape.summary(made["sound"]))
	if not _sound.has("wind") and ((Lights.sanitize(light) if not light.is_empty() else {}).get("wind", {}) as Dictionary).size() > 0:
		out.append("  - the light's wind blows silently: give the sound a `wind` if it should be heard")
	for n in notes:
		out.append("  - " + n)
	return out


## A part of the light taken off by [param name]: what the sun falls through, a lamp or a shadow, by its
## name; or "sun", "sky", "clouds", "wind", "birds" - or "light", all of it (the table then lit as every table was).
func _unlight(name: String) -> bool:
	if not _light_put:
		return false
	var low := name.to_lower()
	if low == "light":
		_light = {}
		return true
	if low in ["sun", "sky", "clouds", "wind", "birds"] and _light.has(low):
		_light.erase(low)
		return true
	for key in ["through", "lamps", "shadows"]:
		var list: Array = _light.get(key, []) if _light.get(key) is Array else []
		for i in list.size():
			if list[i] is Dictionary and String((list[i] as Dictionary).get("name", "")).strip_edges() == name:
				list.remove_at(i)
				return true
	return false


## THE LIGHT IN WORDS, as it will be built: what it is and everything that had to change; where the sun
## falls - how much of the table the camera sees, and of where the cards lie, it reaches through what it
## falls through; how the weather runs in the first ten minutes; and every lamp moved up out of the shot.
func _describe_light() -> PackedStringArray:
	var notes := PackedStringArray()
	var light := Lights.sanitize(_light, notes)
	var out := PackedStringArray()
	if light.is_empty():
		out.append("The light: none of its own - the table is lit as every table was, by a lamp over it and candles in the room.")
		for n in notes:
			out.append("  - " + n)
		return out
	out.append("The light: %s." % Lights.summary(light))
	for n in notes:
		out.append("  - " + n)
	var seed := hash([episode.seed, "light"])
	var lay := CardTable.layout_of(episode.seed)
	var cam: Transform3D = lay["camera"]
	var fov := float(lay["fov"])
	var middle := Vector3(Tables.ORIGIN.x, 0.0, Tables.ORIGIN.y)
	var sun: Dictionary = light["sun"]
	if not sun.is_empty() and not (light["through"] as Array).is_empty():
		var seen := CardTable.seen_points(cam, fov, _safe()["top"])
		var geom := Lights.screens_of(light, middle, AABB(Vector3(-1.2, -0.1, -0.9), Vector3(2.4, 0.8, 1.8)), seen, seed)
		var s := Lights.sun_dir(sun)
		out.append("The sun reaches %d%% of the table the camera sees, and %d%% of where the cards lie (the deck, the shuffle, the spread)." % [
			roundi(Lights.coverage(geom, s, seen, 0.0) * 100.0), roundi(Lights.coverage(geom, s, CardTable.card_points(), 0.0) * 100.0)])
	var w := Lights.weather(light, seed)
	if not (light["clouds"] as Dictionary).is_empty():
		if float(w["cloud"]) >= 0.99:
			out.append("Clouds: the sun is behind them all the while - the sky is covered, the sun a glow through it.")
		elif int(w["passings"]) == 0:
			out.append("Clouds: none crosses the sun in the first ten minutes (%d%% of the time in cloud) - give them more cover, or bigger ones." % roundi(float(w["cloud"]) * 100.0))
		else:
			var last: Array = w["lasting"]
			out.append("Clouds: the sun is behind cloud %d%% of the first ten minutes - %d passing%s over it, %s." % [roundi(float(w["cloud"]) * 100.0),
				int(w["passings"]), "" if int(w["passings"]) == 1 else "s",
				("each %d to %d s" % [roundi(float(last[0])), roundi(float(last[1]))]) if roundi(float(last[0])) != roundi(float(last[1])) else "%d s" % roundi(float(last[1]))])
	if not (light["birds"] as Dictionary).is_empty():
		out.append("Birds: %d crossing%s in the first ten minutes, each shadow over the table for about %.1f s." % [int(w["birds"]),
			"" if int(w["birds"]) == 1 else "s", float(w["over"])])
	out.append_array(_describe_wind(light))
	var in_shot := func(at: Vector3) -> bool: return CardTable.in_shot(cam, fov, at)
	var lamps_at := {}
	for l in light["lamps"]:
		var place := Lights.lamp_place(l, middle, in_shot)
		lamps_at[String((l as Dictionary)["name"])] = place["at"]
		if bool(place["moved"]):
			out.append("  - \"%s\" would be seen where it was put: moved up out of the shot, to %d cm over the table." % [String((l as Dictionary)["name"]),
				roundi((place["at"] as Vector3).y * 100.0)])
	out.append_array(_describe_shadows(light, lamps_at, in_shot))
	return out


## WHERE EACH SHADOW OUT OF THE SHOT FALLS, in words: how much of the table the camera sees, and of where
## the cards lie, its outline covers, on which part of the table, whether it moves - and whether it was
## raised along its light's ray to stay out of the shot and clear of the table.
func _describe_shadows(light: Dictionary, lamps_at: Dictionary, in_shot: Callable) -> PackedStringArray:
	var out := PackedStringArray()
	var casters: Array = light.get("shadows", [])
	if casters.is_empty():
		return out
	var lay := CardTable.layout_of(episode.seed)
	var seen := CardTable.seen_points(lay["camera"], float(lay["fov"]), _safe()["top"])
	var cards := CardTable.card_points()
	var middle := Vector3(Tables.ORIGIN.x, 0.0, Tables.ORIGIN.y)
	var stage := {"middle": middle, "bounds": AABB(Vector3(-1.0, -0.1, -0.7), Vector3(2.0, 0.65, 1.3)), "in_shot": in_shot}
	var s := Lights.sun_dir(light["sun"]) if not (light["sun"] as Dictionary).is_empty() else Vector3.UP
	out.append("Shadows out of the shot:")
	for c in casters:
		var d: Dictionary = c
		var meshes := Lights.caster_meshes(d["parts"])
		var place := Lights.caster_place(d, meshes, light, stage, lamps_at)
		var by := String(d["around"]) if not String(d["around"]).is_empty() else String(d["by"])
		var outlines := Lights.caster_outlines(meshes, place["xform"], s, lamps_at.get(by) if by != "sun" else null)
		var on := 0
		var sum := Vector2.ZERO
		for p in seen:
			if Lights.in_outlines(outlines, Vector2(p.x, p.z)):
				on += 1
				sum += Vector2(p.x, p.z)
		var on_cards := 0
		for p in cards:
			if Lights.in_outlines(outlines, Vector2(p.x, p.z)):
				on_cards += 1
		var kind := String((d["move"] as Dictionary)["kind"])
		var line := "- \"%s\" (%s, %s): " % [String(d["name"]), kind, ("round " + by) if not String(d["around"]).is_empty() else ("the sun's" if by == "sun" else by + "'s")]
		if on == 0:
			line += "its shadow misses the table the camera sees - aim it nearer the middle, or let it hang lower"
		else:
			var at := sum / float(on)
			line += "its shadow covers %d%% of the table the camera sees, %s, and %d%% of where the cards lie" % [
				roundi(100.0 * on / maxf(float(seen.size()), 1.0)), _where_on_table(at - Vector2(middle.x, middle.z)),
				roundi(100.0 * on_cards / maxf(float(cards.size()), 1.0))]
		if bool(place["moved"]):
			line += "; raised along its light to %d cm, out of the shot and clear of the table" % roundi((place["middle"] as Vector3).y * 100.0)
		out.append(line + ".")
	return out


## Where on the table a point (x, z from the middle of the reading, meters) is, in words.
static func _where_on_table(p: Vector2) -> String:
	var side := "the left" if p.x < -0.18 else ("the right" if p.x > 0.18 else "the middle")
	var depth := "far " if p.y < -0.2 else ("near " if p.y > 0.12 else "")
	return "over %s%s" % [depth, side]


## The light in a line, for the table's own picture: what it is, and what moves in it that a still
## picture does not show.
func _light_line(safe: Dictionary) -> String:
	var light: Dictionary = safe.get("light", {})
	if light.is_empty():
		return ""
	var still := PackedStringArray()
	if not (light["clouds"] as Dictionary).is_empty():
		still.append("the sun out")
	if not (light["birds"] as Dictionary).is_empty():
		still.append("no bird crossing")
	var moving := _light_names()
	return "The light in this picture: %s%s%s." % [Lights.summary(light),
		(" - photographed with %s" % " and ".join(still)) if not still.is_empty() else "",
		("; watch %s to see %s move" % [moving, "it" if not moving.contains(",") else "them"]) if moving != "nothing that moves" else ""]


## Whether [param name] is a part of the light that moves: "clouds", "birds", or something the sun falls
## through or a lamp, by its name.
## THE WIND IN WORDS: how often it gusts in the first ten minutes and how hard, and - for what drifts in
## the air - how many of those gusts lift what lies on the cloth.
func _describe_wind(light: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	var wind: Dictionary = light.get("wind", {})
	var drifts: Array = []
	for e in _safe().get("effects", []):
		if String((e as Dictionary)["kind"]) == "drift":
			drifts.append(e)
	if wind.is_empty() and drifts.is_empty():
		return out
	var p := Winds.plan(wind, hash([episode.seed, "wind"]))
	var n := 0
	var most := 0.0
	for i in (p["starts"] as PackedFloat32Array).size():
		if float((p["starts"] as PackedFloat32Array)[i]) < 600.0:
			n += 1
			most = maxf(most, float((p["peaks"] as PackedFloat32Array)[i]))
	out.append("The wind%s: %d gust%s in the first ten minutes, the strongest %.1f m/s over a breeze of %.1f." % ["" if not wind.is_empty() else " (none written: still air, a faint breath)",
		n, "" if n == 1 else "s", most, float(p["breeze"])])
	for d in drifts:
		var e: Dictionary = d
		if float(e["grip"]) >= 0.999:
			out.append("  - \"%s\": nothing lying is ever lifted (grip 1)." % String(e["name"]))
			continue
		var lift := Drifts.LIFT.x + (Drifts.LIFT.y - Drifts.LIFT.x) * float(e["grip"])
		var lifts := 0
		for i in (p["starts"] as PackedFloat32Array).size():
			if float((p["starts"] as PackedFloat32Array)[i]) < 600.0 and float((p["peaks"] as PackedFloat32Array)[i]) >= lift:
				lifts += 1
		out.append("  - \"%s\": %d of those gusts blow hard enough (%.1f m/s) to lift what lies on the cloth%s." % [String(e["name"]), lifts, lift,
			" - none will: lower its grip, or give the wind more gusts" if lifts == 0 else ""])
	return out


func _light_part(name: String) -> bool:
	var light := Lights.sanitize(_light)
	if light.is_empty():
		return false
	if name.to_lower() == "clouds":
		return not (light["clouds"] as Dictionary).is_empty()
	if name.to_lower() == "birds":
		return not (light["birds"] as Dictionary).is_empty()
	if name.to_lower() == "wind":
		return not (light["wind"] as Dictionary).is_empty()
	for key in ["through", "lamps", "shadows"]:
		for e in light[key]:
			if String((e as Dictionary)["name"]) == name:
				return true
	return false


## What moves in the light, by name: clouds, birds, what the sun falls through when it stirs, every lamp
## that is not steady.
func _light_names() -> String:
	var light := Lights.sanitize(_light)
	var out := PackedStringArray()
	if not light.is_empty():
		if not (light["clouds"] as Dictionary).is_empty():
			out.append("clouds")
		if not (light["birds"] as Dictionary).is_empty():
			out.append("birds")
		if not (light["wind"] as Dictionary).is_empty():
			out.append("wind")
		for g in light["through"]:
			if float((g as Dictionary).get("sway", 0.0)) > 0.0 and String((g as Dictionary)["kind"]) in ["blinds", "leaves", "fronds", "branches", "awning", "parasol"]:
				out.append(String((g as Dictionary)["name"]))
		for l in light["lamps"]:
			if String((Lights.LAMPS[String((l as Dictionary)["look"])] as Dictionary)["flicker"]) != "steady":
				out.append(String((l as Dictionary)["name"]))
		for c in light.get("shadows", []):
			if String(((c as Dictionary)["move"] as Dictionary)["kind"]) != "still":
				out.append(String((c as Dictionary)["name"]))
	return ", ".join(out) if not out.is_empty() else "nothing that moves"


## A MOVING PART OF THE LIGHT watched on the episode's own table: four pictures as it moves.
func _watch_light(nm: String) -> Dictionary:
	if _looks >= LOOKS:
		return {"text": _looks_line(false), "error": true}
	if not _can_stand():
		return {"text": "The table cannot be stood in this run (%s), so its light cannot be watched: judge it by what put told you." %
			("no renderer" if not _can_see() else "no ghost session")}
	var got: Dictionary = await _preview.watch_light(draft(), nm)
	if got.has("error"):
		return {"text": "\"%s\" could not be watched: %s" % [nm, String(got["error"])], "error": true}
	_looks += 1
	var frames := PackedStringArray()
	for f in got.get("frames", []):
		frames.append("%.2f s in" % float(f))
	var lines := PackedStringArray([String(got.get("what", ""))])
	lines.append("Four pictures, left to right and down: %s." % ", ".join(frames))
	lines.append(JUDGE_LIGHT)
	lines.append(_looks_line(true))
	return {"text": "\n".join(lines), "images": [got["image"]]}


# --- what the builder makes of the draft --------------------------------------------------------------

## The draft made safe, as the table will build it.
func _safe() -> Dictionary:
	return CardTable.sanitize_table(draft(), _look)


## One block per thing named: its place, its size, its flames - and everything the builder could
## not make as written.
func _describe(names: Array) -> PackedStringArray:
	var safe := _safe()
	var head := CardTable.headroom(episode.seed)
	var out := PackedStringArray()
	for nm in names:
		var at := _index_of(String(nm))
		if at < 0:
			continue
		var raw: Dictionary = _things[at]
		var troubles := _troubles(raw)
		var built := {}
		for t in safe["things"]:
			if String((t as Dictionary).get("name", "")) == String(nm):
				built = t
				break
		if built.is_empty():
			out.append("%d. %s: NOTHING BUILT - %s" % [at + 1, String(nm), "; ".join(troubles) if not troubles.is_empty() else "it has no part the builder can make"])
			continue
		var b := Props.build(built, safe["materials"], hash([episode.seed, at, "describe"]))
		var box: AABB = b["size"]
		var node: Node3D = b["node"]
		var shrunk := node.get_child_count() > 0 and (node.get_child(0) as Node3D).scale.x < 0.999
		var flames := (b["wicks"] as Array).size()
		node.free()
		var place := String(built.get("place", "back"))
		var group := String(built.get("group", ""))
		out.append("%d. %s (%s%s): %s, %d part%s%s" % [at + 1, String(nm), place, (", group " + group) if not group.is_empty() else "",
			TablePreview.size_text(box), _count_parts(built.get("parts", [])), "" if _count_parts(built.get("parts", [])) == 1 else "s",
			(", %d flame%s" % [flames, "" if flames == 1 else "s"]) if flames > 0 else ""])
		if shrunk:
			troubles.append("larger than %d cm across: built smaller, whole" % roundi(Props.MAX_SIZE))
		var wrote := 0
		for p in raw.get("parts", []) if raw.get("parts") is Array else []:
			if p is Dictionary:
				wrote += _flames_written(p as Dictionary)
		if wrote > flames:
			troubles.append("%d of its flames stay unlit: a table lights at most %d things, %d flames on one" % [wrote - flames, CardTable.MAX_CANDLES, CardTable.MAX_FLAMES])
		var room := int(head.get(place, 99))
		if box.size.y * 100.0 > float(room) + 0.5:
			troubles.append("%s cm tall, and \"%s\" shows only %d cm: it will be made smaller or left off" % [TablePreview._cm(box.size.y), place, room])
		for tr in troubles:
			out.append("   - " + tr)
	return out


## What the builder cannot make of thing [param t] as written: one line each.
func _troubles(t: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	if not (t.get("parts") is Array) or (t["parts"] as Array).is_empty():
		out.append("it has no parts")
		return out
	_part_troubles(t["parts"], 0, [Props.MAX_PARTS], "", out)
	var place := String(t.get("place", "")).strip_edges().to_lower()
	if not place.is_empty() and not CardTable.ZONES.has(place):
		out.append("\"%s\" is not a place: it will stand at the back" % place)
	return out


func _part_troubles(list: Array, depth: int, budget: Array, path: String, out: PackedStringArray) -> void:
	for i in list.size():
		var where := "%s%d" % [path, i + 1]
		if int(budget[0]) <= 0:
			out.append("part %s and the rest: past the %d parts a thing may have - left out" % [where, Props.MAX_PARTS])
			return
		if not (list[i] is Dictionary):
			out.append("part %s is not a part - left out" % where)
			continue
		var d: Dictionary = list[i]
		if d.get("parts") is Array:
			if depth >= Props.MAX_DEPTH:
				out.append("group %s is more than %d groups deep - left out, with everything in it" % [where, Props.MAX_DEPTH])
			else:
				_part_troubles(d["parts"], depth + 1, budget, where + ".", out)
			continue
		var shape := String(d.get("shape", "")).strip_edges().to_lower()
		if not Props.SHAPES.has(shape):
			out.append("part %s: \"%s\" is not a shape - left out" % [where, str(d.get("shape", ""))])
			continue
		if shape == "lathe" and Props._points2(d.get("profile"), Vector2(0.0, -1.0), Vector2(Props.MAX_SIZE, Props.MAX_SIZE)).size() < 2:
			out.append("part %s: a lathe's profile needs two [radius, height] points or more - left out" % where)
			continue
		if shape == "tube" and Props._points3(d.get("path"), Props.MAX_SIZE).size() < 2:
			out.append("part %s: a tube's path needs two [x, y, z] points or more - left out" % where)
			continue
		if shape == "sculpt":
			var strokes := Props._strokes(d.get("strokes"))
			if strokes.is_empty():
				out.append("part %s: a sculpt needs `strokes`, each with `points` [[x, y, z, r], ...] - left out" % where)
				continue
			# A ROD THINNER THAN THE SCULPT IS CUT comes out broken: said before it is built, with how thick to make it
			var cut := Props.sculpt_cut({"strokes": strokes, "mirror": Props._flag(d.get("mirror"))})
			var thin: Array = cut["thin"]
			for si in thin.size():
				if float(thin[si]) < float(cut["cell"]) * 0.6:
					out.append("part %s: stroke %d is %s cm thick at its thinnest, finer than this sculpt is cut (about %s cm) - it may come out broken or vanish: make it thicker, or the sculpt smaller" % [where, si + 1,
						str(snappedf(float(thin[si]), 0.01)), str(snappedf(float(cut["cell"]), 0.01))])
		if d.has("warp") and not (d["warp"] is Dictionary):
			out.append("part %s: its warp is not {\"bend\": ..., ...} - not warped" % where)
		elif d.get("warp") is Dictionary:
			for k in (d["warp"] as Dictionary):
				if not (Props.WARPS.has(String(k)) or String(k) in ["scale", "lean"]):
					out.append("part %s: \"%s\" is not a warp - ignored" % [where, String(k)])
		budget[0] = int(budget[0]) - 1
		var names: Array = d["material"] if d.get("material") is Array else [d.get("material", "")]
		for m in names:
			if m is Dictionary:
				continue
			var nm := String(m).strip_edges() if m is String else ""
			if nm.is_empty():
				out.append("part %s names no material - painted in the deck's colors" % where)
			elif not _materials.has(nm) and not Props.MATERIALS.has(nm.to_lower()):
				out.append("part %s: \"%s\" is not one of the table's materials - painted in the deck's colors" % [where, nm])


## What the builder cannot make of material [param m] as written.
static func _material_troubles(name: String, m: Variant) -> PackedStringArray:
	var out := PackedStringArray()
	if not (m is Dictionary):
		out.append("\"%s\" is not a material {kind, color, ...} - painted" % name)
		return out
	var d: Dictionary = m
	var kind := String(d.get("kind", "")).strip_edges().to_lower()
	if not Props.MATERIALS.has(kind):
		out.append("\"%s\": \"%s\" is not a kind of material - painted" % [name, kind])
	if not Props._is_color(d.get("color", "")):
		out.append("\"%s\": its color is not #rrggbb - one of the deck's colors" % name)
	if d.has("play") and not Props.PLAYS.has(String(d["play"]).strip_edges().to_lower()):
		out.append("\"%s\": \"%s\" is not a play of light - none" % [name, str(d["play"])])
	return out


## The flames a part asks for as written, every copy of it.
static func _flames_written(p: Dictionary) -> int:
	var n := 0
	if p.get("parts") is Array:
		for q in p["parts"]:
			if q is Dictionary:
				n += _flames_written(q as Dictionary)
	elif p.get("wicks") is Array:
		n = (p["wicks"] as Array).size()
	elif p.get("wicks") is float or p.get("wicks") is int:
		n = int(p["wicks"])
	elif p.get("wick") == true:
		n = 1
	var c: Variant = p.get("copies", {})
	var count := 1
	if c is Dictionary:
		for kind in c:
			if (c as Dictionary)[kind] is Dictionary:
				count = maxi(1, int(((c as Dictionary)[kind] as Dictionary).get("count", 1)))
	return n * count


static func _count_parts(parts: Variant) -> int:
	var n := 0
	for p in parts if parts is Array else []:
		n += _count_parts((p as Dictionary)["parts"]) if (p as Dictionary).get("parts") is Array else 1
	return n


## The table as a whole against what the look asked for: lit things, and the others.
func _tally() -> String:
	var safe := _safe()
	var lit := 0
	for t in safe["things"]:
		var f := 0
		for p in (t as Dictionary).get("parts", []):
			f += Props.flames_of(p as Dictionary)
		lit += 1 if f > 0 else 0
	var others := (safe["things"] as Array).size() - lit
	var asked := clampi(int(_look.get("candles", 1)), 0, CardTable.MAX_CANDLES)
	var size := CardPrompts.table_size(episode.seed)
	return "The table: %d lit thing%s (%d asked for), %d other thing%s (%d to %d asked for)." % [lit, "" if lit == 1 else "s",
		asked, others, "" if others == 1 else "s", size.x, size.y]


## One block per effect named: what it is, where or when - and anything the builder could not use.
func _describe_air(names: Array) -> PackedStringArray:
	var safe := _safe()
	var out := PackedStringArray()
	for nm in names:
		var at := _effect_of(String(nm))
		if at < 0:
			continue
		var built := {}
		for e in safe.get("effects", []):
			if String((e as Dictionary).get("name", "")) == String(nm):
				built = e
		var troubles := _air_troubles(_effects[at])
		if built.is_empty():
			out.append("- %s: NOT BUILT - %s" % [String(nm), "; ".join(troubles) if not troubles.is_empty() else "there is more air than a table holds"])
			continue
		var what := ""
		match String(built["kind"]):
			"fog":
				what = "fog %s, density %.2f, reaching %d cm" % [String(built["where"]), float(built["density"]), roundi(float(built["height"]))]
			"motes":
				what = "%s %s, %s mm%s" % [Effects.count_of(String(built["look"]), int(built["count"])), String(built["where"]),
					Effects._mm(float(built["size"])), ", lit" if bool(built["light"]) else ""]
			"burst":
				var which: Variant = built.get("which", "every")
				what = "%s on %s (%s), %d of them, %s mm" % [String(built["look"]), String(built["on"]),
					("times " + ", ".join(PackedStringArray((which as Array).map(func(x: Variant) -> String: return str(x))))) if which is Array else String(which),
					int(built["count"]), Effects._mm(float(built["size"]))]
			"drift":
				what = "%s %s, one every %d s or so and up to %d a gust, %s mm, %d%% settling, grip %.1f%s" % [String(built["look"]),
					"falling from overhead" if String(built["from"]) == "above" else "blown in on the wind", roundi(float(built["every"])), roundi(float(built["shake"])),
					Effects._mm(float(built["size"])), roundi(float(built["settle"]) * 100.0), float(built["grip"]),
					(", %d lying at the start" % int(built["lying"])) if int(built["lying"]) > 0 else ""]
		out.append("- %s: %s" % [String(nm), what])
		for tr in troubles:
			out.append("   - " + tr)
	return out


## What the air builder cannot use of effect [param e] as written: one line each.
func _air_troubles(e: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	var kind := String(e.get("kind", "")).strip_edges().to_lower()
	if not Effects.KINDS.has(kind):
		out.append("\"%s\" is not a kind of effect (%s)" % [kind, ", ".join(PackedStringArray(Effects.KINDS.keys()))])
		return out
	if kind == "fog" or kind == "motes":
		var where := String(e.get("where", "")).strip_edges().to_lower()
		if not CardTable.AIR.has(where):
			out.append("\"%s\" is not a place in the air: %s" % [where, ", ".join(PackedStringArray(CardTable.AIR.keys()))])
	if kind == "motes" or kind == "burst":
		var look := String(e.get("look", "")).strip_edges().to_lower()
		var looks: Dictionary = Effects.MOTES if kind == "motes" else Effects.BURSTS
		if not looks.has(look):
			out.append("\"%s\" is not a look of %s: %s" % [look, kind, ", ".join(PackedStringArray(looks.keys()))])
		elif e.has("size") and (e["size"] is float or e["size"] is int):
			var r: Vector2 = (looks[look] as Dictionary)["sizes"]
			if float(e["size"]) < r.x or float(e["size"]) > r.y:
				out.append("a %s is %s to %s mm: its size was kept within that" % [look, Effects._mm(r.x), Effects._mm(r.y)])
		if kind == "motes" and looks.has(look) and String((looks[look] as Dictionary)["shape"]) == "speck" and Props._flag(e.get("light"), false):
			out.append("a %s is a dark speck and carries no light: it was left unlit" % look)
	if kind == "drift":
		var look := String(e.get("look", "")).strip_edges().to_lower()
		if not Drifts.LOOKS.has(look):
			out.append("\"%s\" is not a look of drift: %s" % [look, ", ".join(PackedStringArray(Drifts.LOOKS.keys()))])
		elif e.has("size") and (e["size"] is float or e["size"] is int):
			var r: Vector2 = (Drifts.LOOKS[look] as Dictionary)["sizes"]
			if float(e["size"]) < r.x or float(e["size"]) > r.y:
				out.append("%s are %s to %s mm: their size was kept within that" % [look, Effects._mm(r.x), Effects._mm(r.y)])
		var from := String(e.get("from", "above")).strip_edges().to_lower()
		if not Drifts.FROMS.has(from):
			out.append("\"%s\" is not where a drift comes from (%s): above" % [from, ", ".join(PackedStringArray(Drifts.FROMS.keys()))])
	if kind == "burst":
		var on := String(e.get("on", "")).strip_edges().to_lower()
		if not CardTable.MOMENTS.has(on):
			out.append("\"%s\" is not a moment: %s" % [on, ", ".join(PackedStringArray(CardTable.MOMENTS.keys()))])
		elif on == "jumper" and not _jumps():
			out.append("no card leaps out of the deck in this reading: a burst on \"jumper\" would never be seen")
	return out


## A card leaps out of this episode's shuffle: its draw says so, once drawn; else the seed does.
func _jumps() -> bool:
	var draw: Variant = episode.read_json("draw")
	if draw is Dictionary and (draw as Dictionary).get("cards") is Array and not ((draw as Dictionary)["cards"] as Array).is_empty():
		return bool((((draw as Dictionary)["cards"] as Array)[0] as Dictionary).get("jumper", false))
	return CardProducer.jumps(episode.seed, true, plan)


## The air in a line, for the table's own picture: what is in it, and that a burst is watched.
func _air_line(safe: Dictionary) -> String:
	var parts := PackedStringArray()
	var bursts := 0
	for e in safe.get("effects", []):
		var d: Dictionary = e
		match String(d["kind"]):
			"fog":
				parts.append("%s (fog, %s)" % [String(d["name"]), String(d["where"])])
			"motes":
				parts.append("%s (%s, %s)" % [String(d["name"]), Effects.count_of(String(d["look"]), int(d["count"])), String(d["where"])])
			"burst":
				bursts += 1
			"drift":
				parts.append("%s (%s, one every %d s or so%s)" % [String(d["name"]), String(d["look"]), roundi(float(d["every"])),
					(", %d lying" % int(d["lying"])) if int(d["lying"]) > 0 else ""])
	if parts.is_empty() and bursts == 0:
		return ""
	return "The air in this picture: %s.%s" % [", ".join(parts) if not parts.is_empty() else "none still", (" Its %d burst%s only show at %s moment - watch %s." % [bursts,
		"" if bursts == 1 else "s", "its" if bursts == 1 else "their", "it" if bursts == 1 else "each"]) if bursts > 0 else ""]


func _effect_of(name: String) -> int:
	for i in _effects.size():
		if String((_effects[i] as Dictionary).get("name", "")) == name:
			return i
	return -1


func _effect_names() -> String:
	var out := PackedStringArray()
	for e in _effects:
		out.append(String((e as Dictionary).get("name", "")))
	return ", ".join(out) if not out.is_empty() else "nothing yet"


func _index_of(name: String) -> int:
	for i in _things.size():
		if String((_things[i] as Dictionary).get("name", "")) == name:
			return i
	return -1


func _names() -> String:
	var out := PackedStringArray()
	for t in _things:
		out.append(String((t as Dictionary).get("name", "")))
	return ", ".join(out) if not out.is_empty() else "nothing yet"


## A picture from [param take], counted - or null when none can be taken or none are left.
func _picture(take: Callable) -> Image:
	if _looks >= LOOKS or not _can_see():
		return null
	var img: Image = await take.call()
	if img != null:
		_looks += 1
	return img


func _looks_line(took: bool) -> String:
	if not _can_see():
		return "(No pictures in this run - it has no renderer.)"
	if _looks >= LOOKS:
		return "No looks left: submit the table." if not took else "That was your last look: submit the table."
	return "Looks left: %d." % (LOOKS - _looks)


## Whether this run can take pictures, and stand the episode's table ([TablePreview]) - a gate's seam.
func _can_see() -> bool:
	return TablePreview.can_see()


func _can_stand() -> bool:
	return TablePreview.can_set()
