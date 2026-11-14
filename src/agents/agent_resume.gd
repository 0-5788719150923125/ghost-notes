extends RefCounted
class_name AgentResume

## AgentResume - durable progress for interrupted authoring tools.
##
## A toolset opts in with RESUME_FIELDS: only those data
## properties are saved, never a renderer, a process or an object. The request belongs to the caller;
## AgentTools commits a checkpoint after each completed call, before answering the writer.
## A continuation is a new writer given the original task, restored draft and saved observations.
## It does not depend on a CLI keeping its conversation or hidden reasoning.

const REQUEST := "resume.json"
const CHECKPOINT := "checkpoint.bin"
const VERSION := 1


static func fields(toolset: Object) -> Array:
	var script := toolset.get_script() as Script
	return script.get_script_constant_map().get("RESUME_FIELDS", []) if script != null else []


static func state_of(toolset: Object) -> Dictionary:
	var state := {}
	for key in fields(toolset):
		state[key] = toolset.get(key)
	return state.duplicate(true)


static func write_json(path: String, data: Dictionary) -> String:
	var err := TextGen.put(path + ".part", JSON.stringify(data, "\t"))
	if err.is_empty() and DirAccess.rename_absolute(path + ".part", path) != OK:
		err = "could not keep " + path.get_file()
	return err


static func read_request(dir: String) -> Dictionary:
	var p := dir.path_join(REQUEST)
	if not FileAccess.file_exists(p):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(p)) != OK:
		return {}
	var v: Variant = json.data
	return v if v is Dictionary and int(v.get("version", 0)) == VERSION else {}


static func read_checkpoint(dir: String) -> Dictionary:
	var p := dir.path_join(CHECKPOINT)
	if not FileAccess.file_exists(p) or FileAccess.get_size(p) > 32 * 1024 * 1024:
		return {}
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		return {}
	if f.get_length() < 4 or f.get_32() != f.get_length() - 4:
		return {}
	f.seek(0)
	var v: Variant = f.get_var(false)
	return v if v is Dictionary and int(v.get("version", 0)) == VERSION and v.get("state") is Dictionary else {}


static func save(dir: String, toolset: Object, calls: int, images: int) -> String:
	if fields(toolset).is_empty():
		return ""
	var path := dir.path_join(CHECKPOINT)
	var f := FileAccess.open(path + ".part", FileAccess.WRITE)
	if f == null:
		return "could not save the work's checkpoint"
	f.store_var({"version": VERSION, "script": toolset.get_script().resource_path,
		"state": state_of(toolset), "calls": calls, "images": images,
		"log_bytes": FileAccess.get_size(dir.path_join("tools.jsonl")) if FileAccess.file_exists(dir.path_join("tools.jsonl")) else 0}, false)
	var err := f.get_error()
	f.close()
	if err != OK or DirAccess.rename_absolute(path + ".part", path) != OK:
		return "could not commit the work's checkpoint"
	return ""


## Validate all fields before changing any: a damaged or incompatible checkpoint never half-restores.
static func compatible(script: Script, checkpoint: Dictionary) -> bool:
	if String(checkpoint.get("script", "")) != script.resource_path or not (checkpoint.get("state") is Dictionary):
		return false
	var state: Dictionary = checkpoint["state"]
	var keys: Array = script.get_script_constant_map().get("RESUME_FIELDS", [])
	if keys.is_empty() or state.size() != keys.size():
		return false
	var types := {}
	for property in script.get_script_property_list():
		types[String(property["name"])] = int(property["type"])
	for key in keys:
		if not state.has(key) or typeof(state[key]) != int(types.get(key, TYPE_NIL)):
			return false
	return int(checkpoint.get("calls", -1)) >= 0 and int(checkpoint.get("images", -1)) >= 0


static func restore(toolset: Object, checkpoint: Dictionary) -> bool:
	if not compatible(toolset.get_script(), checkpoint):
		return false
	var state: Dictionary = checkpoint["state"]
	var keys := fields(toolset)
	for key in keys:
		toolset.set(key, state[key])
	return true


static func trim_history(dir: String, entries: Array) -> String:
	var lines := PackedStringArray()
	for entry in entries:
		lines.append(JSON.stringify(entry))
	var path := dir.path_join("tools.jsonl")
	var err := TextGen.put(path + ".part", "\n".join(lines) + ("\n" if not lines.is_empty() else ""))
	if err.is_empty() and DirAccess.rename_absolute(path + ".part", path) != OK:
		err = "could not restore the completed-call history"
	return err


