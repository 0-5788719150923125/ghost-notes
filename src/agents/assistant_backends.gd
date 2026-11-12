extends RefCounted
class_name AssistantBackends

## AssistantBackends - the CLIs [Assistant] can dispatch a feedback note to, and everything that differs
## between them: how a run is launched, how it is resumed, and how its event stream reads.
##
## A registry, not a branch per call site: adding a backend as `if backend == ...` at each place invites a
## run being parsed as another CLI's stream, which fails silently.
##
## Everything here is pure (strings and dictionaries in and out), so tests/app/assistant_backend_check.gd
## drives it with recorded streams and no subprocess.
##
## The prompt is never in argv. [method argv] returns flags, ids and paths only; the prompt reaches the
## CLI on stdin (`claude -p` reads it there with no prompt argument, `codex exec -` by request) from a
## file [method Subprocess.start_redirected] feeds in, so no shell or Windows command-line quoting sees it.

## Key -> display label, the short `name` the agent picker shows, the [Deps] row that resolves its binary,
## and the `writer`: the [TextGen] row whose models and reasoning levels it offers, so the Assistant is
## chosen with the same agent, model and level a writer is ([AgentPick]). Keys are what `[assistant]
## backend` in ghost.cfg stores; "claude_cli" must not change, or every saved choice and entry stops resolving.
##
## A writer is an assistant only where its CLI is an agent that edits the working tree with tools of its
## own. Bedrock is not: the AWS CLI makes one `converse` call, with no tools and no loop.
const REGISTRY := {
	"claude_cli": {"label": "Claude Code CLI", "name": "Claude", "dep": "claude", "writer": "claude",
		"blurb": "Claude Code in this repository with its own tools and every permission, reading CLAUDE.md as an interactive session does. Uses the Claude Code login."},
	"codex_cli": {"label": "Codex CLI (OpenAI)", "name": "Codex", "dep": "codex", "writer": "codex",
		"blurb": "Codex in this repository with full access, no sandbox and no approvals. Uses the Codex login."},
	"grok_cli": {"label": "Grok Build CLI (xAI)", "name": "Grok", "dep": "grok", "writer": "grok",
		"blurb": "Grok Build in this repository with its own tools, every one approved. Uses the Grok login (grok login)."},
}
## The model when none is chosen, where the CLI's own would not be what the picker says: a writer's Claude
## "Default" is Opus (TextGen.Claude), while `claude -p` alone takes the author's own default.
const CLAUDE_DEFAULT := "opus"
## Codex's level when none is chosen: the writer's "Default (medium ...)".
const CODEX_EFFORT := "medium"

## An entry saved before backends were recorded was dispatched to Claude, the only backend there was.
const LEGACY := "claude_cli"


static func has(key: String) -> bool:
	return REGISTRY.has(key)


static func label(key: String) -> String:
	return String((REGISTRY.get(key, REGISTRY[LEGACY]) as Dictionary)["label"])


static func dep(key: String) -> String:
	return String((REGISTRY.get(key, REGISTRY[LEGACY]) as Dictionary)["dep"])


## The [TextGen] row whose models and levels [param key] offers.
static func writer(key: String) -> String:
	return String((REGISTRY.get(key, REGISTRY[LEGACY]) as Dictionary)["writer"])


## A fresh session id (a random UUID, version 4) for a CLI that is handed one rather than making its own.
static func new_session_id() -> String:
	var b := Crypto.new().generate_random_bytes(16)
	b[6] = (b[6] & 0x0f) | 0x40
	b[8] = (b[8] & 0x3f) | 0x80
	var h := b.hex_encode()
	return "%s-%s-%s-%s-%s" % [h.substr(0, 8), h.substr(8, 4), h.substr(12, 4), h.substr(16, 4), h.substr(20, 12)]


