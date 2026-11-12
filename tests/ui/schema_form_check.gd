extends SceneTree

## schema_form_check - a form's controls ([SchemaForm]; next/editing.md step 5).
##
##   godot --headless --path . --script res://tests/ui/schema_form_check.gd
##
## What it holds:
##   - a bounded number is a slider and its box: a drag is one edit, written as it ends (control: the steps of the drag write
##     nothing), the box writes what is typed, and unset both stand at the default, dimmed;
##   - the box's edit is handed over after its press, so an owner that draws its form again never frees the box mid-press
##     (control: a slider's drag, handed over at once);
##   - a color is a picker, written `#rrggbb`;
##   - a reference is a choice among the names the context lists under its `of`, "" first;
##   - one row shape ([method SchemaForm.normalize]): a layer's, a scene's, a tonemap adjustment's and a filter's row each drawn as
##     the form's own (control: a row already in that shape is left as it is).

var _fails := 0


func _initialize() -> void:
	_run.call_deferred()


## (A range says it changed on the next frame, so each change is awaited.)
func _run() -> void:
	var form := SchemaForm.new()
	root.add_child(form)
	var edits: Array = []
	form.edited.connect(func(k: String, v: Variant) -> void: edits.append([k, v]))
	var schema := {"fov": {"label": "Field of view", "type": "float", "min": 10.0, "max": 120.0, "step": 1.0, "default": 48.0, "blurb": "How wide."},
		"tint": {"label": "Tint", "type": "color", "default": "#ff0000", "blurb": "Its color."},
		"who": {"label": "Who", "type": "ref", "of": "actors", "blurb": "Whom it is aimed at."}}
	form.show_fields(schema, {"tint": "#00ff00"}, {"actors": ["blue", "red"]})
	var slide: HSlider = _first(form, "HSlider")
	var spin: SpinBox = _first(form, "SpinBox")
	_ok(slide != null and spin != null and is_equal_approx(slide.value, 48.0) and slide.get_parent().modulate.a < 1.0,
		"a bounded number unset is a slider and its box at the default, dimmed")
	slide.drag_started.emit()
	slide.value = 60.0
	await process_frame
	slide.value = 70.0
	await process_frame
	_ok(edits.is_empty(), "the control: the steps of a drag write nothing")
	slide.drag_ended.emit(true)
	_ok(edits == [["fov", 70.0]] and is_equal_approx(spin.value, 70.0), "the drag is one edit, written as it ends: %s (box %s)" % [str(edits), spin.value])
	spin.value = 33.0
	await process_frame
	_ok(edits.back() == ["fov", 33.0] and is_equal_approx(slide.value, 33.0), "the box writes what is typed, the slider following: %s (slider %s)" % [str(edits.back()), slide.value])
	# The box's edit arrives after its press: an owner that draws its form again on an edit would free the box between its value and
	# its own repeat timer. Control: the slider's drag above, handed over at once
	var redraw := SchemaForm.new()
	root.add_child(redraw)
	var row := {"hold": {"type": "float", "label": "Hold", "default": 4.0, "min": 0.5, "max": 20.0, "step": 0.5}}
	var got: Array = []
	redraw.edited.connect(func(k: String, v: Variant) -> void:
		got.append([k, v])
		redraw.show_fields(row, {"hold": v}))
	redraw.show_fields(row, {"hold": 4.0})
	await process_frame
	var box: SpinBox = _first(redraw, "SpinBox")
	box.value = 4.5
	var during := got.size()
	await process_frame
	_ok(during == 0 and got.size() == 1 and box != _first(redraw, "SpinBox"), "the box's edit is handed over after its press, the form drawn again then (%d during, %d after)" % [during, got.size()])
	redraw.queue_free()
	var pick: ColorPickerButton = _first(form, "ColorPickerButton")
	_ok(pick != null and pick.color.is_equal_approx(Color("#00ff00")), "a color is a picker, showing what is written")
	pick.color_changed.emit(Color("#3366cc"))
	_ok(edits.back() == ["tint", "#3366cc"], "written #rrggbb: %s" % str(edits.back()))
	var ref: OptionButton = null
	for o in form.find_children("*", "OptionButton", true, false):
		if (o as OptionButton).item_count == 3:
			ref = o
	_ok(ref != null and ref.get_item_text(1) == "blue" and ref.get_item_text(2) == "red", "a reference is a choice among the names its context lists")
	# One row shape: a row in any registry's dialect is drawn as this form's own - a layer's flag a switch and its txt a line, a
	# tonemap adjustment (bounds, no type) and a filter (a dial, no type, no bounds) sliders, a scene's listed choice a pick, a
	# rolled number its range; control: a row already in this shape is left as it is
	var dialects := {"flag": {"label": "Flag", "type": "flag", "default": false}, "txt": {"label": "Words", "type": "txt"},
		"exposure": Tonemaps.ADJUSTMENTS["exposure"], "slip": Filters.REGISTRY["slip"],
		"choice": {"label": "Kind", "type": "choice", "options": ["", "a", "b"]}, "rolled": {"label": "Rolled", "type": "num", "range": [1, 4]}}
	var n := {}
	for k in dialects:
		n[k] = SchemaForm.normalize(dialects[k])
	_ok(n["flag"]["type"] == "bool" and n["txt"]["type"] == "text" and n["exposure"]["type"] == "float" and n["slip"]["type"] == "float"
		and float(n["slip"]["max"]) == 1.0 and n["choice"]["type"] == "enum" and n["rolled"]["default"] == [1, 4],
		"every dialect is turned to the one shape: %s" % str(n.values().map(func(r: Dictionary) -> String: return String(r["type"]))))
	var own := {"type": "float", "label": "Seconds", "min": 0.5, "max": 9.0, "default": 1.0}
	_ok(DataPath.same(SchemaForm.normalize(own), own), "the control: a row already in the shape is left as it is")
	form.show_fields(dialects, {})
	_ok(form.find_children("*", "CheckBox", true, false).size() == 1 and form.find_children("*", "HSlider", true, false).size() == 2
		and form.find_children("*", "OptionButton", true, false).size() == 1, "drawn as the form's own: a switch, two sliders, a pick")
	form.queue_free()
	if _fails == 0:
		print("schema_form_check: ALL OK")
		quit(0)
		return
	print("schema_form_check: %d FAILED" % _fails)
	quit(1)


func _first(n: Node, cls: String) -> Node:
	var found := n.find_children("*", cls, true, false)
	return found[0] if not found.is_empty() else null


func _ok(cond: bool, msg: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + msg)
	if not cond:
		_fails += 1
