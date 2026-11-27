extends Window
class_name PropViewer

## PropViewer - one prop whole, in 3D, in a window of its own: built as it stands ([method PropSection.model_of]), lit as its picture
## is ([StudioLook]), and turned in the hand. A drag turns it about any axis (across the window about the upright, up and down about
## the level), a drag with Shift rolls it, the wheel brings it closer, a right or middle drag moves it, and a double click or "Set
## straight" puts it back as it opened. Opened by a click on a prop's picture on the Props card ([PropsCard]) or a shelf
## ([DexWindow]), centered beside the side panel ([method Shell.center_beside]). Drawn only while it is shown; what it holds is let
## go when it closes. Escape or the window's close hides it.
##
## A prop kept with versions ([PropVersions]) is stepped through here, ‹ and ›, and THE VERSION SHOWN WHEN IT IS LEFT IS THE PROP: the
## one on screen when the view closes, or opens another prop, is made the one used ([method keep_shown]) and the section it was opened
## from follows ([method PropSection.refined]) - never on each step, which would write the table again for every version passed.
## Refine… asks an agent to change the version shown as a person says ([PropRefine]): a prop not kept yet is held as a draft first (its
## versions' home, never in the library), the words' window closes, and the agent works on in the background ([PropRefining]) - the
## view says what it is doing while it is on that prop, with Stop, and may close or turn to another prop to refine it too; what the
## agent makes is shown as a new version when the view is on the prop, the prop if it is still shown when the view is left. KEEP IS HERE, never on a card's row: it puts the prop in the library with every version it has, through the section
## it was opened from ([method PropSection.keep_prop]), and says Kept once it is.
##
## THE NAME AT ITS TOP IS THE VERSION SHOWN'S: what an agent called it where its refinement made it something else, or the prop's. A
## kept prop's name is typed over to rename the version shown ([method name_shown]); the prop takes a version's name when that
## version is used, at once where it is the one used already.

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
var _named: LineEdit             # the version shown's name, typed over to rename it
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
var _moved := false              # whether another version was shown since it opened (stepped to, or made by Refine…)
var _prev: Button
var _next: Button
var _ver: Label
var _refine_btn: Button
var _keep_btn: Button
var _stop_btn: Button
var _status: Label
var _status_box: PanelContainer  # the status's ground, laid over the foot of the 3D view: it takes no room from it
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
	# the 3D view and, over its foot, what is said of it: a status that comes and goes never resizes the view (it would refit the
	# prop each time)
	var stage := Control.new()
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.mouse_filter = Control.MOUSE_FILTER_PASS
	col.add_child(stage)
	_view = SubViewportContainer.new()
	_view.stretch = true
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_view.tooltip_text = "Drag to turn it, with Shift to roll it; the wheel brings it closer; drag with the right button to move it. A double click sets it straight."
	_view.gui_input.connect(_on_input)
	stage.add_child(_view)
	_status_box = PanelContainer.new()
	_status_box.anchor_left = 0.0
	_status_box.anchor_right = 1.0
	_status_box.anchor_top = 1.0
	_status_box.anchor_bottom = 1.0
	_status_box.offset_left = 8.0
	_status_box.offset_right = -8.0
	_status_box.offset_bottom = -8.0
	_status_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_status_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ground := StyleBoxFlat.new()
	ground.bg_color = Color(0.05, 0.06, 0.07, 0.72)
	ground.set_corner_radius_all(4)
	ground.content_margin_left = 8.0
	ground.content_margin_right = 8.0
	ground.content_margin_top = 4.0
	ground.content_margin_bottom = 4.0
	_status_box.add_theme_stylebox_override("panel", ground)
	_status_box.visible = false
	stage.add_child(_status_box)
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
	_named = LineEdit.new()
	_named.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_named.flat = true
	_named.select_all_on_focus = true
	_named.text_submitted.connect(func(_t: String) -> void: name_shown(_named.text))
	_named.focus_exited.connect(func() -> void: name_shown(_named.text))
	bar.add_child(_named)
	_caption = Label.new()
	_caption.modulate = Color(1, 1, 1, 0.6)
	bar.add_child(_caption)
	_prev = _bar_button(bar, "‹", "The version before. The one shown when you close this is the prop.", func() -> void: step(-1))
	_ver = Label.new()
	_ver.mouse_filter = Control.MOUSE_FILTER_STOP
	bar.add_child(_ver)
	_next = _bar_button(bar, "›", "The version after. The one shown when you close this is the prop.", func() -> void: step(1))
	_refine_btn = _bar_button(bar, "Refine…", "Have an agent change what you say about the version shown - a part's shape, a size, a color - and keep the rest. It makes a new version beside the others.", toggle_refine)
	_refine_btn.toggle_mode = true
	_stop_btn = _bar_button(bar, "Stop", "Give up the refining under way: nothing is added.", stop_refining)
	_stop_btn.visible = false
	_keep_btn = _bar_button(bar, "Keep", "Keep it in your library, to use on any scene.", keep_prop)
	_bar_button(bar, "Set straight", "Put it back as it opened: upright, seen from a little above its front, whole in the window.", set_straight)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 11)
	_status.modulate = Color(0.75, 1.0, 0.85, 0.95)
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_box.add_child(_status)
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
	keep_shown()
	_asked += 1
	var mine := _asked
	_drop()
	_sec = sec
	_key = key
	_name = name
	_pv = (sec as PropSection).versions_of() if sec is PropSection else null
	_kept = _pv.name_of((sec as PropSection).prop_of(key)) if _pv != null else ""
	_shown = _index_of_row()
	_moved = false
	_say("")
	_show_versions()
	title = name
	_named.text = _shown_name()
	_caption.text = ""
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
	_named.text = _shown_name() if not _kept.is_empty() else name
	_caption.text = String(got.get("size", ""))
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
	keep_shown()
	_asked += 1
	_drop()
	if _refine != null and is_instance_valid(_refine):
		_refine.fold()
		RefineDock.show_on(_refine_btn, _refine)
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
	_moved = true
	_named.text = _shown_name()
	_show_versions()
	_waiting.text = "Building it…"
	_waiting.visible = true
	var got: Dictionary = await _pv.model(_kept, i)
	if mine != _asked or not is_instance_valid(self):
		if got.get("node") is Node:
			(got["node"] as Node).queue_free()
		return
	var turn := _pivot.basis
	hold(got, _shown_name())
	# stepping keeps it turned as it was, to compare the two
	_pivot.basis = turn


