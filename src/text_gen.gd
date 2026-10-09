extends RefCounted
class_name TextGen

## TextGen - who writes the words. The text counterpart of [ImageGen].
##
## A backend turns ONE system prompt plus ONE prompt into ONE reply on disk. Everything above
## that - what is asked, what the reply is for, where it is kept - belongs to the caller (see
## [AgentJobs], which queues the work, and [CardProducer], which asks for it), so a second
## writer is a registry entry and a class here, never a branch at a call site.
##
## THE CONTRACT is [ImageGen]'s, all on the main thread (spawns go through [Subprocess], whose
## death pact is per-thread):
##
##   start(job)    - launch the work; return a pid (<= 0 is a failure, with job.error set)
##   resolve(job)  - after the pid exits: the reply text, or ""
##   failure(job)  - after an empty resolve: one line saying why
##
## `job` is a Dictionary the queue owns: {prompt, system, dir, tier, images}. `dir` is the job's
## own directory - the prompt, the system prompt, the reply and the log are all written there and
## KEPT, so what a writer was shown can always be read back afterwards.
##
## PICTURES go with the words when a caller has them: `images` is `[{path, label, flip}]`, each
## sent ahead of the prompt under its label (turned over when `flip` - a card that came up
## reversed is seen upside down), and listed at the top of `prompt.txt`, so the record says
## which pictures a writer was shown as plainly as which words.
##
## A WRITER, NOT AN AGENT - unless ghost hands it tools. A run works from its prompt alone: Claude
## is run with none of its own tools; Codex, whose `exec` keeps a read-only shell, is TOLD to work
## only from the message and never to open, list or read a file ([constant Codex.ONLY_THIS]) - the
## user's call (2026-10-04): asking is enough, agents follow it. Grok keeps `read_file` only when it
## has pictures to look at, and is told to open nothing else. Each run is also STATELESS (no
## session is kept or resumed) - a caller that wants a conversation sends the conversation, so
## every run's whole input is the prompt file beside its reply.
##
## GHOST'S TOOLS. A job carrying `tools_url` (an [AgentTools] endpoint) is run as an agent whose
## ONLY tools are the ones ghost serves there - it calls them, sees what they return, and works in
## that loop until it is done; every call is kept beside its prompt (`tools.jsonl`). A backend that
## can take them says so ([method Backend.takes_tools]); one that cannot is asked the one-shot way.
##
## THE PROMPT IS NEVER IN ARGV, for the reason [AssistantBackends] gives: it reaches the CLI on
## stdin from a file, and the system prompt from a file the CLI reads itself.

## A picture is sent no larger than this on its long edge: enough to see what is painted, and a
## fraction of the tokens of the painter's full size.
const PICTURE_EDGE := 768

## Keys are what `ghost: cards: writer` (and anything else that asks for words) stores.
const REGISTRY := {
	"claude": Claude,
	"codex": Codex,
	"grok": Grok,
	"bedrock": Bedrock,
}

const LABELS := {
	"claude": "Claude (Claude Code CLI)",
	"codex": "OpenAI (Codex CLI)",
	"grok": "xAI (Grok Build CLI)",
	"bedrock": "Amazon Bedrock (AWS CLI)",
}

## One string literal per entry, for a picker's tooltip - same rule as Medium.BLURBS.
const BLURBS := {
	"claude": "Anthropic's models through the Claude Code CLI, run with no tools and no project context. Uses the Claude Code login.",
	"codex": "OpenAI's models through the Codex CLI, run read-only in the job's own folder and told to work only from the message it is given - and Ghost Notes' tools where a job serves them, as the card table's set dresser does. Uses the Codex login.",
	"grok": "xAI's Grok models through the Grok Build CLI, with ghost's own system prompt, none of its own tools but reading the pictures it is sent - and Ghost Notes' tools where a job serves them, as the card table's set dresser does - no memory, and none of the setup it would borrow from Claude, Cursor or Codex. Uses the Grok login.",
	"bedrock": "Models on Amazon Bedrock - Amazon's own Nova by default, and the open models Bedrock hosts - through the AWS CLI with your AWS credentials and region (aws configure). Billed per token to your AWS account; a model from another provider may subscribe the account to it through AWS Marketplace on first use.",
}

## THE TIER is what a caller asks for instead of a model name: `best` for words somebody will
## hear or read, `fast` for structured bookkeeping nobody sees verbatim. Each backend maps it to
## its own models, so a caller never learns one.
const TIERS := ["best", "fast"]


## Build the backend for [param key], falling back to the first entry for an unknown one: a
## stale document must never leave a caller without a writer.
static func make(key: String) -> Backend:
	var cls: Variant = REGISTRY.get(key, REGISTRY[REGISTRY.keys()[0]])
	return cls.new()


static func has(key: String) -> bool:
	return REGISTRY.has(key)


## THE JSON IN A REPLY, leniently. A writer asked for "only a JSON object" still sometimes
## fences it, or says a word first; neither should cost a run. Takes the outermost object (or
## array) in [param text], with code fences ignored. null when there is none that parses.
static func extract_json(text: String) -> Variant:
	var t := text.strip_edges()
	if t.begins_with("```"):
		var nl := t.find("\n")
		t = t.substr(nl + 1) if nl >= 0 else ""
		var close := t.rfind("```")
		if close >= 0:
			t = t.substr(0, close)
	for pair in [["{", "}"], ["[", "]"]]:
		var a := t.find(String(pair[0]))
		var b := t.rfind(String(pair[1]))
		if a < 0 or b <= a:
			continue
		var j := JSON.new()
		if j.parse(t.substr(a, b - a + 1)) == OK:
			return j.data
	return null


## A picture as a writer is sent it: no larger than [constant PICTURE_EDGE], turned over when
## [param flip]; null when it cannot be read.
static func picture(path: String, flip := false) -> Image:
	var img := Image.load_from_file(path) if FileAccess.file_exists(path) else null
	if img == null or img.is_empty():
		return null
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGB8)
	var edge := maxi(img.get_width(), img.get_height())
	if edge > PICTURE_EDGE:
		var k := float(PICTURE_EDGE) / float(edge)
		img.resize(maxi(1, roundi(img.get_width() * k)), maxi(1, roundi(img.get_height() * k)),
			Image.INTERPOLATE_LANCZOS)
	if flip:
		img.rotate_180()
	return img


## [method picture] as a message content block (a JPEG, base64); empty when it cannot be read.
static func image_block(path: String, flip := false) -> Dictionary:
	var img := picture(path, flip)
	if img == null:
		return {}
	return {"type": "image", "source": {"type": "base64", "media_type": "image/jpeg",
		"data": Marshalls.raw_to_base64(img.save_jpg_to_buffer(0.9))}}


## The record of which pictures went with a prompt: one line each, ahead of the prompt.
static func picture_line(d: Dictionary) -> String:
	return "[picture: %s%s - %s]" % [String(d.get("label", "")).trim_suffix(":"),
		" (turned over, as it lies)" if bool(d.get("flip", false)) else "", String(d.get("path", "")).get_file()]


## Write [param text] to [param path], creating the directory. "" on success, else why not.
static func put(path: String, text: String) -> String:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return "could not write " + path
	f.store_string(text)
	f.close()
	return ""


## The base every backend extends. It does nothing; a backend that forgets a method fails
## visibly (no pid, no reply) rather than silently.
## A picker's efforts: [param dflt] (key "") first, then each of [param levels].
static func effort_list(levels: Array, dflt := "Default") -> Array:
	var out: Array = [{"key": "", "label": dflt}]
	for e in levels:
		out.append({"key": String(e), "label": TextGen.effort_label(String(e))})
	return out


## An effort level as a person reads it.
static func effort_label(key: String) -> String:
	return String({"minimal": "Minimal", "low": "Low", "medium": "Medium", "high": "High",
		"xhigh": "Extra high", "max": "Max", "ultra": "Ultra"}.get(key, key.capitalize()))


# --- what an agent is doing now ---------------------------------------------------------------
#
# A run of many minutes showed nothing but its glyph, and a person could not tell a model thinking
# from one stuck (the user, 2026-10-09: "so we know if agents are thinking, or writing, or looking,
# or whatever. So we know they aren't stuck"). Every backend that writes a stream reads it here as it
# grows, into `job["_now"]`: {doing, tokens (thought, estimated), chars (written), heard (when the
# stream last grew)}; [method AgentJobs.activity] makes the line a status shows.

