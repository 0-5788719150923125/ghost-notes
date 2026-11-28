extends RefCounted
class_name PopupEngineer

## PopupEngineer - a pop-up book's paper engineer at work ([PopupTools]; rules/popup/engineer.yaml): an agent that makes each
## scene's spread in layers of its own from the script's brief, has each layer's picture painted, looks at every spread as the
## show sees it, and refines it in rounds. One at a time a note; it runs to its end whoever lets go of it, and what it made is
## kept at each change ([PopupDesign]).

## Who designs: the text agent and its tier.
const AGENT := "claude"
## What each note's engineer is doing, by the note's path: `{job, url, line, error}`.
static var running := {}


## The engineer set to work on note [param note] with [param tools]; "" started, else why not.
static func start(note: String, tools: PopupTools) -> String:
	if busy(note):
		return "already at work"
	var words := String(tools.body.call()) if tools.body.is_valid() else ""
	var dir := PopupDesign.folder_of(note)
	if dir.is_empty():
		return "the note has no file"
	dir = dir.path_join("jobs").path_join("popup_engineer_%d" % int(Time.get_unix_time_from_system()))
	var look: Variant = (FrontMatter.read_block(words).data as Dictionary).get("illustrations", {})
	var style := ""
	if look is Dictionary and (look as Dictionary).get("style") is Dictionary:
		style = String(((look as Dictionary)["style"] as Dictionary).get("image", ""))
	elif look is Dictionary:
		style = String((look as Dictionary).get("style", ""))
	var vars := {"title": FrontMatter.field_of(words, "title"), "scenes": tools.scenes_text(words), "most": PopupDesign.MOST,
		"style": style.replace("\"", "'") if not style.is_empty() else "the book's own",
		"fold": int(PopupMedium.FOLD), "words_z": "%.2f" % ((PopupLayout.TEXT_TOP - 0.5) * BookMedium.PAGE_H - 0.02)}
	var url := AgentTools.open(dir, tools)
	if url.is_empty():
		return "this session cannot serve an agent its tools"
	var job := AgentJobs.submit({"kind": "text", "backend": AGENT, "tier": "best", "dir": dir, "label": "pop-up engineer",
		"system": Rules.say("popup/engineer.system", vars), "prompt": Rules.say("popup/engineer.prompt", vars), "tools_url": url})
	if job.is_empty():
		AgentTools.close(url)
		return "this session cannot start agents"
	running[note] = {"job": job, "url": url, "line": "starting", "error": ""}
	_watch(note)
	return ""


static func _watch(note: String) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var r: Dictionary = running[note]
	while true:
		var st := AgentJobs.state(String(r["job"]))
		if st != "queued" and st != "running":
			break
		r["line"] = AgentJobs.activity(String(r["job"]))
		await tree.process_frame
	var res := AgentJobs.result(String(r["job"]))
	AgentJobs.forget(String(r["job"]))
	AgentTools.close(String(r["url"]))
	r["job"] = ""
	r["error"] = "" if bool(res.get("ok", false)) else String(res.get("error", "the agent gave no answer"))
	r["line"] = String(res.get("text", "")).strip_edges().left(240) if r["error"] == "" else ""


static func busy(note: String) -> bool:
	return running.has(note) and not String((running[note] as Dictionary)["job"]).is_empty()


## What note [param note]'s engineer is doing or last said, "" for nothing.
static func line(note: String) -> String:
	if not running.has(note):
		return ""
	var r: Dictionary = running[note]
	return String(r["error"]) if not String(r["error"]).is_empty() else String(r["line"])


static func failed(note: String) -> bool:
	return running.has(note) and not String((running[note] as Dictionary)["error"]).is_empty()


static func stop(note: String) -> void:
	if busy(note):
		AgentJobs.cancel(String((running[note] as Dictionary)["job"]))
