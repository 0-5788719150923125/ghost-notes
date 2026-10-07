extends CanvasLayer
class_name NotesList

## NotesList - where Ghost Notes opens (next/notes.md step 8, "No home screen"): a notes app opens on
## its notes. The left panel lists them - the default folder and every folder or file the user added
## ([NoteStore]), newest first - with New (the templates: today's modes, and a plain note) and
## Open…; the main area shows the name and the tagline in large type, with no controls on it.
##
## EVERYTHING THE HOME SCREEN HAD HAS A HOME HERE OR NEAR: the six mode rows are New's templates,
## gated on their agents exactly as the rows were (a disabled item still shows its tooltip, which
## lists every agent of each unfilled role from the registries); Import… and the path or URL field
## make a note with a song or a clip attached; the Environment panel and the Assistant's picker were
## Chrome's already (step 4); the key hint is the tooltips'.
##
## THE ⤓ EXPORT BUTTON HAS NO BUSINESS HERE: nothing is playing, so there is nothing to render.
## Suppressed on the way in and released on the way out - KEYED, because main opens the note FIRST
## and frees this list SECOND, so the note's own claims are already made when this lets go.

## Set by main: open_note.call(path).
var open_note: Callable

const VIDEO_EXTS := ["mp4", "mov", "mkv", "webm", "avi"]
const AUDIO_EXTS := ["wav", "mp3", "ogg", "oga", "flac"]
const COL_DATE := Color(0.5, 0.56, 0.66)

var _panel: SidePanel
var _new: MenuButton
var _source: LineEdit
var _rows: VBoxContainer
var _dialog: FileDialog
var _seen := ""            # the list as last drawn, so it is rebuilt only when it changed
var _poll_t := 0.0


func _ready() -> void:
	layer = 200
	_build()
	var ch := Chrome.of(self)
	if ch != null:
		ch.suppress_export(&"notes")
		# installing an agent and pressing rescan lights its templates up
		ch.environment.probed.connect(_gate_templates)
	refresh()


func _exit_tree() -> void:
	var ch := Chrome.of(self)
	if ch != null:
		ch.release_export(&"notes")


func _process(delta: float) -> void:
	# a note saved, made or deleted elsewhere shows up within a second or two
	_poll_t -= delta
	if _poll_t <= 0.0:
		_poll_t = 1.5
		refresh()


func _build() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.03, 0.03, 0.05, 1.0)
	add_child(bg)
	# THE MAIN AREA while no note is open: the name and the tagline, and nothing to press
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_left = 420.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(col)
	var title := Label.new()
	title.text = Boot.NAME
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0))
	col.add_child(title)
	var tag := Label.new()
	tag.text = Boot.TAGLINE
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_color_override("font_color", Color(0.55, 0.62, 0.75))
	col.add_child(tag)

	_panel = preload("res://src/side_panel.gd").new(380.0)
	_panel.title = "Notes"
	add_child(_panel)
	var box: VBoxContainer = _panel.body
	box.add_theme_constant_override("separation", 10)
	var name := Label.new()
	name.text = Boot.NAME
	name.add_theme_font_size_override("font_size", 20)
	box.add_child(name)
	var sub := Label.new()
	sub.text = Boot.TAGLINE
	sub.add_theme_font_size_override("font_size", 12)
	sub.modulate = Color(1, 1, 1, 0.6)
	box.add_child(sub)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	box.add_child(buttons)
	_new = MenuButton.new()
	_new.text = "New ▾"
	_new.flat = false
	_new.tooltip_text = "A new note from a template - today's modes, or just the words."
	_new.get_popup().id_pressed.connect(_on_new)
	_new.about_to_popup.connect(_gate_templates)
	buttons.add_child(_new)
	var open := Button.new()
	open.text = "Open…"
	open.tooltip_text = ("Open a note from anywhere - a rift chapter, a git repository - and keep it in this "
		+ "list. A song or a video makes a new note with it attached.")
	open.pressed.connect(_open_dialog)
	buttons.add_child(open)

	_source = LineEdit.new()
	_source.placeholder_text = "…or paste a URL or a file path and press Enter"
	_source.tooltip_text = ("A YouTube (or any http) URL makes a Masking note that downloads it. A local "
		+ "path is routed by its extension: a song makes an Auto note, a video a Masking note, a "
		+ "markdown file is opened and kept in the list.")
	_source.text_submitted.connect(_on_source)
	_source.text_changed.connect(func(_t: String) -> void: _source.remove_theme_color_override("font_color"))
	box.add_child(_source)

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 2)
	box.add_child(_rows)
	_fill_templates()


## New's items: one per template, in [constant Components.TEMPLATES]' order.
func _fill_templates() -> void:
	var pop := _new.get_popup()
	pop.clear()
	var i := 0
	for key in Components.TEMPLATES:
		pop.add_item(String(Components.TEMPLATES[key]["label"]), i)
		pop.set_item_metadata(pop.item_count - 1, key)
		i += 1
	_gate_templates()


## GRAY OUT every template whose agents are not installed - the home screen's rule, moved here. The
## tooltip lists every agent of each unfilled role from the registries and suggests installing one
## or several; with them, it names the installed ones. Asked again each time the menu opens and
## whenever the Environment panel's probe lands.
func _gate_templates() -> void:
	var pop := _new.get_popup()
	for i in pop.item_count:
		var key := String(pop.get_item_metadata(i))
		var t: Dictionary = Components.TEMPLATES[key]
		var roles := Capabilities.roles_of(Components.capabilities_of(t["components"]))
		var missing := Capabilities.missing_roles(roles)
		pop.set_item_disabled(i, not missing.is_empty())
		var tip := String(t["blurb"])
		if not roles.is_empty():
			tip += "\n\n" + Capabilities.agents_tooltip(roles, missing)
		pop.set_item_tooltip(i, tip)


