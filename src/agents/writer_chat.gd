extends RefCounted
class_name WriterChat

## WriterChat - a conversation with a writer about one text (the Body's and the Direction's Refine…, [TextRefine]; next/refine.md):
## the author says what to change, the writer changes it with its tools ([TextTools]) where the author sees each change land, and
## says what it did; turn after turn, kept beside the note (`chat.json` in [member dir], each turn's run in `turns/<id>/`) and
## read again when the note opens.
##
## THE CLI'S OWN SESSION CARRIES THE CONVERSATION: a writer that keeps sessions ([method TextGen.Backend.sessions]) is resumed
## turn after turn, so what it was told before is read from the provider's prompt cache and only the new turn is sent; its
## system prompt is fixed at the first turn (rules/agents/refine.yaml). The runs share [member dir] as their `cwd`, where a CLI
## finds its session. A turn that cannot resume one (another agent picked, a writer that keeps none) starts a new session told
## the conversation so far ([method replay]), and so does a resumed turn that failed before it did anything (the CLI no longer
## finds the session).
##
## The writer is told when the author changed the text by hand since it last saw it: the lines that changed ([method
## changed_part]), the whole text only when most of it did.
##
## A writer that takes no tools answers with the whole new text between `<text>` tags ([method split_reply]).
##
## Its owner polls it from a frame ([method poll]), lands each change ([member apply]) and shows what [signal changed] says.
## One conversation a folder is live at a time ([method at]): a panel built again (a card attached, a format picked) is handed
## the one already talking, turn under way and all, and binds its own text to it. An owner leaving lets go ([method let_go]):
## a turn whose text nobody holds a moment later is stopped.
## A turn: `{you, agent, model, effort, at, events: [{said} | {tool, old, new, count, words}], reply, usage, error, running}`.

## Something to show: a turn begun, a word said, a change made, a turn ended or the conversation started again.
signal changed

const FILE := "chat.json"
const VERSION := 1
## The most of the conversation so far a new session is told ([method replay]), newest kept: turns, and characters a turn.
const REPLAY_TURNS := 16
const REPLAY_CHARS := 2400
## Past this share of the lines, or this many characters, a hand's change is told as the whole text ([method changed_part]).
const REWRITTEN_SHARE := 0.6
const REWRITTEN_CHARS := 6000

## The conversation's folder: `chat.json`, the turns' runs, and the CLI's working folder.
var dir := ""
## The text as it stands: `func() -> String`.
var read_text: Callable
## A change to land in it: `func(at: int, gone: int, put: String)` ([member TextTools.apply]).
var apply: Callable
## The note's words, for a text beside them (the Direction): `func() -> String`; unset for the Body.
var read_note: Callable
## What the writer is told it works on: `func() -> Dictionary`, the system prompt's names and flags
## (rules/agents/refine.yaml `system`) and `title`.
var about: Callable
## The rules the writer is told by: a file with `system`, `first` and `turn` taking refine.yaml's names (a sound's designer
## has its own, rules/sound/designer.yaml).
var rules := "agents/refine"
## The tools served beside the text's own: `func(text: TextTools) -> Object`, a toolset ([AgentTools]) that answers the
## text's tools through [param text] and adds its own; unset, the text's tools alone.
var toolset: Callable

var turns: Array = []
## The writer picked last for this conversation: `{agent, model, effort}`, {} for none yet.
var pick := {}
## The CLI session the conversation is in: `{agent, id}`, {} for none.
var session := {}
## The text as the writer last saw it, to tell it what a hand changed since.
var seen := ""

var _job := ""
var _url := ""
var _tools: TextTools = null
var _said_n := 0
var _resumed := false
var _retried := false

## folder -> the conversation live there.
static var _live := {}


## The conversation kept in [param folder]: the one live there, else read from its file if it has one.
static func at(folder: String) -> WriterChat:
	var key := ProjectSettings.globalize_path(folder)
	if _live.has(key):
		return _live[key]
	var c := WriterChat.new()
	c.dir = folder
	c.load()
	_live[key] = c
	return c


## The conversation live in [param folder] now, null for none: what a panel built again takes up, reading nothing.
static func live(folder: String) -> WriterChat:
	return _live.get(ProjectSettings.globalize_path(folder))