## The CLI's own argument vector for one run, the prompt excluded (it goes on stdin, or, for Grok, which
## reads no stdin, from the file it is in). [param session] is empty for a fresh run and the saved
## session/thread id for a resume or follow-up. [param run]: `model` and `effort` as the picker holds them
## ("" each: its "Default"), `prompt_path` (Grok) and `fresh` (Grok: the id a fresh run takes, so it is
## known before the run says it).
static func argv(key: String, bin: String, session: String, repo_root: String, run := {}) -> PackedStringArray:
	var a := PackedStringArray([bin])
	var model := String(run.get("model", ""))
	var effort := String(run.get("effort", ""))
	match key:
		"codex_cli":
			#`resume` is its own subcommand with a narrower flag set (no -C), so the launcher cd's into the repo
			#for every run.
			a.append("exec")
			if not session.is_empty():
				a.append_array(["resume", session])
			a.append_array(["--json", "--skip-git-repo-check",
				"--dangerously-bypass-approvals-and-sandbox",
				"-c", "model_reasoning_effort=" + (effort if not effort.is_empty() else CODEX_EFFORT)])
			if not model.is_empty():
				a.append_array(["-m", model])
			if session.is_empty():
				a.append_array(["-C", repo_root])
			a.append("-")         # the prompt: read it from stdin
		"grok_cli":
			#Claude Code's own stream format (`streaming-messages-json`), so it reads as Claude's does
			a.append_array(["--prompt-file", String(run.get("prompt_path", "")), "--cwd", repo_root,
				"--always-approve", "--output-format", "streaming-messages-json"])
			if not model.is_empty():
				a.append_array(["-m", model])
			if not effort.is_empty():
				a.append_array(["--effort", effort])
			if not session.is_empty():
				a.append_array(["--resume", session])
			elif not String(run.get("fresh", "")).is_empty():
				a.append_array(["-s", String(run["fresh"])])
		_:
			#The level is left out when none is chosen: --effort has no "auto", and unset it takes the author's
			#own. stream-json needs --verbose alongside -p.
			a.append_array(["-p", "--model", model if not model.is_empty() else CLAUDE_DEFAULT])
			if not effort.is_empty():
				a.append_array(["--effort", effort])
			a.append_array(["--dangerously-skip-permissions", "--output-format", "stream-json", "--verbose"])
			if not session.is_empty():
				a.append_array(["--resume", session])
	return a


## The session/thread id an event carries, or "".
static func session_of(key: String, evt: Dictionary) -> String:
	match key:
		"codex_cli":
			if String(evt.get("type", "")) == "thread.started":
				return str(evt.get("thread_id", ""))
			return ""
		_:
			return str(evt.get("session_id", "")) if evt.has("session_id") else ""


## Dig an id out of raw captured text, for a run whose id was never saved: the first that is not empty
## (Grok's opening event carries an empty one).
static func recover_session(key: String, text: String) -> String:
	var k := "\"thread_id\":\"" if key == "codex_cli" else "\"session_id\":\""
	var i := text.find(k)
	while i >= 0:
		i += k.length()
		var j := text.find("\"", i)
		if j > i:
			return text.substr(i, j - i)
		i = text.find(k, i)
	return ""


