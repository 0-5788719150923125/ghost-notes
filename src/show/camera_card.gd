extends VBoxContainer
class_name CameraCard

## CameraCard - the Camera: how a flown camera follows what it turns to, for every format that flies one (the Dispatch desk,
## the desk and the Letter, the novel, the notebook, the tablet), one row per setting of [constant CameraFollow.FIELDS]. A
## row unset stands dimmed at the format's own (its Medium row's `follow`); one moved is the note's, in any format.
##
## Above them, where the format plans shots of its own (the comic, the novel, the notebook, the tablet: [method Medium.uses]
## "camera"), its Severity ([member ShowFeed.camera]): how far, how often and how fast those shots move.
##
## Like the Look it is the Director's ([method Director.set_camera_follow]), so a reading and an export render follow it
## alike, and a playing show takes a change on its next frame. Its block in a document is `camera:`, only what is set (`severity` among them). Where
## and when the camera looks stays the format's; what a format changes for a moment (springs quickened on a new page) is
## laid over these.
##
## Below them, THE CAMERAS ([Cameras]): a list, as the Props card lists props, of the cameras the format in use sees through
## (its sorts alone, [method Cameras.of]; none listed where it has none), each an entry with its own settings, in priority order
## (the higher in the list wins a moment both want; ↑ lifts one). Unset, the format has every sort of its own; an entry's × takes
## that sort off the list, save one the format always sees through (grayed, saying why). Kept in the block as `cameras`, every
## format's entries together: a list edited here leaves another format's as they are.

## The block this card keeps under a document's `ghost:` key.
const KEY := "camera"
## The Severity row, as a form draws it ([SchemaForm]).
const SEVERITY := {"label": "Severity", "type": "float", "min": ShowFeed.CAMERA_MIN, "max": ShowFeed.CAMERA_MAX, "step": 0.05,
	"default": 1.0, "blurb": "How severe the format's own shots are, one knob over them: 0 a slow gentle drift that barely turns and never cuts, 1 the default, 2 fast, restless and cinematic, with real jump cuts. It scales how far a shot may swing, how long a move lasts and how deep a push goes."}

var _said: Label
var _head: Label
var _form: SchemaForm
var _list: VBoxContainer
var _add: MenuButton
var _open := {}


## This card for a note's panel, from what the panel says of itself ([method NoteCards.make]): it asks nothing of it.
static func for_note(_ctx: Dictionary) -> CameraCard:
	return CameraCard.new()


func _init() -> void:
	add_theme_constant_override("separation", 4)
	_said = Label.new()
	_said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_said.add_theme_font_size_override("font_size", 11)
	_said.modulate = Color(1, 1, 1, 0.6)
	add_child(_said)
	_form = SchemaForm.new()
	_form.edited.connect(func(key: String, value: Variant) -> void:
		if key == "severity":
			Director.set_camera(1.0 if value == null else float(value))
			refresh()
			return
		var f: Dictionary = Director.camera_follow.duplicate()
		if value == null:
			f.erase(key)
		else:
			f[key] = value
		Director.set_camera_follow(f)
		refresh())
	add_child(_form)
	_head = Label.new()
	_head.text = "Cameras"
	_head.tooltip_text = "The cameras this format sees through, the highest in the list winning a moment two of them want. Unset, it has every one of its own."
	_head.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_head)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	add_child(_list)
	_add = MenuButton.new()
	_add.text = "+ Add"
	_add.flat = false
	_add.tooltip_text = "Add a camera to the list."
	_add.get_popup().id_pressed.connect(_added)
	add_child(_add)
	Director.medium_changed.connect(refresh)
	refresh()


## The rows drawn again: each at what is set, or dimmed at the format in use's own.
func refresh() -> void:
	var fmt := Director.resolved_medium()
	var own := Medium.follow_of(fmt)
	var label := Registry.label(Medium.REGISTRY, fmt) if Medium.REGISTRY.has(fmt) else fmt
	var shots := Medium.takes_settings(fmt) and Medium.uses(fmt, "camera")
	if not own.is_empty():
		_said.text = "How the camera turns to what it looks at. Unset, a row stands at the %s's own." % label
	elif shots:
		_said.text = "The %s plans its own shots: Severity steers them, and the rest apply where the note is shown in a format that follows." % label
	else:
		_said.text = "The %s flies no camera of its own: these apply where the note is shown in a format that does." % label
	var defaults := CameraFollow.settings(own, {})
	var rows := {}
	var values: Dictionary = Director.camera_follow.duplicate()
	if shots:
		rows["severity"] = SEVERITY
		if not is_equal_approx(Director.camera, 1.0):
			values["severity"] = Director.camera
	for k in CameraFollow.FIELDS:
		var row: Dictionary = (CameraFollow.FIELDS[k] as Dictionary).duplicate()
		row["default"] = defaults[k]
		rows[k] = row
	_form.show_fields(rows, values)
	_draw_cameras()


