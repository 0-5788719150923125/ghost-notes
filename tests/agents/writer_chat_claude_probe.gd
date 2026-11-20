extends SceneTree

## Not a gate: it spends a little of the author's quota (two short turns of the smallest model). It checks that the installed
## Claude Code CLI, run exactly as a Refine… conversation runs it ([WriterChat], [TextGen.Claude]), keeps its session: the first
## turn starts one under its id and edits the text through ghost's tools ([TextTools]); the second resumes it, is told only
## what changed, and reads the first turn back from the prompt cache.
##
##   godot --headless --path . --script res://tests/agents/writer_chat_claude_probe.gd [-- --model haiku]
##
## Run it again after a Claude Code update: `--session-id`, `--resume`, `--setting-sources ""`, `--system-prompt-file` and MCP
## are separate switches, and this is the only check that they still combine as a conversation needs.

const DIR := "user://writer_chat_probe"

var text := "The cat sat on the mat.\nIt was a sunny day.\nThe end."


func _init() -> void:
	_run.call_deferred()


func _read() -> String:
	return text


func _put(at: int, gone: int, piece: String) -> void:
	text = text.substr(0, at) + piece + text.substr(at + gone)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--model")
	var model := args[i + 1] if i >= 0 and i + 1 < args.size() else "haiku"
	AgentJobs.allow_for_tool()
	var chat := WriterChat.at(DIR)
	chat.clear()
	chat.read_text = _read
	chat.apply = _put
	chat.about = func() -> Dictionary:
		return {"what": "the note's words", "title": "Probe", "script": true,
			"marks": [{"label": "Speaker cue", "example": "<!-- speaker: Name -->", "blurb": "Hands the words after it to the named voice."}]}
	var pick := {"agent": "claude", "model": model, "effort": ""}
	for ask in ["Change 'sunny' to 'rainy'. Nothing else.", "Now hand the last line to a voice called Mo, with a speaker cue."]:
		var why := chat.send(ask, pick)
		if not why.is_empty():
			print("writer_chat_claude_probe: not sent - %s" % why)
			quit(1)
			return
		var t0 := Time.get_ticks_msec()
		while chat.busy() and Time.get_ticks_msec() - t0 < 240000:
			AgentJobs.pump()
			chat.poll()
			await process_frame
		var turn: Dictionary = chat.turns.back()
		print("turn %d: %s" % [chat.turns.size(), ask])
		for e in turn["events"]:
			print("  %s" % str(e))
		print("  reply: %s" % String(turn["reply"]))
		print("  usage: %s   error: %s" % [str(turn["usage"]), String(turn["error"])])
		print("  session: %s" % str(chat.session))
		print("  text now: %s" % text.replace("\n", " | "))
	var ok := text.contains("rainy") and text.contains("<!-- speaker: Mo -->") and chat.turns.size() == 2 \
		and int(((chat.turns[1] as Dictionary)["usage"] as Dictionary).get("cached", 0)) > 0
	print("writer_chat_claude_probe: %s" % ("both turns landed, the second read from the cache" if ok else "SOMETHING IS WRONG - see above"))
	quit(0 if ok else 1)
