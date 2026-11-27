extends SceneTree

## made_sounds_check - the sounds a show makes on its own, on the Sound card ([MadeSounds], [ShowSounds]). It holds:
##
## - each sound a show says it makes is an entry, in order, under the show's heading; one not made has its Test off, one made on;
## - a sound made since is shown made at the next read (rebuilt only when what it lists changed);
## - a show that makes none shows nothing (the control), and the part stands hidden.
##
##   godot --headless --path . --script tests/music/made_sounds_check.gd

## A show saying what it makes.
class Stub extends ShowSounds:
	var list: Array = []

	func sounds() -> Array:
		return list

	func heading() -> String:
		return "Made from the hands' acts"


var _fails := 0


func _init() -> void:
	var part := MadeSounds.new()
	var stub := Stub.new()
	stub.list = [{"key": "act:1", "name": "1. rub fur, left", "line": "made, 4 s", "tip": "It rubs the fur.", "path": "/nowhere/act1.wav"},
		{"key": "act:2", "name": "2. tap block, right", "line": "not made yet", "tip": "It taps.", "path": ""}]
	var shows: Array = [stub]
	part.follow(func() -> Array: return shows)
	var entries := part.find_children("*", "EntryCard", true, false)
	var tests := part.find_children("*", "Button", true, false).filter(func(b: Button) -> bool: return b.text.contains("Test"))
	_ok(part.visible and part.listed() == PackedStringArray(["act:1", "act:2"]) and entries.size() == 2 and tests.size() == 2
		and not (tests[0] as Button).disabled and (tests[1] as Button).disabled,
		"each sound a show makes is an entry, in order; one not made has its Test off (%d entries)" % entries.size())
	stub.list[1] = {"key": "act:2", "name": "2. tap block, right", "line": "made, 2 s", "tip": "It taps.", "path": "/nowhere/act2.wav"}
	part.refresh()
	tests = part.find_children("*", "Button", true, false).filter(func(b: Button) -> bool: return b.text.contains("Test") and not b.is_queued_for_deletion())
	_ok(tests.size() == 2 and tests.all(func(b: Button) -> bool: return not b.disabled), "a sound made since is shown made at the next read")
	shows.clear()
	_ok(not part.refresh() and not part.visible, "a show that makes none shows nothing (the control)")
	part.free()
	print("made_sounds_check: %s (%d failure%s)" % ["ALL OK" if _fails == 0 else "FAILED", _fails, "" if _fails == 1 else "s"])
	quit(1 if _fails > 0 else 0)


func _ok(cond: bool, what: String) -> void:
	print(("ok    " if cond else "FAIL  ") + what)
	if not cond:
		_fails += 1
