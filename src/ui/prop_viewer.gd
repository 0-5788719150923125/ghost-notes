extends Window
class_name PropViewer

## PropViewer - one prop whole, in 3D, in a window of its own: built as it stands ([method PropSection.model_of]), lit as its picture
## is ([StudioLook]), and turned in the hand. A drag turns it about any axis (across the window about the upright, up and down about
## the level), a drag with Shift rolls it, the wheel brings it closer, a right or middle drag moves it, and a double click or "Set
## straight" puts it back as it opened. Opened by a click on a prop's picture on the Props card ([PropsCard]) or a shelf
## ([DexWindow]), centered beside the side panel ([method Shell.center_beside]). Drawn only while it is shown; what it holds is let
## go when it closes. Escape or the window's close hides it.
##
## A prop kept with versions ([PropVersions]) is stepped through here, ‹ and ›, and the one shown made the prop by Use this one; the
## section it was opened from follows ([method PropSection.refined]). Refine… asks an agent to change the version shown as a person
## says ([PropRefine]): a prop not kept yet is kept first, and what the agent makes is shown as a new version, used only when chosen.

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
var _sec: ShelfSection = null    # what it was opened from, and the row or offer
var _key := ""
var _name := ""
var _pv: PropVersions = null     # where its versions are kept, null for none
var _kept := ""                  # the name it is kept by, "" while it is not
var _shown := -1                 # which of its versions is shown, -1 where it has none
var _prev: Button
var _next: Button
var _ver: Label
var _use: Button
var _refine_btn: Button
var _status: Label
var _refine: PropRefine = null


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
	_prev = _bar_button(bar, "‹", "The version before.", func() -> void: step(-1))
	_ver = Label.new()
	_ver.mouse_filter = Control.MOUSE_FILTER_STOP
	bar.add_child(_ver)
	_next = _bar_button(bar, "›", "The version after.", func() -> void: step(1))
	_use = _bar_button(bar, "Use this one", "Make the version shown the prop: what the Dex shows, and what every scene that uses it stands.", use_shown)
	_refine_btn = _bar_button(bar, "Refine…", "Have an agent change what you say about the version shown - a part's shape, a size, a color - and keep the rest. It makes a new version beside the others.", open_refine)
	_bar_button(bar, "Set straight", "Put it back as it opened: upright, seen from a little above its front, whole in the window.", set_straight)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 11)
	_status.modulate = Color(0.75, 1.0, 0.85, 0.9)
	_status.visible = false
	col.add_child(_status)
	_show_versions()


