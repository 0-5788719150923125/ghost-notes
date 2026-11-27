extends RefCounted
class_name TableRefine

## TableRefine - an episode's table refined by an agent, as a person asks on its Props card row ([EpisodeProps], [TableProp]): its
## top and the cloths laid on it as written, changed where the words say and nowhere else (`rules/table/table_refiner.yaml`), and
## written as a hand's version of `table.json` - kept, passed by Generate, the table before it a version back - the things on it as
## they stand when the answer lands. It runs in the background whether or not its card or window stays ([PropRefining], under
## [method name_of]): the row says what the agent is doing, and the window, while it is open.

static var _jobs := {}            # name -> its AgentJobs id, "" while starting


## What [PropRefining] knows the refining of the table of the episode at [param dir] by.
static func name_of(dir: String) -> String:
	return "table|" + dir


## Whether an agent is refining the table of the episode at [param dir] now.
static func busy(dir: String) -> bool:
	return PropRefining.busy(name_of(dir))


## The table of the episode at [param dir] refined as [param direction] says, by who [param pick] chooses (`{agent, model, effort}`,
## [AgentPick]), begun and left to run; [param win], while it stays open, hears what the agent is doing and how it ended. "" begun,
## else why not.
static func start(dir: String, direction: String, pick: Dictionary, win: PropRefine = null) -> String:
	if direction.strip_edges().is_empty():
		return "say what to change first"
	var ep := TableEpisode.at_dir(dir)
	if not ep.has("table"):
		return "this episode has no table yet"
	var err := PropRefining.start(name_of(dir))
	if not err.is_empty():
		return err
	_jobs[name_of(dir)] = ""
	_run(ep, direction.strip_edges(), pick, win)
	return ""


## The refining of the table of the episode at [param dir] given up: nothing is written.
static func stop(dir: String) -> void:
	var name := name_of(dir)
	if not _jobs.has(name):
		return
	if String(_jobs[name]).is_empty():
		_jobs.erase(name)
	else:
		AgentJobs.cancel(String(_jobs[name]))


static func _run(ep: TableEpisode, direction: String, pick: Dictionary, win: PropRefine) -> void:
	var name := name_of(ep.dir)
	var raw: Variant = ep.read_json("table")
	var plan: Variant = ep.read_json("plan")
	var p := prompt(raw if raw is Dictionary else {}, plan if plan is Dictionary else {}, direction, ep.has("image:surface"))
	var spec := {"kind": "text", "backend": String(pick.get("agent", "claude")), "tier": "best",
		"dir": ep.dir.path_join("jobs").path_join("table_refine_%d" % int(Time.get_unix_time_from_system())),
		"system": String(p["system"]), "prompt": String(p["prompt"]), "label": "table refine",
		"model": String(pick.get("model", "")), "effort": String(pick.get("effort", ""))}
	if ep.has("image:surface"):
		spec["images"] = [{"path": ep.file_of("image:surface"), "label": "The episode's painting, which a top or cloth of \"painting\" shows:"}]
	if not _jobs.has(name):
		_end(name, {"error": "stopped"}, win)
		return
	var job := AgentJobs.submit(spec)
	if job.is_empty():
		_end(name, {"error": "this session cannot start agents"}, win)
		return
	_jobs[name] = job
	var tree := Engine.get_main_loop() as SceneTree
	while true:
		var st := AgentJobs.state(job)
		if st != "queued" and st != "running":
			break
		var line := AgentJobs.activity(job)
		PropRefining.say(name, line)
		if is_instance_valid(win) and not line.is_empty():
			win.say("An agent is refining the table: %s" % line)
		await tree.process_frame
	var res := AgentJobs.result(job)
	AgentJobs.forget(job)
	_jobs.erase(name)
	if not bool(res.get("ok", false)):
		_end(name, {"error": String(res.get("error", "")) if not String(res.get("error", "")).is_empty() else "the agent gave no answer"}, win)
		return
	_end(name, land(ep, String(res.get("text", ""))), win)


## The refining [param name] ended with [param got] (`{}` written, `{error}` not): said on the row until it is refined again where
## it failed, and in [param win] while it is open.
static func _end(name: String, got: Dictionary, win: PropRefine) -> void:
	if got.has("error"):
		PropRefining.finish(name, got)
	else:
		PropRefining.finish(name, {"index": 0})
		PropRefining.seen(name)
	if is_instance_valid(win):
		win.working(false)
		win.say("Not refined: %s." % String(got["error"]) if got.has("error")
			else "Refined: the table stands as the agent wrote it. The one before is kept a version back.")


## What refining table [param table] (`table.json` as written) of an episode planned as [param plan] asks, changed as
## [param direction] says - the episode's painting coming with it where [param painted]: `{system, prompt}`.
static func prompt(table: Dictionary, plan: Dictionary, direction: String, painted: bool) -> Dictionary:
	var look: Dictionary = plan.get("look", {}) if plan.get("look") is Dictionary else {}
	var spec := {"top": table.get("top", Tables.DEFAULT_TOP), "layers": table.get("layers", Tables.default_layers())}
	var mats: Array = (table.get("materials", {}) as Dictionary).keys() if table.get("materials") is Dictionary else []
	var vars := {"spec": JSON.stringify(spec, "  "), "direction": direction, "vocabulary": Tables.describe(), "painted": painted,
		"materials": ", ".join(PackedStringArray(mats.map(func(m: Variant) -> String: return "\"%s\"" % String(m)))) if not mats.is_empty() else "none",
		"palette": ", ".join(PackedStringArray((look.get("palette", []) as Array).map(func(c: Variant) -> String: return String(c))))
			if look.get("palette") is Array and not (look["palette"] as Array).is_empty() else "any"}
	return {"system": Rules.say("table/table_refiner.system", vars), "prompt": Rules.say("table/table_refiner.prompt", vars)}


## The agent's answer [param text] written into the episode [param ep]'s table as a hand's version: its `top` and `layers` where it
## gives them, and the materials it names added - every thing on the table as it stands. `{}` written, or `{error}`.
static func land(ep: TableEpisode, text: String) -> Dictionary:
	var got: Variant = TextGen.extract_json(text)
	if not (got is Dictionary):
		return {"error": "the agent's answer is not a table"}
	var d: Dictionary = got
	if not (d.get("top") is Dictionary) and not (d.get("layers") is Array):
		return {"error": "the agent's answer has no top and no cloths"}
	var raw: Variant = ep.read_json("table")
	if not (raw is Dictionary):
		return {"error": "the table is not readable"}
	var t: Dictionary = (raw as Dictionary).duplicate(true)
	if d.get("top") is Dictionary:
		t["top"] = d["top"]
	if d.get("layers") is Array:
		t["layers"] = (d["layers"] as Array).filter(func(l: Variant) -> bool: return l is Dictionary)
	if d.get("materials") is Dictionary:
		var mats: Dictionary = t.get("materials", {}) if t.get("materials") is Dictionary else {}
		mats.merge(d["materials"] as Dictionary, true)
		t["materials"] = mats
	if t == raw:
		return {"error": "the agent changed nothing"}
	ep.keep_dressed()
	var err := ep.write_json("table", t)
	if err.is_empty():
		err = ep.note_made("table", "hand")
	if err.is_empty():
		err = ep.set_kept("table", true)
	return {"error": err} if not err.is_empty() else {}
