extends Control
class_name FlagStrip

## FlagStrip - the timeline's flags: a scrub strip with markers on it, Masking's and the editor's alike
## (next/editing.md, "The Timeline"). Masking's [MaskTimeline] is this with its clip's waveform under
## it; any timeline hands it its flags through Callables, as [TrackLane] is handed its block.
##
## Click-drag on the body to scrub (emits `scrubbed`). Marker moves are two-step: a marker's triangle
## handle (the top band only) is grabbable only once it is the selected marker. The first press on a
## handle selects it (emits `marker_picked`); a second press-drag on the selected marker moves it
## (emits `marker_moved` while held).
##
## Ctrl+scroll zooms around the cursor (plain scroll pans when zoomed); all drawing and hit-testing go
## through the shared [TimelineView], so this strip and any lane above it agree on where a second sits.
##
## A marker is a Dictionary with a `time`, and a ramp or a damp (`kind` 0 or 1; see MaskSession.MARKER_KINDS):
## it draws as its anchor line, a triangle handle pointing the way its span runs (back for a ramp, forward
## for a damp) and a translucent tint across exactly its span ([member get_span]). A flag with no span is
## a moment, its tint a hairline.

signal scrubbed(t: float)
signal marker_picked(m: Dictionary)
## Fired once per drag gesture, before the first time-mutation - the undo hook. A plain click-to-select never fires it.
signal marker_drag_started(m: Dictionary)
signal marker_moved(m: Dictionary)

## The shared pixel<->time mapping (one instance shared with every lane).
var tview: TimelineView = null
## The currently-selected marker Dictionary, or null.
var selected: Variant = null
## () -> Array of marker Dictionaries, each with a `time` (and a `kind`, 0 ramp or 1 damp).
var get_markers: Callable = Callable()
## (m) -> Vector2: the seconds marker [param m]'s tint covers; invalid for none.
var get_span: Callable = Callable()
## (m, t) -> void: marker [param m] moved to [param t]; invalid writes `m.time` itself.
var set_time: Callable = Callable()
## () -> float: the latest time a marker may stand at.
var get_extent: Callable = Callable()
## () -> float: where the playhead is.
var get_playhead: Callable = Callable()
## () -> String: what the strip says while it has nothing to show ("" while it has).
var get_empty: Callable = Callable()

var _dragging := false                 # scrubbing the playhead (grabbed empty space)
var _dragging_marker: Variant = null   # the marker Dictionary being dragged, or null
var _drag_started_emitted := false     # per-gesture latch for marker_drag_started

const _HANDLE_H := 16.0    # the triangle-handle band; also the only marker-grab region


func _ready() -> void:
	custom_minimum_size = Vector2(0, 84)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true   # zoomed-in drawing runs past both edges; never bleed out


func _process(_dt: float) -> void:
	if tview != null:
		tview.width = maxf(1.0, size.x)
	queue_redraw()


# --- what it is handed (a subclass may answer these itself) ----------------------------------------------------------

func _markers() -> Array:
	return get_markers.call() if get_markers.is_valid() else []


func _span_of(m: Dictionary) -> Vector2:
	return get_span.call(m) if get_span.is_valid() else Vector2(float(m.get("time", 0.0)), float(m.get("time", 0.0)))


func _move(m: Dictionary, t: float) -> void:
	if set_time.is_valid():
		set_time.call(m, t)
	else:
		m["time"] = t


func _extent() -> float:
	return get_extent.call() if get_extent.is_valid() else (tview.extent if tview != null else 0.0)


func _playhead() -> float:
	return get_playhead.call() if get_playhead.is_valid() else 0.0


## What it says while it cannot be worked ("" while it can).
func _empty_text() -> String:
	if tview == null:
		return "nothing to show"
	return get_empty.call() if get_empty.is_valid() else ""


## Drawn over the background and under the tints, ruler and markers: a subclass's waveform.
func _draw_under() -> void:
	pass


# --- the gestures ---------------------------------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if not _empty_text().is_empty():
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if tview.wheel(mb):
			accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				var m: Variant = _marker_near(mb.position)
				if m != null:
					# Two-step (see the class doc): the first press on a marker only selects it. The owner keeps
					# `selected` in sync from marker_picked synchronously, so the next press sees it selected.
					if selected != null and selected == m:
						_dragging_marker = m
						_drag_started_emitted = false
					else:
						marker_picked.emit(m)
				else:
					_dragging = true
					scrubbed.emit(tview.t_of(mb.position.x))
			else:
				_dragging = false
				_dragging_marker = null
			accept_event()
	elif event is InputEventMouseMotion:
		if _dragging_marker != null:
			_drag_marker_to_x(event.position.x)
			accept_event()
		elif _dragging:
			scrubbed.emit(tview.t_of(event.position.x))
			accept_event()


