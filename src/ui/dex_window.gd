extends Window
class_name DexWindow

## DexWindow - the Dex: what the library keeps, a shelf at a time, a tile an entry. Its sections ([ShelfSection]) are props and voices
## when it is opened on its own (the bottom-right row's button), or the one section a card hands it ("+ Add a prop" on the Props
## card, whose section adds what is picked: Use). Each tile shows an entry's picture, its name (renamed in place where it can be), its
## line and its verbs - Use, Hear for a voice, Export… to hand it on in a file, and what its section offers besides; Import… takes such
## a file in. A filter by words narrows the shelf. A picture is asked for when its tile comes into view ([method
## ShelfSection.want_pictures]) and shown as it arrives; a click on a prop's opens it whole, in 3D ([PropViewer]). It opens centered in
## the room beside the side panel, never under it ([method Shell.center_beside]). Escape or the window's close hides it.

## Its size, at most, against the room beside the panel.
const MOST := Vector2(0.86, 0.86)
const SIZE := Vector2i(860, 640)
## A tile's picture (pixels), and how often the shelf looks for pictures that arrived (seconds).
const PICTURE := Vector2(176, 132)
const LOOK_EVERY := 0.4

var _sections: Array = []          # ShelfSection, in the order their shelves are shown
var _told: Callable = Callable()   # (err: String) -> void: what a press answered
var _tab := ""                     # "<section index>:<shelf key>"
var _filter: LineEdit
var _tabs: HFlowContainer
var _import: Button
var _scroll: ScrollContainer
var _grid: HFlowContainer
var _status: Label
var _tiles := {}                   # offer key -> {pic: TextureRect, has: bool}
var _look_t := 0.0
var _count := -1                   # how many offers there were when the shelf was last filled
var _version := -1                 # the sections' versions, summed, when the shelf was last filled ([method ShelfSection.version])
var _viewer: PropViewer = null
var _player: AudioStreamPlayer
var _playing := ""                 # the file being heard


func _init() -> void:
	visible = false
	title = "Dex"
	close_requested.connect(_close)
	window_input.connect(func(e: InputEvent) -> void:
		if e is InputEventKey and (e as InputEventKey).pressed and (e as InputEventKey).keycode == KEY_ESCAPE:
			_close())
	_player = AudioStreamPlayer.new()
	_player.finished.connect(func() -> void: _playing = "")
	add_child(_player)
	var bg := PanelContainer.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	bg.add_child(col)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	col.add_child(top)
	_filter = LineEdit.new()
	_filter.placeholder_text = "Find"
	_filter.tooltip_text = "Show only what shares these words: its name, its line, what it is made of."
	_filter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_filter.clear_button_enabled = true
	_filter.text_changed.connect(func(_t: String) -> void: _fill())
	_filter.text_submitted.connect(func(_t: String) -> void: _filter.release_focus())
	top.add_child(_filter)
	_import = Button.new()
	_import.text = "Import…"
	_import.focus_mode = Control.FOCUS_NONE
	_import.pressed.connect(func() -> void:
		var sec := _section()
		if sec == null:
			return
		_pick_file(FileDialog.FILE_MODE_OPEN_FILE, "", sec.file_kind(), func(path: String) -> void: _answer(sec.import_from(path), true)))
	top.add_child(_import)
	_tabs = HFlowContainer.new()
	_tabs.add_theme_constant_override("h_separation", 4)
	col.add_child(_tabs)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(_scroll)
	_grid = HFlowContainer.new()
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	_scroll.add_child(_grid)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 11)
	_status.add_theme_color_override("font_color", Color(0.55, 0.95, 0.75, 0.85))
	col.add_child(_status)


func _process(dt: float) -> void:
	if not visible or _sections.is_empty():
		return
	_look_t -= dt
	if _look_t > 0.0:
		return
	_look_t = LOOK_EVERY
	# a shelf read on a worker arrives after the window opens: filled again when what is offered grows or shrinks, or changes
	if _offers().size() != _count or _versions() != _version:
		_fill()
		return
	_show_pictures()


