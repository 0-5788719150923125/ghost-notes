extends RefCounted
class_name DealerTools

## DealerTools - what a dealer can do while it lays an episode's cards out (next/notes.md step 9,
## "Agents choose"): PLACE a card where it should lie, FLIP it face up or down, LOOK at the whole
## layout as the table will check it, and SUBMIT it. Served as tools ([AgentTools]), as the set
## dresser's are ([SetDresserTools]): the dealer keeps a draft here and works on it, and every answer
## says what the table would say - a card off the cloth, partly out of the camera's frame, over the
## deck ([method TablePositions.troubles]) - so the layout is right before it is handed in.
##
## IT CHOOSES WHERE, NEVER WHAT. Which card is which is the shuffle's, from the seed (NO CHEATING): the
## dealer places "card 1", "card 2" in drawing order and is told no names - a dealer that could see
## the draw could deal for it. The plan's spread names each position (its name and its question);
## the dealer gives it a place on the cloth.
##
## A handed-in layout is `layout.json` in the episode's folder (`{positions: [{card, x, z, yaw,
## face}]}`); the episode lays its coordinates over the plan's positions ([method TarotEpisode.document])
## and the table lies its cards there ([method TablePositions.given]). A layout with any trouble is
## not accepted, so the table never has to fall back from a submitted one.

## The file a handed-in layout is written to, in the episode's folder.
const LAYOUT := "layout.json"

var episode: TarotEpisode
var plan: Dictionary
var submitted := false

var _n := 0
var _draft := {}            # card (1-based) -> {x, z, yaw, face}


## [param n]: how many cards the episode draws.
func _init(ep: TarotEpisode, episode_plan: Dictionary, n: int) -> void:
	episode = ep
	plan = episode_plan
	_n = n


func instructions() -> String:
	return ("You lay out the cards of one reading on the table. Place each card - card 1 to card %d, in the order they are drawn - "
		% _n + "where it should lie, then look at the layout, fix what the table objects to, and submit it. "
		+ "You are never told which card is which: the shuffle decides that.\n\n" + TablePositions.describe(episode.seed)
		+ "\n\n" + _spread_line())


func list_tools() -> Array:
	return [
		{"name": "place", "description": "Put a card where it should lie: x and z on the cloth in meters, yaw in degrees (0 = its long side running back to front), face up or down. Placing a card again moves it. Answered with anything the table objects to.",
			"inputSchema": {"type": "object", "properties": {
				"card": {"type": "integer", "minimum": 1, "maximum": _n},
				"x": {"type": "number"}, "z": {"type": "number"}, "yaw": {"type": "number"},
				"face": {"type": "string", "enum": ["up", "down"]}},
				"required": ["card", "x", "z"]}},
		{"name": "flip", "description": "Turn a placed card face up or face down where it lies.",
			"inputSchema": {"type": "object", "properties": {
				"card": {"type": "integer", "minimum": 1, "maximum": _n},
				"face": {"type": "string", "enum": ["up", "down"]}}, "required": ["card", "face"]}},
		{"name": "look", "description": "The whole layout as the table will check it: every card's place, what the table objects to, which cards lie over which, and which are not placed yet.",
			"inputSchema": {"type": "object", "properties": {}}},
		{"name": "submit", "description": "Hand the layout in. Every card must be placed and nothing objected to.",
			"inputSchema": {"type": "object", "properties": {}}},
	]


func call_tool(name: String, args: Dictionary) -> Dictionary:
	match name:
		"place":
			return _place(args)
		"flip":
			return _flip(args)
		"look":
			return {"text": _look()}
		"submit":
			return _submit()
	return {"text": "", "error": "no tool '%s'" % name}


## The draft as slots, in card order - only the placed cards, each with its card number.
func slots() -> Array:
	var out: Array = []
	for k in range(1, _n + 1):
		if _draft.has(k):
			var s := TablePositions.slot_of(_draft[k], k - 1)
			s["card"] = k
			out.append(s)
	return out