## The events [param path] has gained since this was last asked for [param job], as objects: the
## lines finished since, read from a byte offset kept in the job (see [method
## AssistantBackends.lines_since]), so a stream of thousands of lines is never read twice.
static func new_events(job: Dictionary, path: String) -> Array:
	var seen: Dictionary = job.get("_seen", {})
	var got := AssistantBackends.lines_since(path, int(seen.get(path, 0)))
	seen[path] = int(got["offset"])
	job["_seen"] = seen
	var out: Array = []
	for line in got["lines"]:
		var e: Variant = AssistantBackends.json_object(String(line).strip_edges())
		if e is Dictionary:
			out.append(e)
	return out


## The job's state as last read, made if it has none: what it is doing, and how much it has thought
## and written. [param idle] is what it is doing before its stream says.
static func now_of(job: Dictionary, idle := "starting") -> Dictionary:
	if not (job.get("_now") is Dictionary):
		job["_now"] = {"doing": idle, "tokens": 0, "chars": 0, "heard": 0}
	return job["_now"]


## [param path]'s new events read into the job's state by [param read] (`func(now, event)`), and
## when the stream last grew. The state.
static func follow(job: Dictionary, path: String, read: Callable, idle := "starting") -> Dictionary:
	var now := TextGen.now_of(job, idle)
	for e in TextGen.new_events(job, path):
		read.call(now, e)
	if FileAccess.file_exists(path):
		now["heard"] = int(FileAccess.get_modified_time(path))
	return now


## A tool as a person reads it: `mcp__ghost__look` and `ghost__look` are "look".
static func tool_name(name: String) -> String:
	return name.get_slice("__", name.get_slice_count("__") - 1) if name.contains("__") else name


## THE STATUS LINE: what the agent is doing, how much it has thought or written, for how long, and -
## past [param quiet_after] seconds with nothing new on a stream that should be growing - how long
## it has said nothing. "thinking (~11K tokens) · 6:30".
static func activity_line(now: Dictionary, elapsed: int, quiet := 0, quiet_after := 180) -> String:
	var doing := String(now.get("doing", "working"))
	var line := doing
	if doing == "thinking" and int(now.get("tokens", 0)) > 0:
		line += " (~%s tokens)" % TextGen.count(int(now["tokens"]))
	elif doing == "writing" and int(now.get("chars", 0)) > 0:
		line += " (%s characters)" % TextGen.count(int(now["chars"]))
	line += " · " + TextGen.clock(elapsed)
	if quiet >= quiet_after:
		line += " · nothing new for %s" % TextGen.clock(quiet)
	return line


## A RUNNING JOB'S STATUS LINE ([method activity_line]) from its backend's `activity`, read again
## at most once a second: a row redrawn four times a second must not reparse a stream that often.
static func status_of(job: Dictionary) -> String:
	var t := int(Time.get_unix_time_from_system())
	if int(job.get("_status_at", -1)) != t or not job.has("_status"):
		job["_status_at"] = t
		var gen: Variant = job.get("gen")
		var now: Dictionary = gen.activity(job) if gen is Object and (gen as Object).has_method("activity") \
			else TextGen.now_of(job, "working")
		var heard := int(now.get("heard", 0))
		var quiet := t - heard if heard > 0 and String(now.get("doing", "")) != "finishing" else 0
		job["_status"] = TextGen.activity_line(now, t - int(job.get("started", t)), quiet)
	return String(job["_status"])


## 950, 1.2K, 11K.
static func count(n: int) -> String:
	if n < 1000:
		return str(n)
	return ("%.1fK" % (n / 1000.0)) if n < 10000 else "%dK" % int(round(n / 1000.0))


## 0:42, 6:30, 1:02:05.
static func clock(seconds: int) -> String:
	var s := maxi(seconds, 0)
	if s >= 3600:
		return "%d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]
	return "%d:%02d" % [s / 60, s % 60]


class Backend:
	extends RefCounted

	func available() -> bool:
		return false

	## Whether a job's `tools_url` reaches this writer as tools it can call (see the class note).
	func takes_tools() -> bool:
		return false

	## The models a picker offers for this writer: `[{key, label}]`, the default (key "") first.
	static func models() -> Array:
		return [{"key": "", "label": "Default"}]

	## The reasoning efforts a picker offers for this writer running [param model]: `[{key, label}]`,
	## the writer's own default (key "") first - and alone when the writer takes no such setting.
	## A job's `effort` is one of the keys.
	static func efforts(_model := "") -> Array:
		return [{"key": "", "label": "Default"}]

	func start(_job: Dictionary) -> int:
		return -1

	func resolve(_job: Dictionary) -> String:
		return ""

	func failure(job: Dictionary) -> String:
		return String(job.get("error", "the writer produced nothing"))

	## A writer that works in steps starts the next one here once a step's process has ended, and
	## returns its pid; 0 when there is no next step (see [AgentJobs]).
	func advance(_job: Dictionary) -> int:
		return 0

	## WHAT THE WRITER IS DOING NOW (see "what an agent is doing now" above): its state, read off
	## what its run has written so far. A writer that writes no stream is "working".
	func activity(job: Dictionary) -> Dictionary:
		return TextGen.now_of(job, "working")

	## The files every backend writes into the job's directory, named once. `prompt` is the
	## record a person reads; `input` is exactly what the CLI was sent; `reply` is its output
	## stream and `last` its final message, where a backend writes one separately.
	static func paths(job: Dictionary) -> Dictionary:
		var dir := String(job["dir"])
		return {"prompt": dir.path_join("prompt.txt"), "system": dir.path_join("system.txt"),
			"input": dir.path_join("input.jsonl"), "reply": dir.path_join("reply.jsonl"),
			"last": dir.path_join("reply.txt"), "log": dir.path_join("stderr.log")}