func _bar_button(bar: HBoxContainer, text: String, tip: String, pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(pressed)
	bar.add_child(b)
	return b


## Opened on the entry of row or offer [param key] of [param sec], called [param name]: shown at once, the entry when it is built.
func open(sec: ShelfSection, key: String, name: String) -> void:
	_asked += 1
	var mine := _asked
	_drop()
	_sec = sec
	_key = key
	_name = name
	_pv = (sec as PropSection).versions_of() if sec is PropSection else null
	_kept = _pv.name_of((sec as PropSection).prop_of(key)) if _pv != null else ""
	_shown = _index_of_row()
	_say("")
	_show_versions()
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
	if _refine != null and is_instance_valid(_refine):
		_refine.hide()
	hide()


# --- versions ----------------------------------------------------------------------------------------------------------

## The version [param by] places after (or before) the one shown, shown.
func step(by: int) -> void:
	if _pv == null or _kept.is_empty():
		return
	var n := _pv.list(_kept).size()
	var to := clampi(_shown + by, 0, n - 1)
	if to == _shown:
		return
	show_version(to)


## Version [param i] of the prop shown, built and held.
func show_version(i: int) -> void:
	_asked += 1
	var mine := _asked
	_shown = i
	_show_versions()
	_waiting.text = "Building it…"
	_waiting.visible = true
	var got: Dictionary = await _pv.model(_kept, i)
	if mine != _asked or not is_instance_valid(self):
		if got.get("node") is Node:
			(got["node"] as Node).queue_free()
		return
	var turn := _pivot.basis
	hold(got, _name)
	# stepping keeps it turned as it was, to compare the two
	_pivot.basis = turn


## The version shown made the prop, and the section it came from told.
func use_shown() -> void:
	if _pv == null or _kept.is_empty() or _shown < 0:
		return
	var err := _pv.use(_kept, _shown)
	if err.is_empty() and _sec is PropSection:
		err = (_sec as PropSection).refined(_key, _kept)
	_say(err if not err.is_empty() else "Version %d is the prop now." % (_shown + 1))
	_show_versions()


## The Refine window opened on the version shown.
func open_refine() -> void:
	if _refine == null or not is_instance_valid(_refine):
		_refine = PropRefine.new()
		add_child(_refine)
		_refine.asked.connect(_refine_asked)
		_refine.stopped.connect(func() -> void:
			if _pv != null:
				_pv.stop())
	_refine.open_for(_name, self)
	if _pv != null and _pv.busy():
		_refine.working(true)


## Refining asked for: the prop kept where it is not, the version shown handed to the agent, and what it makes shown.
func _refine_asked(direction: String, pick: Dictionary) -> void:
	if _pv == null or not (_sec is PropSection):
		_refine.say("This cannot be refined.")
		return
	if _kept.is_empty():
		var k := _pv.keep((_sec as PropSection).prop_of(_key))
		if k.has("error"):
			_refine.say("Not refined: %s." % String(k["error"]))
			return
		_kept = String(k["name"])
		(_sec as PropSection).refined(_key, _kept)
		_shown = _pv.used(_kept)
		_show_versions()
	var name := _kept
	var from := _shown if _shown >= 0 else _pv.used(name)
	var refine := _refine
	refine.working(true)
	refine.say("Starting…")
	var got: Dictionary = await _pv.refine(name, from, direction, pick, func(line: String) -> void:
		if is_instance_valid(refine):
			refine.say(line))
	if not is_instance_valid(refine):
		return
	refine.working(false)
	if got.has("error"):
		refine.say("Not refined: %s." % String(got["error"]))
		return
	var i := int(got["index"])
	refine.say("Made version %d from version %d. It is shown now; Use this one makes it the prop." % [i + 1, from + 1])
	if visible and _kept == name:
		_say("Version %d is new: compare it with ‹ and ›, and Use this one to make it the prop." % (i + 1))
		show_version(i)


## Which version the row or offer opened on is, by what it is: -1 where it is not kept.
func _index_of_row() -> int:
	if _pv == null or _kept.is_empty() or not (_sec is PropSection):
		return -1
	var h := String((_sec as PropSection).prop_of(_key).get("hash", ""))
	var vs := _pv.list(_kept)
	for i in vs.size():
		if String((vs[i] as Dictionary)["hash"]) == h:
			return i
	return _pv.used(_kept)


## The bar's version controls as the prop stands: shown for a prop kept with more than one version, Use this one offered on any
## but the one used, Refine… on what can be refined.
func _show_versions() -> void:
	if _prev == null:
		return
	var vs := _pv.list(_kept) if _pv != null and not _kept.is_empty() else []
	var many := vs.size() > 1
	for c in [_prev, _ver, _next, _use]:
		(c as Control).visible = many
	var can := _pv != null and _sec is PropSection and _pv.refinable((_sec as PropSection).prop_of(_key))
	_refine_btn.disabled = not can
	_refine_btn.tooltip_text = ("Have an agent change what you say about the version shown - a part's shape, a size, a color - and keep "
		+ "the rest. It makes a new version beside the others.") if can else "This is built by code, not written as parts, so it cannot be refined."
	if not many:
		return
	var used := _pv.used(_kept)
	var i := clampi(_shown, 0, vs.size() - 1)
	_ver.text = "%d / %d" % [i + 1, vs.size()]
	var v: Dictionary = vs[i]
	var made := Time.get_datetime_string_from_unix_time(int(v["made"]), true) if int(v["made"]) > 0 else ""
	_ver.tooltip_text = ("Version %d of %d%s." % [i + 1, vs.size(), ", the one used" if i == used else ""]) + \
		(("\nMade by %s%s from: %s" % [String(v["by"]) if not String(v["by"]).is_empty() else "an agent", " on " + made if not made.is_empty() else "",
			String(v["note"])]) if not String(v["note"]).is_empty() else "\nAs it was kept.")
	_prev.disabled = i <= 0
	_next.disabled = i >= vs.size() - 1
	_use.disabled = i == used
	_use.text = "In use" if i == used else "Use this one"


func _say(text: String) -> void:
	if _status == null:
		return
	_status.text = text
	_status.visible = not text.is_empty()
