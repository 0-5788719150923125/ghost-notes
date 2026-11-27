extends RefCounted
class_name HeadDesign

## HeadDesign - a show's head phrases designed by an agent (next/head.md, [HeadBank], [HeadPlan]): told the show, what the head means to
## the picture and the voice, and what a phrase is written as, it answers a bank of [constant COUNT] phrases. Each is then performed and
## measured ([method HeadPlan.measure]: how often the voice crosses the ears, how near and far, how muffled, how varied) and the numbers
## told back once ([method report]), the agent putting right what does not do what its own line says; the bank it answers then is kept
## for the show, the one before a version back. Runs to its end whoever lets go of it; [member running] says what each is doing.

## How many phrases a bank has.
const COUNT := Vector2i(8, 12)
## What each design under way is doing, by its show: `{line}`.
static var running := {}


## What the designer is told for [param show]: `{system, prompt}` - and, asked again, its phrases [param measured] and its last
## [param answer].
static func prompt(show: String, measured := "", answer := "") -> Dictionary:
	var vars := {"show": show, "fields": HeadPlan.fields_told(), "least": COUNT.x, "most": COUNT.y, "measured": measured,
		"answer": answer}
	return {"system": Rules.say("table/head_designer.system", vars), "prompt": Rules.say("table/head_designer.prompt", vars)}


## Show [param key]'s phrases designed for [param show] by the agent [param pick] (`{agent, model, effort}`) and kept: `{count}` (how
## many it keeps) or `{error}`.
static func design(key: String, show: String, pick: Dictionary) -> Dictionary:
	if running.has(key):
		return {"error": "it is being designed already"}
	if not Library.writable():
		return {"error": "this session is read-only"}
	running[key] = {"line": "designing the head's phrases"}
	var first := await _ask(key, prompt(show), pick)
	var out := {}
	if first.has("error"):
		out = first
	else:
		var phrases: Array = first["phrases"]
		running[key] = {"line": "measuring its phrases, then asking it to put right what does not do what it says"}
		var second := await _ask(key, prompt(show, report(phrases), JSON.stringify({"phrases": phrases})), pick)
		# the second answer where it holds a bank, else the first's
		var kept: Array = second["phrases"] if not second.has("error") and (second["phrases"] as Array).size() >= 3 else phrases
		var err := HeadBank.write(key, kept, "designed for %s" % show.get_slice(":", 0))
		out = {"count": kept.size()} if err.is_empty() else {"error": err}
	running.erase(key)
	return out


## One job of the designer: `{phrases}` (its answer, sanitized) or `{error}`.
static func _ask(key: String, p: Dictionary, pick: Dictionary) -> Dictionary:
	var dir := ProjectSettings.globalize_path(Library.root.path_join("jobs").path_join("head_%d_%d" % [int(Time.get_unix_time_from_system()), randi() % 100000]))
	var job := AgentJobs.submit({"kind": "text", "backend": String(pick.get("agent", "claude")), "tier": "best", "dir": dir,
		"system": String(p["system"]), "prompt": String(p["prompt"]), "label": "head phrases", "model": String(pick.get("model", "")),
		"effort": String(pick.get("effort", ""))})
	if job.is_empty():
		return {"error": "this session cannot start agents"}
	while true:
		var st := AgentJobs.state(job)
		if st != "queued" and st != "running":
			break
		running[key] = {"line": AgentJobs.activity(job)}
		await PropStudio.tree().process_frame
	var res := AgentJobs.result(job)
	AgentJobs.forget(job)
	if not bool(res.get("ok", false)):
		return {"error": String(res.get("error", "")) if not String(res.get("error", "")).is_empty() else "the agent gave no answer"}
	var phrases := answer(String(res.get("text", "")))
	return {"phrases": phrases} if not phrases.is_empty() else {"error": "the agent's answer holds no phrase that can be performed"}


## The agent's answer [param text] read as a bank: its phrases, sanitized, each name once. Pure.
static func answer(text: String) -> Array:
	return HeadBank.phrases_of(TextGen.extract_json(text))


## What [param phrases] really do, measured, a line each as the designer is told it.
static func report(phrases: Array) -> String:
	var out := PackedStringArray()
	for p in phrases:
		var m := HeadPlan.measure(p)
		out.append("- %s (%s): crosses %.1f times, pan %.2f to %.2f, nearest %.2f m, farthest %.2f m, muffled up to %.2f, %.1f s, performances %.3f m apart" % [
			String((p as Dictionary)["name"]), String((p as Dictionary)["line"]).left(80), float(m["crossings"]), float(m["pan_lo"]), float(m["pan_hi"]),
			float(m["nearest"]), float(m["farthest"]), float(m["muffled"]), float(m["seconds"]), float(m["differ"])])
	return "\n".join(out)