## CLAUDE THROUGH THE CLAUDE CODE CLI, as a bare writer.
##
## `--safe-mode` leaves out everything the author has customized - CLAUDE.md, memory, skills,
## hooks, MCP servers, plugins, output styles - and `--system-prompt-file` replaces Claude
## Code's own agent prompt, so the model sees the two files and nothing else (measured: ~480
## input tokens for a one-line prompt). `--tools ""` takes every tool away, so a reply is
## words and only words. `--no-session-persistence`: nothing is resumed, see the class note.
## The message goes in as STREAM-JSON (one user message on stdin), the only input that carries
## pictures; the reply comes back as the stream's `result` event (`--verbose` is required with
## stream-json output). Measured with a picture attached: the tool list stays empty.
## `--bare` would be tighter still and is NOT used - it reads only ANTHROPIC_API_KEY, never the
## subscription login the rest of ghost's Claude runs use.
class Claude:
	extends Backend

	const MODELS := {"best": "opus", "fast": "sonnet"}
	## `--effort`'s levels, as the CLI names them when handed another. Unset, a run takes the
	## author's own Claude Code default for its model (see [method saved_effort]).
	const EFFORTS := ["low", "medium", "high", "xhigh", "max"]

	static func efforts(model := "") -> Array:
		var mine := Claude.saved_effort(model if not model.is_empty() else String(MODELS["best"]))
		return TextGen.effort_list(EFFORTS, "Default" + ((" (%s)" % TextGen.effort_label(mine)) if not mine.is_empty() else ""))

	## The effort the author's Claude Code keeps for a model ([param alias]: "opus", "sonnet"...):
	## `modelSettings.<model id>.effortLevel` in ~/.claude/settings.json, "" when it keeps none.
	static func saved_effort(alias: String) -> String:
		var ms: Variant = Provision.read_json(Deps.home().path_join(".claude/settings.json")).get("modelSettings", {})
		if ms is Dictionary:
			for id in ms as Dictionary:
				var d: Variant = (ms as Dictionary)[id]
				if String(id).contains(alias) and d is Dictionary and (d as Dictionary).has("effortLevel"):
					return str((d as Dictionary)["effortLevel"])
		return ""

	## Claude Code's own aliases - each the newest model of its family, so the list never goes
	## stale. "Default" is the tiers above: Opus for what is heard, Sonnet for the bookkeeping.
	static func models() -> Array:
		return [{"key": "", "label": "Default (Opus)"}, {"key": "fable", "label": "Fable"},
			{"key": "opus", "label": "Opus"}, {"key": "sonnet", "label": "Sonnet"}]

	## The model a job runs on: the one chosen for it, else its tier's.
	static func model_of(job: Dictionary) -> String:
		var chosen := String(job.get("model", ""))
		return chosen if not chosen.is_empty() else String(MODELS.get(String(job.get("tier", "best")), MODELS["best"]))

	func binary() -> String:
		var p := Deps.resolve("claude")
		return p if not p.is_empty() else "claude"

	func available() -> bool:
		return Deps.has("claude")

	func takes_tools() -> bool:
		return true

	func start(job: Dictionary) -> int:
		var p := Backend.paths(job)
		var m := Claude.compose(job)
		if not String(m["error"]).is_empty():
			job["error"] = m["error"]
			return -1
		for pair in [["prompt", m["shown"]], ["system", String(job.get("system", ""))], ["input", m["input"]]]:
			var err := TextGen.put(String(p[pair[0]]), String(pair[1]))
			if not err.is_empty():
				job["error"] = err
				return -1
		var tools := Claude.tool_args(job)
		if tools.is_empty() and not String(job.get("tools_url", "")).is_empty():
			job["error"] = "could not write the tools' config into " + String(job["dir"])
			return -1
		var pid := Subprocess.start_redirected(binary(), Claude.argv(job, String(p["system"]), tools), {"cwd": String(job["dir"]),
			"stdin": String(p["input"]), "out": String(p["reply"]), "err": String(p["log"])},
			"claude writer")
		if pid <= 0:
			job["error"] = "could not start claude (is the Claude Code CLI installed and logged in?)"
		return pid

	## Flags and paths only - the prompt is on stdin. [param tools]: [method tool_args]'s.
	##
	## NONE OF THE AUTHOR'S OWN SETUP: `--safe-mode`, which also drops every MCP server - ghost's
	## included (measured, CLI 2.1.291) - so a writer given ghost's tools loads no settings at all
	## instead (`--setting-sources ""`: no plugin, hook or memory; measured, it is shown no
	## CLAUDE.md), and the system prompt replaces Claude Code's either way.
	static func argv(job: Dictionary, system_path: String, tools: PackedStringArray) -> PackedStringArray:
		var args := PackedStringArray(["-p", "--model", Claude.model_of(job)])
		if not String(job.get("effort", "")).is_empty():
			args.append_array(["--effort", String(job["effort"])])
		args.append_array(PackedStringArray(["--setting-sources", ""]) if not tools.is_empty() else PackedStringArray(["--safe-mode"]))
		args.append_array(["--tools", "",
			"--system-prompt-file", system_path,
			"--input-format", "stream-json", "--output-format", "stream-json", "--verbose",
			"--include-partial-messages", "--no-session-persistence"])
		args.append_array(tools)
		return args

	## GHOST'S TOOLS for a job with a `tools_url`: the server named in a config file beside the
	## prompt (`mcp.json` - a path in argv, never the URL's token), no other server the author has
	## set up (`--strict-mcp-config`), and its tools allowed to run without asking - a print run has
	## nobody to ask. Claude's own tools stay off (`--tools ""`), so ghost's are the only ones. Empty
	## for a job without tools, or when the config cannot be written.
	static func tool_args(job: Dictionary) -> PackedStringArray:
		var url := String(job.get("tools_url", ""))
		if url.is_empty():
			return PackedStringArray()
		var cfg := String(job["dir"]).path_join("mcp.json")
		var err := TextGen.put(cfg, JSON.stringify({"mcpServers": {"ghost": {"type": "http", "url": url}}}, "\t"))
		if not err.is_empty():
			return PackedStringArray()
		return PackedStringArray(["--mcp-config", cfg, "--strict-mcp-config", "--allowedTools", "mcp__ghost"])

	## THE MESSAGE: each picture under its label, then the prompt - as the stream-json line the
	## CLI reads (`input`), and as the record a person reads (`shown`: the pictures listed, then
	## the prompt). `error` names a picture that could not be read: a writer told to talk about
	## a card it was never sent would make it up.
	static func compose(job: Dictionary) -> Dictionary:
		var content: Array = []
		var record := PackedStringArray()
		for im in job.get("images", []):
			var d: Dictionary = im
			var path := String(d.get("path", ""))
			var block := TextGen.image_block(path, bool(d.get("flip", false)))
			if block.is_empty():
				return {"error": "could not read the picture %s" % path.get_file(), "input": "", "shown": ""}
			var label := String(d.get("label", ""))
			if not label.is_empty():
				content.append({"type": "text", "text": label})
			content.append(block)
			record.append(TextGen.picture_line(d))
		var prompt := String(job.get("prompt", ""))
		content.append({"type": "text", "text": prompt})
		return {"error": "",
			"shown": ("\n".join(record) + "\n\n" + prompt) if not record.is_empty() else prompt,
			"input": JSON.stringify({"type": "user", "message": {"role": "user", "content": content}}) + "\n"}

	func resolve(job: Dictionary) -> String:
		var d: Variant = _reply(job)
		if not (d is Dictionary) or bool((d as Dictionary).get("is_error", false)):
			return ""
		return String((d as Dictionary).get("result", "")).strip_edges()

	func failure(job: Dictionary) -> String:
		var d: Variant = _reply(job)
		if d is Dictionary:
			var r := String((d as Dictionary).get("result", "")).strip_edges()
			if not r.is_empty():
				return r.substr(0, 240)
			return "claude ended %s" % String((d as Dictionary).get("subtype", "without a reply"))
		var err := FileAccess.get_file_as_string(String(Backend.paths(job)["log"])).strip_edges()
		if not err.is_empty():
			var lines := err.split("\n")
			return String(lines[lines.size() - 1]).substr(0, 240)
		return String(job.get("error", "claude finished without a reply"))

	## WHAT CLAUDE IS DOING, off its stream as it grows. Its text arrives as it is written only with
	## `--include-partial-messages` (measured: without it, a whole message at once, so a long reading
	## read as thinking until it was done); its thinking is counted by the CLI's own estimates.
	func activity(job: Dictionary) -> Dictionary:
		return TextGen.follow(job, String(Backend.paths(job)["reply"]), Claude.read)

	## One event of Claude Code's stream-json into [param now] (see [method TextGen.follow]).
	static func read(now: Dictionary, e: Dictionary) -> void:
		match String(e.get("type", "")):
			"system":
				if String(e.get("subtype", "")) == "thinking_tokens":
					now["doing"] = "thinking"
					now["tokens"] = int(now["tokens"]) + int(e.get("estimated_tokens_delta", 0))
			"stream_event":
				var ev: Dictionary = e["event"] if e.get("event") is Dictionary else {}
				var block: Dictionary = ev["content_block"] if ev.get("content_block") is Dictionary else {}
				var delta: Dictionary = ev["delta"] if ev.get("delta") is Dictionary else {}
				match String(block.get("type", delta.get("type", ""))):
					"thinking", "thinking_delta":
						now["doing"] = "thinking"
					"text", "text_delta":
						now["doing"] = "writing"
						now["chars"] = int(now["chars"]) + String(delta.get("text", "")).length()
					"tool_use":
						now["doing"] = "calling " + TextGen.tool_name(String(block.get("name", "a tool")))
			"user":
				now["doing"] = "thinking"          # a tool has answered: the model's turn again
			"result":
				now["doing"] = "finishing"

	## The stream's `result` event - the run's outcome - or null when it never came.
	static func _reply(job: Dictionary) -> Variant:
		var out: Variant = null
		for line in FileAccess.get_file_as_string(String(Backend.paths(job)["reply"])).split("\n"):
			var t := String(line).strip_edges()
			if not t.begins_with("{"):
				continue
			var j := JSON.new()
			if j.parse(t) == OK and j.data is Dictionary and String((j.data as Dictionary).get("type", "")) == "result":
				out = j.data
		return out


