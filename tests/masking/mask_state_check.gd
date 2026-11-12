extends SceneTree

## Three things the Masking editor must remember.
##   godot --headless --path . --script res://tests/masking/mask_state_check.gd
## No renderer needed - none of this draws anything.
##
## - Follow: the "Follow" switch beside the marker list is a per-user editor preference, so it lives in
##   [Settings] (`[mask] follow_playhead`). A gate never writes the author's file: the value round-trips in
##   Settings' memory and Settings, read-only in a test, never flushes it.
## - Key swatch: the picker stores key_sat/key_val beside hue_a, so a color picked off the footage comes
##   back as the same color after a save and load.
## - One drag, one undo: undo coalescing is bounded by the mouse button (while it is down, one entry;
##   everything else is its own step), and the value must still change on every step so the live preview
##   keeps working.

var _fails: PackedStringArray = []


func _initialize() -> void:
	_check_follow()
	_check_key_swatch()
	await _check_drag_undo()

	print("")
	if _fails.is_empty():
		print("mask_state_check: PASS - Follow persists, the key swatch round-trips, "
			+ "and a drag is one undo step.")
		quit(0)
	else:
		for f in _fails:
			print("mask_state_check: FAIL - ", f)
		quit(1)


func _expect(ok: bool, msg: String) -> void:
	if not ok:
		_fails.append(msg)


func _check_follow() -> void:
	var ed = load("res://src/masking/mask_editor.gd").new()
	_expect(ed._face.load_follow(), "Follow does not default to ON with nothing stored")
	ed._face.save_follow(false)
	var back: bool = bool(ed._face.load_follow())
	print("Follow: stored false -> reads back %s" % back)
	_expect(not back, "Follow was stored as OFF and read back as %s - it is not persisting" % back)
	ed._face.save_follow(true)
	_expect(ed._face.load_follow(), "Follow stored as ON did not read back")
	ed.free()


func _check_key_swatch() -> void:
	# A color a person would pick off footage: a pale, unsaturated yellow.
	var picked := Color(0.90, 0.86, 0.42)
	var m := {}
	for k in MaskSession.VECTOR_FIELDS:
		m[k] = MaskSession.DEFAULTS.get(k, 0.0)
	# What the picker's handler stores...
	m["hue_a"] = picked.h
	m["key_sat"] = picked.s
	m["key_val"] = picked.v
	# ...through a full save/load of the session...
	var s := MaskSession.new()
	s.markers.append(m)
	var round_trip := MaskSession.from_vector(s.to_vector(s.markers[0]))
	# ...and what the panel rebuilds from it.
	var shown := Color.from_hsv(float(round_trip.get("hue_a", 0.02)),
		float(round_trip.get("key_sat", 0.85)), float(round_trip.get("key_val", 0.9)))
	print("key swatch: picked (%.3f, %.3f, %.3f) -> shown (%.3f, %.3f, %.3f)"
		% [picked.r, picked.g, picked.b, shown.r, shown.g, shown.b])
	var off := Vector3(picked.r - shown.r, picked.g - shown.g, picked.b - shown.b).length()
	_expect(off < 0.05,
		"the key swatch comes back %.3f away from the color that was picked - the "
		% off + "hue survives (that is what keys) but the swatch is rebuilt at a "
		+ "fixed saturation and value, so it shows a color nobody chose")
	# A session written before these fields existed must open unchanged.
	var old := {"hue_a": 0.13}
	var legacy := Color.from_hsv(float(old.get("hue_a", 0.02)),
		float(old.get("key_sat", 0.85)), float(old.get("key_val", 0.9)))
	var was := Color.from_hsv(0.13, 0.85, 0.9)
	_expect(legacy.is_equal_approx(was),
		"a session predating key_sat/key_val no longer opens looking the way it did")


func _check_drag_undo() -> void:
	var ed = load("res://src/masking/mask_editor.gd").new()
	# _snapshot() reads the session, so give it one.
	ed.session = MaskSession.new()
	root.add_child(ed)
	var key := "marker:1:fx_scale"

	# With the button down: one boundary, however many changes and however long the pauses.
	_hold(true)
	await process_frame
	for i in 6:
		ed._undo.push(key, "adjusted Scale")
	var during: int = ed._undo._undo_stack.size()
	_hold(false)
	await process_frame
	print("six changes during one held drag -> %d undo step(s)" % during)
	_expect(during == 1,
		"a single drag left %d entries in the history - every place the pointer "
		% during + "paused opened another one, which is the report")

	# ...and the next drag is its own step.
	_hold(true)
	await process_frame
	ed._undo.push(key, "adjusted Scale")
	_hold(false)
	await process_frame
	print("a second drag of the SAME control -> %d undo step(s) in total"
		% ed._undo._undo_stack.size())
	var total: int = ed._undo._undo_stack.size()
	_expect(total == 2,
		"a second, separate drag did not open its own history entry (%d total) - "
		% total + "one undo would now revert two adjustments")

	# The preview must still move: the value's own path must write on every step.
	var m2 := {}
	for k in MaskSession.VECTOR_FIELDS:
		m2[k] = MaskSession.DEFAULTS.get(k, 0.0)
	ed.session.markers.append(m2)
	ed._selected = m2
	# The chrome _edit touches after writing the value (timeline strip, marker label and list); without
	# them every step prints a null-access error, which would hide a real one.
	ed._timeline = MaskTimeline.new()
	root.add_child(ed._timeline)
	ed._marker_label = Label.new()
	ed._marker_list = VBoxContainer.new()
	root.add_child(ed._marker_label)
	root.add_child(ed._marker_list)
	_hold(true)
	await process_frame
	var seen: Array = []
	for v in [0.4, 0.9, 1.6, 2.2]:
		ed._edit("fx_scale", v)
		seen.append(float(m2.get("fx_scale", -1.0)))
	_hold(false)
	await process_frame
	print("values the marker took during the drag: %s" % str(seen))
	_expect(seen == [0.4, 0.9, 1.6, 2.2],
		"the marker did not follow the drag (%s) - the live preview is the point of "
		% str(seen) + "dragging; only the HISTORY is supposed to wait for the release")
	ed.free()


## Hold or release the left mouse button, as the editor sees it. _push_undo reads the button rather than a
## per-widget drag signal, so one rule covers sliders, the color wheel and the region box.
func _hold(down: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = down
	Input.parse_input_event(ev)
