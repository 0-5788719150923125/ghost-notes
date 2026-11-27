extends RefCounted
class_name PropRefining

## PropRefining - every prop an agent is refining now, at once (next/library.md, "Refining a prop"): one refining a prop at a time,
## any number of props together, each running on whether or not its 3D view is open ([PropVersions], [PropViewer]). Keyed by the name
## the prop is kept or held as a draft by; a prop renamed meanwhile is followed ([method renamed]).
##
## Each is `{state, line, index, name, error, moved}`: `working` while the agent is at it (`line` what it is doing, as it says), then
## `ready` (`index` the version it made, `name` what that version is called, `moved` what it also placed, by name), `placed` (it placed
## the prop or its scene's things and made no version) or `failed` (`error` why) until it is seen ([method seen]) - the
## 3D view on the prop shows the version made, or why not. Its row on the Props card says each meanwhile ([PropsCard]).

static var _on := {}              # name -> {state, line, index, name, error}
static var _moved := {}           # a former name -> the name it was renamed to while it was refined


## [param name] being refined from now: "" begun, else why not (an agent at it already).
static func start(name: String) -> String:
	var at := _now(name)
	if busy(at):
		return "an agent is refining it already"
	_on[at] = {"state": "working", "line": "starting", "index": -1, "name": "", "error": ""}
	return ""


## What the agent refining [param name] is doing, as it says.
static func say(name: String, line: String) -> void:
	var w: Dictionary = _on.get(_now(name), {})
	if String(w.get("state", "")) == "working" and not line.strip_edges().is_empty():
		w["line"] = line.strip_edges()


## The refining of [param name] ended with [param got] (`{index, name}` a version made, `{moved}` the prop and its scene's things placed
## there by name - no version - or both, or `{error}`).
static func finish(name: String, got: Dictionary) -> void:
	var at := _now(name)
	var moved: Dictionary = got.get("moved", {}) if got.get("moved") is Dictionary else {}
	if int(got.get("index", -1)) >= 0:
		_on[at] = {"state": "ready", "line": "", "index": int(got["index"]), "name": String(got.get("name", "")), "error": "", "moved": moved}
	elif not moved.is_empty():
		_on[at] = {"state": "placed", "line": "", "index": -1, "name": "", "error": "", "moved": moved}
	else:
		_on[at] = {"state": "failed", "line": "", "index": -1, "name": "", "error": String(got.get("error", "nothing came of it"))}


## How the refining of [param name] stands, {} for none.
static func of(name: String) -> Dictionary:
	return (_on.get(_now(name), {}) as Dictionary).duplicate()


## Whether an agent is refining [param name] now.
static func busy(name: String) -> bool:
	return String((_on.get(_now(name), {}) as Dictionary).get("state", "")) == "working"


## Whether any prop is being refined, or has a version made or a failure not yet seen.
static func any() -> bool:
	return not _on.is_empty()


## What came of refining [param name] seen: forgotten. One still working is left as it is.
static func seen(name: String) -> void:
	var at := _now(name)
	if not busy(at):
		_on.erase(at)


## [param old] renamed [param to]: what is under way for it, and what a refining still running calls it by, follow.
static func renamed(old: String, to: String) -> void:
	if old == to or old.is_empty() or to.is_empty():
		return
	_moved[old] = to
	if _on.has(old):
		_on[to] = _on[old]
		_on.erase(old)


## The name [param name] has now, following every rename.
static func _now(name: String) -> String:
	var at := name
	var hops := 0
	while _moved.has(at) and hops < 16:
		at = String(_moved[at])
		hops += 1
	return at


## Everything forgotten (a gate's).
static func clear() -> void:
	_on.clear()
	_moved.clear()