## One event -> a short "what is it doing now" line, or "" for events not worth showing.
static func describe(key: String, evt: Dictionary) -> String:
	match key:
		"codex_cli":
			var t := String(evt.get("type", ""))
			if t != "item.started" and t != "item.completed":
				return ""
			var item: Dictionary = evt.get("item", {})
			match String(item.get("type", "")):
				"command_execution":
					return "shell  " + _clip(String(item.get("command", "")), 55)
				"agent_message":
					var s := String(item.get("text", "")).strip_edges()
					return _clip(s, 70) if not s.is_empty() else ""
				"file_change":
					return "edit  " + _clip(_file_change_paths(item), 55)
				"reasoning":
					return "thinking…"
				"error":
					return "⚠ " + _clip(String(item.get("message", "")), 65)
				"":
					return ""
				var other:
					return String(other)
			return ""
		_:
			if String(evt.get("type", "")) != "assistant":
				return ""
			var blocks: Array = evt.get("message", {}).get("content", [])
			for b in blocks:
				if String(b.get("type", "")) == "tool_use":
					var input: Dictionary = b.get("input", {})
					var hint := ""
					for k in ["file_path", "command", "pattern", "path", "prompt"]:
						if input.has(k):
							hint = String(input[k])
							break
					hint = _clip(hint, 55)
					return "%s  %s" % [String(b.get("name", "tool")), hint] if hint != "" else String(b.get("name", "tool"))
			for b in blocks:
				if String(b.get("type", "")) == "text":
					var t := String(b.get("text", "")).strip_edges()
					if t != "":
						return _clip(t, 70)
			return "thinking…"


## The outcome of a finished run, from every event it wrote: `{ok, response, session, cost_usd, usage}`;
## `usage` is the line shown under a done entry (dollars for Claude, tokens for Codex, which reports no price).
static func result(key: String, events: Array) -> Dictionary:
	var out := {"ok": false, "response": "", "session": "", "cost_usd": 0.0, "usage": "", "error": ""}
	match key:
		"codex_cli":
			var last_msg := ""
			var completed := false
			var tokens := {}
			for e in events:
				var evt: Dictionary = e
				match String(evt.get("type", "")):
					"thread.started":
						out.session = str(evt.get("thread_id", ""))
					"item.completed":
						var item: Dictionary = evt.get("item", {})
						if String(item.get("type", "")) == "agent_message":
							last_msg = String(item.get("text", ""))
					"turn.completed":
						completed = true
						var u: Dictionary = evt.get("usage", {})
						for k in u:
							tokens[k] = int(tokens.get(k, 0)) + int(u[k])
					"turn.failed":
						completed = false
						out.error = str((evt.get("error", {}) as Dictionary).get("message", "turn failed")) \
							if evt.get("error") is Dictionary else "turn failed"
					"error":
						out.error = str(evt.get("message", "error"))
			out.response = last_msg
			#A top-level `error` is not by itself a failure (the CLI also reports stream retries that way);
			#`turn.failed` is, and clears `completed` as the last word on the turn.
			out.ok = completed and last_msg != ""
			if out.ok:
				out.error = ""
			if not tokens.is_empty():
				out.usage = "%s in (%s cached) · %s out" % [_k(int(tokens.get("input_tokens", 0))),
					_k(int(tokens.get("cached_input_tokens", 0))), _k(int(tokens.get("output_tokens", 0)))]
		_:
			#Claude Code's stream, and Grok's in the same format: its result may carry no `result` text (the last
			#thing it said is the reply then), and says what went wrong in `errors`
			var parsed: Dictionary = {}
			var last_text := ""
			for e in events:
				var evt: Dictionary = e
				if out.session == "" and String(evt.get("session_id", "")) != "":
					out.session = str(evt.get("session_id", ""))
				match String(evt.get("type", "")):
					"result":
						parsed = evt
					"assistant":
						for blk in (evt.get("message", {}) as Dictionary).get("content", []):
							if blk is Dictionary and String(blk.get("type", "")) == "text" \
									and not String(blk.get("text", "")).strip_edges().is_empty():
								last_text = String(blk["text"])
			if not parsed.is_empty() and parsed.get("is_error", true) == false \
					and (parsed.has("result") or not last_text.is_empty()):
				out.ok = true
				out.response = str(parsed.get("result", last_text))
				if String(parsed.get("session_id", "")) != "":
					out.session = str(parsed["session_id"])
				out.cost_usd = float(parsed.get("total_cost_usd", 0.0))
				out.usage = "$%.3f" % out.cost_usd
			elif parsed.get("errors") is Array and not (parsed["errors"] as Array).is_empty():
				out.error = "; ".join(PackedStringArray((parsed["errors"] as Array).map(func(x: Variant) -> String: return str(x))))
	return out


