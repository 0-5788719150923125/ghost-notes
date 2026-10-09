extends SceneTree

## grok_agent_check - xAI's Grok Build CLI as a writer ([TextGen.Grok]) and a painter
## ([ImageGen.Grok]), with no agent run: `GROK_HOME` is a fixture folder, and the streams are shaped
## as CLI 1.0.50 wrote them.
##
##   godot --headless --path . --script res://tests/grok_agent_check.gd
##
## - THE COMMAND: flags and paths only - the prompt's words are in no argument. A writer's one tool
##   is `read_file`, kept when it has pictures and taken back when it has none (the control: the
##   picture job keeps it); the painter's are the two image tools and `read_file`, nothing that writes
##   a file, its calls approved. The tier is the effort (fast: low; best: the model's own), a chosen
##   level wins, and the painter is low unasked.
## - THE AGENT FILE carries ghost's system prompt as its body (`promptMode: full`), the writer's with
##   Grok's added tools taken away and the painter's with them kept. A system prompt holding `${{` -
##   which Grok would fill in as a template - leads the message instead, word for word, against a plain
##   one, which is the body and not in the message.
## - THE MESSAGE: each picture named by its prepared file, in order; none, and the message is the
##   prompt exactly; a painter's references listed as the requests name them. A picture or reference
##   that cannot be read is refused, never sent as a promise.
## - NONE OF THE AUTHOR'S SETUP: every source Grok borrows from Claude, Cursor and Codex is off for the
##   run, and its memory.
## - GHOST'S TOOLS: a job with them names the server in the agent file (a list), keeps Grok's two MCP
##   tools and allows ghost's calls by rule - the URL never in argv; a job without them has no server
##   and no rule (the control). No skill is ever listed to the model.
## - THE REPLY: the words after a run's last tool call, its chunks joined - not what it said on the way
##   to a call (the control: Grok's one-JSON reply joins both); a reply cut off or failed is no reply,
##   and says why.
## - THE PICTURE: the path the last image tool reported, saved as a real PNG at the target - not a
##   `read_file` result naming a file (the control), and a result that is words, not JSON, is passed
##   over quietly, as are the updates a running tool sends with `"status": null` (the first real run
##   stopped on one). Without one, the stream's error or the agent's last words say why.
## - NO SESSION KEPT: the sessions to delete are the reply's and its folder's, deduplicated, and a name
##   that is not a session id is never handed to the CLI; the folder goes only once no session is left
##   in it (the control: with one left it stays), and no directory names no folder - never Grok's
##   whole sessions root.
## - THE CATALOG: the models and levels the CLI's own cache lists, hidden ones left out; the author's
##   default (config, then GROK_DEFAULT_MODEL) labels Default.

const CATALOG := {"models": {
	"g-big": {"info": {"id": "g-big", "name": "G Big", "hidden": false, "reasoning_effort": "high",
		"reasoning_efforts": [{"id": "xhigh"}, {"id": "high"}, {"id": "medium"}, {"id": "low"}]}},
	"g-small": {"info": {"id": "g-small", "name": "G Small", "hidden": false, "reasoning_effort": "medium",
		"reasoning_efforts": [{"id": "medium"}, {"id": "low"}, {"id": "deep"}]}},
	"g-secret": {"info": {"id": "g-secret", "name": "G Secret", "hidden": true, "reasoning_efforts": []}}}}
const WORDS := "THE-AUTHOR'S \"WORDS\" $(echo no)"

var _fails := 0
var _scratch := ""


func _init() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + what)
	if not cond:
		_fails += 1


