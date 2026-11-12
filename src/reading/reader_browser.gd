extends RefCounted
class_name ReaderBrowser

## ReaderBrowser - the Speaker row's Browse...: every reader of the voice on screen with who they are (a filter
## by gender, a search over the descriptions), so a reader is chosen by description rather than by stepping
## through numbers and listening to each.
##
## On a voice whose readers blend (its backend says `blend`: Kokoro's packs), each reader is ticked, not picked:
## one ticked is that reader, two or more a new voice made of them ([VoiceBlend]) - each with a weight, and in
## Sound and delivery a part - by the method and accent picked along the top. A reader stays ticked while the
## list is filtered past it.
##
## Nothing ticked is a way through, never a pick: the last tick comes off, the tab keeps reading in what it last
## had, Test waits for a tick, and the next tick is that reader alone.
##
## Test is at the top: the Voice card's own Test ([method ReadingCast.press_test]), the passage read in what is
## ticked now. Every change reaches the tab as it is made, as a step of the Speaker number does.
##
## A part of the cast ([ReadingCast]): it reads the voice on screen and its readers from the cast, and hands back
## a reader and a blend ([method ReadingCast.pick]).

## The cast this is a part of.
var cast: ReadingCast

var _popup: PopupPanel
var _tree: Tree
var _test: Button
var _method: OptionButton
var _accent: OptionButton
var _which: OptionButton
var _find: LineEdit
var _summary: Label
var _all: Array = []           # every reader of the voice: [{i, reader, g, d}]
var _blends := false           # whether this voice's readers blend
var _on: Array = []            # what is ticked, in the order ticked: [{i, reader, weight, part}]
var _method_key := "mix"
var _accent_key := ""


func _init(owner: ReadingCast) -> void:
	cast = owner


## Open on the voice on screen, what it reads in now ticked (or picked).
func open() -> void:
	var vid := cast._selected_voice_id()
	_all = VoiceReaders.all(vid)
	if _all.is_empty():
		cast.panel._set_status("Nothing is known about this voice's readers (is it installed, and multi-speaker?).")
		return
	_blends = cast.blends(vid)
	_take_selection()
	if _popup != null and is_instance_valid(_popup):
		_popup.queue_free()
	_popup = PopupPanel.new()
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(620, 500)
	box.add_theme_constant_override("separation", 6)
	_popup.add_child(box)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	box.add_child(top)
	_test = Button.new()
	_test.focus_mode = Control.FOCUS_NONE
	_test.tooltip_text = ("Hear what is ticked now: the Voice card's short fixed passage, read with every setting "
		+ "on this tab. Press again to stop; the press after that reads what is ticked then.")
	_test.pressed.connect(cast.press_test)
	top.add_child(_test)
	show_testing(cast.panel._test_busy())
	_method = OptionButton.new()
	_method.focus_mode = Control.FOCUS_NONE
	_method.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for k in VoiceBlend.METHODS:
		_method.add_item(Registry.label(VoiceBlend.METHODS, k))
		_method.set_item_tooltip(_method.item_count - 1, Registry.blurb(VoiceBlend.METHODS, k))
	_method.select(VoiceBlend.METHODS.keys().find(_method_key))
	_method.item_selected.connect(_method_picked)
	top.add_child(_method)
	_accent = OptionButton.new()
	_accent.focus_mode = Control.FOCUS_NONE
	for k in VoiceBlend.ACCENTS:
		_accent.add_item(Registry.label(VoiceBlend.ACCENTS, k))
		_accent.set_item_tooltip(_accent.item_count - 1, Registry.blurb(VoiceBlend.ACCENTS, k))
	_accent.select(VoiceBlend.ACCENTS.keys().find(_accent_key))
	_accent.item_selected.connect(func(i: int) -> void:
		_accent_key = String(VoiceBlend.ACCENTS.keys()[i])
		_hand_back())
	top.add_child(_accent)
	_method.visible = _blends
	_accent.visible = _blends

	var bar := HBoxContainer.new()
	box.add_child(bar)
	_which = OptionButton.new()
	for label in ["All", "♀ Female", "♂ Male"]:
		_which.add_item(label)
	_which.item_selected.connect(func(_i: int) -> void: _fill())
	bar.add_child(_which)
	_find = LineEdit.new()
	_find.placeholder_text = "Search: soft, deep, calm, raspy…"
	_find.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_find.clear_button_enabled = true
	_find.text_changed.connect(func(_t: String) -> void: _fill())
	bar.add_child(_find)

	_tree = Tree.new()
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.hide_root = true
	_tree.select_mode = Tree.SELECT_ROW
	_tree.item_edited.connect(_edited)
	_tree.item_selected.connect(_selected)
	box.add_child(_tree)

	# One line, trimmed, the whole of it its tooltip: a wrapped label has no width before it is laid out and asks a
	# line a letter (a popup opened 1,500 px tall for an 88-letter summary and never shrank - see the guard below)
	_summary = Label.new()
	_summary.add_theme_font_size_override("font_size", 12)
	_summary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_summary.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_child(_summary)
	var note := Label.new()
	note.text = VoiceReaders.about_of(vid)
	note.add_theme_font_size_override("font_size", 10)
	note.modulate = Color(1, 1, 1, 0.55)
	box.add_child(note)

	cast.panel.add_child(_popup)
	_fill()
	_say()
	# Never the stage's height: a popup is sized to what its controls ask as it opens, before they are laid out,
	# and never shrinks after, so the browser is capped at a share of the stage.
	var stage := cast.panel.get_viewport()          # none for a panel out of the tree (a gate's)
	if stage != null:
		var room := stage.get_visible_rect().size
		_popup.max_size = Vector2i(int(room.x * 0.9), int(room.y * 0.8))
	_popup.popup_centered()


