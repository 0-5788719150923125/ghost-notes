extends RefCounted
class_name ReaderBrowser

## ReaderBrowser - the Voice card's Lab...: the voice on screen worked on in one place, Test at its top. Who reads (on
## a voice of more than one reader, every reader with who they are: a filter by gender, a search over the
## descriptions), and the voice's own rows - the Tone, Pace, Pause, delivery dials and room - which the cast builds
## into it ([method ReadingCast.build_voice]) and keeps as the truth for the tab on screen. A voice of one reader opens
## on its rows alone.
##
## Built once, hung on the Voice row ([method build]): its rows are in the tree wherever the card is, so a change to
## one reaches the tab whether the Lab is open or not. [method open] fills it for the voice on screen, sized to what
## that voice's Lab holds and centered in the room beside the panel - never under the panel where it fits - and it
## stays centered as what it holds changes its size ([method _center]).
##
## On a voice whose readers blend (its backend says `blend`: Kokoro's packs), each reader is ticked, not picked:
## one ticked is that reader, two or more a new voice made of them ([VoiceBlend]) - in Sound and delivery each with
## a part - by the method and accent picked along the top. A reader stays ticked while the list is filtered past it.
##
## Beside the list, THE SHAPE of the voice across each paragraph ([VoiceShape]): each reader's share as a band whose
## edges are dragged (a new reader ticked takes an even share), the Breath and Push lanes, and the noise under them (a
## kind, how far, and its Seed - a number, so the draw heard is the draw shown);
## Shapes fills them in to start from ([constant VoiceBlend.SHAPES]). One reader shaped is that reader moved. While Test
## plays, a playhead on the shape shows where the words being heard stand on it ([method ReadingAudition.place_now]).
##
## Nothing ticked is a way through, never a pick: the last tick comes off, the tab keeps reading in what it last
## had, Test waits for a tick, and the next tick is that reader alone.
##
## Test is the Voice card's own ([method ReadingCast.press_test]), the passage read in what is ticked now. Every
## change reaches the tab as it is made (a drag, as it lets go).
##
## On Ghost Notes' own voice ([FormantVoice]) the readers' pane is the fishing game that breeds it ([VoiceFishing]):
## every voice cast or held there is the tab's. Its line is let go when the Lab closes or Test plays.
##
## A part of the cast ([ReadingCast]): it reads the voice on screen and its readers from the cast, and hands back
## a reader and a blend ([method ReadingCast.pick]).

## The cast this is a part of.
var cast: ReadingCast

var _popup: PopupPanel
var _who: Label                # whose voice the Lab is working on, in which model
var _readers: VBoxContainer    # the list's pane, on a voice of more than one reader
var _fishing: VoiceFishing     # the game's pane, on the formant voice
var _sound: VBoxContainer      # the voice's own rows, the cast's
var _note: Label               # who described the readers
var _tree: Tree
var _test: Button
var _method: OptionButton
var _accent: OptionButton
var _shapes: MenuButton
var _which: OptionButton
var _find: LineEdit
var _shape: VoiceShape
var _shape_box: VBoxContainer
var _noise_kind: OptionButton
var _noise_amount: HSlider
var _noise_seed: SpinBox
var _seed_box: HBoxContainer   # "Seed" and its number, shown with the noise
var _summary: Label
var _all: Array = []           # every reader of the voice: [{i, reader, g, d}]
var _blends := false           # whether this voice's readers blend
var _on: Array = []            # what is ticked, in the order ticked: [{i, reader, part, weights}] (shares, POINTS)
var _lanes := {}               # each lane's points ([constant VoiceBlend.LANES])
var _noise := {}               # {kind, amount, seed}; {} for none
var _method_key := "mix"
var _accent_key := ""

## Room kept between the Lab and the panel beside it.
const BESIDE := 16.0


func _init(owner: ReadingCast) -> void:
	cast = owner


