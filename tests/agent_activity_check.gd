extends SceneTree

## agent_activity_check - WHAT AN AGENT IS DOING NOW, as the Cards rows and the illustration panel say
## it (the user, 2026-10-09: "so we know if agents are thinking, or writing, or looking, or whatever.
## So we know they aren't stuck"). No agent runs: each backend's stream is written here in the shape
## its CLI writes it, a few events at a time.
##
##   godot --headless --path . --script res://tests/agent_activity_check.gd
##
## - EACH BACKEND READS ITS OWN STREAM: Claude (its thinking estimates, its words as they are written
##   - its argv asks for them - and its tool calls by their short names), Codex (a command, a tool, its
##   message; "working" between items), Grok (its thinking and words, ghost's tools by name, a picture
##   looked at, a picture painted; an update still running changes nothing), Bedrock (its step, having
##   no stream).
## - READ AS IT GROWS: each read takes only what was added since the last - nothing counted twice
##   (the control: the same lines read whole again would double the count).
## - THE LINE: what, how much, how long; "nothing new" only past three minutes of a silent stream
##   (the control: two minutes says nothing), and never while it is finishing.
## - THE QUEUE: a queued job is "waiting its turn", a job it does not hold says nothing; every agent
##   step of a Cards row has a maker to name.

var _fails := 0
var _dir := ""


func _init() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + what)
	if not cond:
		_fails += 1


func _run() -> void:
	_dir = ProjectSettings.globalize_path("user://agent_activity_check")
	DirAccess.make_dir_recursive_absolute(_dir)
	for check in [_claude, _codex, _grok, _bedrock, _line, _queue, _rows]:
		if not bool(check.call()):
			_ok(false, "a check stopped part way (script error?)")
	for f in DirAccess.get_files_at(_dir):
		DirAccess.remove_absolute(_dir.path_join(f))
	DirAccess.remove_absolute(_dir)
	print("agent_activity_check: %s" % ("ALL OK" if _fails == 0 else "%d FAILED" % _fails))
	quit(0 if _fails == 0 else 1)


## Append [param events] to [param path], one JSON line each.
func _add(path: String, events: Array) -> void:
	var f := FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	f.seek_end()
	for e in events:
		f.store_line(JSON.stringify(e))
	f.close()


func _claude() -> bool:
	print("-- Claude")
	var job := {"dir": _dir.path_join("claude")}
	DirAccess.make_dir_recursive_absolute(String(job["dir"]))
	var path := String(TextGen.Backend.paths(job)["reply"])
	DirAccess.remove_absolute(path)
	var g := TextGen.Claude.new()
	_ok(String(g.activity(job)["doing"]) == "starting", "before its stream says anything: starting")
	_add(path, [{"type": "system", "subtype": "init"},
		{"type": "system", "subtype": "thinking_tokens", "estimated_tokens": 50, "estimated_tokens_delta": 50},
		{"type": "system", "subtype": "thinking_tokens", "estimated_tokens": 100, "estimated_tokens_delta": 50}])
	var now: Dictionary = g.activity(job)
	_ok(String(now["doing"]) == "thinking" and int(now["tokens"]) == 100, "thinking, its estimates summed (%s)" % str(now))
	_add(path, [{"type": "stream_event", "event": {"type": "content_block_start", "index": 0, "content_block": {"type": "text", "text": ""}}},
		{"type": "stream_event", "event": {"type": "content_block_delta", "index": 0, "delta": {"type": "text_delta", "text": "The lantern"}}}])
	now = g.activity(job)
	_ok(String(now["doing"]) == "writing" and int(now["chars"]) == 11 and int(now["tokens"]) == 100,
		"writing, its words counted as they come - and nothing read twice (%s)" % str(now))
	_add(path, [{"type": "stream_event", "event": {"type": "content_block_start", "index": 1,
		"content_block": {"type": "tool_use", "name": "mcp__ghost__look"}}}])
	_ok(String(g.activity(job)["doing"]) == "calling look", "a tool call, by its short name")
	_add(path, [{"type": "user", "message": {"content": [{"type": "tool_result"}]}}])
	_ok(String(g.activity(job)["doing"]) == "thinking", "a tool answered: the model's turn again")
	_add(path, [{"type": "result", "subtype": "success"}])
	_ok(String(g.activity(job)["doing"]) == "finishing", "the result: finishing")
	var again := TextGen.now_of({}, "starting")
	for e in TextGen.new_events({}, path):
		TextGen.Claude.read(again, e)
	_ok(int(again["tokens"]) == 100, "the control: the whole stream read at once counts the same, once")
	var args: PackedStringArray = TextGen.Claude.argv({"dir": "/x", "tier": "best"}, "/x/system.txt", PackedStringArray())
	_ok(args.has("--include-partial-messages"), "Claude's argv asks for its words as they are written")
	return true


