extends RefCounted
class_name TimelineView

## TimelineView - THE TIMELINE KIT: the shared pixel<->time mapping, and the ruler, wheel and
## playhead every timeline draws with (next/structure.md, step 26). Masking's marker strip and each of
## its track lanes read ONE view, so a second's position agrees across every row; the storyboard's
## strip and a stage entry's lanes keep one each. They tick their rulers by one ladder
## ([method step_for]), zoom and pan with one wheel ([method wheel]), draw one playhead
## ([method draw_playhead]) and tell the time one way ([method Clock.text], as the transport's
## own rail does) - where four had each kept a copy, and the copies had parted.
##
## `extent` is DELIBERATELY a cached value, refreshed only by an explicit
## refresh() call - never derived live from whatever a drag is currently
## touching. In Masking (its session's `timeline_extent()`) the ruler's total length is
## `duration` (which trimming never changes) extended to cover the furthest
## track, plus a fixed overflow margin. Recomputing it mid-drag is exactly the
## "drag a clip's edge and the whole ruler rescales under your cursor" bug every
## timeline editor seems to hit eventually - refresh() is called once a gesture
## ENDS (mouse-up), never during one, so the ruler a handle is being measured
## against never moves while that same handle is what's moving it.

const _MAX_ZOOM := 64.0
## The ruler's steps, seconds: the first that fits is the one ticked ([method step_for]).
const STEPS := [0.5, 1.0, 2.0, 5.0, 10.0, 30.0, 60.0, 120.0, 300.0, 600.0]
## The wheel: how much a Ctrl+wheel notch zooms, and how much of the window a plain notch pans.
const WHEEL_ZOOM := 1.25
const WHEEL_PAN := 0.1

var zoom := 1.0
var view_start := 0.0      # left edge of the visible window, seconds
var extent := 1.0          # cached total ruler length, seconds - see refresh()
var width := 1.0           # widest lane's pixel width; kept current by callers each frame


func refresh(total: float) -> void:
	extent = maxf(1.0, total)
	_clamp_view()


func visible_span() -> float:
	return extent / maxf(1.0, zoom)


func x_of(t: float) -> float:
	return (t - view_start) / maxf(0.001, visible_span()) * width


func t_of(x: float) -> float:
	return view_start + clampf(x / maxf(1.0, width), 0.0, 1.0) * visible_span()


## Zoom around the time under the cursor, so the point being studied stays put.
func zoom_at(x: float, factor: float) -> void:
	var anchor_t := t_of(x)
	zoom = clampf(zoom * factor, 1.0, _MAX_ZOOM)
	view_start = anchor_t - (x / maxf(1.0, width)) * visible_span()
	_clamp_view()


## Pan by a fraction of the visible window (a no-op at zoom 1, where the whole
## extent is already on screen and _clamp_view pins the window).
func pan(frac: float) -> void:
	view_start += visible_span() * frac
	_clamp_view()


func _clamp_view() -> void:
	view_start = clampf(view_start, 0.0, maxf(0.0, extent - visible_span()))


## THE RULER'S STEP: the first of [constant STEPS] that puts no more than [param most] ticks across
## [param span] seconds - finer gradations as a view zooms in, never a crowd of labels.
static func step_for(span: float, most: float) -> float:
	for st in STEPS:
		if span / float(st) <= maxf(most, 1.0):
			return float(st)
	return float(STEPS[-1])


## The ruler's ticks [param step] apart, across what is in view: their times.
func ticks(step: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var t := ceilf(view_start / step) * step
	while t < view_start + visible_span():
		out.append(t)
		t += step
	return out


## A tick's label: the clock at a second or more, tenths under one.
static func tick_label(t: float, step: float) -> String:
	return Clock.text(t) if step >= 1.0 else "%.1f" % t


## THE WHEEL, the same on every ruler: Ctrl+wheel zooms about the pointer, a plain wheel pans. True
## when [param mb] was a wheel notch and the view moved.
func wheel(mb: InputEventMouseButton) -> bool:
	if not mb.pressed or not (mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]):
		return false
	var up := mb.button_index == MOUSE_BUTTON_WHEEL_UP
	if mb.ctrl_pressed:
		zoom_at(mb.position.x, WHEEL_ZOOM if up else 1.0 / WHEEL_ZOOM)
	else:
		pan(-WHEEL_PAN if up else WHEEL_PAN)
	return true


## THE PLAYHEAD on [param c] at [param x], its full height - and, given a [param tag], the time
## riding right above it, so where the line is and what time that is are read in one look.
static func draw_playhead(c: Control, x: float, color: Color, tag := "") -> void:
	c.draw_line(Vector2(x, 0), Vector2(x, c.size.y), color, 2.0)
	if tag.is_empty():
		return
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 8.0
	var tx := clampf(x - w * 0.5, 0.0, c.size.x - w)
	c.draw_rect(Rect2(tx, 2, w, 18), color)
	c.draw_string(font, Vector2(tx + 4, 15), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.05, 0.06, 0.08))