## The Lab, hung on [param host] (the card's Voice row) and hidden until [method open]: the column the voice's own
## rows go in is handed back for the cast to build them into.
func build(host: Node) -> VBoxContainer:
	_popup = PopupPanel.new()
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(0, 500)
	box.add_theme_constant_override("separation", 6)
	_popup.add_child(box)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	box.add_child(top)
	_test = Button.new()
	_test.focus_mode = Control.FOCUS_NONE
	_test.tooltip_text = ("Hear the voice as it stands here: the Voice card's short fixed passage, read with every "
		+ "setting on this tab and what is ticked now. Press again to stop; the press after that reads what is set then.")
	_test.pressed.connect(cast.press_test)
	top.add_child(_test)
	_who = Label.new()
	_who.add_theme_font_size_override("font_size", 12)
	_who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_who.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_who.mouse_filter = Control.MOUSE_FILTER_PASS
	top.add_child(_who)
	_method = OptionButton.new()
	_method.focus_mode = Control.FOCUS_NONE
	for k in VoiceBlend.METHODS:
		_method.add_item(Registry.label(VoiceBlend.METHODS, k))
		_method.set_item_tooltip(_method.item_count - 1, Registry.blurb(VoiceBlend.METHODS, k))
	_method.item_selected.connect(_method_picked)
	top.add_child(_method)
	_accent = OptionButton.new()
	_accent.focus_mode = Control.FOCUS_NONE
	for k in VoiceBlend.ACCENTS:
		_accent.add_item(Registry.label(VoiceBlend.ACCENTS, k))
		_accent.set_item_tooltip(_accent.item_count - 1, Registry.blurb(VoiceBlend.ACCENTS, k))
	_accent.item_selected.connect(func(i: int) -> void:
		_accent_key = String(VoiceBlend.ACCENTS.keys()[i])
		_hand_back())
	top.add_child(_accent)
	_shapes = MenuButton.new()
	_shapes.text = "Shapes ▾"
	_shapes.flat = false
	_shapes.tooltip_text = ("Ways to move the voice across each paragraph: each fills in the mix and the lanes, around "
		+ "the shares as they stand, to drag on from.")
	var menu := _shapes.get_popup()
	for k in VoiceBlend.SHAPES:
		menu.add_item(Registry.label(VoiceBlend.SHAPES, k))
		menu.set_item_tooltip(menu.item_count - 1, Registry.blurb(VoiceBlend.SHAPES, k))
	menu.id_pressed.connect(func(id: int) -> void: apply_shape(String(VoiceBlend.SHAPES.keys()[id])))
	top.add_child(_shapes)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	box.add_child(body)
	_fishing = VoiceFishing.new(cast)
	_fishing.visible = false
	body.add_child(_fishing)
	_popup.popup_hide.connect(_fishing.close)
	_readers = VBoxContainer.new()
	_readers.custom_minimum_size = Vector2(380, 0)
	_readers.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_readers)
	var bar := HBoxContainer.new()
	_readers.add_child(bar)
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
	_readers.add_child(_tree)

	_shape_box = VBoxContainer.new()
	_shape_box.custom_minimum_size = Vector2(470, 0)
	body.add_child(_shape_box)
	_shape_box.add_child(_heading("Across each paragraph"))
	_shape = VoiceShape.new()
	_shape.edited.connect(_shape_edited)
	# the playhead: where the test being heard is across its paragraph
	_shape.follow = func() -> float: return cast.panel._audition.place_now()
	_shape_box.add_child(_shape)
	var noise := HBoxContainer.new()
	noise.add_theme_constant_override("separation", 6)
	_shape_box.add_child(noise)
	_noise_kind = OptionButton.new()
	_noise_kind.focus_mode = Control.FOCUS_NONE
	_noise_kind.add_item("No noise")
	_noise_kind.set_item_tooltip(0, "The voice as it is shaped above, nothing drawn at random.")
	for k in VoiceBlend.NOISES:
		_noise_kind.add_item("Noise: " + Registry.label(VoiceBlend.NOISES, k))
		_noise_kind.set_item_tooltip(_noise_kind.item_count - 1, Registry.blurb(VoiceBlend.NOISES, k))
	_noise_kind.item_selected.connect(_noise_picked)
	noise.add_child(_noise_kind)
	_noise_amount = HSlider.new()
	_noise_amount.min_value = 0.05
	_noise_amount.max_value = 1.0
	_noise_amount.step = 0.05
	_noise_amount.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_noise_amount.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_noise_amount.tooltip_text = "How far the noise takes the voice: at the top, most of the way to another reader."
	_noise_amount.drag_ended.connect(func(changed: bool) -> void:
		if changed:
			_noise["amount"] = _noise_amount.value
			_hand_back())
	noise.add_child(_noise_amount)
	# the draw is a number, shown and stepped: the same seed is the same voice or path again
	_seed_box = HBoxContainer.new()
	_seed_box.add_theme_constant_override("separation", 4)
	noise.add_child(_seed_box)
	var seed_label := Label.new()
	seed_label.text = "Seed"
	_seed_box.add_child(seed_label)
	_noise_seed = SpinBox.new()
	_noise_seed.min_value = 0
	_noise_seed.max_value = 9999
	_noise_seed.step = 1
	_noise_seed.custom_minimum_size = Vector2(84, 0)
	_noise_seed.tooltip_text = ("Which draw of the noise: each number is another voice near this one (Fixed) or another "
		+ "path among them (Wander), and the same number is always the same one.")
	_noise_seed.value_changed.connect(func(v: float) -> void:
		_noise["seed"] = int(v)
		_hand_back())
	_seed_box.add_child(_noise_seed)
	# typed into, the number lets go on Enter or a click anywhere else: nothing else in the pane takes the focus
	var typed := _noise_seed.get_line_edit()
	typed.text_submitted.connect(func(_t: String) -> void: typed.release_focus())
	_popup.window_input.connect(_let_go)

	_sound = VBoxContainer.new()
	_sound.custom_minimum_size = Vector2(330, 0)
	_sound.add_theme_constant_override("separation", 4)
	body.add_child(_sound)

	# One line, trimmed, the whole of it its tooltip: a wrapped label has no width before it is laid out and asks a
	# line a letter, and a popup opened as tall as that never shrinks
	_summary = Label.new()
	_summary.add_theme_font_size_override("font_size", 12)
	_summary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_summary.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_child(_summary)
	_note = Label.new()
	_note.add_theme_font_size_override("font_size", 10)
	_note.modulate = Color(1, 1, 1, 0.55)
	box.add_child(_note)
	host.add_child(_popup)
	_popup.size_changed.connect(_center)
	return _sound


