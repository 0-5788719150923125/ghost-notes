extends RefCounted
class_name MaskRegion

## MaskRegion - the region box, a part of [MaskEditor]: the rectangle a marker's effect is kept
## inside, drawn over the video and dragged by its corners and edges ([method build],
## [method drag_motion]), its checkbox, and the box shown exactly when the selected marker has
## one ([method sync]).
##
## WHAT IT IS HANDED is written out: every `editor.` below is something it reads of the editor (the
## selected marker, the drag in progress, the one path every edit takes).
##
## The panel edits scalars; a rectangle over a picture is not a scalar, and typing
## four numbers to find the edge of a wall is not authoring. So the box is drawn
## where it acts, with grab handles at the corners and edges, and every drag writes
## straight through _edit into the selected marker's reg_* fields - the same path
## as every slider, so undo/coalescing/autosave all work without knowing about it.
##
## It lives INSIDE the composition parent, which is exactly the video's own rect
## (the AspectRatioContainer's letterboxed slot - see _build_editor_ui), so
## converting between a mouse position and frame UV is a plain divide and stays
## correct on any clip shape, portrait included.

## The [MaskEditor] this is a part of: everything read through it is something this part
## is handed, and the list of them is what it depends on.
var editor: MaskEditor

var _region_overlay: Control
var _region_drag_from := Vector2.ZERO   # mouse position at press
var _region_drag_box := Rect2()         # the box at press - drags resolve from THIS
const _REGION_GRAB := 14.0     # px reach of a corner/edge handle
const _REGION_MIN := 0.02      # smallest box side, in UV, so it can't be lost
const _REGION_SNAP := 0.012    # UV distance within which an edge snaps to the frame's
const _REGION_CURSORS := {
	"nw": Control.CURSOR_FDIAGSIZE, "se": Control.CURSOR_FDIAGSIZE,
	"ne": Control.CURSOR_BDIAGSIZE, "sw": Control.CURSOR_BDIAGSIZE,
	"n": Control.CURSOR_VSIZE, "s": Control.CURSOR_VSIZE,
	"w": Control.CURSOR_HSIZE, "e": Control.CURSOR_HSIZE,
	"move": Control.CURSOR_MOVE,
}

# --- the region box: drawn on, and dragged over, the video itself -----------------------------

func build(parent: Control) -> void:
	_region_overlay = Control.new()
	_region_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_region_overlay.z_index = 20           # over the fx layers AND any track PiP
	_region_overlay.visible = false        # only while a region is actually on
	_region_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_region_overlay.draw.connect(_draw_region_overlay)
	_region_overlay.gui_input.connect(_region_overlay_input)
	parent.add_child(_region_overlay)


## The selected marker's box in this overlay's pixels, or an empty rect if there
## is nothing to draw.
func _region_rect_px() -> Rect2:
	if editor._selected == null or _region_overlay == null:
		return Rect2()
	var sz := _region_overlay.size
	var x0: float = minf(float(editor._selected.get("reg_x0", 0.0)), float(editor._selected.get("reg_x1", 1.0)))
	var y0: float = minf(float(editor._selected.get("reg_y0", 0.0)), float(editor._selected.get("reg_y1", 1.0)))
	var x1: float = maxf(float(editor._selected.get("reg_x0", 0.0)), float(editor._selected.get("reg_x1", 1.0)))
	var y1: float = maxf(float(editor._selected.get("reg_y0", 0.0)), float(editor._selected.get("reg_y1", 1.0)))
	return Rect2(x0 * sz.x, y0 * sz.y, (x1 - x0) * sz.x, (y1 - y0) * sz.y)


