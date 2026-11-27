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


func start_refine(name: String, from: int, direction: String, pick: Dictionary, scene := {}) -> String:
	if direction.strip_edges().is_empty():
		return "say what to change first"
	if not Library.writable():
		return "this session is read-only"
	var err := PropRefining.start(name)
	if not err.is_empty():
		return err
	_held[name] = self
	_refine_and_land(name, from, direction, pick, scene)
	return ""


## [method refine] run to its end whoever is looking, what it says and what came of it told to [PropRefining].
func _refine_and_land(name: String, from: int, direction: String, pick: Dictionary, scene := {}) -> void:
	var got: Dictionary = await refine(name, from, direction, pick, func(line: String) -> void: PropRefining.say(name, line), scene)
	PropRefining.finish(name, got)
	_held.erase(name)


func refine(name: String, from: int, direction: String, pick: Dictionary, told: Callable, scene := {}) -> Dictionary:
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
	# ...and the scene it stands in, where it may be placed there: measured and pictured
	var seen := {}
	if not scene.is_empty() and (scene.get("look") as Callable).is_valid():
		if told.is_valid():
			told.call("looking at the scene it stands in")
		seen = await (scene["look"] as Callable).call(dir)
	var p := prompt(name, String(e.get("line", "")), v["thing"], v["materials"], direction, not pics.is_empty(), scene, seen)
	var spec := {"kind": "text", "backend": String(pick.get("agent", "claude")), "tier": "best", "dir": dir, "system": String(p["system"]),
		"prompt": String(p["prompt"]), "label": "prop refine", "model": String(pick.get("model", "")), "effort": String(pick.get("effort", ""))}
	if not pics.is_empty() or not (seen.get("views", []) as Array).is_empty():
		spec["images"] = _labeled(pics, seen)
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
	var text := String(res.get("text", ""))
	var out := {}
	# places, where it answered any: the prop - and whatever else in its scene it moved - put there, no version; then looked at again
	# and put right once
	var applied := apply_places(text, scene) if not scene.is_empty() else {}
	if applied.has("error"):
		return {"error": String(applied["error"])}
	if not (applied.get("moved", {}) as Dictionary).is_empty():
		out["placed"] = applied.get("place", {})
		out["moved"] = applied["moved"]
		if told.is_valid():
			told.call("placed; looking at the scene again")
		var again: Dictionary = await (scene["look"] as Callable).call(dir.path_join("again"))
		var p2 := prompt(name, String(e.get("line", "")), v["thing"], v["materials"], direction, false, scene, again, applied["moved"])
		var job2 := AgentJobs.submit(spec.merged({"system": String(p2["system"]), "prompt": String(p2["prompt"]), "images": _labeled([], again),
			"dir": dir.path_join("again")}, true))
		if not job2.is_empty():
			_jobs[name] = job2
			while true:
				var st2 := AgentJobs.state(job2)
				if st2 != "queued" and st2 != "running":
					break
				if told.is_valid():
					told.call(AgentJobs.activity(job2))
				await PropStudio.tree().process_frame
			var res2 := AgentJobs.result(job2)
			AgentJobs.forget(job2)
			_jobs.erase(name)
			var fixed := apply_places(String(res2.get("text", "")), scene) if bool(res2.get("ok", false)) else {}
			if not (fixed.get("moved", {}) as Dictionary).is_empty():
				(out["moved"] as Dictionary).merge(fixed["moved"], true)
				if fixed.has("place"):
					out["placed"] = fixed["place"]
	# a changed prop, where it answered one: a new version - and, where its scene works something on it that the version lacks, put
	# right once, told what
	if not (thing_in(text)).is_empty():
		var landed := land(name, text, direction, by_of(pick), v["thing"], from)
		if landed.has("error") and out.has("moved"):
			library.refresh()
			return out
		out.merge(landed, true)
		var lacks: PackedStringArray = (scene["lacks"] as Callable).call(thing_in(text)) if scene.get("lacks") is Callable else PackedStringArray()
		if not lacks.is_empty() and int(landed.get("index", -1)) >= 0 and not bool(scene.get("fixing", false)):
			if told.is_valid():
				told.call("its version lacks %s; asking it to put that right" % ", ".join(lacks))
			_jobs.erase(name)
			var again_scene := scene.duplicate()
			again_scene["fixing"] = true
			var fixed := await refine(name, int(landed["index"]), "The version you made lacks what the scene works on it: %s. Put exactly that right (see WHAT THE SCENE WORKS ON IT) and change nothing else." % ", ".join(lacks), pick, told, again_scene)
			if int(fixed.get("index", -1)) >= 0:
				out["index"] = fixed["index"]
				out["name"] = fixed.get("name", out.get("name", ""))
	elif not out.has("moved"):
		out = {"error": "the agent's answer is neither a prop nor a place"}
	library.refresh()
	return out


## The pictures a refine is shown, each labeled: the prop's own (from the front, the side, above) and the scene's ([param seen]
## `views`: from the viewer's eye, the side of the thing, above it).
static func _labeled(pics: Array, seen: Dictionary) -> Array:
	var said := {"prop_front": "The prop, from a little above its front:", "prop_side": "The prop, from its right side:", "prop_above": "The prop, from above:",
		"scene_eye": "The scene, from the viewer's eye (what the show records):", "scene_side": "The scene, from the right of the prop:",
		"scene_above": "The scene, from above the prop:", "scene_lens": "The scene through the camera's lens (its flip screen's picture):"}
	var out: Array = []
	for path in pics + (seen.get("views", []) as Array):
		out.append({"path": String(path), "label": String(said.get(String(path).get_file().get_basename(), "A picture:"))})
	return out