## A quiet heading over a part of the Lab.
static func _heading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 12)
	l.modulate = Color(1, 1, 1, 0.7)
	return l


## Open on the voice on screen: what it reads in now ticked (or picked), its readers' pane shown where it has more
## than one, its shape where they blend.
func open() -> void:
	var vid := cast._selected_voice_id()
	var fishing := vid == FormantVoice.ID
	_fishing.visible = fishing
	if fishing:
		_fishing.open(cast.formant_now())
	_all = VoiceReaders.all(vid)
	var many := cast.readers_of(vid)
	if _all.is_empty() and many > 1:
		# readers nobody described (a voice not yet downloaded) are still picked, by number
		for i in many:
			_all.append({"i": i, "reader": str(i), "g": "", "d": ""})
	_blends = cast.blends(vid) and not _all.is_empty()
	_take_selection()
	_who.text = "%s  ·  %s" % [cast.tab_name(), cast.voice_name(vid)]
	_who.tooltip_text = "Every change here is to %s's voice, and reaches the reading as it is made." % cast.tab_name()
	_readers.visible = not _all.is_empty()
	_shape_box.visible = _blends
	_method.select(VoiceBlend.METHODS.keys().find(_method_key))
	_accent.select(VoiceBlend.ACCENTS.keys().find(_accent_key))
	for c in [_method, _accent, _shapes]:
		(c as Control).visible = _blends
	_summary.visible = not _all.is_empty()
	var described := _all.any(func(r: Dictionary) -> bool: return not String(r["d"]).is_empty())
	_note.text = VoiceReaders.about_of(vid) if described else ""
	if fishing:
		_note.text = "Cast from a seed, let it nibble, Pull, reel it in, then Hold or Fold. Every voice cast or held is this tab's."
	_note.visible = not _note.text.is_empty()
	_fill()
	_show_shape()
	_say()
	# Never the stage's height: a popup is sized to what its controls ask as it opens, before they are laid out,
	# and never shrinks after, so the Lab is capped at a share of the window.
	var host := _popup.get_parent()
	var stage := host.get_viewport() if host != null and host.is_inside_tree() else null   # none out of the tree (a gate's)
	if stage != null:
		var room := stage.get_visible_rect().size
		_popup.max_size = Vector2i(int(room.x * 0.9), int(room.y * 0.8))
	if _popup.visible:
		_popup.hide()
	# the size this voice's Lab asks, never the last one's: centered on a stale size, a narrower Lab keeps a wider
	# one's left edge
	_popup.reset_size()
	_popup.popup()
	_center()
	_center.call_deferred()


