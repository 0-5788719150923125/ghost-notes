extends VBoxContainer
class_name LookCard

## LookCard - the Look: a post-process over the whole picture, one row per filter in [constant
## Filters.REGISTRY] (next/notes.md; one card per section, in every panel that has it).
##
## It is the Director's, like the medium, so a look set here is the look of every session: a reading, a
## song in Auto mode and an export render (a second process against the same settings
## file).
##
## A checkbox and a dial, not a picker: every filter is independently switchable and all are applied in
## one pass in the registry's order. The dial is grayed rather than hidden while its filter is off, so
## the kept value stays in view.
##
## Its block in a document is `look:` (every filter named, off ones at 0), `subtitles:` (how the line
## reveals its words, [constant Subtitles.REVEALS]) and `tonemap:` with `tonemap_adjust:` (the tonemapper
## a 3D set is shown through and the adjustments made to each, [Tonemaps]; a block naming none is Filmic).
##
## The tonemapper is a picker and three dials: one at a time, each with its own preset; the dials are
## that tonemapper's own adjustments, so switching shows where it was left, and "reset" puts the one
## shown back to its preset.

## The block this card keeps under a document's `ghost:` key.
const KEY := "look"

var _filter_summary: Label
var _filter_rows := {}     # filter key -> {box: CheckBox, slider: HSlider, readout: Label}
var _reveal: OptionButton  # how the subtitles reveal a line ([constant Subtitles.REVEALS])
var _tonemap: OptionButton # the tonemapper ([constant Tonemaps.REGISTRY])
var _adjust_rows := {}     # adjustment -> {slider: HSlider, readout: Label}


## This card for a note's panel, from what the panel says of itself ([method NoteCards.make]):
## it asks nothing of it.
static func for_note(_ctx: Dictionary) -> LookCard:
	return LookCard.new()


func _init() -> void:
	add_theme_constant_override("separation", 8)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	add_child(head)
	var title := Label.new()
	title.text = "Look"
	title.custom_minimum_size = Vector2(72, 0)
	title.add_theme_font_size_override("font_size", 12)
	head.add_child(title)
	_filter_summary = Label.new()
	_filter_summary.add_theme_font_size_override("font_size", 11)
	_filter_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_filter_summary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_filter_summary.modulate = Color(1, 1, 1, 0.6)
	head.add_child(_filter_summary)

	for key in Filters.REGISTRY:
		var k := String(key)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		add_child(row)
		var cb := CheckBox.new()
		cb.text = Registry.label(Filters.REGISTRY, k)
		cb.custom_minimum_size = Vector2(128, 0)
		cb.add_theme_font_size_override("font_size", 12)
		cb.tooltip_text = Registry.blurb(Filters.REGISTRY, k)
		row.add_child(cb)
		var sl := HSlider.new()
		sl.min_value = 0.0
		sl.max_value = 1.0
		sl.step = 0.01
		sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sl.tooltip_text = ("How much of it. The top of every range here is deliberately too "
			+ "much, so the interesting settings are in the middle.\n\n"
			+ Registry.blurb(Filters.REGISTRY, k))
		row.add_child(sl)
		var readout := Card.readout(row, sl)
		var live := Director.filter_amount(k)
		cb.set_pressed_no_signal(live > 0.0)
		Card.put_slider(sl, readout, live if live > 0.0 else float(Registry.field(Filters.REGISTRY, k, "default", 0.5)))
		sl.editable = live > 0.0
	# Ticking a filter on must do something visible: with the dial at 0 it lands on the registry's own
	# starting point rather than on silence.
		cb.toggled.connect(func(on: bool) -> void:
			if on and sl.value <= 0.0:
				Card.put_slider(sl, readout, float(Registry.field(Filters.REGISTRY, k, "default", 0.5)))
			sl.editable = on
			Director.set_filter(k, sl.value if on else 0.0)
			refresh())
		sl.value_changed.connect(func(v: float) -> void:
			if not cb.button_pressed:
				return          # a grayed dial keeps its value and changes nothing
			Director.set_filter(k, v)
			refresh())
		_filter_rows[k] = {"box": cb, "slider": sl, "readout": readout}
	_build_tonemap()
	# the subtitles: how a line's words appear, over the look and never under it
	var srow := HBoxContainer.new()
	srow.add_theme_constant_override("separation", 8)
	add_child(srow)
	var sl := Label.new()
	sl.text = "Subtitles"
	sl.custom_minimum_size = Vector2(128, 0)
	sl.add_theme_font_size_override("font_size", 12)
	srow.add_child(sl)
	_reveal = OptionButton.new()
	_reveal.fit_to_longest_item = false
	_reveal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reveal.add_theme_font_size_override("font_size", 12)
	for key in Subtitles.REVEALS:
		_reveal.add_item(String(key).capitalize())
		_reveal.set_item_tooltip(_reveal.item_count - 1, String(Subtitles.REVEALS[key]))
	_reveal.tooltip_text = "How the subtitles reveal each line. " + "; ".join(PackedStringArray(Subtitles.REVEALS.keys().map(
		func(key: Variant) -> String: return "%s: %s" % [String(key).capitalize(), Subtitles.REVEALS[key]])))
	_reveal.select(Subtitles.REVEALS.keys().find(Director.subtitle_reveal))
	_reveal.item_selected.connect(func(i: int) -> void: Director.set_subtitle_reveal(String(Subtitles.REVEALS.keys()[i])))
	srow.add_child(_reveal)
	refresh()


