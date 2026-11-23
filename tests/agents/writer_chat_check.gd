extends SceneTree

## writer_chat_check - a conversation with a writer about one text ([WriterChat], [TextTools]; next/refine.md), and the
## writers keeping a CLI session for it ([TextGen]). No writer runs: a turn's outcome is handed in as a run's would be, and
## the session flags are read off the argument vectors.
##
##   godot --headless --path . --script res://tests/agents/writer_chat_check.gd
##
## - The tools: an edit changes the one place it names, and every place when told (control: a part that is not there, or is
##   there twice, changes nothing and says why); a text written whole; a text nobody holds any more refuses every call.
## - What the writer is told: the system prompt names every mark it is given with its sample, and the note's parts; a
##   Direction's says the note is not its to change (control: a Body's does not); a writer without tools is asked for the
##   text between tags (control: one with tools is not). A first turn carries the text, the author's words, the note and the
##   conversation so far where given (control: none of either when not); a resumed turn tells only the lines a hand changed
##   (control: nothing when the text is as the writer saw it), and the whole text where most of it changed.
## - A turn landing: what the writer said and changed, in order, its reply once (control: the reply also said last is not
##   shown twice), the session and what it cost kept, and all of it read back from the file. A resumed turn that failed before
##   doing anything starts a new session (here refused: a gate starts no agent).
## - A turn ends whoever holds it: a turn whose job ended lands on the next frame with no owner polling (control: not before
##   that frame), and is polled no more; Stop ends a turn at once - one whose writer had already finished lands with its reply,
##   one still waiting lands stopped.
## - Sessions: Claude starts one under its id and resumes it by id (control: a stateless run keeps none); Codex resumes with
##   `exec resume` and is told only the new message (control: a fresh run is ephemeral and told its rules first); Grok starts
##   one under its id and resumes it.

const ROOT := "user://writer_chat_check"

var _fails := 0


func _init() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		print("  FAIL: " + what)


func _run() -> void:
	_wipe(ProjectSettings.globalize_path(ROOT))
	for check in [_tools, _told, _landing, _alone, _sessions]:
		var done: Variant = await (check as Callable).call()
		_ok(done == true, "%s stopped part way (a script error - see above)" % (check as Callable).get_method())
	_wipe(ProjectSettings.globalize_path(ROOT))
	print("writer_chat_check: %s (%d failure%s)" % ["ALL OK" if _fails == 0 else "FAILED", _fails, "" if _fails == 1 else "s"])
	quit(1 if _fails > 0 else 0)