## The Lab in the middle of the room beside the panel it was opened from, as large as it is now: clear of the panel
## where it fits, slid left as far as the window's edge where it does not.
func _center() -> void:
	if _popup == null or not _popup.visible:
		return
	var host := _popup.get_parent() as Control
	if host == null or not host.is_inside_tree():
		return
	var room := host.get_viewport().get_visible_rect()
	var left := room.position.x
	var panel: Control = cast.panel._panel if cast.panel != null else null
	if panel != null and panel.is_visible_in_tree():
		left = maxf(left, panel.get_global_rect().end.x + BESIDE)
	var size := Vector2(_popup.size)
	var x := clampf(left + (room.end.x - left - size.x) * 0.5, room.position.x, maxf(room.position.x, room.end.x - size.x))
	var y := maxf(room.position.y, room.position.y + (room.size.y - size.y) * 0.5)
	var at := Vector2i(roundi(x), roundi(y))
	if _popup.position != at:
		_popup.position = at


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


## The game on screen ([VoiceFishing]): what a gate fishes with.
func fishing() -> VoiceFishing:
	return _fishing


## One sound at a time: the game's line let go for another (Test, a reading).
func hush() -> void:
	if _fishing != null and _fishing.casting():
		_fishing.release_line()


## The shape on screen ([VoiceShape]): what a gate drags.
func shape() -> VoiceShape:
	return _shape


## The Test button says what pressing it does now, as the Voice card's does.
func show_testing(on: bool) -> void:
	if _test != null and is_instance_valid(_test):
		_test.text = "Test ■" if on else "Test"
		# nothing ticked hears nothing; a voice of one reader has nothing to tick; a test playing still stops
		_test.disabled = not _all.is_empty() and _on.is_empty() and not on


## What the tab reads in now, as ticks and a shape: its blend's readers (those this voice holds) with their shares,
## lanes and noise, or its one reader.
func _take_selection() -> void:
	_on = []
	_method_key = "mix"
	_accent_key = ""
	_lanes = {}
	for lane in VoiceBlend.LANES:
		_lanes[lane] = _even([0.0])
	_noise = {}
	var b := VoiceBlend.parse(cast.blend_now()) if _blends else {}
	var curves: Array = []
	for v in b.get("voices", []):
		var at := _index_of(String((v as Dictionary)["reader"]))
		if at >= 0:
			_on.append({"i": at, "reader": String((v as Dictionary)["reader"]), "part": String((v as Dictionary)["part"])})
			curves.append((v as Dictionary)["weights"])
	if not _on.is_empty():
		_method_key = String(b["method"])
		_accent_key = String(b["accent"])
		_set_shares(curves)
		for lane in VoiceBlend.LANES:
			_lanes[lane] = _even(b[lane])
		_noise = (b["noise"] as Dictionary).duplicate()
		return
	if _all.is_empty():
		return
	var i := clampi(cast.speaker_now(), 0, _all.size() - 1)
	_on.append({"i": i, "reader": String((_all[i] as Dictionary).get("reader", "")), "part": "both"})
	_set_shares([[1.0]])


## Each ticked reader's share at each point, from their weights' points ([param curves], one array a reader).
func _set_shares(curves: Array) -> void:
	for r in _on.size():
		(_on[r] as Dictionary)["weights"] = []
	for k in VoiceBlend.POINTS:
		var s := VoiceBlend.shares_at(curves, float(k) / float(VoiceBlend.POINTS - 1))
		for r in _on.size():
			((_on[r] as Dictionary)["weights"] as Array).append(s[r])


func _even(points: Array) -> Array:
	var out: Array = []
	for k in VoiceBlend.POINTS:
		out.append(VoiceBlend.curve_at(points, float(k) / float(VoiceBlend.POINTS - 1)))
	return out


func _curves() -> Array:
	var out: Array = []
	for v in _on:
		out.append((v as Dictionary)["weights"])
	return out


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


