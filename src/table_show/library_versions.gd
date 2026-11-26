extends PropVersions
class_name LibraryVersions

## LibraryVersions - the versions of the library's props, and refining one ([PropVersions], [ThingLibrary]; next/library.md,
## "Refining a prop"). A prop is found by the hash of any of its versions, and one not kept yet is held as a draft on its first refine
## - its versions' home, kept only when a person keeps it.
## Refining hands the version shown to an agent - the writer a person picks ([AgentPick]) - with three pictures of it as built
## ([method PropStudio.views]) and the author's direction, as rules/table/prop_refiner.yaml tells it; what it answers is added as a
## new version ([method land]), never used until a person chooses it - with the name and line it gives where the change made it
## something else, which the prop takes when that version is used ([method ThingLibrary.use_version]). One refining a prop at a time,
## any number of props at once, each running to its end whoever lets go of it ([method start_refine], [PropRefining]); one given up
## adds nothing.

## The library whose props these are.
var library: LibraryProps
## The agent's job refining each prop (its name -> the job), and what refines it, held while it runs whoever let it go.
static var _jobs := {}
static var _held := {}


func _init(lib: LibraryProps) -> void:
	library = lib


func name_of(prop: Dictionary) -> String:
	if prop.is_empty():
		return ""
	var h := String(prop.get("hash", ""))
	if h.is_empty() and prop.get("thing") is Dictionary:
		h = ThingLibrary.hash_of(prop["thing"], prop.get("materials", {}) if prop.get("materials") is Dictionary else {})
	return String(library.held_by_hash().get(h, ""))


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
	var err := library.keep(prop["thing"], prop.get("materials", {}) if prop.get("materials") is Dictionary else {}, "", true)
	if not err.is_empty():
		return {"error": err}
	var name := name_of(prop)
	return {"name": name} if not name.is_empty() else {"error": "it could not be kept"}


func list(name: String) -> Array:
	var e := ThingLibrary.read(name)
	return ThingLibrary.versions_of(e).map(func(v: Dictionary) -> Dictionary:
		return {"note": String(v["note"]), "by": String(v["by"]), "made": int(v["made"]), "hash": String(v["hash"]),
			"name": ThingLibrary.name_of_version(e, v), "line": String(v["line"]) if not String(v["line"]).is_empty() else String(e.get("line", ""))})


func name_version(name: String, i: int, to: String) -> String:
	if not Library.writable():
		return "this session is read-only"
	var vs := ThingLibrary.versions(name)
	var h := String((vs[i] as Dictionary)["hash"]) if i >= 0 and i < vs.size() else ""
	var err := ThingLibrary.name_version(name, i, to)
	library.refresh()
	if err.is_empty():
		_followed(name, h)
	return err


func keep_in_library(prop: Dictionary, line: String) -> String:
	if not refinable(prop):
		return "it is built by code, not written as parts, so it cannot be kept"
	return library.keep(prop["thing"], prop.get("materials", {}) if prop.get("materials") is Dictionary else {}, line)


func kept(name: String) -> bool:
	var e := ThingLibrary.read(name)
	return not e.is_empty() and not bool(e["draft"])


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
	var vs := ThingLibrary.versions(name)
	var h := String((vs[i] as Dictionary)["hash"]) if i >= 0 and i < vs.size() else ""
	var err := ThingLibrary.use_version(name, i)
	library.refresh()
	if err.is_empty():
		_followed(name, h)
	return err


## [param name] renamed (the version of hash [param h] used, or named) told to what is under way for it.
func _followed(name: String, h: String) -> void:
	var now := ThingLibrary.kept_as(h) if not h.is_empty() else ""
	if now.is_empty() or now == name:
		return
	PropRefining.renamed(name, now)
	if _jobs.has(name):
		_jobs[now] = _jobs[name]
		_jobs.erase(name)


func start_refine(name: String, from: int, direction: String, pick: Dictionary) -> String:
	if direction.strip_edges().is_empty():
		return "say what to change first"
	if not Library.writable():
		return "this session is read-only"
	var err := PropRefining.start(name)
	if not err.is_empty():
		return err
	_held[name] = self
	_refine_and_land(name, from, direction, pick)
	return ""


## [method refine] run to its end whoever is looking, what it says and what came of it told to [PropRefining].
func _refine_and_land(name: String, from: int, direction: String, pick: Dictionary) -> void:
	var got: Dictionary = await refine(name, from, direction, pick, func(line: String) -> void: PropRefining.say(name, line))
	PropRefining.finish(name, got)
	_held.erase(name)