## OPENAI THROUGH THE CODEX CLI.
##
## `codex exec` has no system prompt of its own to replace, so the system prompt leads the
## message, after [constant ONLY_THIS]: an agent that keeps a shell is asked to work from the
## message alone. Read-only, in the job's own folder, `--ephemeral` so no session is kept, and
## `-o` names the file the final message is written to. Pictures go as `--image` files - each
## prepared the way Claude is sent it ([method TextGen.picture]) and saved beside the prompt -
## and the message says which is which. The tier is the reasoning effort; the model is the CLI's.
##
## GHOST'S TOOLS ([AgentTools]) are its server `ghost`, named in `-c mcp_servers.ghost.*` overrides: the
## bare endpoint in argv and the job's token read from an environment variable set for this run alone
## (`bearer_token_env_var`), so no argv holds it; its calls approved (`default_tools_approval_mode =
## "approve"`: `codex exec` never asks, and refused ghost's call with "requires approval, but approval
## policy is never"); and room for a slow one (`tool_timeout_sec`). A tool's picture reaches the model
## (measured, codex-cli 0.157.0: described rightly).
class Codex:
	extends Backend

	const EFFORT := {"best": "medium", "fast": "low"}
	## The environment variable a run with ghost's tools reads their token from.
	const TOKEN_ENV := "GHOST_TOOLS_TOKEN"
	## The longest one of ghost's tools may take, in seconds: `set` stands a whole table up and
	## photographs it, and Codex's own limit is a minute.
	const TOOL_TIMEOUT := 600

	## The models Codex offers this installation (see [method ImageGen.Codex.models]).
	static func models() -> Array:
		return ImageGen.Codex.models()

	## The levels Codex offers [param model]; unset, the tier's ([constant EFFORT]).
	static func efforts(model := "") -> Array:
		return TextGen.effort_list(ImageGen.Codex.levels(model), "Default (medium, low for designs)")

	## What an agent with tools is told before anything else.
	const ONLY_THIS := ("You are writing, not working: everything you need is in this message and the "
		+ "pictures attached to it. Do not run commands, and do not open, list or read any file - "
		+ "in this folder or anywhere else. Reply with the text asked for and nothing else.")

	func binary() -> String:
		var p := Deps.resolve("codex")
		return p if not p.is_empty() else "codex"

	func available() -> bool:
		return Deps.has("codex")

	func takes_tools() -> bool:
		return true

	func start(job: Dictionary) -> int:
		var p := Backend.paths(job)
		var m := Codex.compose(job)
		if not String(m["error"]).is_empty():
			job["error"] = m["error"]
			return -1
		for pic in m["pictures"]:
			var d: Dictionary = pic
			var img := TextGen.picture(String(d["from"]), bool(d["flip"]))
			if img == null or img.save_jpg(String(d["to"]), 0.9) != OK:
				job["error"] = "could not prepare the picture %s" % String(d["from"]).get_file()
				return -1
		var err := TextGen.put(String(p["prompt"]), String(m["prompt"]))
		if not err.is_empty():
			job["error"] = err
			return -1
		var url := String(job.get("tools_url", ""))
		var pid := Subprocess.start_redirected(binary(), Codex.argv(job, m["pictures"]),
			{"cwd": String(job["dir"]), "stdin": String(p["prompt"]), "out": String(p["reply"]),
			"err": String(p["log"]), "env": {TOKEN_ENV: AgentTools.token_of(url)} if not url.is_empty() else {}},
			"codex writer")
		if pid <= 0:
			job["error"] = "could not start codex (is the Codex CLI installed and logged in?)"
		return pid

	## THE MESSAGE: what an agent with tools is told first, the system prompt, which picture is
	## which, then the prompt - and the pictures to attach, `{from, flip, to}`, in that order.
	static func compose(job: Dictionary) -> Dictionary:
		var head := PackedStringArray([ONLY_THIS])
		if not String(job.get("tools_url", "")).is_empty():
			head.append(Rules.say("agents/codex.with_tools"))
		var sys := String(job.get("system", "")).strip_edges()
		if not sys.is_empty():
			head.append(sys)
		var pictures: Array = []
		var lines := PackedStringArray()
		for im in job.get("images", []):
			var d: Dictionary = im
			var from := String(d.get("path", ""))
			if not FileAccess.file_exists(from):
				return {"error": "could not read the picture %s" % from.get_file(), "prompt": "", "pictures": []}
			pictures.append({"from": from, "flip": bool(d.get("flip", false)),
				"to": String(job["dir"]).path_join("picture_%d.jpg" % (pictures.size() + 1))})
			lines.append("Attached picture %d - %s" % [pictures.size(), String(d.get("label", "")).trim_suffix(":")])
		var body := "\n\n".join(head) + "\n\n---\n\n"
		if not lines.is_empty():
			body += "\n".join(lines) + "\n\n"
		return {"error": "", "prompt": body + String(job.get("prompt", "")), "pictures": pictures}

	static func argv(job: Dictionary, pictures: Array) -> PackedStringArray:
		var args := PackedStringArray(["exec", "--skip-git-repo-check", "--json", "--ephemeral",
			"-s", "read-only", "-C", String(job["dir"]),
			"-c", "model_reasoning_effort=" + (String(job["effort"]) if not String(job.get("effort", "")).is_empty()
				else String(EFFORT.get(String(job.get("tier", "best")), "medium"))),
			"-o", String(Backend.paths(job)["last"])])
		if not String(job.get("model", "")).is_empty():
			args.append_array(["-m", String(job["model"])])
		var url := String(job.get("tools_url", ""))
		if not url.is_empty():
			# ghost's server - its token in the environment, never here (see the class note)
			for kv in [["url", JSON.stringify(AgentTools.endpoint(url))], ["bearer_token_env_var", JSON.stringify(TOKEN_ENV)],
					["default_tools_approval_mode", "\"approve\""], ["tool_timeout_sec", str(TOOL_TIMEOUT)]]:
				args.append_array(["-c", "mcp_servers.ghost.%s=%s" % kv])
		# `--image=` per file, then `--`: the flag takes many values (see ImageGen.Codex)
		for pic in pictures:
			args.append("--image=" + String((pic as Dictionary)["to"]))
		args.append_array(["--", "-"])
		return args

	func resolve(job: Dictionary) -> String:
		return FileAccess.get_file_as_string(String(Backend.paths(job)["last"])).strip_edges()

	func failure(job: Dictionary) -> String:
		var last := ImageGen.Codex.last_message(String(Backend.paths(job)["reply"]))
		if not last.is_empty():
			return last
		var err := FileAccess.get_file_as_string(String(Backend.paths(job)["log"])).strip_edges()
		if not err.is_empty():
			var lines := err.split("\n")
			return String(lines[lines.size() - 1]).substr(0, 240)
		return String(job.get("error", "codex finished without a reply"))

	## WHAT CODEX IS DOING, off its `--json` events. It says nothing while it reasons or paints - an
	## item is told when it starts or ends - so between items it is "working".
	func activity(job: Dictionary) -> Dictionary:
		return TextGen.follow(job, String(Backend.paths(job)["reply"]), Codex.read)

	## One `codex exec --json` event into [param now] (the painter's too: [method ImageGen.Codex.activity]).
	static func read(now: Dictionary, e: Dictionary) -> void:
		var item: Dictionary = e["item"] if e.get("item") is Dictionary else {}
		match String(e.get("type", "")):
			"turn.started":
				now["doing"] = "working"
			"item.started":
				match String(item.get("type", "")):
					"command_execution":
						now["doing"] = "running a command"
					"mcp_tool_call":
						now["doing"] = "calling " + TextGen.tool_name(String(item.get("tool", "a tool")))
					"web_search":
						now["doing"] = "searching the web"
					"reasoning":
						now["doing"] = "thinking"
			"item.completed":
				if String(item.get("type", "")) == "agent_message":
					now["chars"] = int(now["chars"]) + String(item.get("text", "")).length()
				now["doing"] = "working"
			"turn.completed", "turn.failed":
				now["doing"] = "finishing"


