extends Control
class_name TrackLane

## TrackLane - one clip's block on the shared timeline: drag its left/right edges to trim (in/out
## points), drag its body to shift where it sits on the master timeline. Used for the primary clip's own
## trim block (offset fixed at 0, so `movable` is false there) and one lane per imported track (offset
## draggable). Every lane shares the same TimelineView as the marker strip below them (see
## mask_timeline.gd), so a second lines up in every row; dragging this lane's edges never touches that
## view's cached extent (see TimelineView.refresh), so the ruler a handle is measured against does not
## move mid-drag.
##
## Backed by Callables, not a fixed field name: the caller wires whether a lane reads and writes
## session.clip_in/clip_out (the primary) or one session.tracks[i] dict (a secondary track).

signal changed
## Fired once per drag gesture, before the first mutation - the undo hook, mirroring MaskTimeline.marker_drag_started.
signal drag_started
## Fired once a drag gesture ends (mouse-up): the only safe point to refresh the shared TimelineView's
## cached extent (see TimelineView.refresh), as doing it mid-drag would rescale the ruler being dragged against.
signal drag_ended

var tview: TimelineView = null
var label := ""
var color := Color(0.5, 0.7, 1.0)
var movable := true         # false for the primary lane - its offset is always 0
var full_duration := 0.0    # the SOURCE clip's own full length; trim can't exceed it
## Px of the lane's left edge already occupied by another overlaid control (the volume knob mask_editor.gd
## anchors top-left on every lane): the label starts past this so it never draws under the knob.
var reserved_left := 0.0

var get_in: Callable
var set_in: Callable
var get_out: Callable
var set_out: Callable
var get_offset: Callable = func(): return 0.0
var set_offset: Callable = Callable()   # invalid = shift disabled (the primary lane)
## Fade envelope (seconds in from each trimmed edge). The fade boundary is a second handle at each edge
## (see _hit). Invalid = fades disabled.
var get_fade_in: Callable = Callable()
var set_fade_in: Callable = Callable()
var get_fade_out: Callable = Callable()
var set_fade_out: Callable = Callable()
## Master-timeline seconds to snap a dragged clip's start/end to (other clips' edges,
## the playhead, 0). Invalid = no snapping.
var get_snap_targets: Callable = Callable()
## Current master-timeline playhead position, in seconds. Invalid = no playhead drawn (the primary lane
## skips this: its own timestamp already sits in the marker strip; secondary tracks show their own
## source position at the shared playhead).
var get_playhead: Callable = Callable()

const _EDGE_W := 8.0
const _SNAP_PX := 8.0   # a dragged clip edge within this many px of a target snaps to it
# A fade handle coincident with its trim handle (fade == 0) draws and hits _HANDLE_GAP px in from the
# trim edge, so the two are always adjacent, full-height, independently grabbable targets.
const _HANDLE_GAP := 7.0
var _drag_mode := ""   # "" | "in" | "out" | "fade_in" | "fade_out" | "body"
var _drag_started_emitted := false
var _body_grab_dx := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(0, 26)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _process(_dt: float) -> void:
	# Hide the whole row once its clip's span is entirely outside the zoom/pan window (the same bounds
	# check _draw uses to skip the block): there is nothing to grab, and the VBoxContainer collapses the space.
	if tview != null:
		var b := _bounds()
		visible = tview.x_of(b.y) >= 0.0 and tview.x_of(b.x) <= size.x
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if tview == null:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		# Ctrl+wheel zooms from any lane, about the pointer, as on the strip; a plain wheel is left to the list of lanes, which scrolls them
		if mb.ctrl_pressed and tview.wheel(mb):
			accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_drag_mode = _hit(mb.position)
				_drag_started_emitted = false
				if _drag_mode == "body":
					_body_grab_dx = mb.position.x - tview.x_of(float(get_offset.call()))
				if _drag_mode != "":
					accept_event()
			else:
				var was_dragging := _drag_mode != ""
				_drag_mode = ""
				if was_dragging and _drag_started_emitted:
					drag_ended.emit()
				accept_event()
	elif event is InputEventMouseMotion and _drag_mode != "":
		if not _drag_started_emitted:
			_drag_started_emitted = true
			drag_started.emit()
		_apply_drag(event.position.x)
		accept_event()


func _fade_in_s() -> float:
	return maxf(0.0, float(get_fade_in.call())) if get_fade_in.is_valid() else 0.0


func _fade_out_s() -> float:
	return maxf(0.0, float(get_fade_out.call())) if get_fade_out.is_valid() else 0.0


## The clip's [left, right] edges in master-timeline seconds. A movable (secondary) lane sits at its own
## `offset`, independent of clip_in/clip_out in its own source. The fixed primary lane has no
## independent placement - clip_in/clip_out already are master time (offset is always 0) - so its
## bounds are the trim points directly. Every hit-test, draw and drag reads through this.
func _bounds() -> Vector2:
	var cin: float = get_in.call()
	var cout: float = get_out.call()
	if movable:
		var offset: float = get_offset.call()
		return Vector2(offset, offset + (cout - cin))
	return Vector2(cin, cout)