## The list, as the filter and the search leave it: a tick and a part (where the method gives parts) on a voice
## whose readers blend, a row to pick on one whose readers do not.
func _fill() -> void:
	_tree.clear()
	_tree.columns = 2 if _parts() else 1
	_tree.column_titles_visible = _blends
	if _blends:
		_tree.set_column_title(0, "Reader")
	if _parts():
		_tree.set_column_title(1, "Part")
		_tree.set_column_expand(1, false)
		_tree.set_column_custom_minimum_width(1, 96)
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
		_row_cells(it)
		if first == null and _ticked(int(d["i"])) >= 0:
			first = it
	if first != null:
		if not _blends:
			first.select(0)
		_scroll_to.call_deferred(int(first.get_metadata(0)))


## Reader [param i]'s row brought into view - found again, since the list may have been filled anew since (a row
## held across that would be freed).
func _scroll_to(i: int) -> void:
	var it := row_of(i)
	if it != null:
		_tree.scroll_to_item(it)


## One row's cells as what is ticked says: its tick, and its part while it is ticked.
func _row_cells(it: TreeItem) -> void:
	if not _blends:
		return
	var k := _ticked(int(it.get_metadata(0)))
	it.set_checked(0, k >= 0)
	if _tree.columns < 2:
		return
	if k < 0:
		it.set_cell_mode(1, TreeItem.CELL_MODE_STRING)
		it.set_text(1, "")
		it.set_editable(1, false)
		return
	var labels := PackedStringArray()
	for p in VoiceBlend.PARTS:
		labels.append(Registry.label(VoiceBlend.PARTS, p))
	it.set_cell_mode(1, TreeItem.CELL_MODE_RANGE)
	it.set_editable(1, true)
	it.set_text(1, ",".join(labels))
	var part := String((_on[k] as Dictionary)["part"])
	it.set_range(1, VoiceBlend.PARTS.keys().find(part))
	it.set_tooltip_text(1, Registry.blurb(VoiceBlend.PARTS, part))


## The shape pane as what is ticked says: the bands, the lanes and the noise.
func _show_shape() -> void:
	if _shape == null:
		return
	var who := PackedStringArray()
	for v in _on:
		who.append(String((v as Dictionary)["reader"]))
	_shape.set_shape(who, _curves(), _lanes)
	var kind := String(_noise.get("kind", ""))
	_noise_kind.select(0 if kind.is_empty() else VoiceBlend.NOISES.keys().find(kind) + 1)
	_noise_amount.value = float(_noise.get("amount", 0.3))
	_noise_seed.set_value_no_signal(float(_noise.get("seed", 0)))
	_noise_amount.visible = not kind.is_empty()
	_seed_box.visible = not kind.is_empty()


## A tick or a part changed.
func _edited() -> void:
	var it := _tree.get_edited()
	if it != null:
		edit(it, _tree.get_edited_column())


## Row [param it]'s cell in column [param col] as it now stands, taken: a tick (0) or a part (1). A reader ticked
## takes an even share, the others giving way in proportion; one unticked leaves its share to the rest.
func edit(it: TreeItem, col: int) -> void:
	var i := int(it.get_metadata(0))
	var k := _ticked(i)
	match col:
		0:
			if it.is_checked(0) and k < 0:
				var d: Dictionary = _all[i]
				var n := _on.size()
				for v in _on:
					var w: Array = (v as Dictionary)["weights"]
					for j in w.size():
						w[j] = float(w[j]) * float(n) / float(n + 1)
				var even: Array = []
				even.resize(VoiceBlend.POINTS)
				even.fill(1.0 / float(n + 1))
				# in Sound and delivery the first one ticked gives the sound and the rest the delivery
				_on.append({"i": i, "reader": String(d.get("reader", "")), "weights": even,
					"part": ("delivery" if n > 0 else "sound") if _parts() else "both"})
			elif not it.is_checked(0) and k >= 0:
				_on.remove_at(k)
				_set_shares(_curves())
			_show_shape()
		1:
			if k >= 0:
				(_on[k] as Dictionary)["part"] = String(VoiceBlend.PARTS.keys()[clampi(int(it.get_range(1)), 0,
					VoiceBlend.PARTS.size() - 1)])
	_reshape.call_deferred(i)          # its part shown or hidden - never inside the edit
	_hand_back()


