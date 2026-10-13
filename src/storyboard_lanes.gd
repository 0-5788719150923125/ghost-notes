extends Control
class_name StoryboardLanes

## StoryboardLanes - one stage entry's timeline: a lane per actor, and on it every span that
## happens to that actor - a block for a window (`from` to `to`), a diamond for a moment (`at`).
## The lower rows of the [StoryboardEditor], shown while a stage entry is picked.
##
## THE RULER IS THE ENTRY'S OWN: a track's times are written in seconds of its `nominal`, the
## length it was designed at, and they scale as one piece with the entry's hold and the story's
## tempo - so a lane is drawn in nominal seconds, and dragging a span changes the number that is
## written, whatever speed the entry plays at.
##
## A SPAN FOR SEVERAL ACTORS IS ON EACH OF THEIR LANES; one for everyone (no `target`) is on the
## lane at the top. It is one span wherever it is drawn: picking or dragging it on any lane is the
## same edit.
##
## IT ASKS, THE EDITOR DOES - one signal per gesture, raised when the button comes up, as on
## [StoryboardStrip]: [signal picked], [signal retimed] (a span moved or stretched), and
## [signal wanted] (a double click on empty lane: a new span there, for that actor).

## A span was clicked: its index in the track's list.
signal picked(span: int)
## A span was dragged: its new start and end in nominal seconds (equal, for a moment).
signal retimed(span: int, from: float, to: float)
## An empty place on a lane was double-clicked: [param actor] ("" for everyone) and the time.
signal wanted(actor: String, at: float)

const RULER_H := 16.0
const LANE_H := 22.0
const GUTTER := 96.0               # the lanes' names, at the left
const EDGE := 5.0
const DRAG_START := 5.0
const EVERYONE := ""
const COL_SPAN := Color(0.95, 0.66, 0.28)
const COL_CUE := Color(0.5, 0.86, 0.72)

## The actors' names, in the cast's order.
var actors: Array = []
## The track's spans, as they are written.
var spans: Array = []
## The track's design length, in seconds.
var nominal := 8.0
## The span picked, -1 for none.
var selected := -1
## Seconds into the entry the show is, in nominal seconds; negative when it is not on screen.
var playhead := -1.0
var read_only := false

var _press := -1
var _press_x := 0.0
var _press_lane := 0
var _mode := ""                    # "" | "move" | "in" | "out"
var _drag_x := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(160, RULER_H + LANE_H)


## Show a track: [param p_actors] the cast's names, [param p_spans] its spans, [param p_nominal]
## its design length.
func set_track(p_actors: Array, p_spans: Array, p_nominal: float) -> void:
	actors = p_actors
	spans = p_spans
	nominal = maxf(0.1, p_nominal)
	custom_minimum_size.y = RULER_H + LANE_H * float(_lanes().size()) + 4.0
	queue_redraw()


## The lanes, top to bottom: everyone, then each actor - and any name a span is aimed at that the
## cast does not have, so a span written for a missing actor is seen rather than lost.
func _lanes() -> Array:
	var out: Array = [EVERYONE]
	out.append_array(actors)
	for sp in spans:
		for id in targets_of(sp):
			if not out.has(id):
				out.append(id)
	return out


## The actors a span is aimed at, [] for everyone.
static func targets_of(span: Variant) -> Array:
	if not (span is Dictionary):
		return []
	var t: Variant = (span as Dictionary).get("target")
	if t is Array:
		var out: Array = []
		for id in t as Array:
			out.append(String(id))
		return out
	if t == null or String(t) == "all" or String(t).is_empty():
		return []
	return [String(t)]


## A span's window, `[from, to]` in nominal seconds; a moment's two ends are the same.
static func window_of(span: Variant) -> Array:
	if not (span is Dictionary):
		return [0.0, 0.0]
	var d: Dictionary = span
	if d.has("from"):
		var a := _sec(d["from"])
		return [a, maxf(a, _sec(d.get("to", d["from"])))]
	var at := _sec(d.get("at", 0.0))
	return [at, at]


static func _sec(v: Variant) -> float:
	return float(v) if typeof(v) in [TYPE_INT, TYPE_FLOAT] else 0.0


func _x(t: float) -> float:
	return GUTTER + t / nominal * maxf(1.0, size.x - GUTTER - 6.0)


func _t(x: float) -> float:
	return clampf((x - GUTTER) / maxf(1.0, size.x - GUTTER - 6.0), 0.0, 1.0) * nominal


func _lane_y(i: int) -> float:
	return RULER_H + LANE_H * float(i)


## The rectangles span [param i] is drawn in, one per lane it is on.
func _rects(i: int) -> Array:
	var out: Array = []
	var lanes := _lanes()
	var w := window_of(spans[i])
	var ids := targets_of(spans[i])
	if ids.is_empty():
		ids = [EVERYONE]
	for id in ids:
		var y := _lane_y(lanes.find(id))
		var x0 := _x(float(w[0]))
		var x1 := _x(float(w[1]))
		if is_equal_approx(float(w[0]), float(w[1])):
			out.append(Rect2(x0 - 6.0, y + 3.0, 12.0, LANE_H - 6.0))
		else:
			out.append(Rect2(x0, y + 3.0, maxf(4.0, x1 - x0), LANE_H - 6.0))
	return out


func _is_moment(i: int) -> bool:
	var w := window_of(spans[i])
	return is_equal_approx(float(w[0]), float(w[1]))


