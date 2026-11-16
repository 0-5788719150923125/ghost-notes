extends Window
class_name PropViewer

## PropViewer - one prop whole, in 3D, in a window of its own: built as it stands ([method PropSection.model_of]), lit as its picture
## is ([StudioLook]), and turned in the hand. A drag turns it about any axis (across the window about the upright, up and down about
## the level), a drag with Shift rolls it, the wheel brings it closer, a right or middle drag moves it, and a double click or "Set
## straight" puts it back as it opened. Opened by a click on a prop's picture on the Props card ([PropsCard]) or a shelf
## ([DexWindow]), centered beside the side panel ([method Shell.center_beside]). Drawn only while it is shown; what it holds is let
## go when it closes. Escape or the window's close hides it.

## Its size, at most, against the room beside the panel.
const SIZE := Vector2i(760, 660)
const MOST := Vector2(0.8, 0.88)
## How far a drag turns it (radians a pixel), and how near and far the wheel takes it (times the distance it opens at), a notch at a
## time.
const TURN := 0.008
const NEAREST := 0.2
const FARTHEST := 4.0
const NOTCH := 1.12
## How far above its front it opens seen from (degrees): as its picture is taken.
const OPENS_TILTED := 29.0

var _vp: SubViewport
var _view: SubViewportContainer
var _cam: Camera3D
var _pivot: Node3D               # what turns: the prop hangs under it, its middle on the pivot
var _caption: Label
var _waiting: Label
var _dist := 0.5                 # how far the camera stands when it opens (meters)
var _zoom := 1.0
var _pan := Vector2.ZERO         # the camera moved across the window (meters)
var _asked := 0                  # which opening the prop being built belongs to: a later one wins


func _init() -> void:
	visible = false
	close_requested.connect(_close)
	window_input.connect(func(e: InputEvent) -> void:
		if e is InputEventKey and (e as InputEventKey).pressed and (e as InputEventKey).keycode == KEY_ESCAPE:
			_close())
	var bg := PanelContainer.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	bg.add_child(col)
	_view = SubViewportContainer.new()
	_view.stretch = true
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_view.tooltip_text = "Drag to turn it, with Shift to roll it; the wheel brings it closer; drag with the right button to move it. A double click sets it straight."
	_view.gui_input.connect(_on_input)
	col.add_child(_view)
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_view.add_child(_vp)
	var root := Node3D.new()
	_vp.add_child(root)
	_cam = Camera3D.new()
	_cam.fov = StudioLook.FOV
	_cam.near = 0.002
	_cam.far = 20.0
	_cam.environment = StudioLook.environment()
	root.add_child(_cam)
	StudioLook.light(root)
	_pivot = Node3D.new()
	root.add_child(_pivot)
	_waiting = Label.new()
	_waiting.set_anchors_preset(Control.PRESET_CENTER)
	_waiting.text = "Building it…"
	_waiting.modulate = Color(1, 1, 1, 0.6)
	_vp.add_child(_waiting)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	col.add_child(bar)
	_caption = Label.new()
	_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_caption.clip_text = true
	bar.add_child(_caption)
	var straight := Button.new()
	straight.text = "Set straight"
	straight.tooltip_text = "Put it back as it opened: upright, seen from a little above its front, whole in the window."
	straight.focus_mode = Control.FOCUS_NONE
	straight.pressed.connect(set_straight)
	bar.add_child(straight)


## Opened on the entry of row or offer [param key] of [param sec], called [param name]: shown at once, the entry when it is built.
func open(sec: ShelfSection, key: String, name: String) -> void:
	_asked += 1
	var mine := _asked
	_drop()
	title = name
	_caption.text = name
	_waiting.text = "Building it…"
	_waiting.visible = true
	if not visible:
		var room := Shell.room_beside(get_parent())
		size = Vector2i(mini(SIZE.x, int(room.size.x * MOST.x)), mini(SIZE.y, int(room.size.y * MOST.y)))
		popup()
		Shell.center_beside(self, get_parent())
		(func() -> void: Shell.center_beside(self, get_parent())).call_deferred()
	var got: Dictionary = await sec.model_of(key)
	if mine != _asked or not is_instance_valid(self):
		if got.get("node") is Node:
			(got["node"] as Node).queue_free()
		return
	hold(got, name)