## The version shown made the prop where it is not already, and the section it came from told: what the view is left on, once
## another version has been shown in it (only opened and closed, it changes nothing: a row may stand an older version than the one
## used). Said in the log ([StatusLog]), the view being gone.
func keep_shown() -> void:
	if not _moved or _pv == null or _kept.is_empty() or _shown < 0 or _shown == _pv.used(_kept):
		return
	_moved = false
	var vs := _pv.list(_kept)
	var h := String((vs[_shown] as Dictionary).get("hash", "")) if _shown < vs.size() else ""
	var err := _pv.use(_kept, _shown)
	if err.is_empty():
		_follow(h)
	if err.is_empty() and _sec is PropSection:
		err = (_sec as PropSection).refined(_key, _kept)
	StatusLog.say("prop view", ("%s: version %d not used: %s" % [_kept, _shown + 1, err]) if not err.is_empty()
		else "%s: version %d is the prop now" % [_kept, _shown + 1])


## What the version shown is called: its own name, else the prop's; the name it was opened with where it is not kept.
func _shown_name() -> String:
	if _pv == null or _kept.is_empty():
		return _name
	var vs := _pv.list(_kept)
	if _shown < 0 or _shown >= vs.size():
		return _kept
	var n := String((vs[_shown] as Dictionary).get("name", ""))
	return n if not n.is_empty() else _kept


## The name the prop is kept by now, found by the hash [param h] of one of its versions: what it was renamed to.
func _follow(h: String) -> void:
	var now := _pv.name_of({"hash": h}) if not h.is_empty() else ""
	if not now.is_empty():
		_kept = now
		_name = now
		title = now