## Reader [param i]'s row shaped again - found again, since the list may have been filled anew since.
func _reshape(i: int) -> void:
	var it := row_of(i)
	if it != null:
		_row_cells(it)


## A row picked, on a voice whose readers do not blend: that reader.
func _selected() -> void:
	if _blends:
		return
	var it := _tree.get_selected()
	if it == null:
		return
	var i := int(it.get_metadata(0))
	_on = [{"i": i, "reader": String((_all[i] as Dictionary).get("reader", "")), "part": "both"}]
	_set_shares([[1.0]])
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


## A press anywhere but the Seed number lets go of the number (its text taken, as Enter takes it). The popup's own
## input, so its position is the popup's, as its controls' rects are.
func _let_go(event: InputEvent) -> void:
	var press := event as InputEventMouseButton
	if press == null or not press.pressed or _noise_seed == null or not is_instance_valid(_noise_seed):
		return
	var typed := _noise_seed.get_line_edit()
	if typed.has_focus() and not _noise_seed.get_global_rect().has_point(press.position):
		_noise_seed.apply()
		typed.release_focus()


## A drag let go in the shape: its shares and lanes taken.
func _shape_edited() -> void:
	for r in mini(_on.size(), _shape.weights.size()):
		(_on[r] as Dictionary)["weights"] = (_shape.weights[r] as Array).duplicate()
	for lane in VoiceBlend.LANES:
		_lanes[lane] = (_shape.lanes[lane] as Array).duplicate()
	_hand_back()


## Shape [param key] of [constant VoiceBlend.SHAPES] laid over what is ticked.
func apply_shape(key: String) -> void:
	var got := VoiceBlend.reshaped(key, _curves())
	for r in _on.size():
		(_on[r] as Dictionary)["weights"] = got["weights"][r]
	for lane in VoiceBlend.LANES:
		_lanes[lane] = got[lane]
	_show_shape()
	_hand_back()


## A kind of noise picked (or none): at a third of the way out the first time.
func _noise_picked(i: int) -> void:
	if i == 0:
		_noise = {}
	else:
		_noise = {"kind": String(VoiceBlend.NOISES.keys()[i - 1]), "amount": float(_noise.get("amount", 0.3)),
			"seed": int(_noise.get("seed", 0))}
	_show_shape()
	_hand_back()


## What is ticked and its shape, as the tab's line: shares out of a hundred.
func spec() -> String:
	var voices: Array = []
	for v in _on:
		var d: Dictionary = v
		voices.append({"reader": d["reader"], "part": d["part"],
			"weights": (d["weights"] as Array).map(func(x: float) -> float: return roundf(100.0 * x))})
	return VoiceBlend.compose(_method_key, _accent_key, voices, {"breath": _lanes.get("breath", [0.0]),
		"push": _lanes.get("push", [0.0]), "noise": _noise})


## What is ticked, to the tab: its first reader as the tab's reader, and the line when there are two or one is
## shaped. Nothing ticked hands back nothing: the tab reads on in what it had.
func _hand_back() -> void:
	if not _on.is_empty():
		cast.pick(int((_on[0] as Dictionary)["i"]), spec())
	_say()


## Under the list: the blend in words, the one reader and how to make a blend of it - or, with nothing
## ticked, what to do and what the tab reads in until then.
func _say() -> void:
	if _summary == null:
		return
	if _all.is_empty():
		show_testing(cast.panel._test_busy())
		return
	if _on.is_empty():
		var now := VoiceBlend.line(cast.blend_now(), true)
		if now.is_empty():
			now = String((_all[clampi(cast.speaker_now(), 0, _all.size() - 1)] as Dictionary)["d"]).get_slice(", ", 0)
		_summary.text = "Nothing ticked: tick one, or two or more to blend. Until then it reads in %s." % now
	else:
		var line := spec()
		var one := VoiceReaders.line(_all[int((_on[0] as Dictionary)["i"])], 10)
		_summary.text = VoiceBlend.line(line) if not line.is_empty() \
			else one + ("    -  tick another to blend them into a new voice" if _blends else "")
	_summary.tooltip_text = _summary.text
	if _method != null:
		_method.disabled = _on.size() < 2
		_accent.disabled = _on.size() < 2
		_shapes.disabled = _on.is_empty()
	show_testing(cast.panel._test_busy())