## Opened on [param sections] ([ShelfSection]s): [param told] hears what each press answered, and the shelf shown first is the one
## shown last, else [param first] ("<section title>" or "<section title>:<shelf key>"), else the first.
func open(sections: Array, told := Callable(), first := "") -> void:
	_sections = sections.filter(func(s: Variant) -> bool: return s is ShelfSection)
	_told = told
	var keys := _tab_keys()
	if not keys.has(_tab):
		_tab = keys[0] if not keys.is_empty() else ""
		for k in keys:
			var sec: ShelfSection = _sections[int(String(k).get_slice(":", 0))]
			var named := "%s:%s" % [sec.title(), String(k).get_slice(":", 1)]
			if not first.is_empty() and (first == sec.title() or first == named):
				_tab = k
				break
	title = "Dex" if _sections.size() != 1 else "Dex - %s" % (_sections[0] as ShelfSection).title()
	_status.text = ""
	_fill()
	var host := get_parent()
	var room := Shell.room_beside(host)
	size = Vector2i(mini(SIZE.x, int(room.size.x * MOST.x)), mini(SIZE.y, int(room.size.y * MOST.y)))
	popup()
	Shell.center_beside(self, host)
	(func() -> void: Shell.center_beside(self, get_parent())).call_deferred()


## What adding is called on the shelf shown ("Use"), "" where nothing is added.
func adds_label() -> String:
	var sec := _section()
	return String(sec.adds().get("verb", "")) if sec != null and not sec.adds().is_empty() else ""


## The shelves' tabs as shown, each its label and count.
func shelf_labels() -> Array:
	return _tabs.get_children().map(func(b: Node) -> String: return (b as Button).text)


## The section of the shelf shown, or null.
func _section() -> ShelfSection:
	var i := int(_tab.get_slice(":", 0)) if not _tab.is_empty() else -1
	return _sections[i] if i >= 0 and i < _sections.size() else null


## Every shelf of every section: "<section index>:<shelf key>", in order.
func _tab_keys() -> Array:
	var out: Array = []
	for i in _sections.size():
		for s in (_sections[i] as ShelfSection).shelves():
			out.append("%d:%s" % [i, String((s as Dictionary)["key"])])
	return out


## Every section's version, summed ([method ShelfSection.version]).
func _versions() -> int:
	var n := 0
	for sec in _sections:
		n += (sec as ShelfSection).version()
	return n


## What the section shown offers now.
func _offers() -> Array:
	var sec := _section()
	return sec.offers() if sec != null else []


## Every tile of the shelf shown, as the filter leaves them.
func _fill() -> void:
	for c in _tabs.get_children():
		_tabs.remove_child(c)
		c.queue_free()
	for i in _sections.size():
		var sec: ShelfSection = _sections[i]
		var all := sec.offers()
		for s in sec.shelves():
			var sd: Dictionary = s
			var key := "%d:%s" % [i, String(sd["key"])]
			var n := all.filter(func(o: Dictionary) -> bool: return String(o.get("shelf", "")) == String(sd["key"])).size()
			var b := Button.new()
			b.text = "%s (%d)" % [String(sd["label"]), n]
			b.tooltip_text = String(sd.get("tip", ""))
			b.toggle_mode = true
			b.button_pressed = key == _tab
			b.focus_mode = Control.FOCUS_NONE
			b.pressed.connect(func() -> void:
				_tab = key
				_scroll.scroll_vertical = 0
				_fill())
			_tabs.add_child(b)
	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	_tiles = {}
	var sec := _section()
	var kind := sec.file_kind() if sec != null else {}
	_import.visible = not kind.is_empty()
	_import.tooltip_text = "Take %s someone handed you (a %s file) into your library, read as a made one is." % [
		String(kind.get("label", "an entry")).to_lower(), String(kind.get("ext", ""))] if not kind.is_empty() else ""
	var offers := _offers()
	_count = offers.size()
	_version = _versions()
	var shelf := _tab.get_slice(":", 1) if not _tab.is_empty() else ""
	var words := _filter.text.strip_edges().to_lower().split(" ", false)
	var shown := 0
	for o in offers:
		var od: Dictionary = o
		if String(od.get("shelf", "")) != shelf:
			continue
		var said := ("%s %s %s" % [String(od.get("name", "")), String(od.get("line", "")), String(od.get("tip", ""))]).to_lower()
		if not Array(words).all(func(w: String) -> bool: return said.contains(w)):
			continue
		_grid.add_child(_tile(sec, od))
		shown += 1
	if shown == 0:
		var none := Label.new()
		none.text = "Nothing here yet." if words.is_empty() else "Nothing here shares those words."
		none.modulate = Color(1, 1, 1, 0.6)
		_grid.add_child(none)
	_look_t = 0.0


