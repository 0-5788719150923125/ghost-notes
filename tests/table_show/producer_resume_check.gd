extends SceneTree

## Interrupted authoring resumes its draft, observations, guards and budgets after a new producer
## opens the episode. No agent, GPU or simulation runs: the queue is captured at its boundary.
##
##   godot --headless --path . --script tests/table_show/producer_resume_check.gd

const ROOT := "user://producer_resume_check"
const SPEC := {"title": "Resume", "brief": "A brief", "writer": "claude"}
var _fails := 0
var _queued: Array = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	root.get_node("Settings").set("_read_only", true)
	AgentJobs.allow_for_tool()
	var was := TableEpisode.root
	TableEpisode.root = ROOT
	_rmrf(ProjectSettings.globalize_path(ROOT))
	for test in [_restart, _guards, _already_submitted, _legacy, _other_tools, _explicit_remake]:
		var done: Variant = (test as Callable).call()
		_ok(done == true, "%s ran to completion" % (test as Callable).get_method())
	TableEpisode.root = was
	AgentJobs.allow_for_tool(false)
	_rmrf(ProjectSettings.globalize_path(ROOT))
	print("producer_resume_check: %s" % ("ALL OK" if _fails == 0 else "%d FAILED" % _fails))
	quit(0 if _fails == 0 else 1)


func _ok(ok: bool, text: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + text)
	if not ok:
		_fails += 1


func _episode(seed: int) -> TableEpisode:
	var ep := TableEpisode.open("resume", seed)
	ep.write_json("plan", {"episode_title": "Saved", "spread": {"positions": [{"name": "One", "work": "lift a cup"}]}, "look": {}})
	ep.write_json("draw", {"cards": [{"key": "cup", "name": "Cup"}]})
	ep.write_json("table", {"things": [{"name": "cup", "parts": [{"shape": "box", "size": [3, 3, 3], "material": "wood"}]}]})
	return ep


func _act(name: String) -> Dictionary:
	return {"name": name, "beat": 1, "length": 2, "tracks": [{"thing": "cup", "law": "carry", "to": [0, 5, 0]}]}


func _capture(job: Dictionary) -> String:
	_queued.append(job.duplicate(true))
	return "resume-gate"


func _producer(ep: TableEpisode) -> TableProducer:
	var p := TableProducer.new(ep, SPEC.duplicate(true))
	p._submit_job = _capture
	return p


func _saved(ep: TableEpisode) -> void:
	var p := _producer(ep)
	var dir := ep.job_dir("acts")
	var tools := PuppeteerTools.new(ep, ep.read_json("plan"), dir, ep.read_json("table"))
	tools._put_acts({"acts": [_act("lift"), _act("lower")]})
	tools._looks = 29
	tools._watched = {"lift": true}
	tools._warned_unseen = true
	tools._laid = {"formula": {"id": "formula", "ok": true}}
	tools._fonts = {"roman": "kept"}
	AgentTools.log_call(dir, {"at": int(Time.get_unix_time_from_system()), "tool": "act", "args": {"acts": tools._acts}, "text": "the expensive check is already done", "images": [], "error": false})
	AgentTools.log_call(dir, {"tool": "watch", "args": {"name": "lift"}, "text": "one look left", "images": ["look_29.jpg"], "error": false})
	var pic := Image.create(8, 8, false, Image.FORMAT_RGB8)
	pic.fill(Color.BLUE)
	pic.save_jpg(dir.path_join("look_29.jpg"))
	_ok(AgentResume.save(dir, tools, 91, 29).is_empty(), "draft checkpoint saved")
	# Use the real submission path to capture the original prompt and writer settings.
	var url := AgentTools.open(dir, tools, {"calls": 91, "images": 29})
	p._tools["acts"] = {"url": url, "set": tools}
	p._from["acts"] = ep.made_from("acts")
	p._submit_text("acts", {"system": "original system", "prompt": "original task"}, "best")
	TextGen.put(dir.path_join("prompt.txt"), "original task")
	TextGen.put(dir.path_join("reply.jsonl"), JSON.stringify({"type": "assistant", "message": {"content": [{"type": "text", "text": "The lift is correct; fix the lowering."}]}}) + "\n")
	p.stop()