## The x-position each fade boundary handle draws/hits at: its real position (b.x + fade_in_s / b.y -
## fade_out_s) once dragged out past _HANDLE_GAP, else nudged in from a coincident trim edge. The fade
## seconds themselves (where the envelope starts, drawn in _draw) are never touched by this.
func _fade_handle_xs(x0: float, x1: float, b: Vector2, span: float) -> Vector2:
	var xfi := x0
	var xfo := x1
	if set_fade_in.is_valid():
		xfi = maxf(tview.x_of(b.x + clampf(_fade_in_s(), 0.0, span)), x0 + _HANDLE_GAP)
	if set_fade_out.is_valid():
		xfo = minf(tview.x_of(b.y - clampf(_fade_out_s(), 0.0, span)), x1 - _HANDLE_GAP)
	return Vector2(xfi, xfo)


func _hit(pos: Vector2) -> String:
	var span: float = float(get_out.call()) - float(get_in.call())
	var b := _bounds()
	var x0 := tview.x_of(b.x)
	var x1 := tview.x_of(b.y)
	var fx := _fade_handle_xs(x0, x1, b, span)
	# Whichever handle center is closest wins, over the full lane height, so a click on the trim edge
	# grabs the trim edge even though the fade handle sits _HANDLE_GAP px away.
	var best_mode := ""
	var best_d := _EDGE_W
	if set_fade_in.is_valid():
		var d: float = absf(pos.x - fx.x)
		if d <= best_d:
			best_d = d
			best_mode = "fade_in"
	if set_fade_out.is_valid():
		var d: float = absf(pos.x - fx.y)
		if d <= best_d:
			best_d = d
			best_mode = "fade_out"
	var d_in: float = absf(pos.x - x0)
	if d_in <= best_d:
		best_d = d_in
		best_mode = "in"
	var d_out: float = absf(pos.x - x1)
	if d_out <= best_d:
		best_d = d_out
		best_mode = "out"
	if best_mode != "":
		return best_mode
	if pos.x > x0 and pos.x < x1 and movable:
		return "body"
	return ""


func _apply_drag(x: float) -> void:
	var t := tview.t_of(x)
	var offset: float = get_offset.call()
	var span: float = float(get_out.call()) - float(get_in.call())
	var b := _bounds()
	match _drag_mode:
		"in":
			var cur_out: float = get_out.call()
			var cur_in: float = get_in.call()
			var delta := 0.0
			if movable:
				# A movable lane's right edge is offset + (clip_out - clip_in), so moving clip_in alone
				# would drag the right edge: shift clip_in and offset by the same delta, so the right
				# edge stays put and the left edge tracks the cursor.
				delta = t - offset
				var delta_min: float = -minf(cur_in, offset)
				var delta_max: float = cur_out - 0.1 - cur_in
				delta = clampf(delta, delta_min, delta_max)
				set_in.call(cur_in + delta)
				set_offset.call(offset + delta)
			else:
				var new_in := clampf(t - offset, 0.0, cur_out - 0.1)
				delta = new_in - cur_in
				set_in.call(new_in)
			# Rescale the fade: a fade boundary already set keeps its absolute position as the trim edge
			# slides past it, so the ramp stretches or shrinks. Only once a fade has been dragged out; a
			# fresh (duration 0) edge stays at 0.
			if set_fade_in.is_valid() and _fade_in_s() > 0.0:
				set_fade_in.call(clampf(_fade_in_s() - delta, 0.0, maxf(0.0, cur_out - (cur_in + delta))))
		"out":
			var cur_in: float = get_in.call()
			var cur_out: float = get_out.call()
			var new_out: float
			if movable:
				# Left edge (offset, clip_in) stays put; only clip_out follows the cursor.
				new_out = clampf(t - offset + cur_in, cur_in + 0.1, full_duration)
			else:
				new_out = clampf(t - offset, cur_in + 0.1, full_duration)
			set_out.call(new_out)
			# Same automatic rescale as the "in" edge, mirrored.
			if set_fade_out.is_valid() and _fade_out_s() > 0.0:
				var delta_out := new_out - cur_out
				set_fade_out.call(clampf(_fade_out_s() + delta_out, 0.0, maxf(0.0, new_out - cur_in)))
		"fade_in":
			if set_fade_in.is_valid():
				set_fade_in.call(clampf(t - b.x, 0.0, span))
		"fade_out":
			if set_fade_out.is_valid():
				set_fade_out.call(clampf(b.y - t, 0.0, span))
		"body":
			if set_offset.is_valid():
				var raw := _snap_offset(tview.t_of(x - _body_grab_dx), span)
				set_offset.call(clampf(raw, 0.0, maxf(0.0, tview.extent - span)))
	changed.emit()


