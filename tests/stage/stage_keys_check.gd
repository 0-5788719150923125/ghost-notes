extends SceneTree

## stage_keys_check - A STAGE'S FLAGS: a value that changes at a moment, eased before or after it, and holds ([StageKeys];
## next/editing.md step 10).
##
##   godot --headless --path . --script res://tests/stage/stage_keys_check.gd
##
## What it holds:
##   - before any key a field is what the entry set; a RAMP arrives at its moment (its seconds before it the eased way there),
##     a DAMP begins at it; each holds after; a second key moves on from where the first left it; a place eases as one;
##   - keys are a stage entry's flags on its Timeline: lane "camera", seekable (the `time` engine) where its verbs are not,
##     each its key's place in the storyboard;
##   - THE CONTROL: a key naming no field, and one whose value is not its field's kind, are said and left out.

var _fails := 0


func _initialize() -> void:
	var made := StageKeys.sanitize([
		{"field": "camera.fov", "at": 2.0, "to": 30, "over": 1.0, "ease": "ramp"},
		{"field": "camera.fov", "at": 5.0, "to": 60, "over": 2.0, "ease": "damp"},
		{"field": "camera.eye", "at": 1.0, "to": [0, 1, 2], "over": 0.0, "ease": "damp"},
		{"field": "camera.zoomy", "at": 1.0, "to": 3},
		{"field": "camera.eye", "at": 1.0, "to": 7}])
	var keys: Array = made["keys"]
	var said := " ".join(made["notes"])
	_ok(keys.size() == 3 and said.contains("zoomy") and said.contains("[x, y, z]"), "the control: a key naming no field, and one of the wrong kind, are said and left out: %s" % said)
	var at := func(t: float) -> float: return float(StageKeys.value_at(48.0, keys, "camera.fov", t))
	_ok(at.call(0.5) == 48.0 and at.call(1.0) == 48.0, "before a ramp's seconds, the field is what the entry set")
	_ok(at.call(1.5) < 48.0 and at.call(1.5) > 30.0 and is_equal_approx(at.call(2.0), 30.0), "a ramp eases in and arrives at its moment")
	_ok(is_equal_approx(at.call(4.9), 30.0), "...and holds")
	_ok(is_equal_approx(at.call(5.0), 30.0) and at.call(6.0) > 30.0 and is_equal_approx(at.call(7.0), 60.0) and is_equal_approx(at.call(9.0), 60.0),
		"a damp begins at its moment from where the last left it, eases out, and holds")
	_ok(StageKeys.value_at(Vector3(0, 0, 4), keys, "camera.eye", 0.5) == Vector3(0, 0, 4)
		and StageKeys.value_at(Vector3(0, 0, 4), keys, "camera.eye", 1.0) == Vector3(0, 1, 2), "a place moves as one, a key with no seconds a cut")
	var board := {"sequence": [{"scene": "stage", "hold": 8.0, "cast": [{"id": "blue", "kind": "prism"}],
		"track": {"nominal": 8.0, "spans": [{"from": 0.5, "to": 2.0, "action": "arrive", "target": "blue"}],
			"keys": [{"field": "camera.fov", "at": 3.0, "to": 30, "over": 1.0, "ease": "ramp"}]}}]}
	var tl := Storyboard.timeline(board)
	var g: Dictionary = tl["groups"][0]
	var cam: Dictionary = {}
	var verb: Dictionary = {}
	for l in g["lanes"]:
		if String(l["id"]) == "camera":
			cam = (l["items"] as Array)[0]
		if String(l["id"]) == "blue":
			verb = (l["items"] as Array)[0]
	_ok(String(cam.get("label", "")) == "camera.fov" and Timeline.seekable(g, cam) and not Timeline.seekable(g, verb)
		and String(cam.get("ease", "")) == "ramp" and DataPath.same(cam["source"], ["sequence", 0, "track", "keys", 0]),
		"a key is a flag in lane \"camera\", seekable where a verb is not, its source its place in the storyboard: %s" % str(cam))
	_ok(Timeline.check(tl).is_empty(), "the timeline has no problems")
	# AN ACTOR'S OWN VALUES: a key names its actor, is shown in that actor's lane, and moves only that actor's - THE CONTROL a key with
	# no actor, said and left out
	var ak := StageKeys.sanitize([{"field": "actor.scale", "actor": "blue", "at": 2.0, "to": 0.6, "over": 1.0, "ease": "ramp"},
		{"field": "actor.hue", "at": 1.0, "to": 0.1}])
	_ok((ak["keys"] as Array).size() == 1 and " ".join(ak["notes"]).contains("names no `actor`"), "an actor's key names its actor; one that does not is said and left out")
	var aks: Array = ak["keys"]
	_ok(is_equal_approx(float(StageKeys.value_at(0.3, aks, "actor.scale", 2.0, "blue")), 0.6) and float(StageKeys.value_at(0.3, aks, "actor.scale", 2.0, "red")) == 0.3
		and StageKeys.first_start(aks, "actor.scale", "blue") == 1.0 and StageKeys.first_start(aks, "actor.scale", "red") == INF,
		"it moves its own actor's value alone, from its first key on")
	# THE LOOK'S DIALS: a key names its filter, moves only that filter's, is named and laned as the Look's - THE CONTROL a look key
	# naming no filter, said and left out
	var lk := StageKeys.sanitize([{"field": "look", "filter": "slip", "at": 1.0, "to": 0.9, "over": 1.0, "ease": "ramp"},
		{"field": "look", "at": 1.0, "to": 0.5}])
	var lks: Array = lk["keys"]
	_ok(lks.size() == 1 and " ".join(lk["notes"]).contains("names no `filter`") and StageKeys.key_name(lks[0]) == "look.slip",
		"a key on the Look names its filter; one that does not is said and left out (%s)" % " ".join(lk["notes"]))
	_ok(is_equal_approx(float(StageKeys.value_at(0.1, lks, "look", 1.0, "slip")), 0.9) and float(StageKeys.value_at(0.1, lks, "look", 1.0, "pointillism")) == 0.1,
		"it turns its own filter's dial alone")
	var lb := {"sequence": [{"scene": "stage", "hold": 4.0, "cast": [{"id": "blue", "kind": "prism"}],
		"track": {"nominal": 4.0, "keys": [{"field": "look", "filter": "slip", "at": 2.0, "to": 0.9}]}}]}
	var lane_ids: Array = ((Storyboard.timeline(lb)["groups"] as Array)[0]["lanes"] as Array).map(func(l: Dictionary) -> String: return String(l["id"]))
	_ok(lane_ids.has("look"), "on the timeline it stands in lane \"look\" (%s)" % str(lane_ids))
	board["sequence"][0]["track"]["keys"].append({"field": "actor.scale", "actor": "blue", "at": 4.0, "to": 0.6, "over": 1.0})
	var lanes: Dictionary = {}
	for l in Storyboard.timeline(board)["groups"][0]["lanes"]:
		lanes[String(l["id"])] = (l["items"] as Array).map(func(it: Dictionary) -> String: return String(it["label"]))
	_ok((lanes.get("blue", []) as Array).has("blue.scale"), "it stands in its actor's lane, beside its verbs: %s" % str(lanes))
	if _fails == 0:
		print("stage_keys_check: ALL OK")
		quit(0)
		return
	print("stage_keys_check: %d FAILED" % _fails)
	quit(1)


func _ok(cond: bool, msg: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + msg)
	if not cond:
		_fails += 1