## The span under [param at], or -1: the last one drawn there, which is the one seen.
func span_at(at: Vector2) -> int:
	for i in range(spans.size() - 1, -1, -1):
		for r in _rects(i):
			if (r as Rect2).grow(1.0).has_point(at):
				return i
	return -1


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			_press = span_at(mb.position)
			_press_x = mb.position.x
			_drag_x = mb.position.x
			_mode = ""
			if _press >= 0:
				picked.emit(_press)
			elif mb.double_click and not read_only and mb.position.y >= RULER_H:
				var lanes := _lanes()
				var lane := clampi(int((mb.position.y - RULER_H) / LANE_H), 0, lanes.size() - 1)
				wanted.emit(String(lanes[lane]), snappedf(_t(mb.position.x), 0.05))
			accept_event()
			return
		if _press >= 0 and not _mode.is_empty():
			var w := _dragged(_press)
			var was := window_of(spans[_press])
			if not (is_equal_approx(float(w[0]), float(was[0])) and is_equal_approx(float(w[1]), float(was[1]))):
				retimed.emit(_press, float(w[0]), float(w[1]))
		_press = -1
		_mode = ""
		queue_redraw()
		return
	var mm := event as InputEventMouseMotion
	if mm == null or _press < 0 or read_only:
		return
	_drag_x = mm.position.x
	if _mode.is_empty() and absf(mm.position.x - _press_x) >= DRAG_START:
		_mode = "move"
		if not _is_moment(_press):
			for r in _rects(_press):
				var rect: Rect2 = r
				if absf(_press_x - rect.position.x) <= EDGE:
					_mode = "in"
				elif absf(_press_x - rect.end.x) <= EDGE:
					_mode = "out"
	if not _mode.is_empty():
		queue_redraw()


## Span [param i]'s window as the drag under way leaves it, snapped to a twentieth of a second.
func _dragged(i: int) -> Array:
	var w := window_of(spans[i])
	var a := float(w[0])
	var b := float(w[1])
	var dt := (_drag_x - _press_x) / maxf(1.0, size.x - GUTTER - 6.0) * nominal
	match _mode:
		"move":
			var held := b - a
			a = clampf(a + dt, 0.0, maxf(0.0, nominal - held))
			b = a + held
		"in":
			a = clampf(a + dt, 0.0, b - 0.05)
		"out":
			b = clampf(b + dt, a + 0.05, nominal)
	return [snappedf(a, 0.05), snappedf(b, 0.05)]


func _draw() -> void:
	var font := get_theme_default_font()
	var lanes := _lanes()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.25))
	# the ruler, in nominal seconds
	var step := 1.0
	for s in [0.5, 1.0, 2.0, 5.0, 10.0, 30.0]:
		step = s
		if nominal / s <= (size.x - GUTTER) / 46.0:
			break
	var t := 0.0
	while t <= nominal + 0.001:
		var x := _x(t)
		draw_line(Vector2(x, RULER_H - 4.0), Vector2(x, size.y), Color(1, 1, 1, 0.07))
		draw_string(font, Vector2(x + 2.0, RULER_H - 4.0), SchemaForm.num_text(t), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 1, 1, 0.5))
		t += step
	for i in lanes.size():
		var y := _lane_y(i)
		if i % 2 == 1:
			draw_rect(Rect2(0, y, size.x, LANE_H), Color(1, 1, 1, 0.03))
		var name := "everyone" if String(lanes[i]) == EVERYONE else String(lanes[i])
		var known := i == 0 or actors.has(lanes[i])
		draw_string(font, Vector2(6.0, y + 15.0), name, HORIZONTAL_ALIGNMENT_LEFT, int(GUTTER - 10.0), 11,
			Color(1, 1, 1, 0.7) if known else Color(1.0, 0.55, 0.45, 0.9))
	draw_line(Vector2(GUTTER - 2.0, RULER_H), Vector2(GUTTER - 2.0, size.y), Color(1, 1, 1, 0.2))
	for i in spans.size():
		if not (spans[i] is Dictionary):
			continue
		var sp: Dictionary = spans[i]
		var col := COL_CUE if not String(sp.get("on", "")).is_empty() else COL_SPAN
		var dragging := i == _press and not _mode.is_empty()
		var rects := _rects(i)
		if dragging:
			var w := _dragged(i)
			rects = []
			for r in _rects(i):
				var rect: Rect2 = r
				if _is_moment(i):
					rect.position.x = _x(float(w[0])) - 6.0
				else:
					rect.position.x = _x(float(w[0]))
					rect.size.x = maxf(4.0, _x(float(w[1])) - _x(float(w[0])))
				rects.append(rect)
		for r in rects:
			var rect: Rect2 = r
			var on := i == selected
			if _is_moment(i):
				var c := rect.get_center()
				var h := rect.size.y * 0.5
				var pts := PackedVector2Array([c + Vector2(0, -h), c + Vector2(6, 0), c + Vector2(0, h), c + Vector2(-6, 0)])
				draw_colored_polygon(pts, Color(col, 0.95 if on else 0.6))
				draw_string(font, Vector2(rect.end.x + 3.0, rect.position.y + 12.0), String(sp.get("action", "")).replace("_", " "),
					HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.75))
			else:
				draw_rect(rect, Color(col, 0.6 if on else 0.32))
				draw_rect(rect, Color(col, 1.0), false, 2.0 if on else 1.0)
				draw_string(font, rect.position + Vector2(4.0, 12.0), String(sp.get("action", "")).replace("_", " "),
					HORIZONTAL_ALIGNMENT_LEFT, int(maxf(1.0, rect.size.x - 6.0)), 10, Color(1, 1, 1, 0.95))
	if playhead >= 0.0:
		var px := _x(minf(playhead, nominal))
		draw_line(Vector2(px, 0), Vector2(px, size.y), Color(1.0, 0.35, 0.35), 2.0)
