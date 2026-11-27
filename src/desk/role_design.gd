extends RefCounted
class_name RoleDesign

## RoleDesign - a role's make designed by an agent from words ([PropMakes] `designed`; next/studio.md, "The studio's things"). The
## agent is told what the role is and what the scene does with it, what the scene works on any make of it (`faces`, `needs`), how
## tall it stands, the show it stands in and the scene's other things already designed, as rules/table/prop_designer.yaml says; it
## answers a prop as the library writes one ([ThingLibrary]). An answer that lacks what the scene works is told what it lacks and
## asked once more ([constant TRIES]).
##
## What it makes is held in the library as a draft under the name the agent gives (a person's Keep in its 3D view keeps it,
## [PropViewer]) - or, where a prop of that name is in the library already, added to it as a version and used, so one name stays one
## prop. Another make ([param was] given) is told the one it replaces and asked for another kind of it. It runs to its end whoever
## lets go of it; [member running] says what each is doing.

## How many times an agent is asked for one make.
const TRIES := 2
## What each design under way is doing, by the key it was started with: `{line}`.
static var running := {}


## What the designer of role [param role] is told: `{system, prompt}` - for [param show], beside [param others] (the scene's other
## things, `{name, line}`), replacing [param was] (`{name, line}`, or {}), the last answer having lacked [param lacks].
static func prompt(role: String, show: String, others: Array = [], was: Dictionary = {}, lacks := PackedStringArray()) -> Dictionary:
	var row: Dictionary = PropMakes.ROLES.get(role, {})
	var tall: Array = row.get("tall", [10.0, 100.0])
	var vars := {"role": String(row.get("label", role)), "blurb": String(row.get("blurb", "")), "needs": needs_text(role),
		"tall_lo": _cm(float(tall[0])), "tall_hi": _cm(float(tall[1])), "show": show, "others": others, "has_others": not others.is_empty(),
		"another": not was.is_empty(), "was_name": String(was.get("name", "")), "was_line": String(was.get("line", "")),
		"wrong": not lacks.is_empty(), "lacks": ", ".join(lacks), "props": Props.describe(true), "max_parts": Props.MAX_PARTS,
		"cardless": true, "tools": false, "ornaments": OrnamentLibrary.listing(), "textures": OrnamentLibrary.listing(OrnamentLibrary.TEXTURE)}
	return {"system": Rules.say("table/prop_designer.system", vars), "prompt": Rules.say("table/prop_designer.prompt", vars)}


## What the scene works on any make of role [param role], a line each as an agent is told it: its faces, named parts and points.
static func needs_text(role: String) -> String:
	var row: Dictionary = PropMakes.ROLES.get(role, {})
	var needs := PackedStringArray()
	for f in row.get("faces", []):
		if not (row.get("needs", {}) as Dictionary).has("face " + String(f)):
			needs.append("- a face named \"%s\"" % String(f))
	for k in (row.get("needs", {}) as Dictionary):
		needs.append("- a %s named \"%s\": %s" % [String(k).get_slice(" ", 0), String(k).get_slice(" ", 1), String(row["needs"][k])])
	return "\n".join(needs)