## Every complete JSON object line in [param text], quietly - see Assistant._json_object.
static func events_in(text: String) -> Array:
	var out: Array = []
	for line in text.split("\n"):
		var e = json_object(line.strip_edges())
		if e is Dictionary:
			out.append(e)
	return out


## The lines of a run's stream finished since byte [param offset], for a reader tailing it while it is
## written: `{lines, offset}`, where `offset` is past the last line end. A line still being written waits
## for the next call. Reads bytes from the offset, not get_as_text() (which reads from the start whatever
## the seek, and a String index is not a byte count once the stream holds non-ASCII). A file shorter than
## [param offset] was replaced and is read from its start.
static func lines_since(path: String, offset: int) -> Dictionary:
	var fa := FileAccess.open(path, FileAccess.READ)
	if fa == null:
		return {"lines": PackedStringArray(), "offset": offset}
	var total := fa.get_length()
	if offset > total:
		offset = 0                       # shorter than what was read: a new file, from its start
	var none := {"lines": PackedStringArray(), "offset": offset}
	if offset >= total:
		return none
	fa.seek(offset)
	var chunk := fa.get_buffer(total - offset)
	fa.close()
	var last_nl := chunk.rfind(10)
	if last_nl < 0:
		return none
	return {"lines": chunk.slice(0, last_nl).get_string_from_utf8().split("\n"),
		"offset": offset + last_nl + 1}


static func json_object(line: String) -> Variant:
	if not line.begins_with("{"):
		return null
	var json := JSON.new()
	if json.parse(line) != OK:
		return null
	return json.data


static func _clip(s: String, n: int) -> String:
	return s.substr(0, n) + "…" if s.length() > n else s


static func _k(n: int) -> String:
	return ("%.1fk" % (n / 1000.0)) if n >= 1000 else str(n)


static func _file_change_paths(item: Dictionary) -> String:
	var paths := PackedStringArray()
	for c in item.get("changes", []):
		if c is Dictionary:
			paths.append(String((c as Dictionary).get("path", "")).get_file())
	return ", ".join(paths)


# --- which assistant runs ------------------------------------------------------------------------
# The home screen's until step 8; the Assistant's own panel holds the picker (step 4).

## The picker's keys, in its order: "" (Off), then every row of [constant REGISTRY].
static func picker_keys() -> Array:
	return [""] + REGISTRY.keys()


## The assistant CLIs this machine has, in registry order - asked of the same resolver a dispatch
## launches through.
static func installed() -> Array:
	return REGISTRY.keys().filter(func(k: String) -> bool: return Deps.has(dep(k)))


## The persisted choice as the picker shows it ("" = Off, else a row of [constant REGISTRY]), installed or
## not - read from the Settings autoload by name so this file compiles under a bare `--script` and answers
## in a Masking session from `--mask-edit`.
static func choice() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return ""
	var st := tree.root.get_node_or_null("Settings")
	return String(st.read("assistant", "backend", "")) if st != null else ""


## The assistant that can actually run: the choice, when its CLI is installed; "" (Off) otherwise.
## Whatever dispatches a note or offers to (the console's Ask box, the feedback list's Send) asks this, so
## a missing CLI is never offered. [method gap] says why.
static func runnable() -> String:
	return choice() if gap().is_empty() else ""


## Why no note can be sent, "" when one can: no AI assistant installed, none chosen, or the chosen
## one's CLI missing. One lower-case clause, for whatever says so.
static func gap() -> String:
	var have := installed()
	if have.is_empty():
		return "no AI assistant is installed"
	var chosen := choice()
	if not has(chosen):
		return "no assistant is chosen in the 💬 panel"
	if not have.has(chosen):
		return "%s is not installed" % label(chosen)
	return ""