## The version shown called [param to], as typed over its name: the prop too where it is the version used, and what uses it told.
## Nothing where it is unchanged, or the prop is not kept (its name is the scene's).
func name_shown(to: String) -> void:
	var named := to.strip_edges()
	if _pv == null or _kept.is_empty() or _shown < 0 or named.is_empty() or named == _shown_name():
		_named.text = _shown_name()
		return
	var vs := _pv.list(_kept)
	var h := String((vs[_shown] as Dictionary).get("hash", "")) if _shown < vs.size() else ""
	var used := _shown == _pv.used(_kept)
	var err := _pv.name_version(_kept, _shown, named)
	if err.is_empty() and used:
		_follow(h)
		if _sec is PropSection:
			err = (_sec as PropSection).refined(_key, _kept)
	_say(err if not err.is_empty() else ("Renamed %s." % named if used else "Version %d is called %s: the prop takes the name if you close this on it." % [_shown + 1, named]))
	_named.text = _shown_name()
	_show_versions()


## The prop kept in the library, with every version it has (a person's choice: refining or choosing it keeps nothing), through the
## section it was opened from, which says what it is.
func keep_prop() -> void:
	if not (_sec is PropSection):
		return
	var err := (_sec as PropSection).keep_prop(_key)
	if err.is_empty() and _pv != null:
		var now := _pv.name_of((_sec as PropSection).prop_of(_key))
		if not now.is_empty():
			_kept = now
	_say(err if not err.is_empty() else "Kept in your library as %s." % (_kept if not _kept.is_empty() else _name))
	_show_versions()


## The Refine window opened on the version shown - or, for a row its section refines itself ([method PropSection.refines]), that
## row's own.
func open_refine() -> void:
	if _sec is PropSection and (_sec as PropSection).refines(_key):
		_say((_sec as PropSection).act(_key, "refine"))
		return
	if _refine == null or not is_instance_valid(_refine):
		_refine = PropRefine.new()
		add_child(_refine)
		_refine.asked.connect(_refine_asked)
	_refine.open_for(_name, self)
	RefineDock.show_on(_refine_btn, _refine)


## The Refine button's toggle: the words docked into this view ([method open_refine]), or folded away.
func toggle_refine() -> void:
	if _refine != null and is_instance_valid(_refine) and RefineDock.is_open(_refine):
		_refine.fold()
		RefineDock.show_on(_refine_btn, _refine)
		return
	open_refine()
	RefineDock.show_on(_refine_btn, _refine)


## Refining asked for: the prop held as a draft where it is not kept, the version shown handed to an agent, and the words' window
## closed - the agent works on whether or not this stays open ([PropRefining]); what it says shows here while the view is on the prop,
## and the version it makes is shown when it lands ([method _watch]).
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
	var from := _shown if _shown >= 0 else _pv.used(_kept)
	# ...and the scene it stands in, where a refine may place it there ([method PropSection.scene_of]): a place makes no version
	var err := _pv.start_refine(_kept, from, direction, pick, (_sec as PropSection).scene_of(_key))
	if not err.is_empty():
		_refine.say("Not refined: %s." % err)
		return
	_refine.set_direction("")
	_refine.say("")
	_refine.fold()
	RefineDock.show_on(_refine_btn, _refine)
	_watch()


## The refining of the prop shown, as it stands ([PropRefining]): what the agent is doing said here, with Stop; the version it made
## shown once it lands, or why not - each seen, so said once. Looked at every frame the view is shown.
func _watch() -> void:
	if _kept.is_empty():
		_stop_btn.visible = false
		return
	var w := PropRefining.of(_kept)
	var working := String(w.get("state", "")) == "working"
	if working != _stop_btn.visible:
		_stop_btn.visible = working
		_show_versions()
	match String(w.get("state", "")):
		"working":
			_say("An agent is refining it: %s. You can close this and work on another prop meanwhile." % String(w["line"]))
		"ready":
			PropRefining.seen(_kept)
			var i := int(w["index"])
			var called := String(w.get("name", ""))
			var renamed := "" if called.is_empty() or called == _kept else " It calls it %s, a name the prop takes with it." % called
			var also := " It placed things in the scene too - %s." % _moved_text(w.get("moved", {})) if not (w.get("moved", {}) as Dictionary).is_empty() else ""
			_say("Version %d is new: compare it with ‹ and ›. The one shown when you close this is the prop.%s%s" % [i + 1, renamed, also])
			show_version(i)
		"placed":
			PropRefining.seen(_kept)
			_say("Placed in the scene, no new version - %s. Each thing's entry moves it by hand." % _moved_text(w.get("moved", {})))
		"failed":
			PropRefining.seen(_kept)
			_say("Not refined: %s." % String(w["error"]))