## XAI'S GROK THROUGH THE GROK BUILD CLI (`grok`), as a bare writer.
##
## Grok Build is a coding agent, and four things make it a writer. Its system prompt is ghost's: an
## agent file beside the prompt (`agent.md`, `promptMode: full`) whose body is the system prompt, so
## Grok's own agent prompt is never sent (measured, CLI 1.0.50: a one-line prompt in ~1.7K input
## tokens instead of ~16K). The message is a file the CLI reads itself (`--prompt-file`;
## `--verbatim`, so it is sent as written and never parsed as a slash command). It has none of its
## own tools ([method argv]). And none of the author's own setup comes along ([constant ISOLATION],
## and `skills: []`, without which Grok lists its bundled skills to the model mid-run): Grok reads
## Claude Code's, Cursor's and Codex's instruction files, skills, hooks and MCP servers by default -
## a writer here was shown ~/.claude/CLAUDE.md - and keeps a memory across sessions. What stays is
## Grok's own: a few lines naming the workspace, and one built-in style rule (state things
## affirmatively) that no switch removes.
##
## THE REPLY is the words after the run's last tool call, read off its event stream: Grok's one-JSON
## reply joins every turn's words (measured: "I am about to search." ran straight into the answer).
##
## PICTURES ARE FILES IT READS. Headless Grok attaches nothing (`@path` arrives as text), and
## `read_file` hands the model the picture itself, so a job with pictures gets that one tool and is
## told which files they are (Rules `agents/grok.writer_pictures`), each prepared as Claude is sent it.
##
## GHOST'S TOOLS ([AgentTools]): the server is named in the agent file (`mcpServers`, a list), and
## Grok reaches its tools as MCP tools always are there - `search_tool` finds them (`ghost__put`...),
## `use_tool` calls them. A picture a tool returns reaches the model as a picture, outside the 20 KB cap
## on a tool's text (measured: a 130 KB JPEG, described rightly), and the text cap is raised for these
## runs ([constant TOOLS_ENV]). THE CALLS ARE ALLOWED BY RULE (`--allow MCPTool(ghost__*)`): left to
## Grok's headless auto mode, a classifier judges each call, and it refused ghost's as "Unknown MCP
## tool with unclear behavior" in one run of three; with the rule, three of three ran.
##
## AN AGENT FILE'S BODY IS A TEMPLATE: a `${{ ... }}` in it is filled in (measured: it vanished). A
## system prompt holding one leads the message instead, as Codex is sent its, and arrives as written.
##
## NO SESSION IS KEPT. Grok keeps every run (its messages, the pictures it read, the text in a search
## index) and has no switch against it, so a finished run's sessions are deleted with Grok's own
## `sessions delete`, as the job's last steps ([method forget]). The painter ([ImageGen.Grok]) shares
## all of this.
class Grok:
	extends Backend

	## The tier is the reasoning effort, as Codex's: what is heard runs at the model's own default
	## (Grok recommends its "high"), the bookkeeping at the lightest.
	const EFFORT := {"best": "", "fast": "low"}
	## The switches that leave the author's setup out of a run, set for that run alone: every source
	## Grok borrows from another agent (instructions, rules, skills, MCP servers, hooks, sessions),
	## its memory, its workflows and its helpers, and the update check.
	const ISOLATION := {
		"GROK_CLAUDE_AGENTS_ENABLED": "0", "GROK_CLAUDE_RULES_ENABLED": "0", "GROK_CLAUDE_SKILLS_ENABLED": "0",
		"GROK_CLAUDE_MCPS_ENABLED": "0", "GROK_CLAUDE_HOOKS_ENABLED": "0", "GROK_CLAUDE_SESSIONS_ENABLED": "0",
		"GROK_CURSOR_AGENTS_ENABLED": "0", "GROK_CURSOR_RULES_ENABLED": "0", "GROK_CURSOR_SKILLS_ENABLED": "0",
		"GROK_CURSOR_MCPS_ENABLED": "0", "GROK_CURSOR_HOOKS_ENABLED": "0", "GROK_CURSOR_SESSIONS_ENABLED": "0",
		"GROK_CODEX_AGENTS_ENABLED": "0", "GROK_CODEX_RULES_ENABLED": "0", "GROK_CODEX_SKILLS_ENABLED": "0",
		"GROK_CODEX_MCPS_ENABLED": "0", "GROK_CODEX_HOOKS_ENABLED": "0", "GROK_CODEX_SESSIONS_ENABLED": "0",
		"GROK_MEMORY": "0", "GROK_WORKFLOWS": "0", "GROK_SUBAGENTS": "0", "GROK_DISABLE_AUTOUPDATER": "1",
	}
	## What a run with ghost's tools adds to [constant ISOLATION]: room for a long tool answer's text
	## (Grok cuts one past 20 KB and leaves the rest in a file); its pictures are not counted in it.
	const TOOLS_ENV := {"GROK_MAX_MCP_OUTPUT_BYTES": "200000"}
	## The name ghost's tool server has in an agent file, and the calls the rule allows.
	const SERVER := "ghost"
	## Grok's effort levels, lightest first: the order a picker lists a model's in.
	const LEVELS := ["none", "minimal", "low", "medium", "high", "xhigh", "max"]

	func binary() -> String:
		var p := Deps.resolve("grok")
		return p if not p.is_empty() else "grok"

	func available() -> bool:
		return Deps.has("grok")

	func takes_tools() -> bool:
		return true

	## `$GROK_HOME`, defaulting to ~/.grok like the CLI does.
	static func home() -> String:
		var h := OS.get_environment("GROK_HOME")
		return h if not h.is_empty() else Deps.home().path_join(".grok")

	## THE MODELS THIS INSTALLATION HAS: the catalog the CLI keeps for itself (`models_cache.json`,
	## what `grok models` prints), `{id: info}` in its own order; {} before the CLI has fetched one.
	static func catalog() -> Dictionary:
		var j := JSON.new()
		if j.parse(FileAccess.get_file_as_string(Grok.home().path_join("models_cache.json"))) != OK or not (j.data is Dictionary):
			return {}
		var out := {}
		var listed: Variant = (j.data as Dictionary).get("models", {})
		if listed is Dictionary:
			for id in listed:
				var m: Variant = (listed as Dictionary)[id]
				if m is Dictionary and (m as Dictionary).get("info") is Dictionary:
					out[String(id)] = (m as Dictionary)["info"]
		return out

	## The model a new session runs on: the author's (GROK_DEFAULT_MODEL, else `[models] default` in
	## config.toml), else the catalog's first; "" when there is none.
	static func default_model() -> String:
		var env := OS.get_environment("GROK_DEFAULT_MODEL")
		if not env.is_empty():
			return env
		var section := ""
		for line in FileAccess.get_file_as_string(Grok.home().path_join("config.toml")).split("\n"):
			var t := String(line).strip_edges()
			if t.begins_with("["):
				section = t
			elif section == "[models]" and (t.begins_with("default ") or t.begins_with("default=")):
				return t.get_slice("=", 1).get_slice("#", 0).strip_edges().trim_prefix("\"").trim_suffix("\"")
		var cat := Grok.catalog()
		return String(cat.keys()[0]) if not cat.is_empty() else ""

	## The picker's models: the default first (key "", labeled with the one it is), then the catalog's.
	## Hidden entries stay hidden.
	static func models() -> Array:
		var cat := Grok.catalog()
		var dflt := Grok.default_model()
		var name := (Grok.field(cat.get(dflt, {}), "name") if cat.has(dflt) else dflt)
		var out: Array = [{"key": "", "label": "Default" + ((" (%s)" % name) if not name.is_empty() else "")}]
		for id in cat:
			var info: Dictionary = cat[id]
			if not bool(info.get("hidden", false)):
				out.append({"key": String(id), "label": Grok.field(info, "name") if not Grok.field(info, "name").is_empty() else String(id)})
		return out

	## THE EFFORTS GROK OFFERS [param model] (the default model's for ""), lightest first: the catalog's
	## `reasoning_efforts`, so a picker never offers a level the model would refuse. A model the catalog
	## does not list gets every level any listed model takes.
	static func levels(model := "") -> PackedStringArray:
		var cat := Grok.catalog()
		var want := model if not model.is_empty() else Grok.default_model()
		var every := {}
		var mine := {}
		for id in cat:
			for e in (cat[id] as Dictionary).get("reasoning_efforts", []):
				var k := str((e as Dictionary).get("id", "")) if e is Dictionary else str(e)
				if not k.is_empty():
					every[k] = true
					if String(id) == want:
						mine[k] = true
		var have := mine if not mine.is_empty() else every
		if have.is_empty():
			return PackedStringArray(["low", "medium", "high"])
		var out := PackedStringArray()
		for k in LEVELS:
			if have.has(k):
				out.append(k)
		for k in have:
			if not LEVELS.has(k):
				out.append(String(k))          # a model's own menu id ("deep"), after the levels
		return out

	## The effort [param model] runs at when none is asked for (the default model's for ""), "" when
	## the catalog does not say.
	static func own_effort(model := "") -> String:
		var want := model if not model.is_empty() else Grok.default_model()
		var v: Variant = (Grok.catalog().get(want, {}) as Dictionary).get("reasoning_effort")
		return "" if v == null else str(v)

	static func efforts(model := "") -> Array:
		var own := Grok.own_effort(model)
		return TextGen.effort_list(Grok.levels(model), "Default (%slow for designs)" % ((own + ", ") if not own.is_empty() else ""))

	## THE AGENT FILE a run is started with: the frontmatter Grok reads it by, then [param body] - the
	## system prompt, as it is sent. [param bare] takes away the tools Grok adds to every agent (the
	## image tools among them, which a painter keeps). No skill is found, inherited or listed either
	## way. [param tools_url] names ghost's tool server, the run's only one ([constant SERVER]).
	static func agent_file(role: String, body: String, bare: bool, tools_url := "") -> String:
		var lines := PackedStringArray(["---", "name: ghost-" + role,
			"description: The %s for Ghost Notes." % role, "promptMode: full"])
		if bare:
			lines.append("injectDefaultTools: false")
		lines.append_array(["discoverSkills: false", "inheritSkills: false", "skills: []"])
		if not tools_url.is_empty():
			lines.append_array(["mcpServers:", "  - name: " + SERVER, "    type: http", "    url: " + JSON.stringify(tools_url)])
		lines.append_array(["---", "", body.strip_edges()])
		return "\n".join(lines) + "\n"

	static func agent_path(job: Dictionary) -> String:
		return String(job["dir"]).path_join("agent.md")

	## What every run shares, after its own flags: no memory, no helpers, no web, the job's folder as
	## its workspace, and the model and effort chosen - else [param effort], else the model's own.
	static func common(job: Dictionary, effort: String) -> PackedStringArray:
		var args := PackedStringArray(["--no-memory", "--no-subagents", "--disable-web-search",
			"--cwd", String(job["dir"])])
		if not String(job.get("model", "")).is_empty():
			args.append_array(["-m", String(job["model"])])
		var e := String(job.get("effort", ""))
		if e.is_empty():
			e = effort
		if not e.is_empty():
			args.append_array(["--effort", e])
		return args

	func start(job: Dictionary) -> int:
		var p := Backend.paths(job)
		var m := Grok.compose(job)
		if not String(m["error"]).is_empty():
			job["error"] = m["error"]
			return -1
		for pic in m["pictures"]:
			var d: Dictionary = pic
			var img := TextGen.picture(String(d["from"]), bool(d["flip"]))
			if img == null or img.save_jpg(String(d["to"]), 0.9) != OK:
				job["error"] = "could not prepare the picture %s" % String(d["from"]).get_file()
				return -1
		var url := String(job.get("tools_url", ""))
		for pair in [[p["prompt"], m["message"]], [p["system"], String(job.get("system", ""))],
				[Grok.agent_path(job), Grok.agent_file("writer", String(m["body"]), true, url)]]:
			var err := TextGen.put(String(pair[0]), String(pair[1]))
			if not err.is_empty():
				job["error"] = err
				return -1
		var env: Dictionary = ISOLATION.duplicate()
		if not url.is_empty():
			env.merge(TOOLS_ENV, true)
		job["step"] = "write"
		var pid := Subprocess.start_redirected(binary(), Grok.argv(job, not (m["pictures"] as Array).is_empty()),
			{"cwd": String(job["dir"]), "out": String(p["reply"]), "err": String(p["log"]), "env": env},
			"grok writer")
		if pid <= 0:
			job["error"] = "could not start grok (is the Grok Build CLI installed and logged in?)"
		return pid

	## THE MESSAGE (`message`, written to prompt.txt - exactly what the CLI reads): a system prompt that
	## cannot be the agent file's body ahead of everything, then which picture is which file, then the
	## prompt; the agent file's `body`; and the pictures to prepare, `{from, flip, to}`, in that order.
	## `error` names a picture that cannot be read: a writer told to talk about a card it was never
	## sent would make it up.
	static func compose(job: Dictionary) -> Dictionary:
		var sys := String(job.get("system", "")).strip_edges()
		var fold := sys.contains("${{")
		var pictures: Array = []
		var listed: Array = []
		for im in job.get("images", []):
			var d: Dictionary = im
			var from := String(d.get("path", ""))
			if not FileAccess.file_exists(from):
				return {"error": "could not read the picture %s" % from.get_file(), "message": "", "body": "", "pictures": []}
			var to := String(job["dir"]).path_join("picture_%d.jpg" % (pictures.size() + 1))
			pictures.append({"from": from, "flip": bool(d.get("flip", false)), "to": to})
			listed.append({"n": pictures.size(), "label": String(d.get("label", "")).trim_suffix(":"), "path": to})
		var head := PackedStringArray()
		if fold:
			head.append(sys)
		if not listed.is_empty():
			head.append(Rules.say("agents/grok.writer_pictures", {"pictures": listed}))
		var prompt := String(job.get("prompt", ""))
		return {"error": "", "pictures": pictures,
			"body": sys if not (fold or sys.is_empty()) else Rules.say("agents/grok.writer"),
			"message": ("\n\n".join(head) + "\n\n---\n\n" + prompt) if not head.is_empty() else prompt}

	## Flags and paths only - the message is in its file. A writer's own tools: `read_file` for its
	## pictures, or none (the allowlist names it, then the denylist takes it back: an empty `--tools`
	## is no allowlist at all). The two MCP tools every allowlist keeps stay only for a job with ghost's
	## tools, whose calls are then allowed by rule (see the class note).
	static func argv(job: Dictionary, pictures: bool) -> PackedStringArray:
		var tools := not String(job.get("tools_url", "")).is_empty()
		var deny := PackedStringArray([] if pictures else ["read_file"])
		if not tools:
			deny.append_array(["search_tool", "use_tool"])
		var args := PackedStringArray(["--agent", Grok.agent_path(job),
			"--prompt-file", String(Backend.paths(job)["prompt"]), "--verbatim", "--tools", "read_file"])
		if not deny.is_empty():
			args.append_array(["--disallowed-tools", ",".join(deny)])
		if tools:
			args.append_array(["--allow", "MCPTool(%s__*)" % SERVER])
		args.append_array(Grok.common(job, String(EFFORT.get(String(job.get("tier", "best")), ""))))
		args.append_array(["--output-format", "streaming-json"])
		return args

	## A field of what the CLI wrote, as text: "" for a missing or null one. Its streams carry
	## `"status": null` while a tool runs, and `String(null)` is a script error (it stopped the first
	## real painter run).
	static func field(d: Variant, key: String) -> String:
		var v: Variant = (d as Dictionary).get(key) if d is Dictionary else null
		return "" if v == null else str(v)

	## WHAT GROK IS DOING, off its stream: it streams its thinking and its words as they come, so a
	## Grok run is never silent while it works.
	func activity(job: Dictionary) -> Dictionary:
		var now := TextGen.follow(job, String(Backend.paths(job)["reply"]), Grok.read)
		if String(job.get("step", "")) == "forget":
			now["doing"] = "finishing"
		return now

	## One `--output-format streaming-json` event into [param now] (the painter's too).
	static func read(now: Dictionary, e: Dictionary) -> void:
		match Grok.field(e, "type"):
			"thought":
				now["doing"] = "thinking"
				now["tokens"] = int(now["tokens"]) + Grok.field(e, "data").length() / 4    # ~4 characters a token
			"text":
				now["doing"] = "writing"
				now["chars"] = int(now["chars"]) + Grok.field(e, "data").length()
			"tool_call":
				var tool := Grok.field(e, "toolName")
				match tool:
					"use_tool":
						now["doing"] = "calling " + TextGen.tool_name(Grok.field(e.get("rawInput"), "tool_name"))
					"search_tool":
						now["doing"] = "finding its tools"
					"read_file":
						now["doing"] = "looking at a picture"
					"image_gen", "image_edit":
						now["doing"] = "painting"
					_:
						now["doing"] = "using " + tool
			"tool_call_update":
				if Grok.field(e, "status") in ["completed", "failed"]:
					now["doing"] = "thinking"
			"end":
				now["doing"] = "finishing"

	## A JSON-lines file's objects, quietly.
	static func events(path: String) -> Array:
		var out: Array = []
		if path.is_empty() or not FileAccess.file_exists(path):
			return out
		for line in FileAccess.get_file_as_string(path).split("\n"):
			var t := String(line).strip_edges()
			if not t.begins_with("{"):
				continue
			var j := JSON.new()
			if j.parse(t) == OK and j.data is Dictionary:
				out.append(j.data)
		return out

	## WHAT A RUN SAID, off its `--output-format streaming-json` stream: `said`, the words after its
	## last tool call (words before a call were said on the way to it); `stop` and `session`, from its
	## `end` event; `error`, from an `error` event.
	static func outcome(path: String) -> Dictionary:
		var said := ""
		var out := {"said": "", "stop": "", "session": "", "error": ""}
		for ev in Grok.events(path):
			match Grok.field(ev, "type"):
				"text":
					said += Grok.field(ev, "data")
				"tool_call":
					said = ""
				"end":
					out["stop"] = Grok.field(ev, "stopReason")
					out["session"] = Grok.field(ev, "sessionId")
				"error":
					out["error"] = Grok.field(ev, "message")
		out["said"] = said.strip_edges()
		return out

	func advance(job: Dictionary) -> int:
		if String(job.get("step", "")) == "write":
			job["sessions"] = Grok.sessions_of(String(job["dir"]), String(Grok.outcome(String(Backend.paths(job)["reply"]))["session"]))
		return Grok.forget(job, binary())

	func resolve(job: Dictionary) -> String:
		var o := Grok.outcome(String(Backend.paths(job)["reply"]))
		return String(o["said"]) if String(o["stop"]) == "end_turn" else ""

	func failure(job: Dictionary) -> String:
		if job.has("error"):
			return String(job["error"])
		var o := Grok.outcome(String(Backend.paths(job)["reply"]))
		if not String(o["error"]).is_empty():
			return String(o["error"]).strip_edges().substr(0, 240)
		var stop := String(o["stop"])
		if not stop.is_empty() and stop != "end_turn":
			return "grok stopped: %s" % stop.replace("_", " ")
		var err := FileAccess.get_file_as_string(String(Backend.paths(job)["log"])).strip_edges()
		if not err.is_empty():
			var lines := err.split("\n")
			return String(lines[lines.size() - 1]).substr(0, 240)
		return "grok finished without a reply"

	## The folder Grok keeps a working directory's sessions in (`sessions/<the path, URL-encoded>`,
	## measured); "" for no directory.
	static func group_of(dir: String) -> String:
		return "" if dir.is_empty() else Grok.home().path_join("sessions").path_join(dir.uri_encode())

	## A session id as Grok names one - nothing else is handed to `sessions delete`.
	static func is_session_id(s: String) -> bool:
		return s.length() >= 8 and RegEx.create_from_string("^[0-9A-Za-z-]+$").search(s) != null

	## The sessions a run left: the one its reply names, and any other in the folder Grok keeps for the
	## job's directory, whose only runs are this job's (a run that failed before replying names none).
	static func sessions_of(dir: String, named: String) -> Array:
		var out: Array = []
		if Grok.is_session_id(named):
			out.append(named)
		var g := Grok.group_of(dir)
		if not g.is_empty() and DirAccess.dir_exists_absolute(g):
			for s in DirAccess.get_directories_at(g):
				if Grok.is_session_id(s) and not out.has(s):
					out.append(s)
		return out

	## THE JOB'S LAST STEPS, one per session in `job.sessions`: `grok sessions delete`, which also takes
	## the session out of Grok's search index (removing its folder alone would leave its text there).
	## Once none is left, the job directory's own folder goes too - all it holds then is the prompt's
	## text, as Grok's prompt history. The next step's pid, or 0 when there is none. Best effort: a
	## session that stays costs disk, never the job.
	static func forget(job: Dictionary, bin: String) -> int:
		var left: Array = job.get("sessions", [])
		while not left.is_empty():
			var id := String(left.pop_front())
			job["step"] = "forget"
			var dir := String(job["dir"])
			var pid := Subprocess.start_redirected(bin, PackedStringArray(["sessions", "delete", id]),
				{"cwd": dir, "out": dir.path_join("forget.log"), "err": dir.path_join("forget_err.log")}, "grok forget")
			if pid > 0:
				return pid
		Grok.clear_group(String(job.get("dir", "")))
		return 0

	## The folder Grok keeps for [param dir], removed once no session is left in it.
	static func clear_group(dir: String) -> void:
		var g := Grok.group_of(dir)
		if g.is_empty() or not DirAccess.dir_exists_absolute(g) or not DirAccess.get_directories_at(g).is_empty():
			return
		for f in DirAccess.get_files_at(g):
			DirAccess.remove_absolute(g.path_join(f))
		DirAccess.remove_absolute(g)