func _codex() -> bool:
	print("-- Codex")
	var job := {"dir": _dir.path_join("codex")}
	DirAccess.make_dir_recursive_absolute(String(job["dir"]))
	var path := String(TextGen.Backend.paths(job)["reply"])
	DirAccess.remove_absolute(path)
	var g := TextGen.Codex.new()
	_add(path, [{"type": "thread.started", "thread_id": "t"}, {"type": "turn.started"}])
	_ok(String(g.activity(job)["doing"]) == "working", "a turn begun, nothing said yet: working")
	_add(path, [{"type": "item.started", "item": {"type": "command_execution", "command": "ls"}}])
	_ok(String(g.activity(job)["doing"]) == "running a command", "a command")
	_add(path, [{"type": "item.completed", "item": {"type": "command_execution"}},
		{"type": "item.started", "item": {"type": "mcp_tool_call", "server": "ghost", "tool": "put"}}])
	_ok(String(g.activity(job)["doing"]) == "calling put", "one of ghost's tools, by name")
	_add(path, [{"type": "item.completed", "item": {"type": "agent_message", "text": "hello"}}])
	var now: Dictionary = g.activity(job)
	_ok(String(now["doing"]) == "working" and int(now["chars"]) == 5, "a message said, and on it goes (%s)" % str(now))
	_add(path, [{"type": "turn.completed"}])
	_ok(String(g.activity(job)["doing"]) == "finishing", "the turn done: finishing")
	var pjob := {"dir": job["dir"], "events": path, "_seen": {}}
	_ok(String(ImageGen.Codex.new().activity(pjob)["doing"]) == "finishing", "the painter reads its events as the writer does")
	return true


func _grok() -> bool:
	print("-- Grok")
	var job := {"dir": _dir.path_join("grok"), "step": "write"}
	DirAccess.make_dir_recursive_absolute(String(job["dir"]))
	var path := String(TextGen.Backend.paths(job)["reply"])
	DirAccess.remove_absolute(path)
	var g := TextGen.Grok.new()
	_add(path, [{"type": "thought", "data": "1234567890123456789012345678901234567890"}])
	var now: Dictionary = g.activity(job)
	_ok(String(now["doing"]) == "thinking" and int(now["tokens"]) == 10, "thinking, ~4 characters a token (%s)" % str(now))
	_add(path, [{"type": "text", "data": "I will look."}])
	_ok(String(g.activity(job)["doing"]) == "writing", "writing")
	_add(path, [{"type": "tool_call", "toolCallId": "c1", "toolName": "use_tool", "rawInput": {"tool_name": "ghost__set"}},
		{"type": "tool_call_update", "toolCallId": "c1", "status": null, "content": null}])
	_ok(String(g.activity(job)["doing"]) == "calling set", "ghost's tool by name - an update still running changes nothing")
	_add(path, [{"type": "tool_call_update", "toolCallId": "c1", "status": "completed", "content": []}])
	_ok(String(g.activity(job)["doing"]) == "thinking", "the call answered: thinking")
	_add(path, [{"type": "tool_call", "toolName": "read_file", "rawInput": {}}])
	_ok(String(g.activity(job)["doing"]) == "looking at a picture", "reading a picture")
	_add(path, [{"type": "tool_call", "toolName": "image_edit", "rawInput": {}}])
	_ok(String(g.activity(job)["doing"]) == "painting", "an image tool: painting")
	job["step"] = "forget"
	_ok(String(g.activity(job)["doing"]) == "finishing", "its session being deleted: finishing")
	var pjob := {"dir": job["dir"], "events": path, "step": "paint"}
	_ok(String(ImageGen.Grok.new().activity(pjob)["doing"]) == "painting", "the painter reads its stream as the writer does")
	return true