func _restart() -> bool:
	var ep := _episode(1)
	_saved(ep)
	var p := _producer(TableEpisode.at_dir(ep.dir))
	_ok(p.can_resume("acts"), "a fresh producer discovers interrupted Work on disk")
	var dir := ep.job_dir("acts")
	# The journal may reach disk just before the checkpoint, or end in a torn line.
	AgentTools.log_call(dir, {"tool": "remove", "args": {"names": ["lift"]}, "text": "uncommitted tail", "images": [], "error": false})
	var f := FileAccess.open(dir.path_join("tools.jsonl"), FileAccess.READ_WRITE)
	f.seek_end()
	f.store_string("{torn")
	f.close()
	_ok(p.resume("acts").is_empty(), "Work resumes without a fresh Generate")
	var tools: PuppeteerTools = p._tools["acts"]["set"]
	_ok(tools._acts.size() == 2 and tools._looks == 29 and tools._watched == {"lift": true}
		and tools._warned_unseen and tools._laid.has("formula") and tools._fonts.has("roman"),
		"draft order, 29 looks, watched acts, submit guard and laid ink survive")
	_ok(AgentTools.calls(p._tools["acts"]["url"]) == 91, "the tool-call budget carries on")
	var job: Dictionary = _queued.back()
	_ok(job["system"] == "original system" and String(job["prompt"]).contains("original task")
		and String(job["prompt"]).contains("The lift is correct") and not String(job["prompt"]).contains("uncommitted tail")
		and (job["images"] as Array).size() == 1, "writer receives its original task, saved notes and picture, without an uncommitted call")
	_ok(FileAccess.file_exists(dir.path_join("attempts/001/reply.jsonl")) and AgentResume.history(dir).size() == 2,
		"old writer stream is archived and only committed calls remain in the journal")
	_ok(not p.can_resume("acts"), "a live job cannot be resumed a second time")
	p.stop()
	p = _producer(ep)
	_ok(p.can_resume("acts") and p.resume("acts").is_empty(), "another interruption can be resumed again")
	_ok((p._tools["acts"]["set"] as PuppeteerTools)._looks == 29, "a second resume does not reset looks")
	p._land("acts", {"ok": false, "error": "writer crashed"})
	_ok(p._errors.has("acts") and AgentResume.read_checkpoint(dir).get("calls") == 91,
		"a failed continuation keeps its checkpoint and does not retry from scratch")
	p.stop()
	return true


func _guards() -> bool:
	var ep := _episode(2)
	_saved(ep)
	var p := _producer(ep)
	var before := _queued.size()
	p.start(["acts"])
	_ok(_queued.size() == before and p.can_resume("acts"), "Generate leaves interrupted progress for Resume")
	AgentJobs.allow_for_tool(false)
	_ok(not p.resume("acts").is_empty() and _queued.size() == before, "read-only runs never resume or spend quota")
	AgentJobs.allow_for_tool()
	var original := FileAccess.get_file_as_string(ep.file_of("table"))
	ep.write_json("table", {"things": []})
	_ok(not p.can_resume("acts"), "a changed input prevents continuing an old draft against a new table")
	TextGen.put(ep.file_of("table"), original)
	_ok(p.can_resume("acts"), "restoring identical inputs makes the draft resumable again")
	TextGen.put(ep.file_of("acts"), "a hand's edit")
	_ok(not p.can_resume("acts"), "a hand's replacement of the output is not overwritten by Resume")
	DirAccess.remove_absolute(ep.file_of("acts"))
	TextGen.put(ep.job_dir("acts").path_join(AgentResume.CHECKPOINT), "damaged")
	_ok(not p.can_resume("acts"), "a damaged checkpoint is not offered")
	return true


func _already_submitted() -> bool:
	var ep := _episode(3)
	_saved(ep)
	var dir := ep.job_dir("acts")
	var checkpoint := AgentResume.read_checkpoint(dir)
	var tools := PuppeteerTools.new(ep, ep.read_json("plan"), dir, ep.read_json("table"), true)
	AgentResume.restore(tools, checkpoint)
	tools.submitted = true
	TextGen.put(dir.path_join("submitted.json"), JSON.stringify(tools.draft()))
	AgentResume.save(dir, tools, 92, 29)
	tools.release()
	var p := _producer(ep)
	var before := _queued.size()
	_ok(p.resume("acts").is_empty() and ep.has("acts") and _queued.size() == before,
		"a draft submitted before the crash lands locally, without another writer")
	_ok(not FileAccess.file_exists(dir.path_join(AgentResume.REQUEST)), "a successfully landed run no longer offers Resume")
	p.stop()
	return true