## Whether the browser is open.
func is_open() -> bool:
	return _popup != null and is_instance_valid(_popup) and _popup.visible


## The row of reader [param i], or null where the filter leaves it out.
func row_of(i: int) -> TreeItem:
	if _tree == null or _tree.get_root() == null:
		return null
	for it in _tree.get_root().get_children():
		if int(it.get_metadata(0)) == i:
			return it
	return null


## The Test button says what pressing it does now, as the Voice card's does.
func show_testing(on: bool) -> void:
	if _test != null and is_instance_valid(_test):
		_test.text = "Test ■" if on else "Test"
		_test.disabled = _on.is_empty() and not on      # nothing ticked hears nothing; a test playing still stops


## What the tab reads in now, as ticks: its blend's readers (those this voice holds), or its one reader.
func _take_selection() -> void:
	_on = []
	_method_key = "mix"
	_accent_key = ""
	var b := VoiceBlend.parse(cast.blend_now()) if _blends else {}
	for v in b.get("voices", []):
		var at := _index_of(String((v as Dictionary)["reader"]))
		if at >= 0:
			_on.append({"i": at, "reader": String((v as Dictionary)["reader"]),
				"weight": float((v as Dictionary)["weight"]), "part": String((v as Dictionary)["part"])})
	if _on.size() >= 2:
		_method_key = String(b["method"])
		_accent_key = String(b["accent"])
		return
	_on = []
	var i := clampi(cast.speaker_now(), 0, _all.size() - 1)
	_on.append({"i": i, "reader": String((_all[i] as Dictionary).get("reader", "")), "weight": 1.0, "part": "both"})


func _index_of(reader: String) -> int:
	for r in _all:
		if String((r as Dictionary).get("reader", "")) == reader:
			return int((r as Dictionary)["i"])
	return -1


func _ticked(i: int) -> int:
	for k in _on.size():
		if int((_on[k] as Dictionary)["i"]) == i:
			return k
	return -1


func _parts() -> bool:
	return _blends and bool(Registry.field(VoiceBlend.METHODS, _method_key, "parts", false))


func _weighted() -> bool:
	return _blends and not bool(Registry.field(VoiceBlend.METHODS, _method_key, "unweighted", false))


## The list, as the filter and the search leave it: a tick, a weight (where the method weighs) and a part
## (where it gives parts) on a voice whose readers blend, a row to pick on one whose readers do not.
func _fill() -> void:
	_tree.clear()
	_tree.columns = 1 + (1 if _weighted() else 0) + (1 if _parts() else 0)
	_tree.column_titles_visible = _blends
	if _blends:
		_tree.set_column_title(0, "Reader")
	if _weighted():
		_tree.set_column_title(1, "Weight")
		_tree.set_column_expand(1, false)
		_tree.set_column_custom_minimum_width(1, 76)
		if _parts():
			_tree.set_column_title(2, "Part")
			_tree.set_column_expand(2, false)
			_tree.set_column_custom_minimum_width(2, 96)
	var root := _tree.create_item()
	var want: String = ["", "F", "M"][_which.selected]
	var words := _find.text.strip_edges().to_lower().split(" ", false)
	var first: TreeItem = null
	for r in _all:
		var d: Dictionary = r
		if not want.is_empty() and String(d["g"]) != want:
			continue
		var hay := String(d["d"]).to_lower()
		var ok := true
		for w in words:
			ok = ok and hay.contains(w)
		if not ok:
			continue
		var it := _tree.create_item(root)
		it.set_metadata(0, int(d["i"]))
		if _blends:
			it.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
			it.set_editable(0, true)
		it.set_text(0, "%d   %s" % [int(d["i"]), VoiceReaders.line(d, 10)])
		_shape(it)
		if first == null and _ticked(int(d["i"])) >= 0:
			first = it
	if first != null:
		if not _blends:
			first.select(0)
		_tree.scroll_to_item.call_deferred(first)


