extends VBoxContainer
class_name PropsCard

## PropsCard - the panel's Props card: what the note's presentation sets down, one entry a prop ([EntryCard]) - its picture, its name
## and size, and a × that takes it off - under the groups its sections give ([PropSection], handed by whatever shows props), and "+
## Add a prop", which opens the Dex on the section's shelves ([DexWindow]). A click on an entry opens it: its Used tick, its verbs and
## its properties ([PropSection]'s `fields`, [SchemaForm]), each change handed to its section. A click on a picture opens the prop
## whole, in 3D, to be turned ([PropViewer]). Shown only while some section has a row or something to add. Looked at again every
## second (what a section has follows what is shown and made), and drawn again only when that changed. The Environment card's list
## is one of these.
##
## A PROP AN AGENT IS REFINING SAYS SO ON ITS ROW ([PropRefining]): what the agent is doing, said again in place each look, then that a
## new version is ready, or why not, until its 3D view has shown it - so the progress of every prop refined at once is read here. A
## row refined by something other than its versions (a table show's table, [TableRefine]) names what it is refined as (`refining_as`).

## What the card is for, on its title bar and its chip ([member Card.blurb]).
const BLURB := "What the scene uses: untick a prop to set it aside, click a picture to turn it in 3D - to refine it, or Keep it to use again - and add props from your library."
const POLL := 60              # frames between looks
## How large a row's picture is drawn (pixels).
const PICTURE := Vector2(88, 66)
## How many lines an entry's line is always given ([method EntryCard.hold_lines]).
const LINE_LINES := 3

var _sections: Callable       # () -> Array of PropSection
var _box: VBoxContainer
var _status: Label
var _shelf: DexWindow = null
var _viewer: PropViewer = null
var _seen := 0
var _textures := {}           # Image instance id -> its ImageTexture, so a picture is uploaded once
var _open := {}               # "<section id>:<row key>" -> true: an entry opened
var _entries := {}            # "<section id>:<row key>" -> its EntryCard, as last drawn
var _refining := {}           # "<section id>:<row key>" -> [its line, what its refining says]: said again in place each look


func _init(sections: Callable) -> void:
	_sections = sections
	add_theme_constant_override("separation", 6)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 4)
	add_child(_box)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 11)
	_status.add_theme_color_override("font_color", Color(0.55, 0.95, 0.75, 0.85))
	_status.visible = false
	add_child(_status)


func _ready() -> void:
	refresh()


func _process(_delta: float) -> void:
	if Engine.get_process_frames() % POLL == 0:
		refresh()


## The sections handed now.
func sections() -> Array:
	var out: Array = []
	for s in (_sections.call() if _sections.is_valid() else []):
		if s is PropSection:
			out.append(s)
	return out


## What is offered, looked at again: the card shown with rows and hidden without, the rows drawn again where they changed
## ([param force]: drawn again regardless).
func refresh(force := false) -> void:
	var drawn: Array = []
	var any := false
	_refining.clear()
	for sec in sections():
		var rows: Array = (sec as PropSection).rows()
		if PropRefining.any():
			rows = rows.map(func(r: Dictionary) -> Dictionary: return _with_refining(sec, r))
		var adds: Dictionary = (sec as PropSection).adds()
		any = any or not rows.is_empty() or not adds.is_empty()
		drawn.append([sec, (sec as PropSection).groups(), rows, adds])
	var card := _card()
	if card != null:
		card.visible = any
	var h := hash(_signature(drawn))
	if h != _seen or force:
		_seen = h
		_lay_out(drawn)
	for id in _refining:
		var e: EntryCard = _entries.get(id)
		if e != null and is_instance_valid(e):
			var said: Array = _refining[id]
			e.line_label.text = String(said[1]) if String(said[0]).is_empty() else "%s - %s" % [said[0], said[1]]
			e.line_label.visible = true


## Row [param r] of [param sec] with how its prop's refining stands (`refining`: working, ready or failed, which draws it again as it
## changes), what that says kept to be said in place ([member _refining]); the row as it is where nothing refines its prop.
func _with_refining(sec: PropSection, r: Dictionary) -> Dictionary:
	var pv := sec.versions_of()
	var name := String(r["refining_as"]) if r.get("refining_as") is String \
		else (pv.name_of(sec.prop_of(String(r.get("key", "")))) if pv != null else "")
	var w := PropRefining.of(name) if not name.is_empty() else {}
	if w.is_empty():
		return r
	var out := r.duplicate()
	out["refining"] = String(w["state"])
	var said := ""
	match String(w["state"]):
		"working":
			said = "an agent is refining it: %s" % String(w["line"])
		"ready":
			said = "a new version is ready: open it to see"
		_:
			said = "not refined: %s" % String(w["error"])
	_refining["%d:%s" % [sec.get_instance_id(), String(r.get("key", ""))]] = [String(r.get("line", "")), said]
	return out