## The places an agent's answer [param text] gives put in [param scene] ([method PropSection.scene_of]): its own (`place`) and those of
## the scene's other things it moved (`places`: a thing's name -> its place). `{place, moved}` - `moved` every thing placed, by its name
## (its own under the scene's `role`) - or `{error}` where one could not be (a name the scene has not). {} where it gives none.
static func apply_places(text: String, scene: Dictionary) -> Dictionary:
	var got: Variant = TextGen.extract_json(text)
	if not (got is Dictionary) or scene.is_empty():
		return {}
	var d: Dictionary = got
	var own := String(scene.get("role", ""))
	var names: Array = (scene.get("roles", []) as Array).map(func(r: Dictionary) -> String: return String(r["role"]))
	var out := {"moved": {}}
	var others: Dictionary = d["places"] if d.get("places") is Dictionary else {}
	for k in others:
		var nm := String(k)
		if not (others[k] is Dictionary):
			continue
		if not names.has(nm):
			return {"error": "the scene has no %s to place" % nm}
		var err := String((scene["place"] as Callable).call(others[k])) if nm == own else String((scene["place_role"] as Callable).call(nm, others[k]))
		if not err.is_empty():
			return {"error": err}
		out["moved"][nm] = others[k]
		if nm == own:
			out["place"] = others[k]
	if d.get("place") is Dictionary:
		var err2 := String((scene["place"] as Callable).call(d["place"]))
		if not err2.is_empty():
			return {"error": err2}
		out["place"] = d["place"]
		out["moved"][own if not own.is_empty() else "it"] = d["place"]
	return out if not (out["moved"] as Dictionary).is_empty() else {}


## The place an agent's answer [param text] gives (`{"place": {...}}`), {} where it gives none.
static func place_in(text: String) -> Dictionary:
	var got: Variant = TextGen.extract_json(text)
	return (got as Dictionary)["place"] if got is Dictionary and (got as Dictionary).get("place") is Dictionary else {}


## The prop an agent's answer [param text] gives (its `thing`, or the answer itself where it has parts), {} where it gives none.
static func thing_in(text: String) -> Dictionary:
	var got: Variant = TextGen.extract_json(text)
	if not (got is Dictionary):
		return {}
	var d: Dictionary = got
	if d.get("thing") is Dictionary:
		return d["thing"]
	return d if d.get("parts") is Array else {}


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
## [param direction] says, with pictures of it where [param pictured] - and, standing in [param scene] ([method PropSection.scene_of]),
## the scene as [param seen] has it (`report`, `views`), the refiner free to place it there and to move the scene's other things with
## it; asked again once [param placed] (every thing placed, by its name), whether they stand right: `{system, prompt}`. A prop a scene works (a face, a light, a
## part that follows what it is fed: [method Props.played]) is told the parts a scene plays, and to keep them (`working`).
static func prompt(name: String, line: String, thing: Dictionary, materials: Dictionary, direction: String, pictured: bool, scene := {},
		seen := {}, placed := {}) -> Dictionary:
	var t := thing.duplicate(true)
	t.erase("name")
	var working := Props.played(thing.get("parts", []) if thing.get("parts") is Array else [])
	var fields := PackedStringArray()
	for k in (scene.get("fields", {}) as Dictionary):
		fields.append("- \"%s\": %s (from %s to %s)" % [k, String(scene["fields"][k]["blurb"]), str(scene["fields"][k]["min"]), str(scene["fields"][k]["max"])])
	var vars := {"name": name, "line": line, "spec": JSON.stringify({"thing": t, "materials": materials}, "  "), "direction": direction.strip_edges(),
		"props": Props.describe(working), "max_parts": Props.MAX_PARTS, "cardless": true, "tools": false, "pictured": pictured,
		"working": working, "ornaments": OrnamentLibrary.listing(),
		"textures": OrnamentLibrary.listing(OrnamentLibrary.TEXTURE),
		"in_scene": not scene.is_empty(), "scene_report": String(seen.get("report", "")), "scene_pictured": not (seen.get("views", []) as Array).is_empty(),
		"place_now": JSON.stringify(scene.get("now", {})), "place_fields": "\n".join(fields), "again": not placed.is_empty(),
		"placed": JSON.stringify(placed), "scene_needs": String(scene.get("needs", "")), "has_needs": not String(scene.get("needs", "")).is_empty(),
		"place_roles": "\n".join(PackedStringArray((scene.get("roles", []) as Array).map(func(r: Dictionary) -> String:
			return "- \"%s\": %s%s, placed now at %s" % [String(r["role"]), String(r["label"]), " (this prop)" if String(r["role"]) == String(scene.get("role", "")) else "",
				JSON.stringify(r.get("now", {}))])))}
	return {"system": Rules.say("table/prop_refiner.system", vars),
		"prompt": Rules.say("table/prop_refiner.again" if not placed.is_empty() else "table/prop_refiner.prompt", vars)}


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
