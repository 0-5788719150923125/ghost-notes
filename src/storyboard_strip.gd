extends Control
class_name StoryboardStrip

## StoryboardStrip - a storyboard's entries laid along a ruler: one block per entry, as wide as it
## is scheduled to stay, the tail's after the sequence's. The top row of the [StoryboardEditor].
##
## WHAT IS DRAWN IS WHAT PLAYS: the blocks' starts and lengths are [method Storyboard.schedule]'s,
## the same arithmetic the Director walks, handed in as rows ([member rows]) - this control works
## nothing out about a storyboard itself. An entry held for a fixed time has a hard right edge; one
## that leaves on a cue, or runs its scene's own length, has no fixed end, so its block stops where
## the schedule counts it from and its edge is drawn broken.
##
## IT ASKS, THE EDITOR DOES. A click picks an entry ([signal picked]); a block dragged along the
## row is moved to where it is dropped ([signal moved]); the right edge of a fixed hold dragged is
## a new length ([signal stretched]). Each gesture is ONE signal, raised when the button comes up, so
## a drag is one edit and one step back - the block follows the pointer in between, as a drawing.
## The wheel pans the ruler; with Ctrl it zooms about the pointer ([TimelineView]).

## An entry was clicked: its index, the tail's counted on from the sequence's end; -1 for a click
## on none.
signal picked(index: int)
## An entry was dragged to another place in its own list.
signal moved(from: int, to: int)
## A fixed hold's right edge was dragged: the entry's new SCHEDULED length, in seconds.
signal stretched(index: int, length: float)

const RULER_H := 18.0
const BLOCK_H := 40.0
const EDGE := 6.0                  # how near a block's right edge a pointer grabs it, px
const DRAG_START := 6.0            # how far a pointer moves before a click is a drag, px
const HEIGHT := RULER_H + BLOCK_H + 6.0
const COL_STAGE := Color(0.95, 0.66, 0.28)
const COL_SCENE := Color(0.42, 0.62, 0.95)
const COL_TAIL := Color(0.62, 0.52, 0.86)
const COL_GHOST := Color(0.6, 0.64, 0.7)

## The entries: `{name, start, length, timing, tail, stage}` each, in walk order (the sequence,
## then the tail). `start` and `length` are scheduled seconds.
var rows: Array = []
## The index picked, -1 for none.
var selected := -1
## Where the show is: the entry on screen and how long it has been up; -1 for none.
var play_entry := -1
var play_elapsed := 0.0
## Blocks are shown, never moved (a storyboard read from a file, or one nobody wrote).
var read_only := false
## The ruler shared with whoever else draws in the same seconds.
var view := TimelineView.new()

var _press := -1                   # the entry under the button when it went down
var _press_x := 0.0
var _mode := ""                    # "" | "move" | "size"
var _drag_x := 0.0