func _process(_delta: float) -> void:
	if visible:
		_watch()


## What a refine placed, as a person reads it: each thing by its name and how it moved.
static func _moved_text(moved: Variant) -> String:
	var out := PackedStringArray()
	for k in (moved as Dictionary if moved is Dictionary else {}):
		out.append("the %s %s" % [String(k).replace("_", " "), _place_text((moved as Dictionary)[k])])
	return "; ".join(out) if not out.is_empty() else "nothing moved"


## A place as a person reads it: what moved and how far.
static func _place_text(place: Variant) -> String:
	var said := {"x": "across %s cm", "y": "up %s cm", "z": "toward you %s cm", "turn": "turned %s°", "tilt": "tipped %s°", "roll": "leaned %s°", "scale": "sized %s×"}
	var out := PackedStringArray()
	for k in (place as Dictionary if place is Dictionary else {}):
		if said.has(k):
			out.append(String(said[k]) % str(snappedf(float(place[k]), 0.1)))
	return ", ".join(out) if not out.is_empty() else "where the scene stands it"


## The refining of the prop shown given up: nothing is added.
func stop_refining() -> void:
	if _pv != null and not _kept.is_empty():
		_pv.stop(_kept)


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


## The bar's version controls as the prop stands: shown for a prop kept with more than one version, Refine… on what can be refined;
## the name typed over where it is kept.
func _show_versions() -> void:
	if _prev == null:
		return
	_named.editable = _pv != null and not _kept.is_empty()
	_named.tooltip_text = "The version shown's name. Type over it to rename it: the prop takes the name when this version is the one it uses." \
		if _named.editable else "Its name in this scene. Keep it in your library, or refine it, to rename it."
	var vs := _pv.list(_kept) if _pv != null and not _kept.is_empty() else []
	var many := vs.size() > 1
	for c in [_prev, _ver, _next]:
		(c as Control).visible = many
	var can := _pv != null and _sec is PropSection and _pv.refinable((_sec as PropSection).prop_of(_key))
	var own := _sec is PropSection and (_sec as PropSection).refines(_key)
	_refine_btn.disabled = not (can or own) or (not _kept.is_empty() and PropRefining.busy(_kept))
	_refine_btn.tooltip_text = ("Have an agent change what you say about the version shown - a part's shape, a size, a color - and keep "
		+ "the rest. It makes a new version beside the others.") if can else ("Have an agent change it as you say." if own
		else "This is built by code, not written as parts, so it cannot be refined.")
	var kept := _pv != null and not _kept.is_empty() and _pv.kept(_kept)
	_keep_btn.visible = can
	_keep_btn.disabled = kept
	_keep_btn.text = "Kept" if kept else "Keep"
	_keep_btn.tooltip_text = ("In your library as %s, with every version." % _kept) if kept \
		else "Keep it in your library, with every version it has, to use on any scene."
	if not many:
		return
	var used := _pv.used(_kept)
	var i := clampi(_shown, 0, vs.size() - 1)
	_ver.text = "%d / %d" % [i + 1, vs.size()]
	var v: Dictionary = vs[i]
	var made := Time.get_datetime_string_from_unix_time(int(v["made"]), true) if int(v["made"]) > 0 else ""
	_ver.tooltip_text = ("Version %d of %d%s. The one shown when you close this is the prop." % [i + 1, vs.size(), ", the one used" if i == used else ""]) + \
		(("\nMade by %s%s from: %s" % [String(v["by"]) if not String(v["by"]).is_empty() else "an agent", " on " + made if not made.is_empty() else "",
			String(v["note"])]) if not String(v["note"]).is_empty() else "\nAs it was kept.")
	_prev.disabled = i <= 0
	_next.disabled = i >= vs.size() - 1


func _say(text: String) -> void:
	if _status == null or (_status.text == text and _status_box.visible == not text.is_empty()):
		return
	_status.text = text
	_status_box.visible = not text.is_empty()
