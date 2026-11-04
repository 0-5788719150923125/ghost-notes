extends RefCounted
class_name ModelTools

## ModelTools - WHAT THE MODELER WORKS WITH ([TablePrompts.modeler], [AssemblyModel]): a loop, as the set dresser's and the puppeteer's are, because nobody draws a thing well without looking at it.
##
##   shape   - write sections of it (one of a name already there replaces it), told what the whole now comes to in real parts, and what holds on to nothing
##   remove  - take sections out
##   look    - see it from four sides, as far as a section if asked ([ModelStudio])
##   submit  - hand it in: refused while it comes to too many parts, or anything floats until handed in so twice
##
## What it writes is data, worked out on a worker: a model takes seconds, and the app goes on drawing. EVERY PICTURE COUNTS against [constant LOOKS]; words cost nothing.

const SUBMITTED := "submitted.json"
## How many pictures one modeler may take.
const LOOKS := 24
const JUDGE := "Would a stranger know what this is from any one of these? What is flat, empty, muddy or wrong, and what would make it better?"

var dir := ""
var submitted := false

var _raw := {"sections": []}
var _made := {}
var _looks := 0
var _busy := false
var _released := false
var _warned_floating := false


func _init(job_dir: String) -> void:
	dir = job_dir
	DirAccess.make_dir_recursive_absolute(dir)
	for f in DirAccess.get_files_at(dir):
		var fs := String(f)
		if fs == SUBMITTED or fs == "tools.jsonl" or (fs.begins_with("look_") and fs.ends_with(".jpg")):
			DirAccess.remove_absolute(dir.path_join(fs))


func release() -> void:
	_released = true


func looks_used() -> int:
	return _looks


func instructions() -> String:
	return "Tools for designing what this episode builds: write its shapes, be told what parts they come to, look at it from every side, and hand it in."


func list_tools() -> Array:
	return [
		{"name": "shape", "description": "Write the model, or any part of it. Give any of `name`, `size`, `colors`, `base_color`, and `sections`: each section {name, about, shapes}, in the order it is built; one with the name of a section already there replaces it where it stands, and a new one goes at the end. Answers with what the whole model now comes to in real parts, section by section, what holds on to nothing, and how it looks from straight above.",
			"inputSchema": {"type": "object", "properties": {
				"name": {"type": "string"}, "size": {"type": "array", "items": {"type": "number"}}, "colors": {"type": "object"}, "base_color": {"type": "string"},
				"sections": {"type": "array", "items": {"type": "object"}, "description": "each {name, about, shapes}"}}}},
		{"name": "remove", "description": "Take sections out of the model, by name.", "inputSchema": {"type": "object", "properties": {"names": {"type": "array", "items": {"type": "string"}}}, "required": ["names"]}},
		{"name": "look", "description": "See the model in its real parts on its plate, from four sides, by a plain light: the whole of it, or as it stands once `section` is done.",
			"inputSchema": {"type": "object", "properties": {"section": {"type": "string", "description": "the last section to show (left out: all of them)"}}}},
		{"name": "submit", "description": "Hand the model in as it now stands. Answers with what keeps it from being handed in, if anything; otherwise the design is done, and so is your work.", "inputSchema": {"type": "object", "properties": {}}},
	]


func call_tool(name: String, args: Dictionary) -> Dictionary:
	while _busy and not _released:
		await TablePreview._tree().process_frame
	if _released:
		return {"text": "The model has been handed in and its tools are closed.", "error": true}
	_busy = true
	var out: Dictionary = await _call(name, args)
	_busy = false
	return out


func _call(name: String, args: Dictionary) -> Dictionary:
	match name:
		"shape":
			return await _shape(args)
		"remove":
			return await _remove(args)
		"look":
			return await _look(args)
		"submit":
			return await _submit()
	return {"text": "There is no tool called \"%s\": shape, remove, look and submit are the tools." % name, "error": true}


## The draft as written - the shape a one-reply answer has.
func draft() -> Dictionary:
	return _raw.duplicate(true)