## [param got] held to be turned (`{node, box, size}`, [method PropStudio.model]), captioned [param name] and its size.
func hold(got: Dictionary, name: String) -> void:
	_drop()
	if not (got.get("node") is Node3D):
		_waiting.text = "There is nothing here to build."
		_waiting.visible = true
		return
	_waiting.visible = false
	var node: Node3D = got["node"]
	var box: AABB = got["box"]
	# its bounds are measured at its own scale already
	node.position = -box.get_center()
	_pivot.add_child(node)
	_caption.text = "%s - %s" % [name, String(got.get("size", ""))] if not String(got.get("size", "")).is_empty() else name
	var r := maxf(box.size.length() * 0.5, 0.01)
	var half := deg_to_rad(StudioLook.FOV) * 0.5
	var at := _view.size if _view.size.x > 1.0 and _view.size.y > 1.0 else Vector2(SIZE)
	var aspect := at.x / at.y
	var across := atan(tan(half) * aspect)
	_dist = r / sin(minf(half, across))
	_cam.far = _dist * FARTHEST + r * 4.0 + 1.0
	set_straight()


## Back as it opened: upright, seen from [constant OPENS_TILTED] above its front, whole in the window.
func set_straight() -> void:
	_pivot.basis = Basis(Vector3.RIGHT, deg_to_rad(OPENS_TILTED))
	_zoom = 1.0
	_pan = Vector2.ZERO
	_place_camera()


## What it holds now: the prop's node, or null.
func held() -> Node3D:
	return _pivot.get_child(0) as Node3D if _pivot.get_child_count() > 0 else null


## How it is turned now.
func turned() -> Basis:
	return _pivot.basis


## Turned by a drag of [param by] pixels: across about the upright, up and down about the level; with [param roll], across rolls it
## about the line of sight.
func turn_by(by: Vector2, roll := false) -> void:
	var b := Basis(Vector3.BACK, -by.x * TURN) if roll else Basis(Vector3.UP, by.x * TURN) * Basis(Vector3.RIGHT, by.y * TURN)
	_pivot.basis = (b * _pivot.basis).orthonormalized()


func _on_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
		var mb := e as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_zoom = maxf(NEAREST, _zoom / NOTCH)
				_place_camera()
			MOUSE_BUTTON_WHEEL_DOWN:
				_zoom = minf(FARTHEST, _zoom * NOTCH)
				_place_camera()
			MOUSE_BUTTON_LEFT:
				if mb.double_click:
					set_straight()
		_view.accept_event()
	elif e is InputEventMouseMotion:
		var mm := e as InputEventMouseMotion
		if mm.button_mask & MOUSE_BUTTON_MASK_LEFT:
			turn_by(mm.relative, mm.shift_pressed)
			_view.accept_event()
		elif mm.button_mask & (MOUSE_BUTTON_MASK_RIGHT | MOUSE_BUTTON_MASK_MIDDLE):
			# the prop follows the pointer at the distance the camera stands
			var per := 2.0 * tan(deg_to_rad(StudioLook.FOV) * 0.5) * _dist * _zoom / float(maxi(_vp.size.y, 1))
			_pan -= Vector2(mm.relative.x, -mm.relative.y) * per
			_place_camera()
			_view.accept_event()


func _place_camera() -> void:
	_cam.transform = Transform3D(Basis.IDENTITY, Vector3(_pan.x, _pan.y, _dist * _zoom))


## What it holds let go.
func _drop() -> void:
	for c in _pivot.get_children():
		_pivot.remove_child(c)
		c.queue_free()


func _close() -> void:
	_asked += 1
	_drop()
	hide()