func _on_new(id: int) -> void:
	var pop := _new.get_popup()
	var i := pop.get_item_index(id)
	if i < 0 or pop.is_item_disabled(i):
		return
	var path := NoteStore.create(String(pop.get_item_metadata(i)))
	if not path.is_empty():
		_open(path)


## Rebuild the rows when the notes changed: each a note's title and when it last changed.
func refresh() -> void:
	var notes := NoteStore.list()
	var sig := JSON.stringify(notes)
	if sig == _seen:
		return
	_seen = sig
	for c in _rows.get_children():
		c.queue_free()
	if notes.is_empty():
		var none := Label.new()
		none.text = "No notes yet - New makes one, Open… brings one in."
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.add_theme_font_size_override("font_size", 12)
		none.modulate = Color(1, 1, 1, 0.55)
		_rows.add_child(none)
		return
	for n in notes:
		_rows.add_child(_row(n))


func _row(n: Dictionary) -> Control:
	var b := Button.new()
	b.flat = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.clip_text = true
	b.text = String(n["title"])
	b.tooltip_text = String(n["path"])
	b.custom_minimum_size = Vector2(0, 30)
	b.pressed.connect(_open.bind(String(n["path"])))
	var date := Label.new()
	date.text = when(int(n["mtime"]))
	date.add_theme_font_size_override("font_size", 11)
	date.add_theme_color_override("font_color", COL_DATE)
	date.mouse_filter = Control.MOUSE_FILTER_IGNORE
	date.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	date.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	date.offset_right = -6
	b.add_child(date)
	return b


## When a note last changed, as a list says it: "today", "yesterday", "Oct 3", "2025-12-01".
static func when(mtime: int) -> String:
	if mtime <= 0:
		return ""
	var now := int(Time.get_unix_time_from_system())
	var today := Time.get_datetime_dict_from_unix_time(now)
	var then := Time.get_datetime_dict_from_unix_time(mtime)
	var day := func(d: Dictionary) -> int:
		return int(Time.get_unix_time_from_datetime_dict({"year": d["year"], "month": d["month"], "day": d["day"]}) / 86400)
	var ago: int = int(day.call(today)) - int(day.call(then))
	if ago <= 0:
		return "today"
	if ago == 1:
		return "yesterday"
	var months := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	if int(then["year"]) == int(today["year"]):
		return "%s %d" % [months[int(then["month"]) - 1], int(then["day"])]
	return "%04d-%02d-%02d" % [int(then["year"]), int(then["month"]), int(then["day"])]


func _open(path: String) -> void:
	if open_note.is_valid():
		open_note.call(path)
	queue_free()


func _open_dialog() -> void:
	if _dialog != null and is_instance_valid(_dialog):
		return
	_dialog = FileDialog.new()
	_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_dialog.access = FileDialog.ACCESS_FILESYSTEM
	# In-window, never native: the portal dialog shows nothing at all on a Linux box without
	# xdg-desktop-portal ("I pressed it and nothing happened").
	_dialog.use_native_dialog = false
	_dialog.title = "Open a note, a song or a video"
	_dialog.filters = PackedStringArray(["*.md, *.markdown ; Notes",
		"*.wav, *.mp3, *.ogg, *.oga, *.flac ; Songs", "*.mp4, *.mov, *.mkv, *.webm, *.avi ; Videos",
		"* ; Every file"])
	_dialog.size = Vector2i(820, 560)
	_dialog.file_selected.connect(func(p: String) -> void:
		_close_dialog()
		_take(p))
	_dialog.canceled.connect(_close_dialog)
	add_child(_dialog)
	_dialog.popup_centered()


func _close_dialog() -> void:
	if _dialog != null and is_instance_valid(_dialog):
		_dialog.queue_free()
	_dialog = null


## The free-form field: a URL or a path, routed as Open… routes a file. Anything that is neither
## an existing file nor URL-shaped turns the entry red instead of making a note it cannot fill.
func _on_source(text: String) -> void:
	var s := text.strip_edges()
	if s.is_empty():
		return
	var is_url := s.begins_with("http://") or s.begins_with("https://")
	if not is_url and not FileAccess.file_exists(s) and (s.begins_with("www.")
			or s.to_lower().contains("youtu.be") or s.to_lower().contains("youtube.com")):
		s = "https://" + s   # pasted without a scheme
		is_url = true
	if is_url or FileAccess.file_exists(s):
		_take(s)
	else:
		_source.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))


## A FILE OR A LINK BROUGHT IN: a note is opened and kept in the list; a song makes an Auto note with
## it attached, a video or a link a Masking note.
func _take(s: String) -> void:
	var ext := s.get_extension().to_lower()
	var path := ""
	if s.begins_with("http://") or s.begins_with("https://") or VIDEO_EXTS.has(ext):
		path = NoteStore.create("masking", _title_from(s), "", {"clip": {"path": s}})
	elif AUDIO_EXTS.has(ext):
		path = NoteStore.create("auto", _title_from(s), "", {"song": {"path": s}})
	elif ext in NoteStore.EXTS or FileAccess.file_exists(s):
		NoteStore.add(s)
		path = s
	if not path.is_empty():
		_open(path)


static func _title_from(s: String) -> String:
	if s.begins_with("http"):
		return "Clip from " + s.trim_prefix("https://").trim_prefix("http://").trim_prefix("www.").get_slice("/", 0)
	return s.get_file().get_basename()
