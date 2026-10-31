extends Control
class_name NoteEditor

## NoteEditor - a note opened as a notes app opens one (2026-10-31, the user: "a new note with no components
## automatically gets the 'title' and 'content' fields, akin to how Google [Keep] does it. Once we've opened a
## note, and we're editing those fields, we should expand description to fit the content - breaking from the
## strictly square aspect ratio of the note"): its [NoteTile] grown into a card over the grid, its Title and
## its words both written in place - no Edit, no window.
##
## THE CARD GROWS WITH THE WORDS: as tall as they are, from a few lines up to the screen's height, and past
## that its words scroll ([method _fit]). On a phone it is the whole screen ([member whole]), its bar at the top
## where the keyboard never covers it.
##
## WHO OPENS IT: on the desktop, New and a note with nothing attached ([NotesList]) - a note that is more than
## its words opens on its own panel, where the Body card shows its first lines and Edit; the card's
## [Icons] "open" takes a note there, where "+" attaches what it becomes. On a phone, every note ([PhoneShell]).
##
## WRITTEN AS IT IS TYPED, on a quiet period ([constant SAVE_MS]) and as it closes: the words through [method
## FrontMatter.write_body], which keeps every byte of the frontmatter, and the title through [method
## NoteStore.retitle] - so a note named after its title is renamed with it ([signal moved]). A NEW NOTE'S TITLE
## BOX STARTS EMPTY, its "Untitled" kept until something is written there; and a new note closed with nothing
## written in it is gone ([method NoteStore.discard_if_empty]), as Keep lets an empty one go.
##
## Escape, a click beside the card or Close closes it; Enter in the title goes on to the words.

signal closed(path: String)
signal moved(from: String, to: String)

## How long the typing must stop before the note is written, in ms.
const SAVE_MS := 800
## The card's width on a desktop, and how far down it stands, at scale 1.
const WIDE := 640.0
const TOP := 72.0
## The fewest lines of words the card is tall enough for.
const LEAST_LINES := 4
const SCRIM := Color(0.0, 0.0, 0.0, 0.62)

## The size of everything on it: 1 on a desktop, larger on a phone.
var s := 1.0
## Whether it fills its rect - a phone's screen - rather than standing as a card over the grid.
var whole := false
## The note open in it, "" when none is.
var path := ""
var title_edit: LineEdit
var body: TextEdit
## Where the owner puts its buttons: in the bar, left of Close.
var actions: HBoxContainer
## The note's color ([method NoteTile.color_of]).
var color := Card.PAPER

var _scrim: ColorRect
var _card: PanelContainer
var _band: PanelContainer
var _bar: HBoxContainer
var _date: Label
var _close: Button
var _saved_body := ""           # the words as last read or written: what write_body expects
var _lead := ""                 # the blank lines between the frontmatter and the words, kept as they are
var _dirty_ms := -1             # when the typing stopped, -1 when nothing waits
var _title_dirty := false
var _fresh := false


func _init(p_scale := 1.0, p_whole := false) -> void:
	s = p_scale
	whole = p_whole
	mouse_filter = Control.MOUSE_FILTER_STOP if not whole else Control.MOUSE_FILTER_IGNORE
	visible = false
	_build()


func _ready() -> void:
	resized.connect(_fit)
	# how many lines the words wrap to follows the box's width, which its card settles a moment later
	body.resized.connect(func() -> void: _fit.call_deferred())


func _process(_delta: float) -> void:
	if _dirty_ms >= 0 and Time.get_ticks_msec() - _dirty_ms >= SAVE_MS:
		save()