## Move the dragged marker to the time under `x`.
func _drag_marker_to_x(x: float) -> void:
	if not _drag_started_emitted:
		_drag_started_emitted = true
		marker_drag_started.emit(_dragging_marker)
	_move(_dragging_marker, clampf(tview.t_of(x), 0.0, _extent()))
	marker_moved.emit(_dragging_marker)


## Markers are grabbable only by their triangle handle in the top band - clicking the strip's body always scrubs.
func _get_tooltip(at: Vector2) -> String:
	# A flag's name under the pointer: every flag within a few pixels of it, one a line.
	var said := PackedStringArray()
	for m in _markers():
		if (m as Dictionary).has("label") and absf(tview.x_of(float(m.time)) - at.x) <= 6.0:
			said.append("%s  %s" % [Clock.text(float(m.time)), String(m["label"])])
	return "\n".join(said)


func _marker_near(pos: Vector2) -> Variant:
	if pos.y > _HANDLE_H + 4.0:
		return null
	for m in _markers():
		var mx := tview.x_of(float(m.time))
		if pos.x > mx - 7.0 and pos.x < mx + _HANDLE_H:   # anchor edge through triangle tip
			return m
	return null


# --- the drawing ----------------------------------------------------------------------------------------------------

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.09, 0.10, 0.13, 0.94))
	var empty := _empty_text()
	if not empty.is_empty():
		draw_string(ThemeDB.fallback_font, Vector2(12, size.y * 0.5 + 4), empty, HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
			Color(0.5, 0.55, 0.62))
		return
	var span := tview.visible_span()
	var end := _extent()
	_draw_under()
	# Marker spans: a translucent tint across the time range of each marker's ramp/damp. Ramp = cool/green, damp = warm/orange.
	var markers := _markers()
	for m in markers:
		var mspan := _span_of(m)
		var x0 := tview.x_of(clampf(mspan.x, 0.0, end))
		var x1 := tview.x_of(clampf(mspan.y, 0.0, end))
		if x1 < 0.0 or x0 > size.x:
			continue
		var is_ramp: bool = int(m.get("kind", 0.0)) == 0
		var tint := Color(0.45, 0.85, 0.55, 0.16) if is_ramp else Color(0.95, 0.55, 0.3, 0.16)
		draw_rect(Rect2(x0, 0, maxf(1.0, x1 - x0), size.y), tint)
	# The ruler adapts its tick step to the visible window ([method TimelineView.step_for]).
	var step := TimelineView.step_for(span, 14.0)
	for tt in tview.ticks(step):
		var x := tview.x_of(tt)
		draw_line(Vector2(x, size.y - 14), Vector2(x, size.y), Color(0.3, 0.34, 0.4, 0.6), 1.0)
		draw_string(ThemeDB.fallback_font, Vector2(x + 3, size.y - 4),
			TimelineView.tick_label(tt, step), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.45, 0.5, 0.58))
	# Markers: an anchor line (taller/brighter when selected) plus a triangle handle pointing back (ramp)
	# or forward (damp), colored to match its span tint. The handle is also the only grab region (see _marker_near).
	for m in markers:
		var x := tview.x_of(float(m.time))
		if x < -20.0 or x > size.x + 20.0:
			continue
		var on: bool = selected != null and selected == m
		var is_ramp: bool = int(m.get("kind", 0.0)) == 0
		draw_line(Vector2(x, 0), Vector2(x, size.y - 16),
			Color(1.0, 0.82, 0.4, 0.95) if on else Color(0.55, 0.75, 1.0, 0.85), 3.0 if on else 2.0)
		var col := Color(0.5, 0.95, 0.6) if is_ramp else Color(0.98, 0.6, 0.35)
		if on:
			col = col.lightened(0.35)
		var h := _HANDLE_H
		var tip_x := x - h * 0.7 if is_ramp else x + h * 0.7
		var pts := PackedVector2Array([Vector2(x, 1), Vector2(x, h), Vector2(tip_x, h * 0.5)])
		draw_colored_polygon(pts, col)
		# No words beside a flag: a flag's name is its tooltip, and every flag is listed on the panel's Timeline card.
	# Playhead, with its own time tag riding right above it.
	var t := _playhead()
	var px := tview.x_of(t)
	if px >= -2.0 and px <= size.x + 2.0:
		TimelineView.draw_playhead(self, px, Color(1, 1, 1, 0.92), Clock.text(t))
	# Zoom badge, so a zoomed view never masquerades as the whole of it.
	if tview.zoom > 1.01:
		draw_string(ThemeDB.fallback_font, Vector2(size.x - 74, 14),
			"%.0fx zoom" % tview.zoom, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.7, 0.78, 0.9, 0.8))