func _draw_region_overlay() -> void:
	var r := _region_rect_px()
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return
	var c := _region_overlay
	# Dim what the layer will NOT reach, so the box reads as a window rather than
	# a decoration - four bands around it rather than a rect over it, because the
	# inside must stay a true view of the effect.
	var shade := Color(0, 0, 0, 0.34)
	var sz := c.size
	c.draw_rect(Rect2(0, 0, sz.x, r.position.y), shade)
	c.draw_rect(Rect2(0, r.end.y, sz.x, sz.y - r.end.y), shade)
	c.draw_rect(Rect2(0, r.position.y, r.position.x, r.size.y), shade)
	c.draw_rect(Rect2(r.end.x, r.position.y, sz.x - r.end.x, r.size.y), shade)
	# The border, twice: a dark line under a light one, so it stays visible over
	# both a blown-out wall and a black one.
	c.draw_rect(r, Color(0, 0, 0, 0.75), false, 3.0)
	c.draw_rect(r, Color(1, 1, 1, 0.95), false, 1.0)
	# Corner handles. Drawn as filled squares - a handle you can see is a handle
	# you can hit, and these are the ones the mouse actually looks for first.
	var h := _REGION_GRAB * 0.5
	for p in [r.position, Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), r.end]:
		var box := Rect2(p - Vector2(h, h), Vector2(h * 2.0, h * 2.0))
		c.draw_rect(box, Color(0, 0, 0, 0.75))
		c.draw_rect(box.grow(-1.5), Color(1, 1, 1, 0.95))


## Which part of the box the mouse is over: "nw"/"ne"/"sw"/"se" corners, "n"/"s"/
## "e"/"w" edges, "move" inside, "" outside. Corners are tested first so the
## overlapping edge bands at a corner never win.
func _region_hit(pos: Vector2) -> String:
	var r := _region_rect_px()
	if r.size.x <= 0.0:
		return ""
	var g := _REGION_GRAB
	var near_l: bool = absf(pos.x - r.position.x) <= g
	var near_r: bool = absf(pos.x - r.end.x) <= g
	var near_t: bool = absf(pos.y - r.position.y) <= g
	var near_b: bool = absf(pos.y - r.end.y) <= g
	var in_x: bool = pos.x >= r.position.x - g and pos.x <= r.end.x + g
	var in_y: bool = pos.y >= r.position.y - g and pos.y <= r.end.y + g
	if in_x and in_y:
		if near_l and near_t: return "nw"
		if near_r and near_t: return "ne"
		if near_l and near_b: return "sw"
		if near_r and near_b: return "se"
		if near_l: return "w"
		if near_r: return "e"
		if near_t: return "n"
		if near_b: return "s"
	return "move" if r.has_point(pos) else ""


## The PRESS and hover feedback only. Everything after the press is handled in
## _input instead - see drag_motion for why a drag cannot live here.
func _region_overlay_input(event: InputEvent) -> void:
	if editor._selected == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		editor._region_drag = _region_hit(event.position)
		_region_drag_from = event.position
		_region_drag_box = _region_rect_px()
		# A press OUTSIDE the box is not ours - let it fall through to whatever
		# is underneath rather than swallowing every click on the video for as
		# long as a region exists.
		if editor._region_drag != "":
			_region_overlay.accept_event()
		return
	# Hover feedback: the handles have to advertise themselves or the box looks
	# like a drawing rather than a tool.
	if event is InputEventMouseMotion and editor._region_drag == "":
		var hit := _region_hit(event.position)
		_region_overlay.mouse_default_cursor_shape = _REGION_CURSORS.get(hit, Control.CURSOR_ARROW)


## A DRAG IN PROGRESS, from the editor's own _input rather than the overlay's
## gui_input. gui_input only delivers events that land ON the control, so a drag
## that leaves the video pane silently stops updating - and the single most
## natural gesture with this tool is shoving an edge PAST the frame border to
## mean "all the way to the edge". Through gui_input that gesture stopped at
## whatever pixel the cursor last crossed on its way out, leaving the box a
## fraction of a percent short of the border: a thin unpainted band of the very
## color being removed, hugging the top of the picture. Reading the mouse from
## _input instead lets the drag continue past the edge and clamp cleanly at it.
func drag_motion(event: InputEvent) -> void:
	if editor._region_drag == "" or _region_overlay == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and not event.pressed:
		editor._region_drag = ""
		return
	if event is InputEventMouseMotion:
		_region_apply_drag(_region_overlay.get_local_mouse_position())


