extends RefCounted
class_name GamePrepTools

## GamePrepTools - what the game master has alone, before anyone sits down (next/tabletop.md): real dice for what the game's rules roll when a character is made, and handing the preparation in. Nothing thrown here is on any table.

const SUBMITTED := "submitted.json"

var dir := ""
var seed_value := 0
## Every player who must have a sheet.
var players: PackedStringArray = PackedStringArray()
var submitted := false
var _rolled := 0
var _released := false


func _init(job_dir: String, seed_of: int, the_players: PackedStringArray) -> void:
	dir = job_dir
	seed_value = seed_of
	players = the_players
	DirAccess.make_dir_recursive_absolute(dir)
	for f in DirAccess.get_files_at(dir):
		if String(f) == SUBMITTED or String(f) == "tools.jsonl":
			DirAccess.remove_absolute(dir.path_join(String(f)))


func release() -> void:
	_released = true


func instructions() -> String:
	return "Real dice, for what the rules roll when a character is made, and handing your preparation in."


func list_tools() -> Array:
	return [
		{"name": "roll", "description": "Real dice, now. Written as players write them: 4d6dl1, 1d20+5, 2d6. What comes up stands. Say what it is for.",
			"inputSchema": {"type": "object", "properties": {"dice": {"type": "string"}, "why": {"type": "string"}}, "required": ["dice"]}},
		{"name": "submit_prep", "description": "Hand in the whole preparation, in the shape you were shown. Answered with what is missing, if anything.",
			"inputSchema": {"type": "object", "properties": {"prep": {"type": "object"}}, "required": ["prep"]}},
	]


func call_tool(name: String, args: Dictionary) -> Dictionary:
	if _released or submitted:
		return {"text": "This preparation is handed in.", "error": true}
	match name:
		"roll":
			_rolled += 1
			var got := DiceNotation.roll(String(args.get("dice", "")), hash([seed_value, "prep", _rolled]))
			if not bool(got["ok"]):
				return {"text": String(got["error"]), "error": true}
			return {"text": String(got["words"])}
		"submit_prep":
			var prep: Variant = args.get("prep")
			var wrong := problems(prep, players)
			if not wrong.is_empty():
				return {"text": "\n".join(wrong), "error": true}
			var path := dir.path_join(SUBMITTED)
			var f := FileAccess.open(path + ".part", FileAccess.WRITE)
			if f == null:
				return {"text": "could not write it", "error": true}
			f.store_string(JSON.stringify(prep))
			f.close()
			DirAccess.rename_absolute(path + ".part", path)
			submitted = true
			return {"text": "Handed in. Your work is done."}
	return {"text": "No tool called %s." % name, "error": true}


## What a preparation lacks, each said in words: only what the table reads is required - every player a sheet and a want.
static func problems(prep: Variant, the_players: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	if not (prep is Dictionary):
		return PackedStringArray(["the preparation is an object"])
	var d: Dictionary = prep
	if String(d.get("starts", "")).strip_edges().is_empty():
		out.append("`starts`: the situation they are dropped into")
	if not (d.get("people") is Dictionary):
		out.append("`people`: each player's character, sheet and want")
		return out
	var people: Dictionary = d["people"]
	for who in the_players:
		var got: Variant = _named(people, who)
		if not (got is Dictionary):
			out.append("`people`: nothing for %s" % who)
			continue
		var g: Dictionary = got
		if not (g.get("sheet") is Dictionary) or (g["sheet"] as Dictionary).is_empty():
			out.append("%s has no `sheet`" % who)
		if String(g.get("wants", "")).strip_edges().is_empty():
			out.append("%s has no `wants`" % who)
	return out


static func _named(people: Dictionary, who: String) -> Variant:
	if people.has(who):
		return people[who]
	for k in people:
		if String(k).to_lower() == who.to_lower():
			return people[k]
	return null
