extends CanvasLayer
class_name RowStatus

## RowStatus - an export's progress line, over the bottom-right row: what it is doing and how far along (amber), how it
## ended (green, or red when it failed) - the look of the video's export line ([Exporter]), for any mode's export to
## say itself the same way. It stands right-aligned over the row and wraps upward, rides the shell's room along the
## bottom ([member Shell.bottom_inset]), steps aside while a panel is open above the row, and a line saying how an
## export ended clears itself after a while. What it says is logged too ([StatusLog]).

## Its widest, ending at the row's right edge.
const WIDE := 588.0
const WORKING := Color(0.95, 0.92, 0.7)
const DONE := Color(0.82, 0.95, 0.86)
const FAILED := Color(1.0, 0.7, 0.6)
## Seconds a line saying how an export ended stays (a failure twice as long).
const LINGER := 8.0

var _label: Label
var _left := -1.0           # seconds the line has left, -1 while it is working


func _ready() -> void:
	layer = Shell.ROW_LAYER
	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_label.add_theme_constant_override("shadow_offset_x", 1)
	_label.add_theme_constant_override("shadow_offset_y", 1)
	_label.visible = false
	add_child(_label)


## Under way: [param text] ("Exporting the song… 40%").
func working(text: String) -> void:
	_show(text, WORKING, -1.0)


## Ended well: [param text] ("✓  Saved …"), cleared after LINGER.
func done(text: String) -> void:
	_show(text, DONE, LINGER)
	StatusLog.say("export", text)


## Ended badly: [param text], cleared after twice LINGER.
func failed(text: String) -> void:
	_show(text, FAILED, LINGER * 2.0)
	StatusLog.say("export", text)


## Nothing said.
func clear() -> void:
	_left = -1.0
	if _label != null:
		_label.visible = false


## What it says now, "" while it says nothing.
func said() -> String:
	return _label.text if _label != null and _label.visible else ""


func _show(text: String, color: Color, linger: float) -> void:
	if _label == null:
		return
	_label.text = text
	_label.add_theme_color_override("font_color", color)
	_label.visible = true
	_left = linger
	_place()


func _process(delta: float) -> void:
	if _label == null or not _label.visible:
		return
	if _left >= 0.0:
		_left -= delta
		if _left <= 0.0:
			clear()
			return
	_place()


func _place() -> void:
	var sh := Shell.of(self)
	var inset := sh.bottom_inset if sh != null else 0.0
	var w := WIDE
	var vp := get_viewport()
	if vp != null:
		w = minf(WIDE, maxf(160.0, vp.get_visible_rect().size.x - 56.0))
	_label.offset_left = -Shell.ROW_MARGIN - w
	_label.offset_right = -Shell.ROW_MARGIN
	_label.offset_top = -110.0 - inset
	_label.offset_bottom = -74.0 - inset
	_label.modulate.a = 0.0 if sh != null and sh.panel_open() else 1.0
