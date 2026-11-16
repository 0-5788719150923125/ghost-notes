extends SceneTree

## Gate for [StatusLog]: what a panel, a card or the Pipeline card says on screen reaches the log, where it can be copied.
## It holds:
##
## - words said are logged, a line of the log each line of them, under where they were said;
## - the same words said again are not logged again (the control: words that change are);
## - a place that says nothing and then the same words again logs them again;
## - two places are each their own.
##
## Run: godot --headless --path . --script tests/ui/status_log_check.gd

var _fails: Array = []


class _Catch extends Logger:
	var lock := Mutex.new()
	var said: Array[String] = []

	func _log_message(message: String, _error: bool) -> void:
		lock.lock()
		said.append(message.strip_edges())
		lock.unlock()


func _init() -> void:
	var catch := _Catch.new()
	OS.add_logger(catch)
	StatusLog.say("medium", "3 problems\n⚠  > l opens nothing")
	StatusLog.say("medium", "3 problems\n⚠  > l opens nothing")
	var once := _ours(catch)
	StatusLog.say("medium", "1 problem")
	var changed := _ours(catch)
	StatusLog.say("medium", "")
	StatusLog.say("medium", "1 problem")
	var again := _ours(catch)
	StatusLog.say("pipeline: Pictures / the dog", "Failed - could not read dog.webm")
	var other := _ours(catch)
	OS.remove_logger(catch)
	_ok(once == ["ghost: medium: 3 problems", "ghost: medium: ⚠  > l opens nothing"],
		"words said are logged, a line each, under where they were said (%s)" % str(once))
	_ok(changed.size() == 3 and changed[2] == "ghost: medium: 1 problem",
		"the same words again are not logged again, and words that change are (%s)" % str(changed))
	_ok(again.size() == 4 and again[3] == "ghost: medium: 1 problem", "after saying nothing, the same words are logged again (%s)" % str(again))
	_ok(other.size() == 5 and other[4] == "ghost: pipeline: Pictures / the dog: Failed - could not read dog.webm",
		"each place is its own (%s)" % str(other))
	if _fails.is_empty():
		print("status_log_check: ALL OK")
		quit(0)
	else:
		for f in _fails:
			print("status_log_check: FAIL  " + f)
		quit(1)


## What the log has had of StatusLog's so far.
func _ours(catch: _Catch) -> Array:
	catch.lock.lock()
	var out := catch.said.filter(func(s: String) -> bool: return s.begins_with("ghost: medium:") or s.begins_with("ghost: pipeline:"))
	catch.lock.unlock()
	return out


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails.append(what)