## One row's cells as what is ticked says: its tick, and its weight and part while it is ticked.
func _shape(it: TreeItem) -> void:
	if not _blends:
		return
	var k := _ticked(int(it.get_metadata(0)))
	it.set_checked(0, k >= 0)
	for col in range(1, _tree.columns):
		if k < 0:
			it.set_cell_mode(col, TreeItem.CELL_MODE_STRING)
			it.set_text(col, "")
			it.set_editable(col, false)
			continue
		var v: Dictionary = _on[k]
		it.set_cell_mode(col, TreeItem.CELL_MODE_RANGE)
		it.set_editable(col, true)
		if col == 1:
			it.set_range_config(1, VoiceBlend.WEIGHT_MIN, VoiceBlend.WEIGHT_MAX, 0.1)
			it.set_range(1, float(v["weight"]))
			it.set_tooltip_text(1, "Its share of the blend: a ratio, so 2 and 1 are two parts to one.")
		else:
			var labels := PackedStringArray()
			for p in VoiceBlend.PARTS:
				labels.append(Registry.label(VoiceBlend.PARTS, p))
			it.set_text(2, ",".join(labels))
			it.set_range(2, VoiceBlend.PARTS.keys().find(String(v["part"])))
			it.set_tooltip_text(2, Registry.blurb(VoiceBlend.PARTS, String(v["part"])))


## A tick, a weight or a part changed.
func _edited() -> void:
	var it := _tree.get_edited()
	if it != null:
		edit(it, _tree.get_edited_column())


## Row [param it]'s cell in column [param col] as it now stands, taken: a tick (0), a weight (1) or a part (2).
func edit(it: TreeItem, col: int) -> void:
	var i := int(it.get_metadata(0))
	var k := _ticked(i)
	match col:
		0:
			if it.is_checked(0) and k < 0:
				var d: Dictionary = _all[i]
				# in Sound and delivery the first one ticked gives the sound and the rest the delivery
				_on.append({"i": i, "reader": String(d.get("reader", "")), "weight": 1.0,
					"part": ("delivery" if _on.size() > 0 else "sound") if _parts() else "both"})
			elif not it.is_checked(0) and k >= 0:
				_on.remove_at(k)
		1:
			if k >= 0:
				(_on[k] as Dictionary)["weight"] = it.get_range(1)
		2:
			if k >= 0:
				(_on[k] as Dictionary)["part"] = String(VoiceBlend.PARTS.keys()[clampi(int(it.get_range(2)), 0,
					VoiceBlend.PARTS.size() - 1)])
	_reshape.call_deferred(i)          # its weight and part shown or hidden - never inside the edit
	_hand_back()


## Reader [param i]'s row shaped again - found again, since the list may have been filled anew since.
func _reshape(i: int) -> void:
	var it := row_of(i)
	if it != null:
		_shape(it)


## A row picked, on a voice whose readers do not blend: that reader.
func _selected() -> void:
	if _blends:
		return
	var it := _tree.get_selected()
	if it == null:
		return
	var i := int(it.get_metadata(0))
	_on = [{"i": i, "reader": String((_all[i] as Dictionary).get("reader", "")), "weight": 1.0, "part": "both"}]
	_hand_back()


## A method picked: Sound and delivery gives a blend of readers all on both sides the first one's sound
## and the rest's delivery, so it is heard to do something the moment it is picked.
func _method_picked(i: int) -> void:
	_method_key = String(VoiceBlend.METHODS.keys()[i])
	if _parts() and _on.all(func(v: Dictionary) -> bool: return String(v["part"]) == "both"):
		for k in _on.size():
			(_on[k] as Dictionary)["part"] = "sound" if k == 0 else "delivery"
	_fill()
	_hand_back()


## What is ticked, to the tab: its first reader as the Speaker number, and the blend when there are two.
## Nothing ticked hands back nothing: the tab reads on in what it had.
func _hand_back() -> void:
	if not _on.is_empty():
		cast.pick(int((_on[0] as Dictionary)["i"]), VoiceBlend.compose(_method_key, _accent_key, _on))
	_say()


## Under the list: the blend in words, the one reader and how to make a blend of it - or, with nothing
## ticked, what to do and what the tab reads in until then.
func _say() -> void:
	if _summary == null:
		return
	if _on.is_empty():
		var now := VoiceBlend.line(cast.blend_now(), true)
		if now.is_empty():
			now = String((_all[clampi(cast.speaker_now(), 0, _all.size() - 1)] as Dictionary)["d"]).get_slice(", ", 0)
		_summary.text = "Nothing ticked: tick one, or two or more to blend. Until then it reads in %s." % now
	else:
		var spec := VoiceBlend.compose(_method_key, _accent_key, _on)
		var one := VoiceReaders.line(_all[int((_on[0] as Dictionary)["i"])], 10)
		_summary.text = VoiceBlend.line(spec) if not spec.is_empty() \
			else one + ("    -  tick another to blend them into a new voice" if _blends else "")
	_summary.tooltip_text = _summary.text
	if _method != null:
		_method.disabled = _on.size() < 2
		_accent.disabled = _on.size() < 2
	show_testing(cast.panel._test_busy())