func refine(name: String, from: int, direction: String, pick: Dictionary, told: Callable) -> Dictionary:
	if _jobs.has(name):
		return {"error": "it is being refined already"}
	if direction.strip_edges().is_empty():
		return {"error": "say what to change first"}
	if not Library.writable():
		return {"error": "this session is read-only"}
	var e := ThingLibrary.read(name)
	var vs := ThingLibrary.versions_of(e)
	if from < 0 or from >= vs.size():
		return {"error": "%s has no version %d" % [name, from + 1]}
	_jobs[name] = ""
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
	if not _jobs.has(name):
		return {"error": "stopped"}
	var job := AgentJobs.submit(spec)
	if job.is_empty():
		_jobs.erase(name)
		return {"error": "this session cannot start agents"}
	_jobs[name] = job
	while true:
		var st := AgentJobs.state(job)
		if st != "queued" and st != "running":
			break
		if told.is_valid():
			told.call(AgentJobs.activity(job))
		await PropStudio.tree().process_frame
	var res := AgentJobs.result(job)
	AgentJobs.forget(job)
	_jobs.erase(_jobs.find_key(job) if _jobs.find_key(job) != null else name)
	if not bool(res.get("ok", false)):
		return {"error": String(res.get("error", "")) if not String(res.get("error", "")).is_empty() else "the agent gave no answer"}
	var out := land(name, String(res.get("text", "")), direction, by_of(pick), v["thing"], from)
	library.refresh()
	return out


func stop(name: String) -> void:
	var at := name
	for k in _jobs:
		if PropRefining._now(String(k)) == PropRefining._now(name):
			at = String(k)
	if not _jobs.has(at):
		return
	if String(_jobs[at]).is_empty():
		_jobs.erase(at)
	else:
		AgentJobs.cancel(String(_jobs[at]))


func busy(name: String) -> bool:
	return PropRefining.busy(name)


## What refining [param name] (said by [param line]) asks: its version written as [param thing] and [param materials], changed as
## [param direction] says, with pictures of it where [param pictured]: `{system, prompt}`. A prop a scene works (a face, a light, a
## part that follows what it is fed: [method Props.played]) is told the parts a scene plays, and to keep them (`working`).
static func prompt(name: String, line: String, thing: Dictionary, materials: Dictionary, direction: String, pictured: bool) -> Dictionary:
	var t := thing.duplicate(true)
	t.erase("name")
	var working := Props.played(thing.get("parts", []) if thing.get("parts") is Array else [])
	var vars := {"name": name, "line": line, "spec": JSON.stringify({"thing": t, "materials": materials}, "  "), "direction": direction.strip_edges(),
		"props": Props.describe(working), "max_parts": Props.MAX_PARTS, "cardless": true, "tools": false, "pictured": pictured,
		"working": working, "ornaments": OrnamentLibrary.listing(),
		"textures": OrnamentLibrary.listing(OrnamentLibrary.TEXTURE)}
	return {"system": Rules.say("table/prop_refiner.system", vars), "prompt": Rules.say("table/prop_refiner.prompt", vars)}


## The agent's answer [param text] added to [param name] as a new version, made by [param by] as [param direction] directed from
## version [param from] - the scale of [param was] (the version refined) kept where the answer leaves it out, and the `name` and `line`
## it gives kept on the version: `{index, name}` (what the version is called), or `{error}` where it is no prop or builds nothing.
static func land(name: String, text: String, direction: String, by: String, was: Dictionary = {}, from := -1) -> Dictionary:
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
	var called := String(d["name"]).strip_edges() if d.get("thing") is Dictionary and d.get("name") is String else ""
	var said := String(d["line"]).strip_edges() if d.get("line") is String else ""
	var why: Array = []
	var i := ThingLibrary.add_version(name, thing, mats, direction, by, why, from, called, said)
	if i < 0:
		return {"error": "; ".join(PackedStringArray(why))}
	var e := ThingLibrary.read(name)
	return {"index": i, "name": ThingLibrary.name_of_version(e, ThingLibrary.versions_of(e)[i])}


## Who refined, in a few words: the agent and its model.
static func by_of(pick: Dictionary) -> String:
	var agent := String(pick.get("agent", ""))
	var model := String(pick.get("model", ""))
	return agent if model.is_empty() else "%s %s" % [agent, model]