func _bedrock() -> bool:
	print("-- Bedrock")
	var g := TextGen.Bedrock.new()
	_ok(String(g.activity({"step": "lookup"})["doing"]) == "looking up its models", "the lookup")
	var waiting := String(g.activity({"step": "converse", "model": "amazon.nova-pro-v1:0"})["doing"])
	_ok(waiting == "waiting for Nova Pro", "the call: waiting for its model, by its own name (%s)" % waiting)
	var p := ImageGen.Bedrock.new()
	_ok(String(p.activity({"step": "direct"})["doing"]) == "writing the picture's prompt" and String(p.activity({"step": "paint"})["doing"]) == "painting",
		"the painter: its director, then its painting")
	_ok(int(g.activity({"step": "converse"}).get("heard", 0)) == 0, "no stream, so never 'nothing new'")
	return true


func _line() -> bool:
	print("-- the line")
	var now := {"doing": "thinking", "tokens": 11234, "chars": 0}
	_ok(TextGen.activity_line(now, 390) == "thinking (~11K tokens) · 6:30", TextGen.activity_line(now, 390))
	_ok(TextGen.activity_line({"doing": "writing", "chars": 1234}, 72) == "writing (1.2K characters) · 1:12",
		TextGen.activity_line({"doing": "writing", "chars": 1234}, 72))
	_ok(TextGen.activity_line({"doing": "calling look"}, 3725, 200) == "calling look · 1:02:05 · nothing new for 3:20",
		"three minutes silent: said (%s)" % TextGen.activity_line({"doing": "calling look"}, 3725, 200))
	_ok(not TextGen.activity_line({"doing": "thinking"}, 300, 120).contains("nothing new"), "the control: two minutes is not")
	var job := {"started": int(Time.get_unix_time_from_system()) - 400, "_now": {"doing": "finishing", "tokens": 0, "chars": 0,
		"heard": int(Time.get_unix_time_from_system()) - 400}}
	_ok(not TextGen.status_of(job).contains("nothing new"), "finishing is never 'nothing new' (%s)" % String(job["_status"]))
	return true


func _queue() -> bool:
	print("-- the queue")
	AgentJobs._queue.append({"id": "probe-queued", "kind": "text"})
	_ok(AgentJobs.activity("probe-queued") == "waiting its turn", "a queued job waits its turn")
	AgentJobs._queue.pop_back()
	_ok(AgentJobs.activity("no-such-job").is_empty(), "a job it does not hold says nothing")
	var path := _dir.path_join("running.jsonl")
	_add(path, [{"type": "thought", "data": "abcdefgh"}])
	AgentJobs._running["probe-running"] = {"id": "probe-running", "gen": ImageGen.Grok.new(), "events": path,
		"started": int(Time.get_unix_time_from_system()) - 65, "step": "paint"}
	var a := AgentJobs.activity("probe-running")
	AgentJobs._running.erase("probe-running")
	_ok(a.begins_with("thinking (~2 tokens) · 1:0"), "a running job: what its stream says, and for how long (%s)" % a)
	return true


func _rows() -> bool:
	print("-- the Cards rows")
	var ed: GDScript = load("res://src/cards_editor.gd")
	var makers: Dictionary = ed.MAKERS
	var missing := PackedStringArray()
	for r in ed.ROWS:
		for s in r[1]:
			var kind := String(s).get_slice(":", 0)
			if not (kind in ["draw", "script"]) and not makers.has(kind):
				missing.append(String(s))
	_ok(missing.is_empty(), "every agent step a row covers has a maker to name (%s)" % ", ".join(missing))
	return true