## One entry's tile: its picture, name, line and verbs.
func _tile(sec: ShelfSection, o: Dictionary) -> Control:
	var key := String(o["key"])
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(PICTURE.x, 0)
	box.add_theme_constant_override("separation", 2)
	var sound := String(o.get("sound", ""))
	if o.has("sound"):
		var mark := Label.new()
		mark.text = "♪"
		mark.custom_minimum_size = Vector2(PICTURE.x, PICTURE.y * 0.5)
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		mark.add_theme_font_size_override("font_size", 40)
		mark.modulate = Color(1, 1, 1, 0.5 if sound.is_empty() else 0.85)
		mark.tooltip_text = String(o.get("tip", ""))
		mark.mouse_filter = Control.MOUSE_FILTER_PASS
		box.add_child(mark)
	else:
		var pic := TextureRect.new()
		pic.custom_minimum_size = PICTURE
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.tooltip_text = String(o.get("tip", ""))
		if sec.turns():
			pic.tooltip_text = (pic.tooltip_text + "\n" if not pic.tooltip_text.is_empty() else "") + "Click to look at it whole, in 3D."
			pic.mouse_filter = Control.MOUSE_FILTER_STOP
			pic.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			pic.gui_input.connect(func(e: InputEvent) -> void:
				if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
					pic.accept_event()
					look_at(sec, key, String(o.get("name", key))))
		var has := o.get("picture") is Image and not (o["picture"] as Image).is_empty()
		if has:
			pic.texture = ImageTexture.create_from_image(o["picture"] as Image)
		box.add_child(pic)
		_tiles[key] = {"pic": pic, "has": has}
	if bool(o.get("named", false)):
		var name := LineEdit.new()
		name.text = String(o.get("name", key))
		name.tooltip_text = "Its name in the library: type another and press Enter to rename it."
		name.text_submitted.connect(func(t: String) -> void:
			name.release_focus()
			_answer(sec.rename(key, t), true))
		name.focus_exited.connect(func() -> void:
			if name.text.strip_edges() != String(o.get("name", key)) and not name.text.strip_edges().is_empty():
				_answer(sec.rename(key, name.text), true))
		box.add_child(name)
	else:
		var name := Label.new()
		name.text = String(o.get("name", key))
		name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name.custom_minimum_size = Vector2(PICTURE.x, 0)
		box.add_child(name)
	var line := Label.new()
	line.text = String(o.get("line", ""))
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size = Vector2(PICTURE.x, 0)
	line.add_theme_font_size_override("font_size", 11)
	line.modulate = Color(1, 1, 1, 0.65)
	box.add_child(line)
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 4)
	box.add_child(row)
	var adds := sec.adds()
	if not adds.is_empty():
		row.add_child(_button(String(adds.get("verb", "Use")), String(adds.get("tip", "")), false, func() -> void: _answer(sec.add(key), false)))
	if o.has("sound"):
		row.add_child(_button("Hear", "Hear it say a few lines." if not sound.is_empty() else "Nothing to hear yet: it is said once the voice is kept from its card.",
			sound.is_empty(), func() -> void: hear(sound)))
	if sec.exportable(key):
		var kind := sec.file_kind()
		row.add_child(_button("Export…", "Write it to a file you can hand on (a %s): what it is, nothing else." % String(kind.get("ext", "")), false,
			func() -> void: _pick_file(FileDialog.FILE_MODE_SAVE_FILE, String(o.get("name", "entry")).validate_filename() + String(kind.get("ext", "")),
				kind, func(path: String) -> void: _answer(sec.export_to(key, path), false))))
	for v in (o.get("verbs", []) as Array):
		var vd: Dictionary = v
		row.add_child(_button(String(vd.get("label", vd.get("key", ""))), String(vd.get("tip", "")), bool(vd.get("off", false)),
			func() -> void: _answer(sec.act(key, String(vd["key"])), true)))
	return box


