extends SceneTree

## reading_timeline_check - A NOTE'S WORDS AS A TIMELINE ([ReadingTimeline]; next/editing.md step 12: "the Letter and the Dispatch
## desk hand a score from the marks they have").
##
##   godot --headless --path . --script res://tests/reading/reading_timeline_check.gd
##
## Each heading of the words a group, each mark a flag in its own lane where the reader comes to it (each word as long as the reader
## says one, a rest a mark asks for counted in), its source its place in the text; THE CONTROL: words with no marks have none.

const BODY := "# One\n\nHello there friend. <!-- pause: 2 --> Then more words here.\n\n# Two\n\n<!-- heard: phone --> On the line now."

var _fails := 0


func _initialize() -> void:
	var tl := ReadingTimeline.of(BODY, 0.5)
	var groups: Array = tl.get("groups", [])
	_ok(String(tl.get("clock", "")) == "voice" and groups.size() == 2 and String(groups[0]["label"]) == "One" and String(groups[1]["label"]) == "Two",
		"each heading a group, on the voice's clock: %s" % str(groups.map(func(g: Dictionary) -> String: return String(g["label"]))))
	var pause: Dictionary = (groups[0]["lanes"] as Array)[0]["items"][0] if not groups.is_empty() else {}
	var heard: Dictionary = (groups[1]["lanes"] as Array)[0]["items"][0] if groups.size() > 1 else {}
	_ok(is_equal_approx(float(pause.get("at", -1.0)), 1.5) and String((groups[0]["lanes"] as Array)[0]["id"]) == "pause",
		"a mark is a flag in its own lane where the reader comes to it (pause at %s s)" % str(pause.get("at")))
	_ok(groups.size() > 1 and is_equal_approx(float(groups[1]["start"]), 5.5) and is_equal_approx(float(heard.get("at", -1.0)), 0.0),
		"the rest it asks for is counted in: the next heading starts at %s s" % str(groups[1]["start"] if groups.size() > 1 else "?"))
	var src: Array = pause.get("source", [0, 0, -1])
	_ok(BODY.substr(int(src[2]), String(pause.get("text", "")).length()) == "<!-- pause: 2 -->", "its source is its place in the text")
	_ok(Timeline.check(tl).is_empty(), "the timeline has no problems: %s" % ", ".join(Timeline.check(tl)))
	_ok(ReadingTimeline.of("Just words, and no marks at all.", 0.5).is_empty(), "the control: words with no marks have no timeline")
	if _fails == 0:
		print("reading_timeline_check: ALL OK")
		quit(0)
		return
	print("reading_timeline_check: %d FAILED" % _fails)
	quit(1)


func _ok(cond: bool, msg: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + msg)
	if not cond:
		_fails += 1