## The owner holding the text is going: a turn under way is stopped unless another binds the text within a moment (a panel
## built again does in the same frame).
func let_go() -> void:
	if not busy():
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	await tree.create_timer(1.5).timeout
	if busy() and not read_text.is_valid():
		stop()
		poll()


func load() -> void:
	var p := dir.path_join(FILE)
	if dir.is_empty() or not FileAccess.file_exists(p):
		return
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(p)) != OK or not (j.data is Dictionary) or int((j.data as Dictionary).get("version", 0)) != VERSION:
		return
	var d: Dictionary = j.data
	turns = d.get("turns", []) if d.get("turns") is Array else []
	pick = d.get("pick", {}) if d.get("pick") is Dictionary else {}
	session = d.get("session", {}) if d.get("session") is Dictionary else {}
	seen = String(d.get("seen", ""))
	for t in turns:
		if t is Dictionary and bool((t as Dictionary).get("running", false)):
			(t as Dictionary)["running"] = false
			(t as Dictionary)["error"] = "stopped when Ghost Notes closed"


## Written whole, by rename, so a crash leaves the last one. "" once written, else why not.
func save() -> String:
	if dir.is_empty():
		return "no folder to keep it in"
	DirAccess.make_dir_recursive_absolute(dir)
	var p := dir.path_join(FILE)
	var err := TextGen.put(p + ".part", JSON.stringify({"version": VERSION, "pick": pick, "session": session, "seen": seen,
		"turns": turns}, "\t"))
	if err.is_empty() and DirAccess.rename_absolute(p + ".part", p) != OK:
		err = "could not keep the conversation"
	return err


## Whether a turn is under way.
func busy() -> bool:
	return not _job.is_empty()


## What the writer is doing now, as a status line; "" between turns.
func activity() -> String:
	return AgentJobs.activity(_job) if busy() else ""


## The author's [param message] sent to the writer [param chosen] (`{agent, model, effort}`). "" once sent, else why not.
func send(message: String, chosen: Dictionary) -> String:
	if busy():
		return "the writer is still at work"
	var said := message.strip_edges()
	if said.is_empty():
		return "say what to change first"
	var agent := String(chosen.get("agent", ""))
	if not TextGen.has(agent):
		return "pick a writer first"
	var gen := TextGen.make(agent)
	if not gen.available():
		return "%s is not installed" % Registry.label(TextGen.REGISTRY, agent)
	pick = {"agent": agent, "model": String(chosen.get("model", "")), "effort": String(chosen.get("effort", ""))}
	var earlier := turns.duplicate()
	var text := String(read_text.call()) if read_text.is_valid() else ""
	var tools := gen.takes_tools()
	var info: Dictionary = about.call() if about.is_valid() else {}
	_resumed = gen.sessions() and String(session.get("agent", "")) == agent and not String(session.get("id", "")).is_empty()
	var prompt := turn_message(seen, text, said, rules) if _resumed else \
		first_message(info, text, said, replay(earlier), String(read_note.call()) if read_note.is_valid() else "", rules)
	var turn := {"you": said, "agent": agent, "model": pick["model"], "effort": pick["effort"], "at": int(Time.get_unix_time_from_system()),
		"events": [], "reply": "", "usage": {}, "error": "", "running": true}
	var run := dir.path_join("turns").path_join("%d_%d" % [int(Time.get_unix_time_from_system()), turns.size() + 1])
	var spec := {"kind": "text", "backend": agent, "tier": "best", "dir": ProjectSettings.globalize_path(run),
		"cwd": ProjectSettings.globalize_path(dir), "system": system_of(info, tools, rules), "prompt": prompt,
		"label": "refine %s" % String(info.get("what", "text")), "model": pick["model"], "effort": pick["effort"]}
	if gen.sessions():
		spec["session"] = {"id": String(session["id"]) if _resumed else AssistantBackends.new_session_id(), "resume": _resumed}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	if tools:
		# through this conversation, so a panel built again mid-turn is the one changed
		_tools = TextTools.new()
		_tools.read_text = func() -> Variant: return read_text.call() if read_text.is_valid() else null
		_tools.apply = func(where: int, gone: int, put: String) -> void:
			if apply.is_valid():
				apply.call(where, gone, put)
		if read_note.is_valid():
			_tools.read_note = func() -> String: return String(read_note.call()) if read_note.is_valid() else ""
		_tools.calling = func() -> void: _take_said(AgentJobs.said(_job, true))
		_tools.changed = _changed_by_writer
		_url = AgentTools.open(String(spec["dir"]), toolset.call(_tools) if toolset.is_valid() else _tools)
		if _url.is_empty():
			return "this session cannot serve the writer its tools"
		spec["tools_url"] = _url
	_job = AgentJobs.submit(spec)
	if _job.is_empty():
		_close_tools()
		return "this session cannot start agents"
	_said_n = 0
	turns.append(turn)
	save()
	changed.emit()
	return ""