func _input(e: InputEvent) -> void:
	var k := e as InputEventKey
	if visible and not whole and k != null and k.pressed and k.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func _build() -> void:
	_scrim = ColorRect.new()
	_scrim.color = SCRIM if not whole else Color(0, 0, 0, 0)
	_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scrim.mouse_filter = Control.MOUSE_FILTER_STOP if not whole else Control.MOUSE_FILTER_IGNORE
	_scrim.gui_input.connect(func(e: InputEvent) -> void:
		var mb := e as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			close())
	add_child(_scrim)
	_card = PanelContainer.new()
	add_child(_card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	_card.add_child(col)

	_bar = HBoxContainer.new()
	_bar.add_theme_constant_override("separation", roundi(4 * s))
	var bar_pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		bar_pad.add_theme_constant_override("margin_" + side, roundi((10.0 if side in ["left", "right"] else 6.0) * s))
	bar_pad.add_child(_bar)
	_close = Button.new()
	_close.text = "‹ Notes" if whole else "Close"
	_close.flat = true
	_close.focus_mode = Control.FOCUS_NONE
	_close.add_theme_font_size_override("font_size", roundi(14 * s))
	_close.pressed.connect(close)
	_date = Label.new()
	_date.add_theme_font_size_override("font_size", roundi(11 * s))
	_date.add_theme_color_override("font_color", NoteTile.COL_DATE)
	_date.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_date.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions = HBoxContainer.new()
	actions.add_theme_constant_override("separation", roundi(2 * s))
	if whole:
		_bar.add_child(_close)
		_bar.add_child(_date)
		_date.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_bar.add_child(actions)
		col.add_child(bar_pad)

	_band = PanelContainer.new()
	col.add_child(_band)
	title_edit = LineEdit.new()
	title_edit.placeholder_text = "Title"
	title_edit.add_theme_font_size_override("font_size", roundi(20 * s))
	for state in ["normal", "focus", "read_only"]:
		title_edit.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	title_edit.text_changed.connect(func(_t: String) -> void:
		_title_dirty = true
		_dirty_ms = Time.get_ticks_msec())
	title_edit.text_submitted.connect(func(_t: String) -> void: body.grab_focus())
	_band.add_child(title_edit)

	body = TextEdit.new()
	body.placeholder_text = "Take a note…"
	body.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL if whole else Control.SIZE_FILL
	body.add_theme_font_size_override("font_size", roundi(15 * s))
	body.add_theme_constant_override("line_spacing", roundi(3 * s))
	var flat := StyleBoxEmpty.new()
	flat.content_margin_left = roundf(12 * s)
	flat.content_margin_right = roundf(12 * s)
	flat.content_margin_top = roundf(8 * s)
	flat.content_margin_bottom = roundf(8 * s)
	for state in ["normal", "focus", "read_only"]:
		body.add_theme_stylebox_override(state, flat)
	body.add_theme_color_override("background_color", Color(0, 0, 0, 0))
	# the system keyboard comes up by itself for a TextEdit on a phone; no code of ours asks for it
	body.text_changed.connect(func() -> void:
		_dirty_ms = Time.get_ticks_msec()
		_fit.call_deferred())
	col.add_child(body)
	if not whole:
		_bar.add_child(_date)
		_bar.add_child(actions)
		_bar.add_child(_close)
		col.add_child(bar_pad)
	_style()


## OPEN [param p] IN THE CARD - what another note waited to write, written first. [param fresh]: a note New
## made a moment ago (its title box empty, and gone again if it is closed empty).
func open(p: String, fresh := false) -> void:
	if visible and not path.is_empty() and path != p:
		close()
	if not FileAccess.file_exists(p):
		return
	path = p
	_fresh = fresh
	var raw := FileAccess.get_file_as_string(p)
	# the blank line under the frontmatter is the file's, not the words': kept, and never shown
	var all := FrontMatter.lf(String(FrontMatter.split(raw)["body"]))
	_saved_body = all.lstrip("\n")
	_lead = all.substr(0, all.length() - _saved_body.length())
	title_edit.text = "" if fresh else NoteStore.title_of(p)
	body.text = _saved_body
	body.clear_undo_history()
	body.set_caret_line(0)
	_dirty_ms = -1
	_title_dirty = false
	color = NoteTile.color_of(Components.attached_of(NoteStore.blocks_of(p)))
	_date.text = "Edited %s" % NoteTile.when(FileAccess.get_modified_time(p)) if not fresh else ""
	_style()
	visible = true
	_fit()
	_fit.call_deferred()
	if fresh:
		title_edit.grab_focus.call_deferred()


## WRITE WHAT WAITS: the words, keeping the frontmatter byte for byte, and the title ([method NoteStore.retitle] -
## the file renamed with it when its name follows it).
func save() -> void:
	if path.is_empty() or _dirty_ms < 0:
		return
	_dirty_ms = -1
	if body.text != _saved_body:
		var err := FrontMatter.write_body(path, _lead + body.text, _lead + _saved_body)
		if err.is_empty():
			_saved_body = body.text
		else:
			push_warning("ghost: %s was not saved - %s" % [path.get_file(), err])
	if _title_dirty:
		_title_dirty = false
		var t := title_edit.text.strip_edges()
		if not (t.is_empty() and _fresh):
			var was := path
			path = NoteStore.retitle(path, t)
			if path != was:
				moved.emit(was, path)


## CLOSE IT, what waits written: the grid shows the note as it is now ([signal closed]).
func close() -> void:
	if not visible:
		return
	save()
	var p := path
	if _fresh and title_edit.text.strip_edges().is_empty() and body.text.strip_edges().is_empty():
		NoteStore.discard_if_empty(p)
	path = ""
	visible = false
	closed.emit(p)


## Let the note go without writing anything more - it is being deleted.
func drop() -> void:
	_dirty_ms = -1
	_title_dirty = false
	path = ""
	visible = false


## THE CARD GROWS WITH ITS WORDS: as many lines as they wrap to, at least [constant LEAST_LINES], and never past
## the screen - there the words scroll inside it. On a phone it fills the screen.
func _fit() -> void:
	if size.x <= 0.0:
		return
	var margin := roundf(16 * s)
	if whole:
		_card.position = Vector2.ZERO
		_card.size = size
		return
	var w := minf(WIDE * s, size.x - 2.0 * margin)
	var room := size.y - TOP * s - margin
	var flat := body.get_theme_stylebox("normal")
	var pad := flat.content_margin_top + flat.content_margin_bottom if flat != null else 0.0
	var lines := maxi(body.get_total_visible_line_count(), LEAST_LINES)
	var other := _band.get_combined_minimum_size().y + _bar.get_parent_control().get_combined_minimum_size().y + 2.0
	var want := lines * (body.get_line_height()) + pad
	body.custom_minimum_size = Vector2(0, clampf(want, 0.0, maxf(room - other, 80.0 * s)))
	_card.size = Vector2(w, 0)
	_card.size = Vector2(w, _card.get_combined_minimum_size().y)
	_card.position = Vector2(floorf((size.x - w) / 2.0), TOP * s)


func _style() -> void:
	var c := color
	var outer := StyleBoxFlat.new()
	outer.bg_color = NoteTile.COL_BODY
	outer.border_color = Color(c, 0.9)
	outer.set_border_width_all(1)
	outer.set_corner_radius_all(roundi(6 * s) if not whole else 4)
	outer.set_content_margin_all(1)
	outer.shadow_color = Color(0, 0, 0, 0.45)
	outer.shadow_size = 0 if whole else roundi(18 * s)
	_card.add_theme_stylebox_override("panel", outer)
	var band := StyleBoxFlat.new()
	band.bg_color = Color(c, 0.18)
	band.corner_radius_top_left = roundi(5 * s) if not whole else 0
	band.corner_radius_top_right = band.corner_radius_top_left
	band.content_margin_left = roundf(12 * s)
	band.content_margin_right = roundf(12 * s)
	band.content_margin_top = roundf(8 * s)
	band.content_margin_bottom = roundf(8 * s)
	_band.add_theme_stylebox_override("panel", band)
	title_edit.add_theme_color_override("font_color", c.lightened(0.45))
	title_edit.add_theme_color_override("font_placeholder_color", Color(c.lightened(0.3), 0.45))
