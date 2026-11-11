extends PanelContainer
class_name GraphicsPanel

## GraphicsPanel - how finely the picture is drawn, live and in an export, above the bottom-right row (Chrome's
## framed-picture button, beside the Environment's).
##
## It renders [Graphics]' rows and adds nothing of its own: a line per row, a column per tier, each choice bound to its setting
## ([method Settings.bind], kept by its value, never its place in the list), and a change to the column this process
## draws at applied at once ([method Graphics.apply]) - a choice in the Export column waits for the next export, which
## reads it. A shared row (bounce light, which changes the look) is one choice across both columns, and a row only one
## column has (the viewer's resolution) says in the other what that column goes by.
##
## WHAT IT COSTS IS SHOWN: while the panel is open the stage's drawing time is measured on the graphics card and said
## at its foot, a few times a second - so whether there is room for more is read off the machine, not guessed.
## Measuring is off while it is closed.

const COL_TEXT := Color(0.70, 0.78, 0.90)
const COL_DIM := Color(0.50, 0.57, 0.68)
const COL_IDLE := Color(0.40, 0.46, 0.56)
## How often the drawing time is read, while open (seconds).
const READ_EVERY := 0.25

var _choices := {}               # "<tier>/<key>" -> OptionButton (a shared row's under both tiers)
var _cost: Label
var _t := 0.0


func _ready() -> void:
	_build_ui()
	visibility_changed.connect(_on_shown)
	_on_shown()


func _build_ui() -> void:
	# THE ENVIRONMENT PANEL'S CORNER (see deps_panel.gd): pinned bottom-right, grown up and left, standing on the row
	anchor_left = 1.0
	anchor_top = 1.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = -28
	offset_top = -Shell.ROW_TOP - 8
	offset_right = -28
	offset_bottom = -Shell.ROW_TOP - 8
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	custom_minimum_size = Vector2(440, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.08, 0.11, 0.92)
	sb.border_color = Color(0.18, 0.21, 0.27)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	add_theme_stylebox_override("panel", sb)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	add_child(col)

	var head := HBoxContainer.new()
	col.add_child(head)
	var title := Label.new()
	title.text = "Graphics"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", COL_TEXT)
	head.add_child(title)
	var reset := Button.new()
	reset.text = "defaults"
	reset.flat = true
	reset.focus_mode = Control.FOCUS_NONE
	reset.add_theme_font_size_override("font_size", 11)
	reset.tooltip_text = "Every row back to its default: the live viewer as it always drew, an export finer."
	reset.pressed.connect(reset_all)
	head.add_child(reset)

	col.add_child(HSeparator.new())
	var hint := Label.new()
	hint.text = "How finely the picture is drawn - never what is in it. The live viewer starts as it always drew; an export draws finer, since a slow frame costs a render only time."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(416, 0)
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", COL_IDLE)
	col.add_child(hint)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 4)
	col.add_child(grid)
	grid.add_child(Control.new())
	for t in Graphics.TIERS:
		var h := Label.new()
		h.text = "Live" if t == "live" else "Export"
		h.add_theme_font_size_override("font_size", 11)
		h.add_theme_color_override("font_color", COL_DIM)
		h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		h.tooltip_text = "What the viewer draws now." if t == "live" else "What an exported video is drawn at."
		h.mouse_filter = Control.MOUSE_FILTER_PASS
		grid.add_child(h)
	for key in Graphics.SETTINGS:
		var name_label := Label.new()
		name_label.text = Registry.label(Graphics.SETTINGS, key)
		name_label.tooltip_text = Registry.blurb(Graphics.SETTINGS, key)
		name_label.mouse_filter = Control.MOUSE_FILTER_PASS
		name_label.add_theme_font_size_override("font_size", 12)
		name_label.add_theme_color_override("font_color", COL_TEXT)
		grid.add_child(name_label)
		if bool(Registry.field(Graphics.SETTINGS, key, "shared", false)):
			# ONE CHOICE FOR BOTH: in the live column, the export's cell saying it follows
			grid.add_child(_choice(key, "live"))
			grid.add_child(_note("same", "It changes the look, so an export is drawn as the viewer is."))
			_choices["export/" + key] = _choices["live/" + key]
		else:
			for t in Graphics.TIERS:
				if Graphics.has_tier(key, t):
					grid.add_child(_choice(key, t))
				else:
					# ONE COLUMN'S ALONE: the other's cell says what it goes by instead
					grid.add_child(_note(String(Registry.field(Graphics.SETTINGS, key, "other", "")), Registry.blurb(Graphics.SETTINGS, key)))

	col.add_child(HSeparator.new())
	_cost = Label.new()
	_cost.add_theme_font_size_override("font_size", 10)
	_cost.add_theme_color_override("font_color", COL_DIM)
	col.add_child(_cost)
	_say_cost()


## A cell with no choice in it: [param text], dim, [param tip] over it.
func _note(text: String, tip: String) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.tooltip_text = tip
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", COL_IDLE)
	return l


## One cell: [param key]'s choices for tier [param t], bound to where they are kept.
func _choice(key: String, t: String) -> OptionButton:
	var o := OptionButton.new()
	o.focus_mode = Control.FOCUS_NONE
	o.fit_to_longest_item = false
	o.custom_minimum_size = Vector2(136, 0)
	o.add_theme_font_size_override("font_size", 11)
	o.tooltip_text = Registry.blurb(Graphics.SETTINGS, key)
	var values := Graphics.values_of(key)
	for opt in Registry.field(Graphics.SETTINGS, key, "options", []):
		o.add_item(String((opt as Array)[1]))
	Settings.bind(o, Graphics.SECTION, Graphics.key_of(key, t), Graphics.default_of(key, t), values)
	# after the bind's own write, so what is applied is the choice just made
	var shared := bool(Registry.field(Graphics.SETTINGS, key, "shared", false))
	o.item_selected.connect(func(_i: int) -> void:
		if shared or t == Graphics.tier():
			Graphics.apply())
	_choices["%s/%s" % [t, key]] = o
	return o


## Every row to its default, in both columns, and applied.
func reset_all() -> void:
	for key in Graphics.SETTINGS:
		for t in Graphics.TIERS:
			var o: OptionButton = _choices.get("%s/%s" % [t, key])
			if o == null:
				continue
			var dflt: Variant = Graphics.default_of(key, t)
			Settings.write(Graphics.SECTION, Graphics.key_of(key, t), dflt)
			o.select(maxi(0, Graphics.values_of(key).find(dflt)))
	Graphics.apply()


## The cell for [param key] in tier [param t] (a gate's handle).
func choice(key: String, t: String) -> OptionButton:
	return _choices.get("%s/%s" % [t, key])


func _on_shown() -> void:
	Graphics.measure(visible)
	set_process(visible)
	_t = 0.0
	_say_cost()


func _process(delta: float) -> void:
	_t += delta
	if _t >= READ_EVERY:
		_t = 0.0
		_say_cost()


func _say_cost() -> void:
	if _cost == null:
		return
	var ms := Graphics.stage_ms()
	if Graphics.stage() == null:
		_cost.text = "Nothing is on the stage yet: open a note to see what drawing it costs."
	elif ms <= 0.0:
		_cost.text = "The stage is drawn only as it changes: play the note to see what a frame costs."
	else:
		var px := Graphics.stage().size
		_cost.text = "The stage's last frame, %d x %d: %.1f ms on the graphics card (the card alone could draw %d a second)." % [px.x, px.y, ms, int(1000.0 / ms)]