func _run() -> void:
	var settings := root.get_node_or_null("Settings")
	if settings != null:
		settings.set("_read_only", true)
	var keep := {}
	for k in ["GROK_HOME", "GROK_DEFAULT_MODEL"]:
		keep[k] = OS.get_environment(k)
	OS.unset_environment("GROK_DEFAULT_MODEL")
	_scratch = ProjectSettings.globalize_path("user://grok_agent_check")
	_wipe(_scratch)
	DirAccess.make_dir_recursive_absolute(_scratch.path_join("home"))
	OS.set_environment("GROK_HOME", _scratch.path_join("home"))
	for check in [_command, _agent_file, _message, _isolation, _reply, _picture, _sessions, _catalog]:
		if not bool(check.call()):
			_ok(false, "a check stopped part way (script error?)")
	for k in keep:
		if String(keep[k]).is_empty():
			OS.unset_environment(k)
		else:
			OS.set_environment(k, keep[k])
	_wipe(_scratch)
	print("grok_agent_check: %s" % ("ALL OK" if _fails == 0 else "%d FAILED" % _fails))
	quit(0 if _fails == 0 else 1)


func _put(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _wipe(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for d in DirAccess.get_directories_at(path):
		_wipe(path.path_join(d))
	for f in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	DirAccess.remove_absolute(path)


static func _keys(list: Array) -> Array:
	return list.map(func(e: Dictionary) -> String: return String(e["key"]))


static func _after(args: PackedStringArray, flag: String) -> String:
	var at := args.find(flag)
	return args[at + 1] if at >= 0 and at + 1 < args.size() else ""


func _command() -> bool:
	print("-- the command")
	var dir := _scratch.path_join("job")
	var job := {"dir": dir, "tier": "best", "prompt": WORDS, "system": WORDS}
	var w: PackedStringArray = TextGen.Grok.argv(job, false)
	_ok(not " ".join(w).contains("WORDS"), "the writer's argv holds no word of the prompt or the system prompt")
	_ok(_after(w, "--agent") == dir.path_join("agent.md") and _after(w, "--prompt-file") == dir.path_join("prompt.txt")
		and w.has("--verbatim") and _after(w, "--cwd") == dir and _after(w, "--output-format") == "streaming-json",
		"the agent file, the message file read as written, the job's folder, a stream of events")
	_ok(_after(w, "--tools") == "read_file" and _after(w, "--disallowed-tools") == "read_file,search_tool,use_tool",
		"no pictures: the one tool named, then taken back - no tools at all")
	var wp: PackedStringArray = TextGen.Grok.argv(job, true)
	_ok(_after(wp, "--disallowed-tools") == "search_tool,use_tool", "the control: with pictures, read_file stays")
	_ok(not w.has("--allow") and not w.has("--always-approve"), "no tools of ghost's: no call allowed by rule")
	var tjob := {"dir": dir, "tier": "best", "tools_url": "http://127.0.0.1:9/mcp/SECRETTOKEN"}
	var t: PackedStringArray = TextGen.Grok.argv(tjob, false)
	_ok(_after(t, "--disallowed-tools") == "read_file" and _after(t, "--allow") == "MCPTool(ghost__*)"
		and not " ".join(t).contains("SECRETTOKEN") and not t.has("--always-approve"),
		"ghost's tools: search_tool and use_tool kept, ghost's calls allowed by rule (Grok's classifier refused one in three), the URL not in argv")
	_ok(not TextGen.Grok.argv(tjob, true).has("--disallowed-tools"), "...and with pictures, nothing taken back")
	_ok(w.has("--no-memory") and w.has("--no-subagents") and w.has("--disable-web-search"), "no memory, no helpers, no web")
	_ok(not w.has("--effort") and not w.has("-m"), "best, unasked: the model's own effort, the default model")
	job["tier"] = "fast"
	_ok(_after(TextGen.Grok.argv(job, false), "--effort") == "low", "fast: the lightest effort")
	job["effort"] = "xhigh"
	job["model"] = "g-small"
	var chosen: PackedStringArray = TextGen.Grok.argv(job, false)
	_ok(_after(chosen, "--effort") == "xhigh" and _after(chosen, "-m") == "g-small", "a chosen effort and model win")
	var pjob := {"dir": dir, "prompt": WORDS, "refs": []}
	var p: PackedStringArray = ImageGen.Grok.argv(pjob)
	_ok(not " ".join(p).contains("WORDS"), "the painter's argv holds no word of the request")
	_ok(_after(p, "--tools") == "image_gen,image_edit,read_file" and _after(p, "--disallowed-tools") == "search_tool,use_tool"
		and not " ".join(p).contains("run_terminal") and not " ".join(p).contains("write"),
		"the painter's tools: the two image tools and read_file, nothing that writes a file")
	_ok(p.has("--always-approve") and not p.has("--allow"), "the painter's calls approved: none goes to Grok's classifier")
	_ok(_after(p, "--effort") == "low" and _after(p, "--output-format") == "streaming-json", "the painter: low unasked, a stream of events")
	pjob["effort"] = "high"
	_ok(_after(ImageGen.Grok.argv(pjob), "--effort") == "high", "...and a chosen level wins")
	return true


func _agent_file() -> bool:
	print("-- the agent file")
	var wa := TextGen.Grok.agent_file("writer", "Be a writer.", true)
	_ok(wa.begins_with("---\n") and wa.contains("\npromptMode: full\n") and wa.contains("\ninjectDefaultTools: false\n")
		and wa.contains("\ndiscoverSkills: false\n") and wa.ends_with("---\n\nBe a writer.\n"),
		"the writer's: Grok's prompt replaced, its added tools and skills left out, the body last")
	var pa := TextGen.Grok.agent_file("painter", "Paint.", false)
	_ok(pa.contains("\npromptMode: full\n") and not pa.contains("injectDefaultTools"), "the painter's keeps the added (image) tools")
	_ok(wa.contains("\nskills: []\n") and pa.contains("\nskills: []\n"), "no skill listed to the model (Grok listed its bundled ones mid-run)")
	_ok(not wa.contains("mcpServers"), "the control: no tools of ghost's, no server")
	var url := "http://127.0.0.1:9/mcp/abc"
	var ta := TextGen.Grok.agent_file("writer", "Set the table.", true, url)
	_ok(ta.contains("\nmcpServers:\n  - name: ghost\n    type: http\n    url: \"%s\"\n---\n" % url),
		"ghost's tools: its server named in the agent file, as a list (a map is refused)")
	var dir := _scratch.path_join("job")
	var plain := TextGen.Grok.compose({"dir": dir, "system": "You are the reader.", "prompt": "Read."})
	_ok(String(plain["body"]) == "You are the reader." and String(plain["message"]) == "Read.",
		"a plain system prompt is the body, and the message is the prompt exactly")
	var tmpl := "Say ${{ tools.by_kind.read }} as written."
	var folded := TextGen.Grok.compose({"dir": dir, "system": tmpl, "prompt": "Read."})
	_ok(String(folded["message"]).begins_with(tmpl + "\n\n---\n\n") and String(folded["message"]).ends_with("Read.")
		and not String(folded["body"]).contains("${{") and not String(folded["body"]).is_empty(),
		"a system prompt holding ${{ leads the message word for word; the body is the rules' own line")
	var none := TextGen.Grok.compose({"dir": dir, "prompt": "Read."})
	_ok(String(none["body"]) == Rules.say("agents/grok.writer"), "no system prompt: the rules' line, never an empty body")
	return true


func _message() -> bool:
	print("-- the message")
	var dir := _scratch.path_join("job")
	var a := _scratch.path_join("a.png")
	var b := _scratch.path_join("b.png")
	for f in [a, b]:
		Image.create(8, 8, false, Image.FORMAT_RGB8).save_png(f)
	var m := TextGen.Grok.compose({"dir": dir, "prompt": "Write.", "images": [
		{"path": a, "label": "The card:", "flip": true}, {"path": b, "label": "The table:"}]})
	var msg := String(m["message"])
	_ok(String(m["error"]).is_empty() and msg.ends_with("\n\n---\n\nWrite."), "the pictures come first, then the prompt")
	_ok(msg.contains("Attached picture 1 - The card: " + dir.path_join("picture_1.jpg"))
		and msg.contains("Attached picture 2 - The table: " + dir.path_join("picture_2.jpg"))
		and msg.find("picture_1.jpg") < msg.find("picture_2.jpg"), "each named by its prepared file, in order")
	_ok(msg.contains("read_file"), "...and the writer is told to look at them with read_file")
	var pics: Array = m["pictures"]
	_ok(pics.size() == 2 and bool((pics[0] as Dictionary)["flip"]) and String((pics[1] as Dictionary)["from"]) == b,
		"the files to prepare, turned over where the card lies reversed")
	var gone := TextGen.Grok.compose({"dir": dir, "prompt": "Write.", "images": [{"path": _scratch.path_join("nope.png")}]})
	_ok(String(gone["error"]).contains("nope.png"), "a picture that cannot be read is refused")
	var pm := ImageGen.Grok.compose({"dir": dir, "prompt": "Paint.", "refs": [a, b]})
	_ok(String(pm["message"]).begins_with("Attached image 1: %s\nAttached image 2: %s" % [a, b])
		and String(pm["message"]).ends_with("\n\n---\n\nPaint."), "the painter's references, as the requests name them")
	_ok(String(ImageGen.Grok.compose({"dir": dir, "prompt": "Paint.", "refs": []})["message"]) == "Paint.",
		"no references: the request exactly")
	_ok(String(ImageGen.Grok.compose({"dir": dir, "prompt": "Paint.", "refs": [_scratch.path_join("nope.png")]})["error"]).contains("nope.png"),
		"a reference that cannot be read is refused")
	return true


func _isolation() -> bool:
	print("-- none of the author's setup")
	var env: Dictionary = TextGen.Grok.ISOLATION
	var off := 0
	for who in ["CLAUDE", "CURSOR", "CODEX"]:
		for what in ["AGENTS", "RULES", "SKILLS", "MCPS", "HOOKS", "SESSIONS"]:
			if String(env.get("GROK_%s_%s_ENABLED" % [who, what], "")) == "0":
				off += 1
	_ok(off == 18, "every source borrowed from Claude, Cursor and Codex is off (%d of 18)" % off)
	_ok(String(env.get("GROK_MEMORY", "")) == "0" and String(env.get("GROK_WORKFLOWS", "")) == "0",
		"no memory, no workflows")
	_ok(int(TextGen.Grok.TOOLS_ENV.get("GROK_MAX_MCP_OUTPUT_BYTES", "0")) > 20000,
		"a run with ghost's tools takes a tool's text past Grok's 20 KB cap")
	return true


func _reply() -> bool:
	print("-- the reply")
	var dir := _scratch.path_join("reply")
	var job := {"dir": dir}
	var reply := dir.path_join("reply.jsonl")
	var g := TextGen.Grok.new()
	var run := [{"type": "text", "data": "I am about to look."},
		{"type": "tool_call", "toolCallId": "c0", "toolName": "read_file", "status": "pending"},
		{"type": "tool_call_update", "toolCallId": "c0", "status": null, "content": null},
		{"type": "tool_call_update", "toolCallId": "c0", "status": "completed", "content": []},
		{"type": "text", "data": "  The "}, {"type": "thought", "data": "hmm"}, {"type": "text", "data": "words.\n"},
		{"type": "end", "stopReason": "end_turn", "sessionId": "01a11f61-94ec"}]
	_put(reply, "\n".join(run.map(func(e: Dictionary) -> String: return JSON.stringify(e))) + "\n")
	_ok(g.resolve(job) == "The words.", "an ended turn: the words after its last tool call, its chunks joined")
	_ok(not g.resolve(job).contains("about to look"), "the control: what it said on the way to a tool call is not the reply")
	_ok(TextGen.Grok.outcome(reply)["session"] == "01a11f61-94ec", "the run's session, from its end event")
	_put(reply, JSON.stringify({"type": "text", "data": "The wor"}) + "\n" + JSON.stringify({"type": "end", "stopReason": "max_tokens"}) + "\n")
	_ok(g.resolve(job).is_empty() and g.failure(job) == "grok stopped: max tokens", "cut off: no reply, and says so")
	_put(reply, JSON.stringify({"type": "error", "message": "Couldn't start session: not logged in"}) + "\n")
	_ok(g.resolve(job).is_empty() and g.failure(job).contains("not logged in"), "an error: its message")
	return true


func _picture() -> bool:
	print("-- the picture")
	var dir := _scratch.path_join("paint")
	var made := _scratch.path_join("home/sessions/s/01a11f65-5242/images/1.jpg")
	var later := _scratch.path_join("home/sessions/s/01a11f65-5242/images/2.jpg")
	var looked := _scratch.path_join("a.png")
	DirAccess.make_dir_recursive_absolute(made.get_base_dir())
	var img := Image.create(12, 18, false, Image.FORMAT_RGB8)
	img.fill(Color(0.1, 0.2, 0.8))
	img.save_jpg(made)
	img.fill(Color(0.9, 0.8, 0.1))
	img.save_jpg(later)
	var events := dir.path_join("events.jsonl")
	var lines := [
		{"type": "tool_call", "toolCallId": "c0", "toolName": "read_file", "status": "pending"},
		{"type": "tool_call_update", "toolCallId": "c0", "status": "completed",
			"content": [{"type": "content", "content": {"type": "text", "text": JSON.stringify({"path": looked})}}]},
		{"type": "text", "data": "Painting it."},
		{"type": "tool_call", "toolCallId": "c1", "toolName": "image_gen", "status": "pending"},
		{"type": "tool_call_update", "toolCallId": "c1", "status": null, "content": [], "rawOutput": null},
		{"type": "tool_call_update", "toolCallId": "c1", "status": null, "content": null},
		{"type": "tool_call_update", "toolCallId": "c1", "status": "completed",
			"content": [{"type": "content", "content": {"type": "text", "text": JSON.stringify({"path": made, "filename": "1.jpg"})}}]},
		{"type": "tool_call", "toolCallId": "c2", "toolName": "image_edit", "status": "pending"},
		{"type": "tool_call_update", "toolCallId": "c2", "status": "completed",
			"content": [{"type": "content", "content": {"type": "text", "text": "Image blocked by moderation."}}]},
		{"type": "end", "stopReason": "end_turn", "sessionId": "01a11f65-5242"}]
	_put(events, "\n".join(lines.map(func(e: Dictionary) -> String: return JSON.stringify(e))) + "\n")
	_ok(ImageGen.Grok.made(events) == made, "the path the image tool reported - not the read_file result, nor words")
	_ok(ImageGen.Grok.session_id(events) == "01a11f65-5242", "the run's session, from its end event")
	var job := {"dir": dir, "events": events, "target": dir.path_join("image.png")}
	ImageGen.Grok.collect(job)
	var g := ImageGen.Grok.new()
	var got := g.resolve(job)
	var back := Image.load_from_file(got) if not got.is_empty() else null
	var head := FileAccess.get_file_as_bytes(got).slice(0, 4) if not got.is_empty() else PackedByteArray()
	_ok(got == dir.path_join("image.png") and back != null and back.get_size() == Vector2i(12, 18)
		and head == PackedByteArray([0x89, 0x50, 0x4E, 0x47]), "saved as a real PNG at the target, whole")
	lines.insert(lines.size() - 1, {"type": "tool_call", "toolCallId": "c3", "toolName": "image_edit"})
	lines.insert(lines.size() - 1, {"type": "tool_call_update", "toolCallId": "c3", "status": "completed",
		"content": [{"type": "content", "content": {"type": "text", "text": JSON.stringify({"path": later})}}]})
	_put(events, "\n".join(lines.map(func(e: Dictionary) -> String: return JSON.stringify(e))) + "\n")
	_ok(ImageGen.Grok.made(events) == later, "the last picture made is the one kept")
	var none := dir.path_join("none.jsonl")
	_put(none, "\n".join([JSON.stringify({"type": "text", "data": "Thinking. "}),
		JSON.stringify({"type": "tool_call", "toolCallId": "c1", "toolName": "image_gen"}),
		JSON.stringify({"type": "text", "data": "That request was refused."})]) + "\n")
	var empty := {"dir": dir.path_join("empty"), "events": none}
	ImageGen.Grok.collect(empty)
	_ok(g.resolve(empty).is_empty() and g.failure(empty) == "That request was refused.",
		"no picture: the agent's words after its last tool call say why")
	_put(none, JSON.stringify({"type": "error", "message": "rate limited"}) + "\n")
	_ok(g.failure(empty) == "rate limited", "...or the stream's error")
	return true


func _sessions() -> bool:
	print("-- no session kept")
	var dir := _scratch.path_join("job dir")
	var group := TextGen.Grok.group_of(dir)
	_ok(group == _scratch.path_join("home/sessions").path_join(dir.uri_encode()), "a directory's sessions folder, URL-encoded")
	_ok(TextGen.Grok.group_of("").is_empty(), "no directory names no folder (never the whole sessions root)")
	for s in ["01a11f65-aaaa", "01a11f65-bbbb", "not a session"]:
		DirAccess.make_dir_recursive_absolute(group.path_join(s))
	_put(group.path_join("prompt_history.jsonl"), "{}\n")
	var ids := TextGen.Grok.sessions_of(dir, "01a11f65-aaaa")
	ids.sort()
	_ok(ids == ["01a11f65-aaaa", "01a11f65-bbbb"], "the reply's and the folder's, once each; a name that is no id left out (%s)" % str(ids))
	_ok(TextGen.Grok.sessions_of(dir, "../../etc").size() == 2, "...and a reply naming no id adds none")
	TextGen.Grok.clear_group(dir)
	_ok(DirAccess.dir_exists_absolute(group), "the control: with a session left, the folder stays")
	for s in ["01a11f65-aaaa", "01a11f65-bbbb", "not a session"]:
		DirAccess.remove_absolute(group.path_join(s))
	_ok(TextGen.Grok.forget({"dir": dir, "sessions": []}, "grok") == 0 and not DirAccess.dir_exists_absolute(group),
		"none left: no step, and the folder (its prompt history) is gone")
	return true


func _catalog() -> bool:
	print("-- the catalog")
	var home := _scratch.path_join("home")
	_put(home.path_join("models_cache.json"), JSON.stringify(CATALOG))
	_put(home.path_join("config.toml"), "[ui]\ndefault = \"nope\"\n\n[models]\ndefault = \"g-small\"   # mine\n")
	var models: Array = TextGen.Grok.models()
	_ok(_keys(models) == ["", "g-big", "g-small"], "the cache's models, the hidden one left out")
	_ok(String(models[0]["label"]) == "Default (G Small)", "Default names the config's model, not another table's key (%s)" % models[0]["label"])
	_ok(Array(TextGen.Grok.levels("g-big")) == ["low", "medium", "high", "xhigh"], "a model's levels, lightest first")
	_ok(Array(TextGen.Grok.levels("")) == ["low", "medium", "deep"], "Default: the default model's, its own menu id last")
	_ok(Array(TextGen.Grok.levels("g-unknown")) == ["low", "medium", "high", "xhigh", "deep"], "an unlisted model: every listed level")
	_ok(String(TextGen.Grok.efforts("g-big")[0]["label"]) == "Default (high, low for designs)", "the writer's Default names the model's own effort")
	_ok(String(ImageGen.Grok.efforts("")[0]["label"]) == "Default (low)" and _keys(ImageGen.Grok.models()) == _keys(models),
		"the painter: low by default, the same agents")
	OS.set_environment("GROK_DEFAULT_MODEL", "g-big")
	_ok(TextGen.Grok.default_model() == "g-big", "GROK_DEFAULT_MODEL wins over the config")
	OS.unset_environment("GROK_DEFAULT_MODEL")
	_ok(TextGen.has("grok") and ImageGen.REGISTRY.has("grok") and TextGen.make("grok").takes_tools()
		and not Deps.entry("grok").is_empty(), "a writer and a painter, a Deps row, and the writer takes ghost's tools")
	return true