func _legacy() -> bool:
	var ep := _episode(4)
	var dir := ep.job_dir("acts")
	DirAccess.make_dir_recursive_absolute(dir)
	TextGen.put(dir.path_join("prompt.txt"), "old task")
	TextGen.put(dir.path_join("system.txt"), "old system")
	var at := int(Time.get_unix_time_from_system())
	for entry in [
		{"tool": "act", "args": {"acts": [_act("lift"), _act("lower")]}},
		{"tool": "watch", "args": {"name": "lift"}, "images": ["look_01.jpg"]},
		{"tool": "act", "args": {"acts": [_act("lift")]}},
		{"tool": "remove", "args": {"names": ["lower"]}},
		{"tool": "model", "args": {"name": "lift"}, "images": ["look_02.jpg"]}]:
		entry["at"] = at
		entry["error"] = false
		entry["text"] = "completed"
		AgentTools.log_call(dir, entry)
	var p := _producer(ep)
	_ok(p.can_resume("acts") and p.resume("acts").is_empty(), "Work made before checkpoints can recover from completed calls")
	var tools: PuppeteerTools = p._tools["acts"]["set"]
	_ok(tools._acts.size() == 1 and tools._acts[0]["name"] == "lift" and tools._looks == 2 and tools._watched.is_empty(),
		"legacy recovery preserves replacements, removals, looks and watch invalidation")
	_ok(FileAccess.file_exists(dir.path_join(AgentResume.CHECKPOINT)), "legacy recovery adopts a durable checkpoint")
	p.stop()
	return true


func _other_tools() -> bool:
	var ep := _episode(5)
	var table := SetDresserTools.new(ep, ep.read_json("plan"), ep.job_dir("table"))
	table._things = [{"name": "kept thing"}]
	table._looks = 53
	table._set_since_change = true
	var model := ModelTools.new(ep.job_dir("model"))
	model._raw = {"sections": [{"name": "kept section"}]}
	model._made = {"point": Vector3(1, 2, 3), "notes": PackedStringArray(["kept"])}
	model._looks = 23
	var skin := DecoratorTools.new(ep.job_dir("skin"), [])
	skin._raw = {0: {"elements": [{"id": "kept element"}]}}
	skin._looks = 11
	var solve := SolverTools.new(ep, {}, ep.job_dir("solve"))
	solve.checks = 7
	solve.runs = 4
	for pair in [["table", table], ["model", model], ["skin", skin], ["solve", solve]]:
		var step := String(pair[0])
		var tool: Object = pair[1]
		var dir := ep.job_dir(step)
		DirAccess.make_dir_recursive_absolute(dir)
		AgentResume.save(dir, tool, 12, 6)
		var restored := _producer(ep)._resume_tools(step, SPEC)
		_ok(AgentResume.restore(restored, AgentResume.read_checkpoint(dir)) and AgentResume.state_of(restored) == AgentResume.state_of(tool),
			"%s restores its full data, including typed arrays and integer dictionary keys" % step)
		restored.call("release")
		tool.call("release")
	return true


func _explicit_remake() -> bool:
	var ep := _episode(6)
	_saved(ep)
	var p := _producer(ep)
	var before := _queued.size()
	p.start(["acts"], true)
	_ok(_queued.size() == before + 1 and p._tools.has("acts"), "an explicit regenerate starts a new writer")
	var tools: PuppeteerTools = p._tools["acts"]["set"]
	_ok(tools._acts.is_empty() and tools._looks == 0 and AgentResume.read_checkpoint(ep.job_dir("acts")).is_empty(),
		"regenerate starts a fresh draft without borrowing the old checkpoint")
	p.stop()
	_ok(not p.can_resume("acts"), "a new attempt with no completed calls has no resumable progress")
	var other := _episode(7)
	_saved(other)
	p = _producer(other)
	p.spec["writer"] = "bedrock"
	p.start(["acts"], true)
	p.stop()
	_ok(not p.can_resume("acts"), "regenerating with a one-shot writer cannot resurrect an earlier tool draft as legacy progress")
	return true


func _rmrf(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for child in DirAccess.get_directories_at(path):
		_rmrf(path.path_join(child))
	for name in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(name))
	DirAccess.remove_absolute(path)