## What is drawn, as one value to tell a change by: every row's fields, a picture by whether it is there.
static func _signature(drawn: Array) -> String:
	var parts: Array = []
	for d in drawn:
		parts.append(JSON.stringify(d[1]))
		for r in (d[2] as Array):
			var row: Dictionary = (r as Dictionary).duplicate()
			row["picture"] = row.get("picture") != null
			parts.append(JSON.stringify(row))
		parts.append(JSON.stringify(d[3]))
	return "|".join(PackedStringArray(parts))


func _lay_out(drawn: Array) -> void:
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()
	var live := {}
	_entries.clear()
	for d in drawn:
		var sec: PropSection = d[0]
		var rows: Array = d[2]
		for g in (d[1] as Array):
			var key := String((g as Dictionary)["key"])
			var mine := rows.filter(func(r: Dictionary) -> bool: return String(r.get("group", "")) == key)
			if mine.is_empty():
				continue
			var head := Label.new()
			head.text = String((g as Dictionary)["label"])
			head.tooltip_text = String((g as Dictionary).get("tip", ""))
			head.mouse_filter = Control.MOUSE_FILTER_PASS
			head.add_theme_font_size_override("font_size", 12)
			head.modulate = Color(1, 1, 1, 0.75)
			_box.add_child(head)
			for r in mine:
				_box.add_child(_row(sec, r, live))
		var adds: Dictionary = d[3]
		if not adds.is_empty():
			var add := Button.new()
			add.text = String(adds.get("label", "+ Add a prop"))
			add.tooltip_text = String(adds.get("tip", ""))
			add.focus_mode = Control.FOCUS_NONE
			add.pressed.connect(open_shelf.bind(sec))
			_box.add_child(add)
	_textures = live


## One prop's entry ([EntryCard]): its picture, name and line and its × - and, opened, its tick, its verbs and its properties. A row
## that is always open (`open`) has no ×; one with nothing to do never opens.
func _row(sec: PropSection, r: Dictionary, live: Dictionary) -> Control:
	var key := String(r["key"])
	var id := "%d:%s" % [sec.get_instance_id(), key]
	var e := EntryCard.new(String(r.get("name", key)), String(r.get("line", "")), String(r.get("tip", r.get("name", key))))
	# (its line always three lines tall: what it says - an agent refining it, most of all - never moves the buttons under it)
	e.hold_lines(LINE_LINES)
	_entries[id] = e
	if r.has("picture"):
		var pic := TextureRect.new()
		pic.custom_minimum_size = PICTURE
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.texture = _texture(r.get("picture"), live)
		pic.mouse_filter = Control.MOUSE_FILTER_PASS
		if pic.texture == null:
			pic.modulate = Color(1, 1, 1, 0.3)
		if sec.turns():
			look_on_click(pic, sec, key, String(r.get("name", key)))
		e.set_picture(pic)
	var always := bool(r.get("open", false))
	if not always:
		if r.has("remove_tip"):
			e.set_remove(func() -> void: _said(sec.remove(key)), String(r["remove_tip"]))
		else:
			e.set_remove(Callable(), "", String(r.get("remove_off", "It cannot be taken off here.")))
	var verbs := HFlowContainer.new()
	verbs.add_theme_constant_override("h_separation", 4)
	verbs.add_theme_constant_override("v_separation", 4)
	if r.get("on") is bool:
		var tick := CheckBox.new()
		tick.text = "Used"
		tick.focus_mode = Control.FOCUS_NONE
		tick.button_pressed = bool(r["on"])
		tick.tooltip_text = String(r.get("on_tip", "Ticked, the scene uses it; unticked, it is set aside."))
		tick.toggled.connect(func(on: bool) -> void: _said(sec.set_on(key, on)))
		verbs.add_child(tick)
	for v in (r.get("verbs", []) as Array):
		var vd: Dictionary = v
		if vd.get("choices") is Array:
			verbs.add_child(_choice(sec, key, vd))
			continue
		var b := Button.new()
		b.text = String(vd.get("label", vd.get("key", "")))
		b.tooltip_text = String(vd.get("tip", ""))
		b.focus_mode = Control.FOCUS_NONE
		b.disabled = bool(vd.get("off", false))
		if vd.has("pressed"):
			b.toggle_mode = true
			b.button_pressed = bool(vd["pressed"])
		b.add_theme_font_size_override("font_size", 12)
		if bool(vd.get("opens", false)):
			b.pressed.connect(func() -> void:
				var other := sec.choices(key)
				if other != null:
					open_shelf(other))
		else:
			b.pressed.connect(func() -> void: _said(sec.act(key, String(vd["key"]))))
		verbs.add_child(b)
	if verbs.get_child_count() > 0:
		e.options.add_child(verbs)
	var fields: Dictionary = r.get("fields", {}) if r.get("fields") is Dictionary else {}
	if not fields.is_empty():
		var form := SchemaForm.new()
		form.show_fields(fields, r.get("values", {}) if r.get("values") is Dictionary else {})
		form.edited.connect(func(field: String, value: Variant) -> void: _said(sec.set_field(key, field, value)))
		e.options.add_child(form)
	e.fixed = always
	e.open = _open.has(id)
	e.toggled.connect(func(on: bool) -> void:
		if on:
			_open[id] = true
		else:
			_open.erase(id))
	return e