func _init() -> void:
	custom_minimum_size = Vector2(120, HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE


## Show [param p_rows], keeping the ruler's zoom. The ruler is as long as the entries, and a
## little more, so there is always somewhere to drop the last one.
func set_rows(p_rows: Array) -> void:
	rows = p_rows
	var end := 1.0
	for r in rows:
		end = maxf(end, float(r["start"]) + float(r["length"]))
	view.extent = end * 1.08 + 0.5
	view.pan(0.0)
	queue_redraw()


func _process(_delta: float) -> void:
	if not is_equal_approx(view.width, size.x):
		view.width = maxf(1.0, size.x)
		queue_redraw()


## The entry whose block is under [param x], or -1.
func index_at(x: float) -> int:
	for i in rows.size():
		var r := _rect(i)
		if x >= r.position.x and x <= r.end.x:
			return i
	return -1


func _rect(i: int) -> Rect2:
	var r: Dictionary = rows[i]
	var x0 := view.x_of(float(r["start"]))
	var x1 := view.x_of(float(r["start"]) + float(r["length"]))
	return Rect2(x0, RULER_H + 2.0, maxf(3.0, x1 - x0 - 1.0), BLOCK_H)


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null:
		if mb.pressed and mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var up := mb.button_index == MOUSE_BUTTON_WHEEL_UP
			if mb.ctrl_pressed:
				view.zoom_at(mb.position.x, 1.25 if up else 0.8)
			else:
				view.pan(-0.12 if up else 0.12)
			queue_redraw()
			accept_event()
			return
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_press = index_at(mb.position.x)
			_press_x = mb.position.x
			_drag_x = mb.position.x
			_mode = ""
			picked.emit(_press)                # -1: a click on no entry picks none
			accept_event()
			return
		# the button came up: a drag is one edit, made now
		if _press >= 0 and _mode == "move":
			var to := _drop_index(_press, mb.position.x)
			if to != _press:
				moved.emit(_press, to)
		elif _press >= 0 and _mode == "size":
			var r: Dictionary = rows[_press]
			var length := maxf(Storyboard.MIN_ENTRY, view.t_of(mb.position.x) - float(r["start"]))
			if not is_equal_approx(length, float(r["length"])):
				stretched.emit(_press, length)
		_press = -1
		_mode = ""
		queue_redraw()
		return
	var mm := event as InputEventMouseMotion
	if mm == null:
		return
	if _press < 0:
		var hover := index_at(mm.position.x)
		mouse_default_cursor_shape = Control.CURSOR_HSIZE if _on_edge(hover, mm.position.x) else Control.CURSOR_ARROW
		return
	if read_only:
		return
	_drag_x = mm.position.x
	if _mode.is_empty() and absf(mm.position.x - _press_x) >= DRAG_START:
		_mode = "size" if _on_edge(_press, _press_x) else "move"
	if not _mode.is_empty():
		queue_redraw()


## Is [param x] on the right edge of entry [param i], where a fixed hold is dragged longer?
func _on_edge(i: int, x: float) -> bool:
	if i < 0 or read_only or String((rows[i] as Dictionary)["timing"]) != "hold":
		return false
	return absf(x - _rect(i).end.x) <= EDGE


## Where entry [param from] lands when it is let go at [param x]: an index in its OWN list (the
## sequence's entries stay in the sequence, the tail's in the tail).
func _drop_index(from: int, x: float) -> int:
	var tail := bool((rows[from] as Dictionary)["tail"])
	var first := -1
	var before := 0                    # the others of its list whose middle the pointer has passed
	for i in rows.size():
		if bool((rows[i] as Dictionary)["tail"]) != tail:
			continue
		if first < 0:
			first = i
		if i == from:
			continue
		var r := _rect(i)
		if x > r.position.x + r.size.x * 0.5:
			before += 1
	return first + before


func _draw() -> void:
	var font := get_theme_default_font()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.25))
	_draw_ruler(font)
	for i in rows.size():
		if _mode == "move" and i == _press:
			continue
		_draw_block(i, _rect(i), font, 1.0)
	if _press >= 0 and _mode == "move":
		var r := _rect(_press)
		r.position.x += _drag_x - _press_x
		_draw_block(_press, r, font, 0.75)
		var to := _drop_index(_press, _drag_x)
		var tr := _rect(to)
		var x := tr.end.x if to > _press else tr.position.x
		draw_line(Vector2(x, RULER_H), Vector2(x, size.y), Color(1, 1, 1, 0.9), 2.0)
	elif _press >= 0 and _mode == "size":
		var r2 := _rect(_press)
		r2.size.x = maxf(3.0, _drag_x - r2.position.x)
		draw_rect(r2, Color(1, 1, 1, 0.25))
		draw_line(Vector2(r2.end.x, RULER_H), Vector2(r2.end.x, size.y), Color(1, 1, 1, 0.9), 2.0)
	if play_entry >= 0 and play_entry < rows.size():
		var p: Dictionary = rows[play_entry]
		var px := view.x_of(float(p["start"]) + minf(play_elapsed, float(p["length"])))
		draw_line(Vector2(px, 0), Vector2(px, size.y), Color(1.0, 0.35, 0.35), 2.0)


func _draw_ruler(font: Font) -> void:
	var span := view.visible_span()
	var step := 1.0
	for s in [1.0, 2.0, 5.0, 10.0, 30.0, 60.0, 120.0, 300.0, 600.0]:
		step = s
		if span / s <= size.x / 70.0:
			break
	var t := floorf(view.view_start / step) * step
	while t <= view.view_start + span:
		var x := view.x_of(t)
		if x >= 0.0:
			draw_line(Vector2(x, RULER_H - 5.0), Vector2(x, RULER_H), Color(1, 1, 1, 0.45))
			draw_string(font, Vector2(x + 3.0, RULER_H - 5.0), _clock(t), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.55))
		t += step
	draw_line(Vector2(0, RULER_H), Vector2(size.x, RULER_H), Color(1, 1, 1, 0.2))


func _draw_block(i: int, r: Rect2, font: Font, alpha: float) -> void:
	var row: Dictionary = rows[i]
	var col := COL_GHOST if read_only and bool(row.get("ghost", false)) else \
		(COL_TAIL if bool(row["tail"]) else (COL_STAGE if bool(row["stage"]) else COL_SCENE))
	var picked_now := i == selected
	draw_rect(r, Color(col, (0.55 if picked_now else 0.3) * alpha))
	draw_rect(r, Color(col, alpha), false, 2.0 if picked_now else 1.0)
	if String(row["timing"]) != "hold":
		# no fixed end: the edge is broken where the schedule only counts from
		var x := r.end.x
		draw_rect(Rect2(x - 1.0, r.position.y, 3.0, r.size.y), Color(0.05, 0.05, 0.08, 1.0))
		var y := r.position.y
		while y < r.end.y:
			draw_line(Vector2(x, y), Vector2(x, minf(y + 4.0, r.end.y)), Color(col, alpha), 1.0)
			y += 8.0
	if r.size.x < 26.0:
		return
	var label := "%d  %s" % [i + 1, String(row["name"]).replace("_", " ")]
	var w := int(r.size.x - 8.0)
	draw_string(font, r.position + Vector2(5.0, 16.0), label, HORIZONTAL_ALIGNMENT_LEFT, w, 12, Color(1, 1, 1, 0.95 * alpha))
	var said := ("%.1f s" % float(row["length"])) if String(row["timing"]) == "hold" else \
		("on a cue" if String(row["timing"]) == "cue" else "its own")
	if bool(row["tail"]):
		said += "  ↻"
	draw_string(font, r.position + Vector2(5.0, 32.0), said, HORIZONTAL_ALIGNMENT_LEFT, w, 10, Color(1, 1, 1, 0.6 * alpha))


static func _clock(t: float) -> String:
	var s := int(maxf(0.0, t))
	return "%d:%02d" % [s / 60, s % 60]
