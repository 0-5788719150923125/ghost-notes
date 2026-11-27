extends Control
class_name CurveEdit

## CurveEdit - a curve of points dragged in a box: left to right is what the curve runs along (a stretch of words, a word), 0 to 1,
## bottom to top its value from [member lo] to [member hi] (a multiplier on a log scale, [member log_scale]), a faint line at
## [member neutral] where it moves nothing. With no points it lies on that line.
##
## Drag a point to move it; double-click the box to add one there, a point to take it off (right-click takes one off too). A point
## pinned to a name ([member pins]: `[name, value]` in place of `[x, value]`) is drawn where its name stands and moves up and down
## only. [signal edited] when a drag lets go or a point comes or goes: [member points] is then the curve. Under the pointer, the value
## there in its unit ([member unit]).

signal edited

const PAD := 6.0
const HIT := 8.0
const SAMPLES := 48

## The curve: `[[x, value]]` in order of x, x 0 to 1 or a name of [member pins].
var points: Array = []
var lo := -1.0
var hi := 1.0
var neutral := 0.0
## Drawn on a log scale: a multiplier, whose lo and hi are above 0.
var log_scale := false
## Where each pinned name is drawn, 0 to 1.
var pins := {}
## How the curve runs between points: "line" straight (a stretch's axis), "ease" eased (a word's pitch, as the host draws it).
var between := "line"
## Said after a value under the pointer ("x", "st", "dB").
var unit := ""
## The names along the bottom, `[[x, text]]` ("start", "end").
var marks: Array = []

var _drag := -1
var _hover := Vector2(-1, -1)
var _font: Font


func _init() -> void:
	custom_minimum_size = Vector2(220, 56)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	clip_contents = true


func _ready() -> void:
	_font = get_theme_default_font()


## [param p]'s x, 0 to 1: a pinned point where its name stands.
func x_of(p: Array) -> float:
	return float(pins.get(String(p[0]), 0.5)) if p[0] is String else float(p[0])


func _y_unit(v: float) -> float:
	if log_scale:
		return inverse_lerp(log(maxf(lo, 1e-4)), log(maxf(hi, 1e-4)), log(maxf(v, 1e-4)))
	return inverse_lerp(lo, hi, v)


func _value_at_unit(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	if log_scale:
		return exp(lerpf(log(maxf(lo, 1e-4)), log(maxf(hi, 1e-4)), u))
	return lerpf(lo, hi, u)


func _to_px(x: float, v: float) -> Vector2:
	var w := size.x - 2.0 * PAD
	var h := size.y - 2.0 * PAD
	return Vector2(PAD + x * w, PAD + (1.0 - clampf(_y_unit(v), 0.0, 1.0)) * h)


func _from_px(at: Vector2) -> Vector2:
	var w := maxf(size.x - 2.0 * PAD, 1.0)
	var h := maxf(size.y - 2.0 * PAD, 1.0)
	return Vector2(clampf((at.x - PAD) / w, 0.0, 1.0), _value_at_unit(1.0 - (at.y - PAD) / h))


## The points in order of where they are drawn.
func _sorted() -> Array:
	var out := points.duplicate(true)
	out.sort_custom(func(a: Array, b: Array) -> bool: return x_of(a) < x_of(b))
	return out


## The curve's value at [param x], 0 to 1: held before its first point and after its last.
func value_at(x: float) -> float:
	var pts := _sorted()
	if pts.is_empty():
		return neutral
	if x <= x_of(pts[0]):
		return float(pts[0][1])
	for i in range(pts.size() - 1):
		var x0 := x_of(pts[i])
		var x1 := x_of(pts[i + 1])
		if x <= x1:
			var u := (x - x0) / (x1 - x0) if x1 > x0 else 1.0
			if between == "ease":
				u = u * u * (3.0 - 2.0 * u)
			var a := float(pts[i][1])
			var b := float(pts[i + 1][1])
			return exp(lerpf(log(maxf(a, 1e-4)), log(maxf(b, 1e-4)), u)) if log_scale else lerpf(a, b, u)
	return float(pts[pts.size() - 1][1])


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color(0, 0, 0, 0.25))
	draw_rect(r, Color(1, 1, 1, 0.12), false, 1.0)
	var ny := _to_px(0.0, neutral).y
	draw_dashed_line(Vector2(PAD, ny), Vector2(size.x - PAD, ny), Color(1, 1, 1, 0.25), 1.0, 4.0)
	for name in pins:
		var px := _to_px(float(pins[name]), neutral).x
		draw_line(Vector2(px, PAD), Vector2(px, size.y - PAD), Color(1, 0.85, 0.4, 0.18), 1.0)
	var line := PackedVector2Array()
	for k in SAMPLES + 1:
		var x := float(k) / float(SAMPLES)
		line.append(_to_px(x, value_at(x)))
	draw_polyline(line, Color(0.55, 0.85, 1.0, 0.95), 2.0, true)
	for i in points.size():
		var p: Array = points[i]
		var at := _to_px(x_of(p), float(p[1]))
		var pinned: bool = p[0] is String
		draw_circle(at, 4.5, Color(1, 0.85, 0.4) if pinned else Color(0.55, 0.85, 1.0))
		draw_arc(at, 4.5, 0.0, TAU, 16, Color(0, 0, 0, 0.6), 1.0)
	if _font != null:
		for m in marks:
			draw_string(_font, Vector2(_to_px(float(m[0]), lo).x + 2.0, size.y - 2.0), String(m[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
				Color(1, 1, 1, 0.4))
		var said := ""
		if _drag >= 0 and _drag < points.size():
			said = _say(float(points[_drag][1]))
		elif _hover.x >= 0.0:
			said = _say(_from_px(_hover).y)
		if not said.is_empty():
			draw_string(_font, Vector2(size.x - PAD - 64.0, PAD + 9.0), said, HORIZONTAL_ALIGNMENT_RIGHT, 64.0, 10, Color(1, 1, 1, 0.75))


func _say(v: float) -> String:
	var t := ("%.2f" % v) if absf(v) < 10.0 else ("%.1f" % v)
	if unit == "x":
		return t + "x"
	return ("+" if v > 0.0 else "") + t + ((" " + unit) if not unit.is_empty() else "")


func _nearest(at: Vector2) -> int:
	var best := -1
	var d := HIT
	for i in points.size():
		var p: Array = points[i]
		var q := _to_px(x_of(p), float(p[1]))
		if q.distance_to(at) <= d:
			d = q.distance_to(at)
			best = i
	return best


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null:
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed and mb.double_click:
			var i := _nearest(mb.position)
			if i >= 0:
				points.remove_at(i)
			else:
				var v := _from_px(mb.position)
				points.append([snappedf(v.x, 0.01), snappedf(v.y, 0.01)])
				points = _sorted()
			_drag = -1
			queue_redraw()
			edited.emit()
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_drag = _nearest(mb.position)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed and _drag >= 0:
			_drag = -1
			points = _sorted()
			queue_redraw()
			edited.emit()
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			var i := _nearest(mb.position)
			if i >= 0:
				points.remove_at(i)
				queue_redraw()
				edited.emit()
			accept_event()
		return
	var mm := event as InputEventMouseMotion
	if mm != null:
		_hover = mm.position
		if _drag >= 0 and _drag < points.size():
			var v := _from_px(mm.position)
			var p: Array = points[_drag]
			points[_drag] = [p[0] if p[0] is String else snappedf(v.x, 0.01), snappedf(v.y, 0.01)]
		queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_hover = Vector2(-1, -1)
		queue_redraw()
	elif what == NOTIFICATION_RESIZED:
		queue_redraw()
