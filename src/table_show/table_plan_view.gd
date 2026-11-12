extends Control
class_name TablePlanView

## TablePlanView - THE TABLE FROM ABOVE, TO MOVE THINGS ON (next/editing.md step 7: "a second view: the plan from above
## (`TableBlueprint`) ... drag on the plan to place"). The set dresser's own blueprint of the table standing ([method
## TableMedium.blueprint]: the top, where the cards go, gray where the camera does not see, each thing's foot), drawn to fit;
## a click on a thing's foot picks it ([signal picked]) and a drag moves it ([signal moved]: where it would stand now, in
## centimeters from the middle of the reading - a thing's `at`). Nothing is written here: the owner writes the table, and the
## table stands with it the next time it is set. A thing moved is drawn where it was put until then.

## A thing's foot was clicked.
signal picked(thing: String)
## A thing was dragged to stand with its middle at [param at_cm] (a thing's `at`, centimeters from the middle of the reading).
signal moved(thing: String, at_cm: Vector2)

## The blueprint shown ([method TableThings.blueprint]).
var data := {}
## The thing picked, "" for none: drawn ringed.
var selected := ""

var _paper: TableBlueprint
var _marks: Marks
var _view := {}
var _drag := ""
var _grab := Vector2.ZERO      # where the drag began, meters on the table
var _now := Vector2.ZERO       # ...and where it is


## What is drawn over the paper: the thing picked ringed, the one dragged where it is going.
class Marks extends Node2D:
	var plan: TablePlanView

	func _draw() -> void:
		plan._draw_marks(self)


func _init() -> void:
	custom_minimum_size = Vector2(0, 240)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "The table from above: click a thing's foot to pick it, drag it to move it. It stands there the next time the table is set."
	_paper = TableBlueprint.new()
	add_child(_paper)
	_marks = Marks.new()
	_marks.plan = self
	add_child(_marks)
	resized.connect(_fit)


## Show blueprint [param d] ({} for none).
func show_plan(d: Dictionary) -> void:
	data = d
	_paper.data = d
	_view = TableBlueprint.view(d) if not d.is_empty() else {}
	_paper.queue_redraw()
	_fit()


func _fit() -> void:
	var k := _k()
	for n in [_paper, _marks]:
		(n as Node2D).scale = Vector2(k, k)
		(n as Node2D).position = _offset()
	_marks.queue_redraw()


func _k() -> float:
	var sheet := Vector2(TableBlueprint.SHEET)
	return minf(size.x / sheet.x, size.y / sheet.y) if size.x > 0.0 and size.y > 0.0 else 0.25


func _offset() -> Vector2:
	return ((size - Vector2(TableBlueprint.SHEET) * _k()) * 0.5).floor()


## Where this control's point [param p] falls on the table, meters (the blueprint's plane: x right, z toward the reader).
func to_table(p: Vector2) -> Vector2:
	if _view.is_empty():
		return Vector2.ZERO
	return ((p - _offset()) / _k() - (_view["origin"] as Vector2)) / float(_view["scale"])


## ...and back: where [param m] (meters on the table) falls on this control.
func to_control(m: Vector2) -> Vector2:
	return _offset() + ((_view["origin"] as Vector2) + m * float(_view["scale"])) * _k()


## The thing whose foot is under [param m] (meters on the table), "" for none - the last drawn first, as it lies on top.
func thing_at(m: Vector2) -> String:
	var things: Array = data.get("things", [])
	for i in range(things.size() - 1, -1, -1):
		var t: Dictionary = things[i]
		if t.get("foot") is PackedVector2Array and Geometry2D.is_point_in_polygon(m, t["foot"]):
			return String(t.get("name", ""))
	return ""


## A thing's `at` for its middle at [param m] (meters on the table): centimeters from the middle of the reading.
static func at_cm(m: Vector2) -> Vector2:
	return (m - Tables.ORIGIN) * 100.0


## Thing [param name] drawn moved by [param by] meters, until the table stands again: its foot, box and middle.
func shift(name: String, by: Vector2) -> void:
	for t in data.get("things", []):
		var d: Dictionary = t
		if String(d.get("name", "")) != name:
			continue
		var foot := PackedVector2Array()
		for q in (d["foot"] as PackedVector2Array):
			foot.append(q + by)
		d["foot"] = foot
		d["bb"] = Rect2((d["bb"] as Rect2).position + by, (d["bb"] as Rect2).size)
		d["at"] = (d["at"] as Vector2) + by
	_paper.queue_redraw()
	_marks.queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if data.is_empty() or _view.is_empty():
		return
	var mb := event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			var m := to_table(mb.position)
			var name := thing_at(m)
			if not name.is_empty():
				selected = name
				_drag = name
				_grab = m
				_now = m
				picked.emit(name)
			_marks.queue_redraw()
			accept_event()
		elif not _drag.is_empty():
			var name := _drag
			_drag = ""
			if _now.distance_to(_grab) > 0.003:
				var mid := Vector2.ZERO
				for t in data.get("things", []):
					if String((t as Dictionary).get("name", "")) == name:
						mid = (t as Dictionary)["at"]
				shift(name, _now - _grab)
				moved.emit(name, at_cm(mid + _now - _grab))
			_marks.queue_redraw()
			accept_event()
		return
	var mm := event as InputEventMouseMotion
	if mm != null and not _drag.is_empty():
		_now = to_table(mm.position)
		_marks.queue_redraw()
		accept_event()


func _draw_marks(c: CanvasItem) -> void:
	if _view.is_empty():
		return
	for t in data.get("things", []):
		var d: Dictionary = t
		var name := String(d.get("name", ""))
		if name != selected and name != _drag:
			continue
		var by := (_now - _grab) if name == _drag else Vector2.ZERO
		var pts := PackedVector2Array()
		for q in (d["foot"] as PackedVector2Array):
			pts.append((_view["origin"] as Vector2) + (q + by) * float(_view["scale"]))
		if pts.size() >= 2:
			pts.append(pts[0])
			c.draw_polyline(pts, Color(0.95, 0.45, 0.1), 5.0, true)
