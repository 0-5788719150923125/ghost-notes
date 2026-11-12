extends Window
class_name DesignWindow

## DesignWindow - ✎ ON A PAINTED DESIGN: its elements as rows (next/editing.md step 4: "A painted design: its elements as rows
## (layer, tool, pot, beat, seconds): reorder, move to a beat, re-time, remove"). What a late fix to 732687 cost a rule, a repaint
## and a splice by hand (`el_224`, one liner run on the jaw; `el_208`, one blend) is a press here.
##
## Each element of each design (`skin.json`, [Skins]) a row: its id, the layer it lays, the tool and how, the pot, then what may
## change - the beat it is laid in, the seconds it may take, its place among the rest (↑ ↓), and ✕. Apply hands the design back
## to whoever opened it ([member take]), who writes it as a hand's version and makes the work again from it; the elements' own
## programs (the host's) are untouched - only which run, when and for how long.

## (doc: Dictionary) -> String: the design written, "" when it was, else why not.
var take: Callable = Callable()

var _doc := {}
var _beats: Array = []
var _grid: GridContainer
var _said: Label
var _rows: Array = []          # per row: {g, e, beat: OptionButton, seconds: SpinBox, gone}


func _init() -> void:
	visible = false
	transient = true
	min_size = Vector2i(820, 440)
	title = "The design's elements"
	close_requested.connect(hide)
	var bg := PanelContainer.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	bg.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	margin.add_child(col)
	_said = Label.new()
	_said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_said.modulate = Color(1.0, 0.75, 0.45)
	_said.visible = false
	col.add_child(_said)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 9
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_grid)
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_END
	col.add_child(foot)
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.pressed.connect(hide)
	foot.add_child(cancel)
	var apply_b := Button.new()
	apply_b.text = "Apply"
	apply_b.tooltip_text = "Write the design as yours (what stood a version back) and make the work again from it."
	apply_b.pressed.connect(func() -> void: apply())
	foot.add_child(apply_b)


## Open on design document [param doc] (`skin.json`), its elements' beats chosen among [param beats] ("intro", "1", ... "close").
func open_on(doc: Dictionary, beats: Array, over: Node) -> void:
	_doc = doc.duplicate(true)
	_beats = beats
	_said.visible = false
	_build()
	if not is_inside_tree():
		over.add_child(self)
	TextField.pop_up(self, over, Vector2(0.72, 0.78))


func _build() -> void:
	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	_rows = []
	for h in ["Element", "Layer", "Tool", "Pot", "Beat", "Seconds", "", "", ""]:
		var l := Label.new()
		l.text = h
		l.modulate = Color(1, 1, 1, 0.6)
		_grid.add_child(l)
	var designs: Array = _doc.get("designs", []) if _doc.get("designs") is Array else []
	for gi in designs.size():
		var els: Array = (designs[gi] as Dictionary).get("elements", []) if designs[gi] is Dictionary else []
		for ei in els.size():
			var e: Dictionary = els[ei] if els[ei] is Dictionary else {}
			var plan: Dictionary = e.get("plan", {}) if e.get("plan") is Dictionary else {}
			for text in [String(e.get("id", "")), String(e.get("stage", "")), "%s, %s" % [String(plan.get("part", "")), String(plan.get("how", ""))],
					String(plan.get("pot", ""))]:
				var l := Label.new()
				l.text = text
				l.clip_text = true
				l.custom_minimum_size.x = 90
				_grid.add_child(l)
			var beat := OptionButton.new()
			for b in _beats:
				beat.add_item(String(b))
			beat.select(maxi(_beats.find(str(plan.get("beat", ""))), 0))
			_grid.add_child(beat)
			var secs := SpinBox.new()
			secs.min_value = 0.5
			secs.max_value = 600.0
			secs.step = 0.5
			secs.value = float(plan.get("seconds", 10.0))
			_grid.add_child(secs)
			var row := {"g": gi, "e": ei, "beat": beat, "seconds": secs}
			_rows.append(row)
			for glyph in ["↑", "↓", "✕"]:
				var b := Button.new()
				b.text = glyph
				b.flat = true
				b.tooltip_text = {"↑": "Laid before the one above it", "↓": "Laid after the one below it", "✕": "Not laid at all"}[glyph]
				b.pressed.connect(_press.bind(gi, ei, glyph))
				_grid.add_child(b)


## The rows' values taken into the design ([member _doc]), as they stand.
func _gather() -> void:
	for r in _rows:
		var e: Dictionary = ((_doc["designs"] as Array)[int(r["g"])] as Dictionary)["elements"][int(r["e"])]
		if not (e.get("plan") is Dictionary):
			continue
		var plan: Dictionary = e["plan"]
		var b := (r["beat"] as OptionButton).selected
		if b >= 0 and b < _beats.size():
			plan["beat"] = String(_beats[b])
		plan["seconds"] = (r["seconds"] as SpinBox).value


func _press(gi: int, ei: int, glyph: String) -> void:
	_gather()
	var els: Array = ((_doc["designs"] as Array)[gi] as Dictionary)["elements"]
	match glyph:
		"✕":
			els.remove_at(ei)
		"↑":
			if ei > 0:
				var e: Variant = els[ei]
				els.remove_at(ei)
				els.insert(ei - 1, e)
		"↓":
			if ei < els.size() - 1:
				var e: Variant = els[ei]
				els.remove_at(ei)
				els.insert(ei + 1, e)
	_build()


## APPLY: the design as the rows say, handed over; written, the window closes - refused, it stays, saying why.
func apply() -> String:
	_gather()
	var err: String = take.call(_doc.duplicate(true)) if take.is_valid() else "nothing here can take it"
	if err.is_empty():
		hide()
	else:
		_said.text = "Not written: " + err
		_said.visible = true
	return err


## The design as it stands in the rows (for a gate).
func design() -> Dictionary:
	_gather()
	return _doc.duplicate(true)