## A verb that is a choice ([param vd]: `choices` `[{key, label}]`, `chosen` the key picked now): a picker beside the buttons, its
## label before it, a pick done by the section as `<verb>:<choice>` ([method PropSection.act]). A choice keyed "" stands for how it
## is now and picks nothing.
func _choice(sec: PropSection, key: String, vd: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var label := Label.new()
	label.text = String(vd.get("label", vd.get("key", "")))
	label.add_theme_font_size_override("font_size", 12)
	label.tooltip_text = String(vd.get("tip", ""))
	label.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_child(label)
	var pick := OptionButton.new()
	pick.fit_to_longest_item = false
	pick.clip_text = true
	pick.custom_minimum_size = Vector2(150, 0)
	pick.focus_mode = Control.FOCUS_NONE
	pick.tooltip_text = String(vd.get("tip", ""))
	pick.add_theme_font_size_override("font_size", 12)
	pick.disabled = bool(vd.get("off", false))
	for c in (vd["choices"] as Array):
		pick.add_item(String((c as Dictionary).get("label", "")))
		pick.set_item_metadata(pick.item_count - 1, String((c as Dictionary).get("key", "")))
		if String((c as Dictionary).get("key", "")) == String(vd.get("chosen", "")):
			pick.select(pick.item_count - 1)
	pick.item_selected.connect(func(i: int) -> void:
		var c := String(pick.get_item_metadata(i))
		if not c.is_empty():
			_said(sec.act(key, "%s:%s" % [String(vd["key"]), c])))
	row.add_child(pick)
	return row


func _texture(img: Variant, live: Dictionary) -> Texture2D:
	if not (img is Image) or (img as Image).is_empty():
		return null
	var id := (img as Image).get_instance_id()
	var tex: Texture2D = _textures.get(id)
	if tex == null:
		tex = ImageTexture.create_from_image(img as Image)
	live[id] = tex
	return tex


## What a press answered, said under the rows ("" said nothing went wrong), and the rows looked at again.
func _said(err: String) -> void:
	_status.text = err
	_status.visible = not err.is_empty()
	refresh(true)


## [param pic] opens the prop of row or offer [param key] of [param sec], called [param name], whole in 3D when it is clicked
## ([method look_at]).
func look_on_click(pic: Control, sec: PropSection, key: String, name: String) -> void:
	pic.mouse_filter = Control.MOUSE_FILTER_STOP
	pic.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if pic.tooltip_text.is_empty():
		pic.tooltip_text = "Click to look at it whole, in 3D."
	pic.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			pic.accept_event()
			look_at(sec, key, name))


## The prop of row or offer [param key] of [param sec], called [param name], opened whole in 3D ([PropViewer]).
func look_at(sec: PropSection, key: String, name: String) -> void:
	if _viewer == null or not is_instance_valid(_viewer):
		_viewer = PropViewer.new()
		add_child(_viewer)
	_viewer.open(sec, key, name)


## The Dex opened on [param sec]'s shelves: a prop picked there is added by it.
func open_shelf(sec: PropSection) -> void:
	if _shelf == null or not is_instance_valid(_shelf):
		_shelf = DexWindow.new()
		add_child(_shelf)
	_shelf.open([sec], func(err: String) -> void: _said(err))


## How many rows are shown now.
func row_count() -> int:
	var n := 0
	for sec in sections():
		n += ((sec as PropSection).rows()).size()
	return n


func _card() -> Card:
	var n: Node = get_parent()
	while n != null and not (n is Card):
		n = n.get_parent()
	return n as Card