## Visible writer notes only: never embed a raw stream (it can contain megabytes of picture data).
static func notes(dir: String) -> String:
	var path := dir.path_join("reply.jsonl")
	if not FileAccess.file_exists(path):
		return ""
	var f := FileAccess.open(path, FileAccess.READ)
	var out := ""
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line.is_empty():
			continue
		var json := JSON.new()
		if json.parse(line) != OK:
			continue
		var event: Variant = json.data
		if not (event is Dictionary):
			continue
		var text := ""
		if event.get("type") == "assistant" and event.get("message") is Dictionary:
			for part in event["message"].get("content", []):
				if part is Dictionary and part.get("type") == "text":
					text += String(part.get("text", "")) + "\n"
		elif event.get("type") == "item.completed" and event.get("item") is Dictionary and event["item"].get("type") == "agent_message":
			text = String(event["item"].get("text", ""))
		elif event.get("type") == "text" and event.get("data") is String:
			text = event["data"]
		if not text.is_empty():
			out = (out + "\n" + text).right(24000)
	return out.strip_edges()


static func finish(dir: String) -> void:
	for name in [REQUEST, CHECKPOINT]:
		if FileAccess.file_exists(dir.path_join(name)):
			DirAccess.remove_absolute(dir.path_join(name))


## Only complete log lines, up to the checkpoint's commit boundary. A crash can leave one partial
## line, or a completed log entry whose state had not yet been committed; neither is replayed.
static func history(dir: String, limit := -1) -> Array:
	var p := dir.path_join("tools.jsonl")
	if not FileAccess.file_exists(p):
		return []
	var f := FileAccess.open(p, FileAccess.READ)
	var bytes := f.get_buffer(f.get_length() if limit < 0 else mini(limit, f.get_length()))
	var lines := bytes.get_string_from_utf8().split("\n")
	var out: Array = []
	for i in maxi(0, lines.size() - 1):
		var json := JSON.new()
		if json.parse(lines[i]) != OK:
			return []
		var entry: Variant = json.data
		if not (entry is Dictionary) or not (entry.get("args") is Dictionary) or not (entry.get("tool") is String):
			return []
		out.append(entry)
	return out


## Keep each writer attempt before the CLI rewrites its stream. Tool history and pictures keep
## their names across continuations. No endpoint or token is carried into the new writer.
static func archive(dir: String) -> String:
	var n := 1
	while DirAccess.dir_exists_absolute(dir.path_join("attempts/%03d" % n)):
		n += 1
	var to := dir.path_join("attempts/%03d" % n)
	if DirAccess.make_dir_recursive_absolute(to) != OK:
		return "could not keep the interrupted writer's files"
	for name in ["prompt.txt", "system.txt", "input.jsonl", "reply.jsonl", "reply.txt", "stderr.log", "tools.jsonl", REQUEST, CHECKPOINT]:
		var from := dir.path_join(name)
		if FileAccess.file_exists(from) and DirAccess.copy_absolute(from, to.path_join(name)) != OK:
			return "could not keep " + name
	return ""


static func continuation(toolset: Object, entries: Array, calls: int) -> String:
	var draft: Variant = toolset.call("draft") if toolset.has_method("draft") else state_of(toolset)
	var lines := PackedStringArray([
		"RESUME THE INTERRUPTED WORK. Your tools already hold the saved draft below. Continue from it; do not start over or repeat completed calls just to reconstruct it. The original task still applies. The look budget and tool-call budget have NOT reset (%d calls already used). Only the call interrupted by the stop may need repeating. Use the saved observations to decide what remains, then submit through your tools." % calls,
		"SAVED DRAFT:\n" + JSON.stringify(draft, "\t"),
		"RECENT COMPLETED CALLS (earlier changes are already in the saved draft):"])
	if toolset.has_method("looks_used"):
		var most := int(toolset.get_script().get_script_constant_map().get("LOOKS", 0))
		var used := int(toolset.call("looks_used"))
		lines.insert(1, "Looks already used: %d of %d. Looks remaining: %d." % [used, most, maxi(0, most - used)])
	for entry in entries.slice(maxi(0, entries.size() - 32)):
		lines.append("%s %s\n%s" % [entry["tool"], JSON.stringify(entry["args"]).left(2000), String(entry.get("text", "")).left(4000)])
	return "\n\n".join(lines)