func _button(text: String, tip: String, off: bool, pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.disabled = off
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(pressed)
	return b


## The entry of offer [param key] of [param sec], called [param name], opened whole in 3D ([PropViewer]).
func look_at(sec: ShelfSection, key: String, name: String) -> void:
	if _viewer == null or not is_instance_valid(_viewer):
		_viewer = PropViewer.new()
		add_child(_viewer)
	_viewer.open(sec, key, name)


## The sound in the file at [param path] heard, or stopped if it is the one playing.
func hear(path: String) -> void:
	if _player.playing and _playing == path:
		_player.stop()
		_playing = ""
		return
	var stream: AudioStream = null
	match path.get_extension().to_lower():
		"wav":
			stream = AudioStreamWAV.load_from_file(path)
		"ogg":
			stream = AudioStreamOggVorbis.load_from_file(path)
	if stream == null:
		_answer("that sound cannot be played", false)
		return
	_player.stream = stream
	_player.play()
	_playing = path


## What a press answered, said here and to whoever opened it; a change to the shelf shown again ([param again]).
func _answer(err: String, again: bool) -> void:
	_status.text = err
	if _told.is_valid():
		_told.call(err)
	if again:
		_fill()


## A file picked anywhere on the machine ([param mode] open or save, [param named] the name offered, [param kind] its section's
## [method ShelfSection.file_kind]), handed to [param then].
func _pick_file(mode: FileDialog.FileMode, named: String, kind: Dictionary, then: Callable) -> void:
	var fd := FileDialog.new()
	fd.file_mode = mode
	fd.access = FileDialog.ACCESS_FILESYSTEM
	# in-window, never native: the portal dialog shows nothing on a Linux box without xdg-desktop-portal
	fd.use_native_dialog = false
	fd.filters = PackedStringArray(["*%s, *.json ; %s" % [String(kind.get("ext", ".json")), String(kind.get("label", "Files"))]])
	if not named.is_empty():
		fd.current_file = named
	fd.file_selected.connect(func(path: String) -> void:
		then.call(path)
		fd.queue_free())
	fd.canceled.connect(fd.queue_free)
	add_child(fd)
	fd.popup_centered(Vector2i(720, 480))


## The pictures of the tiles in view asked for, and those that arrived shown.
func _show_pictures() -> void:
	var sec := _section()
	if sec == null:
		return
	var view := Rect2(Vector2(0, _scroll.scroll_vertical), _scroll.size)
	var want: Array = []
	for k in _tiles:
		var t: Dictionary = _tiles[k]
		if bool(t["has"]):
			continue
		var pic: TextureRect = t["pic"]
		var at := pic.get_parent() as Control
		if at != null and view.intersects(Rect2(at.position, at.size)):
			want.append(k)
	if want.is_empty():
		return
	sec.want_pictures(want)
	for o in sec.offers():
		var k := String((o as Dictionary)["key"])
		if want.has(k) and (o as Dictionary).get("picture") is Image:
			var t: Dictionary = _tiles[k]
			(t["pic"] as TextureRect).texture = ImageTexture.create_from_image((o as Dictionary)["picture"] as Image)
			t["has"] = true


func _close() -> void:
	_player.stop()
	_playing = ""
	hide()