## The turn under way given up: it ends as stopped, and whatever it changed stays (each change can be taken back).
func stop() -> void:
	if busy():
		AgentJobs.cancel(_job)


## The conversation started again: its turns and its session let go, the next turn a new session.
func clear() -> void:
	stop()
	poll()
	turns.clear()
	session = {}
	seen = ""
	_retried = false
	save()
	changed.emit()


## A frame's look at the turn under way: what the writer said since, and the turn landed once it ends.
func poll() -> void:
	if not busy():
		return
	var st := AgentJobs.state(_job)
	if st == "queued" or st == "running":
		_take_said(AgentJobs.said(_job))
		return
	var res := AgentJobs.result(_job)
	AgentJobs.forget(_job)
	_job = ""
	_take_said(res.get("said", []) if res.get("said") is Array else [])
	_close_tools()
	_land(res)


func _land(res: Dictionary) -> void:
	var turn: Dictionary = turns.back()
	turn["running"] = false
	var ok := bool(res.get("ok", false))
	var events: Array = turn["events"]
	if not ok and _resumed and not _retried and events.is_empty() and String(res.get("error", "")) != "cancelled":
		# the session could not be resumed: a new one, told the conversation so far
		turns.pop_back()
		session = {}
		_retried = true
		var why := send(String(turn["you"]), {"agent": turn["agent"], "model": turn["model"], "effort": turn["effort"]})
		if why.is_empty():
			return
		turns.append(turn)
		res = {"ok": false, "error": why}
	_retried = false
	if ok:
		var reply := String(res.get("text", "")).strip_edges()
		if _tools == null and not TextGen.make(String(turn["agent"])).takes_tools():
			var parts := split_reply(reply)
			if parts["text"] != null:
				var now := String(read_text.call()) if read_text.is_valid() else ""
				if apply.is_valid() and String(parts["text"]) != now:
					apply.call(0, now.length(), String(parts["text"]))
					events.append({"tool": "write", "words": String(parts["text"]).split(" ", false).size()})
			reply = String(parts["said"])
		if not events.is_empty() and (events.back() as Dictionary).has("said") and String((events.back() as Dictionary)["said"]).strip_edges() == reply:
			events.pop_back()
		turn["reply"] = reply
		turn["usage"] = res.get("usage", {}) if res.get("usage") is Dictionary else {}
		var sid := String(res.get("session", ""))
		session = {"agent": turn["agent"], "id": sid} if not sid.is_empty() else {}
	else:
		var err := String(res.get("error", ""))
		turn["error"] = "stopped" if err == "cancelled" else (err if not err.is_empty() else "the writer gave no answer")
		if String(res.get("session", "")).is_empty() and not _resumed:
			session = {}
	if ok or _tools_changed(events):
		seen = String(read_text.call()) if read_text.is_valid() else seen
	save()
	changed.emit()


func _tools_changed(events: Array) -> bool:
	for e in events:
		if (e as Dictionary).has("tool"):
			return true
	return false


func _take_said(said: Array) -> void:
	if turns.is_empty() or said.size() <= _said_n:
		return
	var events: Array = (turns.back() as Dictionary)["events"]
	for i in range(_said_n, said.size()):
		events.append({"said": String(said[i])})
	_said_n = said.size()
	changed.emit()


func _changed_by_writer(entry: Dictionary) -> void:
	if turns.is_empty():
		return
	((turns.back() as Dictionary)["events"] as Array).append(entry)
	changed.emit()


func _close_tools() -> void:
	if not _url.is_empty():
		AgentTools.close(_url)
	_url = ""
	_tools = null


# --- what the writer is told, pure for the gate ----------------------------------------------------------------------