## MODELS ON AMAZON BEDROCK, THROUGH THE AWS CLI: Amazon's own Nova (the default) and the open
## models Bedrock hosts, run on the machine's AWS credentials and region (`aws configure`) and
## billed per token to that account.
##
## One `bedrock-runtime converse` call per job. Its whole request - the system prompt, the pictures
## (JPEG, base64) and the prompt - is a JSON file the CLI reads itself (`--cli-input-json
## file://...`), so nothing the author wrote is ever in argv. `--cli-binary-format base64` is
## explicit because a `cli_binary_format = raw-in-base64-out` in the user's config would send the
## pictures' base64 as the bytes themselves.
##
## WHICH MODELS, AND WHERE TO CALL THEM, is the account's own answer: [BedrockCatalog]. A model is
## kept by its base id and called on its route, in the region that serves it; a job finding no
## fresh catalog looks it up first, as steps of its own ([method advance]).
##
## ONE API, MANY MODELS: Converse evens out most differences between providers, and the two that
## remain are retried as steps: a model that takes no system prompt is sent it at the head of the
## message, and one whose output limit is under [constant MAX_TOKENS] is asked again inside it.
class Bedrock:
	extends Backend

	const Catalog := preload("res://src/bedrock_catalog.gd")
	## The model per tier: Amazon's newest for what is heard, its cheaper one for bookkeeping. Both
	## see pictures - a card's passage is sent its card.
	const MODELS := {"best": "amazon.nova-2-lite-v1:0", "fast": "amazon.nova-lite-v1:0"}
	## Nova 1 models stop at 10K output tokens (Nova 2 Lite at 64K); a card show's plan runs to ~6K.
	const MAX_TOKENS := 10000
	## Nova 2's extended thinking (`reasoningConfig.maxReasoningEffort`), off unless asked for; no
	## other Amazon model takes it. Its tokens bill as output.
	const EFFORTS := ["low", "medium", "high"]
	## What the model picker offers before the account has been asked; the catalog replaces it.
	const SEED := [
		{"id": "amazon.nova-2-lite-v1:0", "name": "Nova 2 Lite", "provider": "Amazon", "images": true},
		{"id": "amazon.nova-pro-v1:0", "name": "Nova Pro", "provider": "Amazon", "images": true},
		{"id": "amazon.nova-lite-v1:0", "name": "Nova Lite", "provider": "Amazon", "images": true},
		{"id": "amazon.nova-micro-v1:0", "name": "Nova Micro", "provider": "Amazon", "images": false},
	]

	func binary() -> String:
		var p := Deps.resolve("aws")
		return p if not p.is_empty() else "aws"

	func available() -> bool:
		return Deps.has("aws")

	## The account's text models when it has been asked, else [constant SEED].
	static func listed() -> Array:
		var list := Catalog.models("TEXT")
		return list if not list.is_empty() else SEED

	static func models() -> Array:
		var out: Array = [{"key": "", "label": "Default (%s)" % Bedrock.name_of(MODELS["best"])}]
		for m in Bedrock.listed():
			var d: Dictionary = m
			out.append({"key": String(d["id"]),
				"label": Catalog.label(d) + ("" if bool(d.get("images", true)) else " (text only)")})
		return out

	## Whether a model (a base id or a route) thinks when asked: Nova 2's.
	static func thinks(id: String) -> bool:
		return id.contains("nova-2")

	static func efforts(model := "") -> Array:
		var id := model if not model.is_empty() else String(MODELS["best"])
		return TextGen.effort_list(EFFORTS if Bedrock.thinks(id) else [], "Default (off)")

	static func name_of(id: String) -> String:
		for m in Bedrock.listed() + SEED:
			if String((m as Dictionary)["id"]) == id:
				return Catalog.label(m)
		return id

	## The base model a job runs on: the one chosen for it, else its tier's.
	static func model_of(job: Dictionary) -> String:
		var chosen := String(job.get("model", ""))
		return chosen if not chosen.is_empty() else String(MODELS.get(String(job.get("tier", "best")), MODELS["best"]))

	## False only for a model known to read text alone.
	static func sees_pictures(id: String) -> bool:
		for m in Bedrock.listed() + SEED:
			if String((m as Dictionary)["id"]) == id:
				return bool((m as Dictionary).get("images", true))
		return true

	func start(job: Dictionary) -> int:
		var model := Bedrock.model_of(job)
		if not (job.get("images", []) as Array).is_empty() and not Bedrock.sees_pictures(model):
			job["error"] = "%s reads text only, and this job sends pictures - choose another model" % Bedrock.name_of(model)
			return -1
		var m := Bedrock.compose(job)
		if not String(m["error"]).is_empty():
			job["error"] = m["error"]
			return -1
		var p := Backend.paths(job)
		for pair in [["prompt", m["shown"]], ["system", String(job.get("system", ""))]]:
			var err := TextGen.put(String(p[pair[0]]), String(pair[1]))
			if not err.is_empty():
				job["error"] = err
				return -1
		job["content"] = m["content"]
		job["max_tokens"] = MAX_TOKENS
		job["catalog"] = Catalog.fresh()
		if (job["catalog"] as Dictionary).is_empty():
			return Catalog.start_lookup(job, binary())
		return _converse(job)

	## After a step: the next lookup, the call itself, or the call again where a retry applies.
	func advance(job: Dictionary) -> int:
		match String(job.get("step", "")):
			"lookup":
				var next := Catalog.after_lookup(job, binary())
				return _converse(job) if next == 0 else maxi(next, 0)
			"converse":
				if not Provision.read_json(String(Backend.paths(job)["reply"])).is_empty():
					return 0
				match Bedrock.retry_of(job, Catalog.cli_error(String(Backend.paths(job)["log"]))):
					"fold":
						job["fold"] = true
						return _converse(job)
					"cap":
						job["max_tokens"] = Bedrock.output_cap(Catalog.cli_error(String(Backend.paths(job)["log"])),
							int(job["max_tokens"]))
						return _converse(job)
		return 0

	## What to do about a failed call, from the CLI's complaint: "fold" (the model takes no system
	## prompt - send it in the message), "cap" (ask inside the model's own output limit) or "".
	## Each is tried once.
	static func retry_of(job: Dictionary, why: String) -> String:
		var t := why.to_lower()
		if t.contains("system message") and not bool(job.get("fold", false)) \
				and not String(job.get("system", "")).strip_edges().is_empty():
			return "fold"
		if Bedrock.output_cap(why, int(job.get("max_tokens", MAX_TOKENS))) > 0:
			return "cap"
		return ""

	## The output limit a refusal names ("... is not less or equal to 4096"): the largest number in
	## it under [param asked], when the complaint is about the token limit at all; else 0.
	static func output_cap(why: String, asked: int) -> int:
		var t := why.to_lower()
		if not (t.contains("max_tokens") or t.contains("maxtokens") or t.contains("max tokens") or t.contains("maximum tokens")):
			return 0
		var best := 0
		for m in RegEx.create_from_string("\\d+").search_all(t):
			var n := int(m.get_string())
			if n >= 256 and n < asked and n > best:
				best = n
		return best

	## WHAT IT IS DOING: Converse answers all at once, so its step is all there is to say.
	func activity(job: Dictionary) -> Dictionary:
		var now := TextGen.now_of(job, "working")
		match String(job.get("step", "")):
			"lookup":
				now["doing"] = "looking up its models"
			"converse":
				now["doing"] = "waiting for " + Bedrock.bare_name(Bedrock.model_of(job))
		return now

	## A model's own name, with no provider before it ("Nova Pro"): a status line's parts are already
	## set apart by " · ".
	static func bare_name(id: String) -> String:
		for m in Bedrock.listed() + SEED:
			if String((m as Dictionary)["id"]) == id:
				return String((m as Dictionary).get("name", id))
		return id

	func _converse(job: Dictionary) -> int:
		job["step"] = "converse"
		var p := Backend.paths(job)
		var model := Bedrock.model_of(job)
		var e := Catalog.entry(job.get("catalog", {}), model)
		if e.is_empty():
			job["error"] = "%s is not offered to this AWS account in any region it reaches" % Bedrock.name_of(model)
			return -1
		job["route"] = "%s in %s" % [String(e["route"]), String(e["region"])]
		var req := Bedrock.request(String(e["route"]), String(job.get("system", "")), job.get("content", []),
			int(job.get("max_tokens", MAX_TOKENS)), bool(job.get("fold", false)), String(job.get("effort", "")))
		var err := TextGen.put(String(p["input"]), JSON.stringify(req))
		if not err.is_empty():
			job["error"] = err
			return -1
		return Catalog.run(job, binary(), Bedrock.argv(String(p["input"]), String(e["region"])),
			String(p["reply"]), String(p["log"]), "bedrock writer")

	## THE MESSAGE: each picture under its label, then the prompt, as Converse content blocks
	## (`content`), and the record a person reads (`shown`). `error` names a picture that could not
	## be read: a writer told to talk about a card it was never sent would make it up.
	static func compose(job: Dictionary) -> Dictionary:
		var content: Array = []
		var record := PackedStringArray()
		for im in job.get("images", []):
			var d: Dictionary = im
			var block := Bedrock.picture_block(String(d.get("path", "")), bool(d.get("flip", false)))
			if block.is_empty():
				return {"error": "could not read the picture %s" % String(d.get("path", "")).get_file(),
					"content": [], "shown": ""}
			var label := String(d.get("label", ""))
			if not label.is_empty():
				content.append({"text": label})
			content.append(block)
			record.append(TextGen.picture_line(d))
		var prompt := String(job.get("prompt", ""))
		content.append({"text": prompt})
		return {"error": "", "content": content,
			"shown": ("\n".join(record) + "\n\n" + prompt) if not record.is_empty() else prompt}

	## A picture as a Converse image block (JPEG, base64); {} when it cannot be read.
	static func picture_block(path: String, flip := false) -> Dictionary:
		var img := TextGen.picture(path, flip)
		if img == null:
			return {}
		return {"image": {"format": "jpeg", "source": {"bytes": Marshalls.raw_to_base64(img.save_jpg_to_buffer(0.9))}}}

	## The Converse request, as the CLI reads it from its input file. [param fold] sends the system
	## prompt at the head of the message, for a model that takes none. [param effort] turns on a
	## thinking model's extended thinking; at "high", Nova 2 wants no output cap at all.
	static func request(model_id: String, system: String, content: Array, max_tokens := MAX_TOKENS,
			fold := false, effort := "") -> Dictionary:
		var blocks := content.duplicate()
		var has_system := not system.strip_edges().is_empty()
		if fold and has_system:
			blocks.push_front({"text": system})
		var req := {"modelId": model_id,
			"messages": [{"role": "user", "content": blocks}],
			"inferenceConfig": {"maxTokens": max_tokens}}
		if has_system and not fold:
			req["system"] = [{"text": system}]
		if not effort.is_empty() and Bedrock.thinks(model_id):
			req["additionalModelRequestFields"] = {"reasoningConfig": {"type": "enabled", "maxReasoningEffort": effort}}
			if effort == "high":
				req.erase("inferenceConfig")
		return req

	## Flags and a path only - the request is in the file.
	static func argv(request_path: String, region := "") -> PackedStringArray:
		var args := PackedStringArray(["bedrock-runtime", "converse",
			"--cli-input-json", "file://" + request_path,
			"--cli-binary-format", "base64", "--cli-read-timeout", "300"])
		if not region.is_empty():
			args.append_array(["--region", region])
		args.append_array(["--output", "json", "--no-cli-pager"])
		return args

	func resolve(job: Dictionary) -> String:
		return Bedrock.reply_text(job, String(Backend.paths(job)["reply"]))

	## A Converse reply's words: its text blocks, joined (a reasoning model's thinking is left out);
	## "" for a reply cut off at the token limit, which is a failure and not a short answer.
	static func reply_text(job: Dictionary, path: String) -> String:
		if String(job.get("step", "")) != "converse":
			return ""
		var d := Provision.read_json(path)
		if d.is_empty() or String(d.get("stopReason", "")) == "max_tokens":
			return ""
		var parts := PackedStringArray()
		for c in ((d.get("output", {}) as Dictionary).get("message", {}) as Dictionary).get("content", []):
			if c is Dictionary and (c as Dictionary).has("text"):
				parts.append(String((c as Dictionary)["text"]))
		var u: Dictionary = d.get("usage", {})
		print("ghost: %s wrote %d tokens from %d (%s)" % [Bedrock.name_of(Bedrock.model_of(job)),
			int(u.get("outputTokens", 0)), int(u.get("inputTokens", 0)), String(job.get("route", ""))])
		return "".join(parts).strip_edges()

	func failure(job: Dictionary) -> String:
		if job.has("error"):
			return String(job["error"])
		var d := Provision.read_json(String(Backend.paths(job)["reply"]))
		if String(d.get("stopReason", "")) == "max_tokens":
			return "%s ran past %d tokens and was cut off" % [Bedrock.name_of(Bedrock.model_of(job)),
				int(job.get("max_tokens", MAX_TOKENS))]
		var err := Catalog.cli_error(String(Backend.paths(job)["log"]))
		return err if not err.is_empty() else "aws finished without a reply"