## Gentle snap: if the dragged clip's start or end lands within _SNAP_PX of any snap target (other clip
## edges, the playhead, 0), align it exactly. Returns the offset.
func _snap_offset(raw: float, span: float) -> float:
	if not get_snap_targets.is_valid():
		return raw
	var tol: float = absf(tview.t_of(_SNAP_PX) - tview.t_of(0.0))   # px threshold, in seconds
	var best := raw
	var best_d := tol
	for tv in get_snap_targets.call():
		var tgt := float(tv)
		var d0 := absf(raw - tgt)                # snap the clip's start
		if d0 < best_d:
			best_d = d0
			best = tgt
		var d1 := absf((raw + span) - tgt)       # snap the clip's end
		if d1 < best_d:
			best_d = d1
			best = tgt - span
	return best


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.09, 0.10, 0.13, 0.94))
	if tview == null:
		return
	var offset: float = get_offset.call()
	var cin: float = get_in.call()
	var cout: float = get_out.call()
	var b := _bounds()
	var x0 := tview.x_of(b.x)
	var x1 := tview.x_of(b.y)
	if x1 < 0.0 or x0 > size.x:
		return
	var xa := clampf(x0, -4.0, size.x + 4.0)
	var xb := clampf(x1, -4.0, size.x + 4.0)
	draw_rect(Rect2(xa, 2, maxf(1.0, xb - xa), size.y - 4), Color(color.r, color.g, color.b, 0.35))
	draw_rect(Rect2(xa, 2, maxf(1.0, xb - xa), size.y - 4), Color(color.r, color.g, color.b, 0.9), false, 2.0)
	# Fade envelope: a triangle darkening the clip from full at the fade boundary down to silence at the
	# trimmed edge (the same envelope drives audio and video). Only the ramp is drawn.
	var span := cout - cin
	var top := 2.0
	var bot := size.y - 2.0
	var xfi := tview.x_of(b.x + clampf(_fade_in_s(), 0.0, span))
	var xfo := tview.x_of(b.y - clampf(_fade_out_s(), 0.0, span))
	if _fade_in_s() > 0.0 and xfi > x0:
		draw_colored_polygon(PackedVector2Array([Vector2(x0, bot), Vector2(xfi, top), Vector2(xfi, bot)]),
			Color(0.02, 0.02, 0.04, 0.62))
	if _fade_out_s() > 0.0 and xfo < x1:
		draw_colored_polygon(PackedVector2Array([Vector2(xfo, top), Vector2(x1, bot), Vector2(xfo, bot)]),
			Color(0.02, 0.02, 0.04, 0.62))
	# Grip handles at each trimmable edge (drawn even for the immovable primary: only body shift is gated by `movable`).
	if x0 >= -_EDGE_W and x0 <= size.x + _EDGE_W:
		draw_rect(Rect2(x0 - 2.5, 2, 5, size.y - 4), color.lightened(0.35))
	if x1 >= -_EDGE_W and x1 <= size.x + _EDGE_W:
		draw_rect(Rect2(x1 - 2.5, 2, 5, size.y - 4), color.lightened(0.35))
	# The second handle at each edge - the fade boundary - a full-height bright bar nudged _HANDLE_GAP px
	# in from a coincident trim edge (see _fade_handle_xs).
	var fade_col := Color(1.0, 0.95, 0.55, 0.95)
	var fx := _fade_handle_xs(x0, x1, b, span)
	if set_fade_in.is_valid() and fx.x >= -_EDGE_W and fx.x <= size.x + _EDGE_W:
		draw_rect(Rect2(fx.x - 2.0, 2, 4, size.y - 4), fade_col)
	if set_fade_out.is_valid() and fx.y >= -_EDGE_W and fx.y <= size.x + _EDGE_W:
		draw_rect(Rect2(fx.y - 2.0, 2, 4, size.y - 4), fade_col)
	if label != "":
		# ...inside its block, cut at its end, so a name past a short block does not run over the next one's
		var lx := clampf(maxf(xa + 6, reserved_left), 4, size.x - 60)
		var room := minf(xb, size.x) - lx - 4.0
		if room > 18.0:
			draw_string(ThemeDB.fallback_font, Vector2(lx, size.y * 0.5 + 4),
				label, HORIZONTAL_ALIGNMENT_LEFT, room, 12, Color(0.9, 0.92, 0.96, 0.9))
	# Playhead, same style as MaskTimeline's, tagged with this track's own local source position (cin +
	# how far the master playhead sits into the clip's span). Only drawn while the master playhead is over
	# this clip's span (outside it the track isn't playing, see MaskTracks.sync).
	if get_playhead.is_valid():
		var master_t: float = get_playhead.call()
		var local_t := master_t - offset + cin
		if local_t >= cin and local_t < cout:
			var px := tview.x_of(master_t)
			if px >= -2.0 and px <= size.x + 2.0:
				TimelineView.draw_playhead(self, px, Color(1, 1, 1, 0.92), Clock.text(local_t))