## Role [param role]'s make designed for [param show] by the agent [param pick] (`{agent, model, effort}`, [AgentPick]) and held in the
## library: `{name}` (what it is kept or held as), or `{error}`. [param key] names it in [member running]; [param others] and
## [param was] as [method prompt] takes them.
static func design(key: String, role: String, show: String, pick: Dictionary, others: Array = [], was: Dictionary = {}) -> Dictionary:
	if running.has(key):
		return {"error": "it is being designed already"}
	if not Library.writable():
		return {"error": "this session is read-only"}
	running[key] = {"line": "designing it"}
	var lacks := PackedStringArray()
	var out := {}
	for attempt in TRIES:
		var p := prompt(role, show, others, was, lacks)
		var dir := ProjectSettings.globalize_path(Library.root.path_join("jobs").path_join("design_%d_%d" % [int(Time.get_unix_time_from_system()), randi() % 100000]))
		var job := AgentJobs.submit({"kind": "text", "backend": String(pick.get("agent", "claude")), "tier": "best", "dir": dir,
			"system": String(p["system"]), "prompt": String(p["prompt"]), "label": "prop design", "model": String(pick.get("model", "")),
			"effort": String(pick.get("effort", ""))})
		if job.is_empty():
			out = {"error": "this session cannot start agents"}
			break
		while true:
			var st := AgentJobs.state(job)
			if st != "queued" and st != "running":
				break
			running[key] = {"line": AgentJobs.activity(job)}
			await PropStudio.tree().process_frame
		var res := AgentJobs.result(job)
		AgentJobs.forget(job)
		if not bool(res.get("ok", false)):
			out = {"error": String(res.get("error", "")) if not String(res.get("error", "")).is_empty() else "the agent gave no answer"}
			break
		var got := answer(role, String(res.get("text", "")))
		if got.has("lacks") and attempt + 1 < TRIES:
			lacks = got["lacks"]
			running[key] = {"line": "asked again: it lacked %s" % ", ".join(lacks)}
			continue
		if got.has("lacks"):
			out = {"error": "the design lacks %s" % ", ".join(got["lacks"])}
			break
		if got.has("error"):
			out = got
			break
		out = held(got, by_of(pick), "designed as %s" % String((PropMakes.ROLES.get(role, {}) as Dictionary).get("label", role)).to_lower())
		break
	running.erase(key)
	return out


## The agent's answer [param text] read as a make of role [param role]: `{name, line, thing, materials}`, `{lacks}` (what the scene
## works that it has not) or `{error}`. Pure.
static func answer(role: String, text: String) -> Dictionary:
	var got: Variant = TextGen.extract_json(text)
	if not (got is Dictionary):
		return {"error": "the agent's answer is not a prop"}
	var d: Dictionary = got
	var thing: Dictionary = (d["thing"] as Dictionary).duplicate(true) if d.get("thing") is Dictionary else {}
	if not (thing.get("parts") is Array) or (thing["parts"] as Array).is_empty():
		return {"error": "the agent's answer has no parts"}
	thing.erase("materials")
	thing.erase("at")
	var mats: Dictionary = d["materials"] if d.get("materials") is Dictionary else {}
	var safe := Props.sanitize({"things": [thing.merged({"name": "x"})], "materials": mats}, ["#888888"])
	if (safe["things"] as Array).is_empty():
		return {"error": "the agent's answer builds nothing"}
	var lacks := PropMakes.missing(role, thing, true)
	var has_faces := PropMakes.faces_of(thing["parts"])
	for f in (PropMakes.ROLES.get(role, {}) as Dictionary).get("faces", []):
		if not has_faces.has(String(f)) and not lacks.has("face " + String(f)):
			lacks.append("face " + String(f))
	if not lacks.is_empty():
		return {"lacks": lacks}
	var label := String((PropMakes.ROLES.get(role, {}) as Dictionary).get("label", role)).to_lower()
	var name := String(d.get("name", "")).strip_edges() if d.get("name") is String else ""
	return {"name": name if not name.is_empty() else label, "line": String(d.get("line", "")).strip_edges() if d.get("line") is String else "",
		"thing": thing, "materials": mats}


## Make [param got] (`{name, line, thing, materials}`, [method answer]) held in the library: a draft under its name, or a version of
## the prop already of that name, used. `{name}` or `{error}`.
static func held(got: Dictionary, by: String, note: String) -> Dictionary:
	var name := String(got["name"])
	if not ThingLibrary.read(name).is_empty():
		var why: Array = []
		var i := ThingLibrary.add_version(name, got["thing"], got["materials"], note, by, why, -1, name, String(got["line"]))
		if i < 0:
			return {"error": "; ".join(PackedStringArray(why))}
		var used := ThingLibrary.use_version(name, i)
		return {"name": name} if used.is_empty() else {"error": used}
	var err := ThingLibrary.keep((got["thing"] as Dictionary).merged({"name": name}, true), got["materials"], String(got["line"]), true)
	return {"name": name} if err.is_empty() else {"error": err}


## Who designed it, in a few words: the agent and its model.
static func by_of(pick: Dictionary) -> String:
	var agent := String(pick.get("agent", "claude"))
	var model := String(pick.get("model", ""))
	return agent if model.is_empty() else "%s %s" % [agent, model]


static func _cm(v: float) -> String:
	return str(int(v)) if is_equal_approx(v, roundf(v)) else String.num(v, 1)