## The tonemapper's rows: the picker with its reset, then a dial per adjustment.
func _build_tonemap() -> void:
	var trow := HBoxContainer.new()
	trow.add_theme_constant_override("separation", 8)
	add_child(trow)
	var tl := Label.new()
	tl.text = "Tonemapper"
	tl.custom_minimum_size = Vector2(128, 0)
	tl.add_theme_font_size_override("font_size", 12)
	tl.mouse_filter = Control.MOUSE_FILTER_PASS
	tl.tooltip_text = ("How a 3D set's light is brought down to what a screen can show - the card table, the desk, "
		+ "the book, the tablet. Each has a preset of its own, and the dials below are kept for each apart.")
	trow.add_child(tl)
	_tonemap = OptionButton.new()
	_tonemap.fit_to_longest_item = false
	_tonemap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tonemap.add_theme_font_size_override("font_size", 12)
	for key in Tonemaps.REGISTRY:
		_tonemap.add_item(Registry.label(Tonemaps.REGISTRY, key))
		_tonemap.set_item_tooltip(_tonemap.item_count - 1, Registry.blurb(Tonemaps.REGISTRY, key))
	_tonemap.tooltip_text = tl.tooltip_text
	_tonemap.item_selected.connect(func(i: int) -> void:
		Director.set_tonemap(String(Tonemaps.REGISTRY.keys()[i]))
		_sync_tonemap()
		refresh())
	trow.add_child(_tonemap)
	var reset := Button.new()
	reset.text = "reset"
	reset.flat = true
	reset.focus_mode = Control.FOCUS_NONE
	reset.add_theme_font_size_override("font_size", 11)
	reset.tooltip_text = "This tonemapper's dials back to its preset."
	reset.pressed.connect(func() -> void:
		for name in Tonemaps.ADJUSTMENTS:
			Director.set_tonemap_adjust(name, Tonemaps.neutral(name))
		_sync_tonemap()
		refresh())
	trow.add_child(reset)
	for name in Tonemaps.ADJUSTMENTS:
		var adj: Dictionary = Tonemaps.ADJUSTMENTS[name]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		add_child(row)
		var lab := Label.new()
		lab.text = "   " + String(adj["label"])
		lab.custom_minimum_size = Vector2(128, 0)
		lab.add_theme_font_size_override("font_size", 12)
		lab.mouse_filter = Control.MOUSE_FILTER_PASS
		lab.tooltip_text = String(adj["blurb"])
		row.add_child(lab)
		var sl := HSlider.new()
		sl.min_value = float(adj["min"])
		sl.max_value = float(adj["max"])
		sl.step = float(adj["step"])
		sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sl.tooltip_text = String(adj["blurb"])
		row.add_child(sl)
		var readout := Card.readout(row, sl)
		var n := String(name)
		sl.value_changed.connect(func(v: float) -> void:
			Director.set_tonemap_adjust(n, v)
			refresh())
		_adjust_rows[n] = {"slider": sl, "readout": readout}
	_sync_tonemap()