func _place(args: Dictionary) -> Dictionary:
	var k := int(args.get("card", 0))
	if k < 1 or k > _n:
		return {"text": "", "error": "there is no card %d - this reading draws %d" % [k, _n]}
	if not (typeof(args.get("x")) in [TYPE_INT, TYPE_FLOAT]) or not (typeof(args.get("z")) in [TYPE_INT, TYPE_FLOAT]):
		return {"text": "", "error": "a place needs x and z, in meters"}
	_draft[k] = {"x": float(args["x"]), "z": float(args["z"]), "yaw": float(args.get("yaw", 0.0)),
		"face": "down" if String(args.get("face", "up")) == "down" else "up"}
	var mine := _troubles_of(k)
	return {"text": ("card %d placed at x %.3f, z %.3f, yaw %.1f, face %s." % [k, float(args["x"]), float(args["z"]),
		float(_draft[k]["yaw"]), _draft[k]["face"]]) + ("" if mine.is_empty() else " The table objects: " + "; ".join(mine))}


func _flip(args: Dictionary) -> Dictionary:
	var k := int(args.get("card", 0))
	if not _draft.has(k):
		return {"text": "", "error": "card %d is not placed yet" % k}
	(_draft[k] as Dictionary)["face"] = "down" if String(args.get("face", "up")) == "down" else "up"
	return {"text": "card %d is face %s." % [k, _draft[k]["face"]]}


func _look() -> String:
	var lines := PackedStringArray()
	for s in slots():
		var p: Vector3 = s["pos"]
		lines.append("card %d: x %.3f, z %.3f, yaw %.1f, face %s" % [int(s["card"]), p.x, p.z, rad_to_deg(float(s["yaw"])), s["face"]])
	var missing := PackedStringArray()
	for k in range(1, _n + 1):
		if not _draft.has(k):
			missing.append("card %d" % k)
	if not missing.is_empty():
		lines.append("Not placed yet: " + ", ".join(missing))
	var t := troubles()
	lines.append("The table objects to nothing." if t.is_empty() else "The table objects: " + "; ".join(t))
	var notes := TablePositions.notes(slots())
	if not notes.is_empty():
		lines.append("Overlapping (allowed): " + "; ".join(notes))
	return "\n".join(lines)


## What the table objects to in the draft as it stands.
func troubles() -> PackedStringArray:
	var placed := slots()
	var raw := TablePositions.troubles(placed, episode.seed)
	# the slots are the placed cards in order: put each trouble back on its own card's number
	var out := PackedStringArray()
	for line in raw:
		var i := int(String(line).get_slice(" ", 1).trim_suffix(":")) - 1
		var k := int((placed[i] as Dictionary)["card"]) if i >= 0 and i < placed.size() else i + 1
		out.append("card %d: %s" % [k, String(line).get_slice(": ", 1)])
	return out


func _troubles_of(k: int) -> PackedStringArray:
	var out := PackedStringArray()
	for line in troubles():
		if String(line).begins_with("card %d:" % k):
			out.append(String(line).get_slice(": ", 1))
	return out


func _submit() -> Dictionary:
	if _draft.size() < _n:
		return {"text": "", "error": "not every card is placed: " + _look().get_slice("\n", _draft.size())}
	var t := troubles()
	if not t.is_empty():
		return {"text": "", "error": "the table objects: " + "; ".join(t)}
	var positions: Array = []
	for k in range(1, _n + 1):
		var d: Dictionary = _draft[k]
		positions.append({"card": k, "x": snappedf(float(d["x"]), 0.0001), "z": snappedf(float(d["z"]), 0.0001),
			"yaw": snappedf(float(d["yaw"]), 0.01), "face": d["face"]})
	DirAccess.make_dir_recursive_absolute(episode.dir)
	var f := FileAccess.open(episode.dir.path_join(LAYOUT), FileAccess.WRITE)
	if f == null:
		return {"text": "", "error": "could not write the layout (error %d)" % FileAccess.get_open_error()}
	f.store_string(JSON.stringify({"positions": positions}, "\t"))
	f.close()
	submitted = true
	return {"text": "The layout is handed in: %d cards." % _n}


func _spread_line() -> String:
	var names := PackedStringArray()
	var spread: Variant = plan.get("spread", {})
	for p in ((spread as Dictionary).get("positions", []) if spread is Dictionary else []):
		if p is Dictionary:
			names.append("card %d - %s" % [names.size() + 1, String((p as Dictionary).get("name", "?"))])
	return ("The plan names the positions: " + "; ".join(names) + ".") if not names.is_empty() else ""