# --- the cameras -------------------------------------------------------------------------------------------------------

## The format in use's list as it stands: the note's, or every sort of the format dimmed where it has none.
func _cameras() -> Array:
	return Cameras.sanitize(Director.cameras, true, Director.resolved_medium())


func _draw_cameras() -> void:
	for c in _list.get_children():
		c.queue_free()
	var fmt := Director.resolved_medium()
	var any := not Cameras.of(fmt).is_empty()
	_head.visible = any
	_list.visible = any
	_add.visible = Cameras.of(fmt).any(func(k: String) -> bool: return Cameras.kept(k).is_empty())
	if not any:
		return
	var list := _cameras()
	var own := Director.cameras.any(func(e: Dictionary) -> bool:
		return String(Registry.field(Cameras.REGISTRY, String(e.get("sort", "")), "format", "")) == fmt)
	for i in list.size():
		var e: Dictionary = list[i]
		var sort := String(e["sort"])
		var entry := EntryCard.new(Registry.label(Cameras.REGISTRY, sort), Registry.blurb(Cameras.REGISTRY, sort))
		entry.modulate = Color(1, 1, 1, 1.0 if own else 0.6)
		var at := i
		var why := Cameras.kept(sort)
		if why.is_empty() and list.size() <= 1:
			why = "A show keeps one camera at least."
		entry.set_remove(func() -> void: _set_list(_without(at)), "Take this camera off the list.", why)
		entry.open = bool(_open.get(sort, false))
		entry.toggled.connect(func(o: bool) -> void: _open[sort] = o)
		var form := SchemaForm.new()
		var rows := {}
		var values := {}
		var fields: Dictionary = Registry.field(Cameras.REGISTRY, sort, "fields", {})
		for k in fields:
			rows[k] = (fields[k] as Dictionary).duplicate()
			if e.has(k):
				values[k] = e[k]
		form.show_fields(rows, values)
		form.edited.connect(func(key: String, value: Variant) -> void:
			var l := _cameras()
			var d: Dictionary = l[at]
			if value == null:
				d.erase(key)
			else:
				d[key] = value
			_set_list(l))
		if not rows.is_empty():
			entry.options.add_child(form)
		if i > 0 and Cameras.kept(sort).is_empty() and Cameras.kept(String(list[i - 1]["sort"])).is_empty():
			var up := Button.new()
			up.text = "↑ Before the one above"
			up.tooltip_text = "Give this camera the moments it and the one above both want."
			up.pressed.connect(func() -> void:
				var l := _cameras()
				var d: Variant = l[at]
				l.remove_at(at)
				l.insert(at - 1, d)
				_set_list(l))
			entry.options.add_child(up)
		_list.add_child(entry)
	var pop := _add.get_popup()
	pop.clear()
	var keys := Cameras.REGISTRY.keys()
	for k in keys.size():
		if String(Registry.field(Cameras.REGISTRY, String(keys[k]), "format", "")) == fmt and Cameras.rank(list, String(keys[k])) < 0:
			pop.add_item(Registry.label(Cameras.REGISTRY, String(keys[k])), k)
			pop.set_item_tooltip(pop.item_count - 1, Registry.blurb(Cameras.REGISTRY, String(keys[k])))
	_add.disabled = pop.item_count == 0


func _without(i: int) -> Array:
	var l := _cameras()
	l.remove_at(i)
	return l


func _added(id: int) -> void:
	var l := _cameras()
	l.append({"sort": String(Cameras.REGISTRY.keys()[id])})
	_set_list(l)


## The format in use's list [param l], every other format's entries kept as they are.
func _set_list(l: Array) -> void:
	var fmt := Director.resolved_medium()
	var others := Director.cameras.filter(func(e: Dictionary) -> bool:
		return String(Registry.field(Cameras.REGISTRY, String(e.get("sort", "")), "format", "")) != fmt)
	Director.set_cameras(others + l)
	refresh()


# --- the block ---------------------------------------------------------------------------------------------------------

## The block for a document: only what is set.
func capture() -> Dictionary:
	var out := {}
	if not is_equal_approx(Director.camera, 1.0):
		out["severity"] = snappedf(Director.camera, 0.01)
	for k in Director.camera_follow:
		out[k] = snappedf(float(Director.camera_follow[k]), 0.01)
	if not Director.cameras.is_empty():
		out["cameras"] = Director.cameras.duplicate(true)
	return out


## ...and back: what the block sets, the rest at the format's own (Severity at 1).
func apply(block: Dictionary) -> void:
	var sev: Variant = block.get("severity")
	Director.set_camera(float(sev) if (sev is float or sev is int) else 1.0)
	Director.set_camera_follow(block)
	Director.set_cameras(block.get("cameras", []) if block.get("cameras") is Array else [])
	refresh()