func _wipe(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for d in DirAccess.get_directories_at(dir):
		_wipe(dir.path_join(d))
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.remove_absolute(dir)


## A text held in a box, as a card holds it, and a toolset over it.
class Held:
	var text := ""
	var changes: Array = []

	func read() -> String:
		return text

	func put(at: int, gone: int, piece: String) -> void:
		text = text.substr(0, at) + piece + text.substr(at + gone)


func _tools() -> bool:
	var held := Held.new()
	held.text = "The cat sat.\nThe dog sat.\nThe end."
	var t := TextTools.new()
	t.read_text = held.read
	t.apply = held.put
	t.changed = func(e: Dictionary) -> void: held.changes.append(e)
	var r := t.call_tool("edit", {"old": "The cat sat.", "new": "The cat slept."})
	_ok(not r.has("error") and held.text == "The cat slept.\nThe dog sat.\nThe end." and held.changes.size() == 1,
		"an edit changes the one place it names (%s)" % held.text)
	r = t.call_tool("edit", {"old": "The bird sat.", "new": "x"})
	_ok(r.has("error") and held.text.contains("The cat slept."), "CONTROL: a part that is not there changes nothing, and says why")
	r = t.call_tool("edit", {"old": "The", "new": "A"})
	_ok(r.has("error") and String(r["error"]).contains("3 times") and held.text.begins_with("The cat"),
		"CONTROL: a part there more than once changes nothing unless every one is meant (%s)" % str(r))
	r = t.call_tool("edit", {"old": "The", "new": "A", "every": true})
	_ok(not r.has("error") and held.text == "A cat slept.\nA dog sat.\nA end.", "every place it is, when told (%s)" % held.text)
	r = t.call_tool("write", {"text": "New words."})
	_ok(held.text == "New words." and String((held.changes.back() as Dictionary)["tool"]) == "write", "a text written whole")
	_ok(String(t.call_tool("read", {})["text"]) == "New words.", "read shows it as it stands")
	_ok(not t.list_tools().any(func(d: Dictionary) -> bool: return d["name"] == "read_note"), "no read_note for a text beside no note")
	var gone := TextTools.new()
	gone.read_text = func() -> Variant: return null
	gone.apply = held.put
	_ok(gone.call_tool("write", {"text": "lost"}).has("error") and held.text == "New words.", "a text nobody holds refuses every call")
	return true


func _told() -> bool:
	var marks := [{"label": "Speaker cue", "example": "<!-- speaker: Name -->", "blurb": "Hands the words to a voice."}]
	var parts := [{"label": "Voice", "blurb": "Reads the note aloud."}]
	var body := WriterChat.system_of({"what": "the note's words", "title": "A Night", "script": true, "parts": parts, "marks": marks}, true)
	_ok(body.contains("<!-- speaker: Name -->") and body.contains("Hands the words to a voice.") and body.contains("Reads the note aloud.")
		and body.contains("A Night") and Rules.missing.is_empty(), "the system prompt names each mark with its sample, and the note's parts (%s)" % str(Rules.missing))
	_ok(not body.contains("<text>") and body.contains("tools"), "CONTROL: a writer with tools is not asked for the text between tags")
	var bare := WriterChat.system_of({"what": "the note's words", "script": true}, false)
	_ok(bare.contains("<text>") and not bare.contains("THE MARKS"), "a writer without tools is asked for the text between tags, and no marks are named when none are given")
	var dirn := WriterChat.system_of({"what": "the note's Direction", "direction": true}, true)
	_ok(dirn.contains("The note is not yours") and not body.contains("The note is not yours"),
		"a Direction's says the note is not its to change (control: a Body's does not)")
	var first := WriterChat.first_message({"title": "A Night"}, "Once upon a time.", "Make it darker.", "THE AUTHOR: before", "The note's words.")
	_ok(first.contains("Once upon a time.") and first.contains("Make it darker.") and first.contains("The note's words.")
		and first.contains("THE AUTHOR: before"), "a first turn carries the text, the words, the note and the conversation so far")
	var plain := WriterChat.first_message({}, "Once upon a time.", "Make it darker.")
	_ok(not plain.contains("<note>") and not plain.contains("BEFORE"), "CONTROL: no note and no conversation when none is given")
	var was := "one\ntwo\nthree\nfour\nfive\nsix\nseven\neight"
	var next := WriterChat.turn_message(was, was.replace("four", "FOUR"), "Shorter.")
	_ok(next.contains("<was>") and next.contains("four") and next.contains("FOUR") and not next.contains("eight") and next.contains("Shorter."),
		"a resumed turn tells the lines a hand changed, a line round them (%s)" % next)
	var same := WriterChat.turn_message(was, was, "Shorter.")
	_ok(not same.contains("<was>") and not same.contains("<text>") and same.contains("Shorter."), "CONTROL: nothing told when the text is as the writer saw it")
	var most := WriterChat.turn_message(was, "a\nb\nc\nd\ne\nf\ng\neight", "Shorter.")
	_ok(most.contains("<text>") and most.contains("a\nb\nc"), "the whole text where most of it changed")
	var split := WriterChat.split_reply("Here it is.\n<text>\nNew words.\n</text>\nDone.")
	_ok(String(split["text"]) == "New words." and String(split["said"]) == "Here it is.\n\nDone.", "a reply's text between tags, and the rest (%s)" % str(split))
	_ok(WriterChat.split_reply("Just a question?")["text"] == null, "CONTROL: a reply with no tags changes nothing")
	return true


func _landing() -> bool:
	var held := Held.new()
	held.text = "The cat sat."
	var dir := ROOT.path_join("body")
	var chat := WriterChat.at(dir)
	chat.read_text = held.read
	chat.apply = held.put
	chat.turns.append({"you": "Make it sleep.", "agent": "claude", "model": "", "effort": "", "at": 0, "events": [], "reply": "",
		"usage": {}, "error": "", "running": true})
	chat._take_said(["I'll change the verb."])
	held.put(8, 3, "slept")
	chat._changed_by_writer({"tool": "edit", "old": "sat", "new": "slept", "count": 1})
	chat._take_said(["I'll change the verb.", "Changed sat to slept."])
	chat._land({"ok": true, "text": "Changed sat to slept.", "session": "abc-123",
		"usage": {"fresh": 900, "cached": 12000, "made": 0, "out": 80, "usd": 0.01}})
	var turn: Dictionary = chat.turns[0]
	var events: Array = turn["events"]
	_ok(events.size() == 2 and String((events[0] as Dictionary).get("said", "")) == "I'll change the verb."
		and String((events[1] as Dictionary).get("tool", "")) == "edit", "what was said and changed, in order (%s)" % str(events))
	_ok(String(turn["reply"]) == "Changed sat to slept." and not bool(turn["running"]), "the reply once, not shown twice (%s)" % str(turn))
	_ok(chat.session == {"agent": "claude", "id": "abc-123"} and chat.seen == "The cat slept.", "the session kept, and the text as the writer saw it")
	WriterChat._live.clear()
	var back := WriterChat.at(dir)
	_ok(back.turns.size() == 1 and String((back.turns[0] as Dictionary)["reply"]) == "Changed sat to slept."
		and int(((back.turns[0] as Dictionary)["usage"] as Dictionary).get("cached", 0)) == 12000 and back.session.get("id") == "abc-123",
		"all of it read back from the file")
	_ok(WriterChat.at(dir) == back, "one conversation a folder is live: a panel built again is handed the same one")
	# a resumed turn that failed before doing anything: a new session, told the conversation so far - refused here
	back.read_text = held.read
	back.apply = held.put
	back.turns.append({"you": "Again.", "agent": "claude", "model": "", "effort": "", "at": 0, "events": [], "reply": "",
		"usage": {}, "error": "", "running": true})
	back._resumed = true
	back._land({"ok": false, "error": "No conversation found with session ID: abc-123"})
	_ok(back.session.is_empty() and back.turns.size() == 2 and not String((back.turns[1] as Dictionary)["error"]).is_empty()
		and not bool((back.turns[1] as Dictionary)["running"]), "a resumed turn that failed starts a new session (refused in a gate: %s)" % str(back.turns[1]))
	back.clear()
	_ok(back.turns.is_empty() and back.session.is_empty(), "a new conversation forgets the turns and the session")
	var r := WriterChat.replay([{"you": "Shorter.", "reply": "Cut a line.", "events": [{"tool": "edit"}], "error": ""}])
	_ok(r.contains("THE AUTHOR: Shorter.") and r.contains("1 change to the text") and r.contains("Cut a line."), "the conversation so far, for a new session (%s)" % r)
	return true


func _alone() -> bool:
	var held := Held.new()
	held.text = "The cat sat."
	var chat := WriterChat.at(ROOT.path_join("alone"))
	chat.read_text = held.read
	chat.apply = held.put
	var turn := func(job: String) -> Dictionary:
		var t := {"you": "Again.", "agent": "claude", "model": "", "effort": "", "at": 0, "events": [], "reply": "", "usage": {}, "error": "",
			"running": true}
		chat.turns.append(t)
		chat._job = job
		return t
	var t1: Dictionary = turn.call("gate-ended")
	AgentJobs._ended["gate-ended"] = {"ok": true, "text": "Done.", "path": "", "error": ""}
	chat._tick(true)
	_ok(bool(t1["running"]), "control: the turn was landed before a frame passed")
	await process_frame
	await process_frame
	_ok(not bool(t1["running"]) and String(t1["reply"]) == "Done." and not chat.busy(), "a turn whose job ended did not land by itself (%s)" % str(t1))
	_ok(not process_frame.is_connected(chat.poll), "a landed turn is still polled each frame")
	var t2: Dictionary = turn.call("gate-finished")
	AgentJobs._ended["gate-finished"] = {"ok": true, "text": "All moved.", "path": "", "error": ""}
	chat.stop()
	_ok(not bool(t2["running"]) and String(t2["reply"]) == "All moved.", "Stop on a writer already finished did not land its reply (%s)" % str(t2))
	var t3: Dictionary = turn.call("gate-queued")
	AgentJobs._queue.append({"id": "gate-queued"})
	chat.stop()
	_ok(not bool(t3["running"]) and String(t3["error"]) == "stopped" and not chat.busy(), "Stop on a waiting turn did not end it (%s)" % str(t3))
	AgentJobs._ended.erase("gate-queued")
	return true


func _sessions() -> bool:
	var job := {"dir": "/tmp/turn", "cwd": "/tmp/chat", "tier": "best", "session": {"id": "u-1", "resume": false}}
	var a := TextGen.Claude.argv(job, "/tmp/turn/system.txt", PackedStringArray())
	_ok(a.has("--session-id") and a[a.find("--session-id") + 1] == "u-1" and not a.has("--no-session-persistence"), "Claude starts a session under its id (%s)" % str(a))
	job["session"] = {"id": "u-1", "resume": true}
	a = TextGen.Claude.argv(job, "/tmp/turn/system.txt", PackedStringArray())
	_ok(a.has("--resume") and a[a.find("--resume") + 1] == "u-1" and not a.has("--session-id"), "and resumes it by id")
	var still := TextGen.Claude.argv({"dir": "/tmp/turn", "tier": "best"}, "/tmp/turn/system.txt", PackedStringArray())
	_ok(still.has("--no-session-persistence") and not still.has("--resume"), "CONTROL: a stateless run keeps none")
	_ok(TextGen.cwd_of(job) == "/tmp/chat" and TextGen.cwd_of({"dir": "/tmp/turn"}) == "/tmp/turn", "a conversation's runs start in its folder")
	var c := TextGen.Codex.argv({"dir": "/tmp/turn", "cwd": "/tmp/chat", "tier": "best", "session": {"id": "th-9", "resume": true}}, [])
	_ok(c[0] == "exec" and c[1] == "resume" and c[c.size() - 2] == "th-9" and c[c.size() - 1] == "-" and not c.has("--ephemeral")
		and not c.has("-C") and c.has("sandbox_mode=\"read-only\""), "Codex resumes with exec resume, read-only (%s)" % str(c))
	var cf := TextGen.Codex.argv({"dir": "/tmp/turn", "cwd": "/tmp/chat", "tier": "best", "session": {"id": "x", "resume": false}}, [])
	_ok(not cf.has("resume") and not cf.has("--ephemeral") and cf[cf.find("-C") + 1] == "/tmp/chat", "a fresh conversation's first run keeps its thread (%s)" % str(cf))
	var cs := TextGen.Codex.argv({"dir": "/tmp/turn", "tier": "best"}, [])
	_ok(cs.has("--ephemeral") and not cs.has("resume"), "CONTROL: a stateless Codex run is ephemeral")
	var told := TextGen.Codex.compose({"dir": "/tmp/turn", "system": "SYSTEM WORDS", "prompt": "Shorter.", "session": {"id": "th-9", "resume": true}})
	var fresh := TextGen.Codex.compose({"dir": "/tmp/turn", "system": "SYSTEM WORDS", "prompt": "Shorter."})
	_ok(String(told["prompt"]) == "Shorter." and String(fresh["prompt"]).contains("SYSTEM WORDS") and String(fresh["prompt"]).contains(TextGen.Codex.ONLY_THIS),
		"a resumed Codex turn is told only the new message (control: a fresh one its rules first)")
	var g := TextGen.Grok.common({"dir": "/tmp/turn", "cwd": "/tmp/chat", "session": {"id": "g-1", "resume": false}}, "")
	var gr := TextGen.Grok.common({"dir": "/tmp/turn", "cwd": "/tmp/chat", "session": {"id": "g-1", "resume": true}}, "")
	_ok(g.has("-s") and g[g.find("-s") + 1] == "g-1" and gr.has("--resume") and g[g.find("--cwd") + 1] == "/tmp/chat",
		"Grok starts one under its id and resumes it, in the conversation's folder")
	var now := {}
	TextGen.Claude.read(now, {"type": "assistant", "message": {"content": [{"type": "text", "text": "I'll cut it."}, {"type": "tool_use", "name": "mcp__ghost__edit"}]}})
	_ok(now.get("said", []) == ["I'll cut it."], "what Claude says between its calls is kept to show as it comes (%s)" % str(now))
	return true
