extends SceneTree

## design_window_check - a painted design's elements as rows ([DesignWindow]; next/editing.md step 4).
##
##   godot --headless --path . --script res://tests/table_show/design_window_check.gd
##
## On a made design of three elements: an element moved to another beat and re-timed, one removed, one moved up - and the
## design handed back is exactly that, every other key of every element as it was. The control: opened and applied with no
## change, the design handed back is the one given.

var _fails := 0


func _initialize() -> void:
	var doc := {"designs": [{"thing": "mask", "part": "face", "elements": [
		{"id": "el_1", "stage": "white base", "paint": "white", "fill": "M 0 0 Z", "plan": {"part": "sponge", "how": "sponge", "beat": "intro", "seconds": 40.0, "pot": "white pot", "host": "el_1"}},
		{"id": "el_2", "stage": "rust", "paint": "rust", "fill": "M 0 0 Z", "plan": {"part": "flat brush", "how": "sweep", "beat": "1", "seconds": 30.0, "pot": "rust pot", "host": "el_2"}},
		{"id": "el_3", "stage": "lines", "paint": "black", "fill": "M 0 0 Z", "plan": {"part": "liner", "how": "line", "beat": "2", "seconds": 20.0, "pot": "black pot", "host": "el_3"}}]}]}
	var w := DesignWindow.new()
	root.add_child(w)
	var got: Array = []
	w.take = func(d: Dictionary) -> String:
		got.append(d)
		return ""
	w.open_on(doc, ["intro", "1", "2", "close"], root)
	_ok(w.apply().is_empty() and DataPath.same(got[0], doc), "the control: applied with no change, the design is the one given")
	w.open_on(doc, ["intro", "1", "2", "close"], root)
	(w._rows[1]["beat"] as OptionButton).select(2)
	(w._rows[1]["seconds"] as SpinBox).value = 12.5
	w._press(0, 0, "✕")
	w._press(0, 1, "↑")
	var d := w.design()
	var els: Array = d["designs"][0]["elements"]
	_ok(els.size() == 2 and String(els[0]["id"]) == "el_3" and String(els[1]["id"]) == "el_2",
		"one removed, one moved up: %s" % str(els.map(func(e: Dictionary) -> String: return String(e["id"]))))
	_ok(String(els[1]["plan"]["beat"]) == "2" and float(els[1]["plan"]["seconds"]) == 12.5, "one moved to another beat and re-timed")
	_ok(String(els[1]["plan"]["host"]) == "el_2" and String(els[1]["fill"]) == "M 0 0 Z" and String(els[1]["stage"]) == "rust",
		"every other key of it as it was - its program, its shape, its layer")
	w.queue_free()
	if _fails == 0:
		print("design_window_check: ALL OK")
		quit(0)
		return
	print("design_window_check: %d FAILED" % _fails)
	quit(1)


func _ok(cond: bool, msg: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + msg)
	if not cond:
		_fails += 1