func _shape(args: Dictionary) -> Dictionary:
	for k in ["name", "size", "colors", "base_color"]:
		if args.has(k):
			_raw[k] = args[k]
	for s in (args.get("sections") if args.get("sections") is Array else []):
		if not (s is Dictionary):
			continue
		var nm := String((s as Dictionary).get("name", "")).strip_edges().to_lower()
		var list: Array = _raw["sections"]
		var at := -1
		for i in list.size():
			if String((list[i] as Dictionary).get("name", "")).strip_edges().to_lower() == nm:
				at = i
		if at >= 0:
			list[at] = s
		else:
			list.append(s)
	return await _said()


func _remove(args: Dictionary) -> Dictionary:
	var names: Array = args.get("names") if args.get("names") is Array else []
	var left: Array = []
	for s in _raw["sections"]:
		if not names.has(String((s as Dictionary).get("name", "")).strip_edges()) and not names.has(String((s as Dictionary).get("name", "")).strip_edges().to_lower()):
			left.append(s)
	_raw["sections"] = left
	return await _said()


func _said() -> Dictionary:
	await _make_now()
	return {"text": AssemblyModel.report(_made) + "\n\n" + AssemblyModel.plan_text(_made)}


## The model worked out on a worker: the app goes on drawing while it is.
func _make_now() -> void:
	var holder := {}
	var raw := draft()
	var task := WorkerThreadPool.add_task(func() -> void: holder["made"] = AssemblyModel.make(raw), false, "a model laid")
	while not WorkerThreadPool.is_task_completed(task):
		await TablePreview._tree().process_frame
	WorkerThreadPool.wait_for_task_completion(task)
	_made = holder["made"]


func _look(args: Dictionary) -> Dictionary:
	if _looks >= LOOKS:
		return {"text": "No looks left: submit the model.", "error": true}
	if _made.is_empty() or (_made["parts"] as Array).is_empty():
		return {"text": "There is nothing to look at yet: write some shapes.", "error": true}
	if not TablePreview.can_see():
		return {"text": "No pictures can be taken in this run: judge it by what `shape` told you."}
	var upto := -1
	if args.get("section") is String:
		var want := String(args["section"]).strip_edges().to_lower()
		var found := -1
		for i in (_made["sections"] as Array).size():
			if String(((_made["sections"] as Array)[i] as Dictionary)["name"]) == want:
				found = i
		if found < 0:
			return {"text": "There is no section called \"%s\"." % want, "error": true}
		upto = 0
		for q in _made["parts"]:
			if int((q as Dictionary)["section"]) <= found:
				upto += 1
	var got: Dictionary = await ModelStudio.views(_made, upto)
	if got.has("error"):
		return {"text": "It could not be shown: %s" % String(got["error"]), "error": true}
	_looks += 1
	return {"text": "%s Looks left: %d." % [JUDGE, LOOKS - _looks], "images": [got["image"]]}


func _submit() -> Dictionary:
	await _make_now()
	var parts: Array = _made["parts"]
	if parts.is_empty():
		return {"text": "It comes to no parts yet.\n" + AssemblyModel.report(_made), "error": true}
	if parts.size() > AssemblyModel.PARTS_MOST:
		return {"text": "It comes to %d parts, and %d is the most anyone could build in a video. Make it simpler where nobody would miss it: wide flat parts, fewer rough edges." % [parts.size(), AssemblyModel.PARTS_MOST], "error": true}
	if String(_made["name"]).is_empty():
		return {"text": "It needs a `name`: what it is, in plain words.", "error": true}
	if not (_made["floating"] as Array).is_empty() and not _warned_floating:
		_warned_floating = true
		return {"text": AssemblyModel.report(_made) + "\nFix what floats: nobody can put it there. (Submit again to hand it in anyway, and what floats will never go on.)", "error": true}
	var err := TextGen.put(dir.path_join(SUBMITTED) + ".part", JSON.stringify({"raw": _raw, "made": safe(_made)}))
	if err.is_empty() and DirAccess.rename_absolute(dir.path_join(SUBMITTED) + ".part", dir.path_join(SUBMITTED)) != OK:
		err = "could not move the model into place"
	if not err.is_empty():
		return {"text": "The model could not be handed in: %s" % err, "error": true}
	submitted = true
	return {"text": "Handed in: %s, %d parts. The design is done - your work is done; end with one short line." % [String(_made["name"]), parts.size()]}


## What was made, as a file can hold it.
static func safe(made: Dictionary) -> Dictionary:
	var out := made.duplicate()
	out["notes"] = Array(made.get("notes", PackedStringArray()))
	return out