## The picker and the dials, back from the Director: the tonemapper chosen and its own adjustments.
func _sync_tonemap() -> void:
	if _tonemap == null:
		return
	_tonemap.select(maxi(0, Tonemaps.REGISTRY.keys().find(Director.tonemap)))
	var a := Director.tonemap_adjustments()
	for n in _adjust_rows:
		Card.put_slider(_adjust_rows[n]["slider"], _adjust_rows[n]["readout"], float(a[n]))


## The one-line summary beside the heading - what is actually on, in pipeline order.
func refresh() -> void:
	if _filter_summary == null or not is_instance_valid(_filter_summary):
		return
	var text := Filters.describe(Director.resolved_filters())
	# the tonemapper leads, once it is not the one every set was tuned in
	if Director.tonemap != Tonemaps.DEFAULT:
		text = Registry.label(Tonemaps.REGISTRY, Director.tonemap) + ("" if text == "none" else ", " + text)
	_filter_summary.text = text
	_filter_summary.tooltip_text = ("Applied to the WHOLE picture, in this order, after "
		+ "every scene has drawn - and to nothing above it, so the subtitles stay clean. "
		+ "It is a Director setting like Medium, so it is also the look of a song in Auto "
		+ "mode and of an export render.\n\nOn now: " + text)


## The rows, back from the Director after a document set the filters, including the number beside each
## dial (a note opened from nothing builds this card at the registry's defaults, and the block that
## arrives next moves the dial alone).
func sync_rows() -> void:
	for k in _filter_rows:
		var row: Dictionary = _filter_rows[k]
		var amt := Director.filter_amount(String(k))
		var cb: CheckBox = row["box"]
		var sl: HSlider = row["slider"]
		cb.set_pressed_no_signal(amt > 0.0)
		sl.editable = amt > 0.0
		if amt > 0.0:
			Card.put_slider(sl, row["readout"], amt)
	if _reveal != null:
		_reveal.select(Subtitles.REVEALS.keys().find(Director.subtitle_reveal))
	_sync_tonemap()
	refresh()


## The block for a document: every filter named, off ones at 0.
func capture() -> Dictionary:
	var looks := {}
	for k in Filters.REGISTRY:
		looks[k] = snappedf(Director.filter_amount(k), 0.01)
	var out := {"filters": looks, "subtitles": Director.subtitle_reveal, "tonemap": Director.tonemap}
	# only the tonemappers someone adjusted: one never touched is at its preset
	var adjust := {}
	for key in Director.tonemap_adjust:
		var a: Dictionary = Director.tonemap_adjust[key]
		var snapped := {}
		for n in a:
			snapped[n] = snappedf(float(a[n]), 0.01)
		adjust[key] = snapped
	if not adjust.is_empty():
		out["tonemap_adjust"] = adjust
	return out


## ...and back: every filter the block names set, every one it leaves out off.
func apply(block: Dictionary) -> void:
	if block.get("filters") is Dictionary:
		for k in Filters.REGISTRY:
			Director.set_filter(k, float((block["filters"] as Dictionary).get(k, 0.0)))
	if block.get("subtitles") is String:
		Director.set_subtitle_reveal(String(block["subtitles"]))
	if block.get("tonemap") is String or block.get("tonemap_adjust") is Dictionary:
		Director.set_tonemap_all(String(block.get("tonemap", Tonemaps.DEFAULT)), block.get("tonemap_adjust", {}))
	if block.get("filters") is Dictionary or block.get("subtitles") is String or block.has("tonemap") or block.has("tonemap_adjust"):
		sync_rows()