## Resolve a drag to new box corners and write them. Everything is computed from
## the box AS IT WAS AT MOUSE-DOWN plus the total delta since - never
## incrementally from the current box, which drifts and makes a slow drag land
## somewhere different from a fast one covering the same distance.
func _region_apply_drag(pos: Vector2) -> void:
	var sz := _region_overlay.size
	if sz.x <= 0.0 or sz.y <= 0.0:
		return
	var d := pos - _region_drag_from
	var b := _region_drag_box
	var x0 := b.position.x
	var y0 := b.position.y
	var x1 := b.end.x
	var y1 := b.end.y
	if editor._region_drag == "move":
		# Moving keeps the SIZE and stays inside the frame, so dragging a box
		# off the edge parks it against the edge instead of shrinking it.
		var mx: float = clampf(x0 + d.x, 0.0, sz.x - b.size.x)
		var my: float = clampf(y0 + d.y, 0.0, sz.y - b.size.y)
		x0 = mx; y0 = my; x1 = mx + b.size.x; y1 = my + b.size.y
	else:
		if editor._region_drag.contains("w"):
			x0 = clampf(x0 + d.x, 0.0, x1 - _REGION_MIN * sz.x)
		if editor._region_drag.contains("e"):
			x1 = clampf(x1 + d.x, x0 + _REGION_MIN * sz.x, sz.x)
		if editor._region_drag.contains("n"):
			y0 = clampf(y0 + d.y, 0.0, y1 - _REGION_MIN * sz.y)
		if editor._region_drag.contains("s"):
			y1 = clampf(y1 + d.y, y0 + _REGION_MIN * sz.y, sz.y)
	# SNAP TO THE FRAME. An edge released within a few pixels of the picture's own
	# border means the border - nobody drags a box to 0.4% off the top on purpose,
	# and the difference is not visible in the editor but IS visible in the result
	# as a hairline of the color being removed. Exact 0/1 also lets the shader
	# skip that side's falloff entirely (see region_mask), so a flush edge paints
	# the very first row instead of fading into it.
	editor._edit("reg_x0", snap_edge(x0 / sz.x))
	editor._edit("reg_y0", snap_edge(y0 / sz.y))
	editor._edit("reg_x1", snap_edge(x1 / sz.x))
	editor._edit("reg_y1", snap_edge(y1 / sz.y))
	_region_overlay.queue_redraw()


## Pull a box edge onto the frame's border if it is nearly there. In UV, because
## that is what gets stored; the threshold is generous enough to be reachable by
## hand and far too small to swallow a deliberate placement.
static func snap_edge(v: float) -> float:
	if v < _REGION_SNAP:
		return 0.0
	if v > 1.0 - _REGION_SNAP:
		return 1.0
	return clampf(v, 0.0, 1.0)


## The checkbox. ON seeds a box worth dragging (the middle of the frame) rather
## than the full frame, which would have invisible handles pinned in the corners
## and look broken. OFF restores the whole frame - the layer acts everywhere
## again, which is the same state every session had before regions existed.
func on_toggled(on: bool) -> void:
	if editor._syncing:
		return
	if on:
		editor._edit("reg_x0", 0.15)
		editor._edit("reg_y0", 0.10)
		editor._edit("reg_x1", 0.85)
		editor._edit("reg_y1", 0.55)
	else:
		editor._edit("reg_x0", 0.0)
		editor._edit("reg_y0", 0.0)
		editor._edit("reg_x1", 1.0)
		editor._edit("reg_y1", 1.0)
	editor._refresh_panel()   # re-reads the box, the checkbox and the edge slider's visibility


## Show the box exactly when the selected marker actually has a region. Called
## from _refresh_panel (selection/undo/reload) and after every toggle.
func sync() -> void:
	if _region_overlay == null:
		return
	var on := editor._selected != null and MaskSession.has_region(editor._selected)
	_region_overlay.visible = on
	# MOUSE_FILTER_IGNORE while hidden is belt-and-braces: an invisible Control
	# does not receive input anyway, but this one sits over the whole video and a
	# future change that leaves it visible-but-empty must not eat every click.
	_region_overlay.mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE
	if on:
		_region_overlay.queue_redraw()
