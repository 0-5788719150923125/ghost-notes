extends VBoxContainer
class_name LookCard

## LookCard - the Look: a post-process over the whole picture, one row per filter in
## [constant Filters.REGISTRY] (next/notes.md step 5: one card per section, in every panel that has
## it - the Generative panel built it and the Cards panel borrowed it by inheriting the whole panel).
##
## IT IS THE DIRECTOR'S, like the medium, so a look set here is the look of every session: a
## reading, a synthesis take, a song in Auto mode, and an export render, which boots a second
## process against the same settings file and inherits it with no flag to pass.
##
## A CHECKBOX AND A DIAL, NOT A PICKER, and that is the design rather than the layout. Being asked
## to choose between monochrome and grain is the wrong question - black and white film HAS grain -
## so every filter is independently switchable and they are all applied in one pass, in the
## registry's order. The dial is grayed rather than hidden while its filter is off: a control that
## vanishes takes its value with it as far as anyone looking can tell, and the value is kept.
##
## Its block in a document is `look:` - every filter named, off ones at 0, so the block says
## exactly which look the chapter is shown in.

## The block this card keeps under a document's `ghost:` key.
const KEY := "look"

var _filter_summary: Label
var _filter_rows := {}     # filter key -> {box: CheckBox, slider: HSlider}


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
		cb.text = String(Filters.LABELS.get(k, k))
		cb.custom_minimum_size = Vector2(128, 0)
		cb.add_theme_font_size_override("font_size", 12)
		cb.tooltip_text = String(Filters.BLURBS.get(k, ""))
		row.add_child(cb)
		var sl := HSlider.new()
		sl.min_value = 0.0
		sl.max_value = 1.0
		sl.step = 0.01
		sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sl.tooltip_text = ("How much of it. The top of every range here is deliberately too "
			+ "much, so the interesting settings are in the middle.\n\n"
			+ String(Filters.BLURBS.get(k, "")))
		row.add_child(sl)
		var readout := Card.readout(row, sl)
		var live := Director.filter_amount(k)
		cb.set_pressed_no_signal(live > 0.0)
		Card.put_slider(sl, readout, live if live > 0.0 else float(Filters.DEFAULTS.get(k, 0.5)))
		sl.editable = live > 0.0
		# TICKING A FILTER ON MUST DO SOMETHING VISIBLE. A box whose dial happens to be at 0
		# reads as a broken checkbox, so switching on with nothing dialed in lands on the
		# registry's own starting point rather than on silence.
		cb.toggled.connect(func(on: bool) -> void:
			if on and sl.value <= 0.0:
				Card.put_slider(sl, readout, float(Filters.DEFAULTS.get(k, 0.5)))
			sl.editable = on
			Director.set_filter(k, sl.value if on else 0.0)
			refresh())
		sl.value_changed.connect(func(v: float) -> void:
			if not cb.button_pressed:
				return          # a grayed dial keeps its value and changes nothing
			Director.set_filter(k, v)
			refresh())
		_filter_rows[k] = {"box": cb, "slider": sl}
	refresh()


## The one-line summary beside the heading - what is actually on, in pipeline order.
func refresh() -> void:
	if _filter_summary == null or not is_instance_valid(_filter_summary):
		return
	var text := Filters.describe(Director.resolved_filters())
	_filter_summary.text = text
	_filter_summary.tooltip_text = ("Applied to the WHOLE picture, in this order, after "
		+ "every scene has drawn - and to nothing above it, so the subtitles stay clean. "
		+ "It is a Director setting like Medium, so it is also the look of a song in Auto "
		+ "mode and of an export render.\n\nOn now: " + text)


## The rows, back from the Director - after a document set the filters.
func sync_rows() -> void:
	for k in _filter_rows:
		var row: Dictionary = _filter_rows[k]
		var amt := Director.filter_amount(String(k))
		var cb: CheckBox = row["box"]
		var sl: HSlider = row["slider"]
		cb.set_pressed_no_signal(amt > 0.0)
		sl.editable = amt > 0.0
		if amt > 0.0:
			sl.set_value_no_signal(amt)
	refresh()


## The block for a document: every filter named, off ones at 0.
func capture() -> Dictionary:
	var looks := {}
	for k in Filters.REGISTRY:
		looks[k] = snappedf(Director.filter_amount(k), 0.01)
	return {"filters": looks}


## ...and back: every filter the block names set, every one it leaves out off.
func apply(block: Dictionary) -> void:
	if block.get("filters") is Dictionary:
		for k in Filters.REGISTRY:
			Director.set_filter(k, float((block["filters"] as Dictionary).get(k, 0.0)))
		sync_rows()
