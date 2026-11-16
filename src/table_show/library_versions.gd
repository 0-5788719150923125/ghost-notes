extends PropVersions
class_name LibraryVersions

## LibraryVersions - the versions of the library's props, and refining one ([PropVersions], [ThingLibrary]; next/library.md,
## "Refining a prop"). A prop is found kept by the hash of any of its versions, and one not kept yet is kept on its first refine.
## Refining hands the version shown to an agent - the writer a person picks ([AgentPick]) - with three pictures of it as built
## ([method PropStudio.views]) and the author's direction, as rules/table/prop_refiner.yaml tells it; what it answers is added as a
## new version ([method land]), never used until a person chooses it. One refining at a time; one given up adds nothing.

## The library whose props these are.
var library: LibraryProps
var _job := ""                   # the agent's job under way, "" for none
var _busy := false               # from the pictures until the answer lands


func _init(lib: LibraryProps) -> void:
	library = lib


func name_of(prop: Dictionary) -> String:
	if prop.is_empty():
		return ""
	var h := String(prop.get("hash", ""))
	if h.is_empty() and prop.get("thing") is Dictionary:
		h = ThingLibrary.hash_of(prop["thing"], prop.get("materials", {}) if prop.get("materials") is Dictionary else {})
	return String(library.kept_by_hash().get(h, ""))


func refinable(prop: Dictionary) -> bool:
	return prop.get("thing") is Dictionary and (prop["thing"] as Dictionary).get("parts") is Array \
		and not ((prop["thing"] as Dictionary)["parts"] as Array).is_empty()


func keep(prop: Dictionary) -> Dictionary:
	var already := name_of(prop)
	if not already.is_empty():
		return {"name": already}
	if not refinable(prop):
		return {"error": "it is built by code, not written as parts, so it cannot be refined"}
	if not Library.writable():
		return {"error": "this session is read-only"}
	var err := library.keep(prop["thing"], prop.get("materials", {}) if prop.get("materials") is Dictionary else {}, "")
	if not err.is_empty():
		return {"error": err}
	var name := name_of(prop)
	return {"name": name} if not name.is_empty() else {"error": "it could not be kept"}


func list(name: String) -> Array:
	return ThingLibrary.versions(name).map(func(v: Dictionary) -> Dictionary:
		return {"note": String(v["note"]), "by": String(v["by"]), "made": int(v["made"]), "hash": String(v["hash"])})


func used(name: String) -> int:
	return ThingLibrary.used_of(ThingLibrary.read(name))


func model(name: String, i: int) -> Dictionary:
	var vs := ThingLibrary.versions(name)
	if i < 0 or i >= vs.size():
		return {}
	var v: Dictionary = vs[i]
	return await PropStudio.model(v["thing"], v["materials"], String(v["hash"]))


func use(name: String, i: int) -> String:
	if not Library.writable():
		return "this session is read-only"
	var err := ThingLibrary.use_version(name, i)
	library.refresh()
	return err


func refine(name: String, from: int, direction: String, pick: Dictionary, told: Callable) -> Dictionary:
	if _busy:
		return {"error": "it is being refined already"}
	if direction.strip_edges().is_empty():
		return {"error": "say what to change first"}
	if not Library.writable():
		return {"error": "this session is read-only"}
	var e := ThingLibrary.read(name)
	var vs := ThingLibrary.versions_of(e)
	if from < 0 or from >= vs.size():
		return {"error": "%s has no version %d" % [name, from + 1]}
	_busy = true
	var v: Dictionary = vs[from]
	var dir := ProjectSettings.globalize_path(Library.root.path_join("jobs").path_join("refine_%d_%d" % [int(Time.get_unix_time_from_system()), randi() % 100000]))
	if told.is_valid():
		told.call("looking at it from three sides")
	var pics: Array = await PropStudio.views(v["thing"], v["materials"], String(v["hash"]), dir)
	var p := prompt(name, String(e.get("line", "")), v["thing"], v["materials"], direction, not pics.is_empty())
	var spec := {"kind": "text", "backend": String(pick.get("agent", "claude")), "tier": "best", "dir": dir, "system": String(p["system"]),
		"prompt": String(p["prompt"]), "label": "prop refine", "model": String(pick.get("model", "")), "effort": String(pick.get("effort", ""))}
	if not pics.is_empty():
		var said := {"front": "From a little above its front:", "side": "From its right side:", "above": "From above:"}
		spec["images"] = pics.map(func(path: String) -> Dictionary:
			return {"path": path, "label": String(said.get(path.get_file().get_basename().trim_prefix("prop_"), "The prop:"))})
	_job = AgentJobs.submit(spec)
	if _job.is_empty():
		_busy = false
		return {"error": "this session cannot start agents"}
	while true:
		var st := AgentJobs.state(_job)
		if st != "queued" and st != "running":
			break
		if told.is_valid():
			told.call(AgentJobs.activity(_job))
		await PropStudio.tree().process_frame
	var res := AgentJobs.result(_job)
	AgentJobs.forget(_job)
	_job = ""
	_busy = false
	if not bool(res.get("ok", false)):
		return {"error": String(res.get("error", "")) if not String(res.get("error", "")).is_empty() else "the agent gave no answer"}
	var out := land(name, String(res.get("text", "")), direction, by_of(pick), v["thing"])
	library.refresh()
	return out


func stop() -> void:
	if not _job.is_empty():
		AgentJobs.cancel(_job)


func busy() -> bool:
	return _busy


## What refining [param name] (said by [param line]) asks: its version written as [param thing] and [param materials], changed as
## [param direction] says, with pictures of it where [param pictured]: `{system, prompt}`.
static func prompt(name: String, line: String, thing: Dictionary, materials: Dictionary, direction: String, pictured: bool) -> Dictionary:
	var t := thing.duplicate(true)
	t.erase("name")
	var vars := {"name": name, "line": line, "spec": JSON.stringify({"thing": t, "materials": materials}, "  "), "direction": direction.strip_edges(),
		"props": Props.describe(), "max_parts": Props.MAX_PARTS, "cardless": true, "tools": false, "pictured": pictured}
	return {"system": Rules.say("table/prop_refiner.system", vars), "prompt": Rules.say("table/prop_refiner.prompt", vars)}


## The agent's answer [param text] added to [param name] as a new version, made by [param by] as [param direction] directed - the
## scale of [param was] (the version refined) kept where the answer leaves it out: `{index}`, or `{error}` where it is no prop or
## builds nothing.
static func land(name: String, text: String, direction: String, by: String, was: Dictionary = {}) -> Dictionary:
	var got: Variant = TextGen.extract_json(text)
	if not (got is Dictionary):
		return {"error": "the agent's answer is not a prop"}
	var d: Dictionary = got
	var thing: Dictionary = d["thing"] if d.get("thing") is Dictionary else d
	if not (thing.get("parts") is Array):
		return {"error": "the agent's answer has no parts"}
	thing = thing.duplicate(true)
	thing.erase("materials")
	if was.has("scale") and not thing.has("scale"):
		thing["scale"] = was["scale"]
	var mats: Dictionary = d["materials"] if d.get("materials") is Dictionary else {}
	var why: Array = []
	var i := ThingLibrary.add_version(name, thing, mats, direction, by, why)
	return {"index": i} if i >= 0 else {"error": "; ".join(PackedStringArray(why))}


## Who refined, in a few words: the agent and its model.
static func by_of(pick: Dictionary) -> String:
	var agent := String(pick.get("agent", ""))
	var model := String(pick.get("model", ""))
	return agent if model.is_empty() else "%s %s" % [agent, model]