## The system prompt, fixed for the conversation: [param info] is [member about]'s, [param tools] whether the writer edits
## with tools or answers with the text, [param from] the rules ([member rules]).
static func system_of(info: Dictionary, tools: bool, from := "agents/refine") -> String:
	var vars := {"what": "the note's words", "title": "", "direction": false, "brief": false, "script": false, "parts": [],
		"marks": [], "tools": tools}
	vars.merge(info, true)
	vars["has_parts"] = not (vars["parts"] as Array).is_empty()
	vars["has_marks"] = not (vars["marks"] as Array).is_empty()
	vars["tools"] = tools
	return Rules.say(from + ".system", vars)


## A first turn's message: the note a Direction stands beside ([param note]), the conversation so far for a session started
## again ([param earlier], [method replay]'s), the text whole, and the author's words.
static func first_message(info: Dictionary, text: String, message: String, earlier := "", note := "", from := "agents/refine") -> String:
	return Rules.say(from + ".first", {"title": String(info.get("title", "")), "has_note": not note.strip_edges().is_empty(),
		"note": note.strip_edges(), "has_replay": not earlier.is_empty(), "replay": earlier, "has_text": not text.strip_edges().is_empty(),
		"text": text, "message": message})


## A resumed turn's message: what a hand changed since the writer saw [param was] ([method changed_part]), and the author's words.
static func turn_message(was: String, now: String, message: String, from := "agents/refine") -> String:
	var ch := changed_part(was, now)
	return Rules.say(from + ".turn", {"has_change": ch.has("was"), "was": String(ch.get("was", "")), "now": String(ch.get("now", "")),
		"rewritten": ch.has("text"), "text": String(ch.get("text", "")), "message": message})


## What changed between [param was] and [param now], by lines: {} for nothing; `{was, now}` - the lines that changed with one
## line round them; or `{text}` - [param now] whole, where most of it changed. Lines are compared from each end, so a run of
## changes is told as one span from the first to the last.
static func changed_part(was: String, now: String) -> Dictionary:
	if was == now:
		return {}
	var a := was.split("\n")
	var b := now.split("\n")
	var head := 0
	while head < a.size() and head < b.size() and a[head] == b[head]:
		head += 1
	var tail := 0
	while tail < a.size() - head and tail < b.size() - head and a[a.size() - 1 - tail] == b[b.size() - 1 - tail]:
		tail += 1
	var from := maxi(0, head - 1)
	var was_part := "\n".join(a.slice(from, mini(a.size(), a.size() - tail + 1)))
	var now_part := "\n".join(b.slice(from, mini(b.size(), b.size() - tail + 1)))
	var changed_lines := b.size() - tail - head
	if was.strip_edges().is_empty() or now_part.length() > REWRITTEN_CHARS \
			or (b.size() > 4 and float(changed_lines) > REWRITTEN_SHARE * float(b.size())):
		return {"text": now}
	return {"was": was_part, "now": now_part}


## The conversation so far, for a session that cannot be resumed: each turn's words and reply, newest [constant REPLAY_TURNS],
## each cut to [constant REPLAY_CHARS]; "" for none.
static func replay(earlier: Array) -> String:
	var out := PackedStringArray()
	for t in earlier.slice(maxi(0, earlier.size() - REPLAY_TURNS)):
		var d: Dictionary = t
		out.append("THE AUTHOR: " + String(d.get("you", "")).left(REPLAY_CHARS))
		var did := PackedStringArray()
		for e in d.get("events", []):
			if (e as Dictionary).has("tool"):
				did.append(String((e as Dictionary)["tool"]))
		var reply := String(d.get("reply", "")) if String(d.get("error", "")).is_empty() else "(stopped: %s)" % String(d["error"])
		out.append("YOU%s: %s" % [(" (%d change%s to the text)" % [did.size(), "" if did.size() == 1 else "s"]) if not did.is_empty() else "",
			reply.left(REPLAY_CHARS)])
	return "\n\n".join(out)


## A reply from a writer without tools: `{text}` - the new text between `<text>` tags, null where it gave none - and `said`,
## the rest.
static func split_reply(reply: String) -> Dictionary:
	var a := reply.find("<text>")
	var b := reply.rfind("</text>")
	if a < 0 or b < a:
		return {"text": null, "said": reply.strip_edges()}
	var inner := reply.substr(a + 6, b - a - 6)
	if inner.begins_with("\n"):
		inner = inner.substr(1)
	if inner.ends_with("\n"):
		inner = inner.left(-1)
	return {"text": inner, "said": (reply.left(a) + reply.substr(b + 7)).strip_edges()}
