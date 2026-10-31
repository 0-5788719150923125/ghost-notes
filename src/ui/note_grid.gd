extends VBoxContainer
class_name NoteGrid

## NoteGrid - the notes, as a notes app shows them (2026-10-31, the user: "a Google Keep kind of look:
## extremely simple, centered with wide margins, a search bar at the top, and a 2-3 columns of sticky
## notes"): the name, a search field with the owner's icon buttons beside it ([member actions], [Icons]),
## and every note as a square [NoteTile] in a centered grid that scrolls up and down, newest first
## ([method NoteStore.list]). The desktop's [NotesList] and the phone's [PhoneShell] both show it - only
## [member s], the size of everything, differs - so the phone's list is the desktop's ("the mobile view is
## important").
##
## EVERY TILE ONE SIZE, AS MANY COLUMNS AS FIT, BETWEEN [constant LEAST_COLS] AND [constant MOST_COLS]: at
## most [constant TILE] square, never under [constant TILE_LEAST] while a column can be given up instead, and
## the column the tiles make is the header's width too ([method _layout]).
##
## THE SEARCH NARROWS THE GRID as it is typed: a note stays when every word typed is in its title, its words
## or the names of its components ([method NoteStore.summary_of] `words`), so "letter" finds the letters.
## Escape clears it; Enter opens the first note left.
##
## A NOTE SAVED, MADE OR DELETED ELSEWHERE SHOWS UP within [constant POLL] seconds: the list is compared,
## and a note's file is read again only when it changed.

signal opened(path: String)
signal delete_asked(path: String)

const TILE := 272.0
const TILE_LEAST := 200.0
const GAP := 16.0
const MARGIN := 24.0
const MOST_COLS := 3
const LEAST_COLS := 2
const POLL := 1.5

## The size of everything on it: 1 on a desktop, larger on a phone.
var s := 1.0
## Whether a tile carries an × ([signal delete_asked]).
var deletable := true
## Where the owner puts its buttons, right of the search.
var actions: HBoxContainer
var search: LineEdit
## How many columns the tiles stand in, and how big each is, as last laid out.
var columns := 0
var side := 0.0

var _top: Control
var _header: VBoxContainer
var _scroll: ScrollContainer
var _column: VBoxContainer
var _grid: GridContainer
var _empty: Label
var _tiles: Array = []          # [NoteTile], in the list's order
var _known := {}                # path -> {mtime, summary}: a file read again only when it changed
var _seen := ""
var _poll_t := 0.0


func _init(p_scale := 1.0, p_deletable := true) -> void:
	s = p_scale
	deletable = p_deletable
	add_theme_constant_override("separation", roundi(18 * s))
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build()


func _ready() -> void:
	resized.connect(_layout)
	refresh(true)
	_layout()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_poll_t -= delta
	if _poll_t <= 0.0:
		_poll_t = POLL
		refresh()
	var at := get_global_mouse_position()
	var view := _scroll.get_global_rect()
	for t in _tiles:
		var tile: NoteTile = t
		tile.set_hover(tile.visible and view.has_point(at) and tile.get_global_rect().has_point(at))


func _build() -> void:
	# A PLAIN CONTROL, NOT A CONTAINER, and the header placed in it by hand ([method _layout]): a container
	# takes its child's width as its own least, so the width the last layout gave the header held the whole
	# grid at least that wide, and it could never lay out narrower again.
	_top = Control.new()
	_top.resized.connect(_place_header)
	add_child(_top)
	_header = VBoxContainer.new()
	_header.add_theme_constant_override("separation", roundi(4 * s))
	_top.add_child(_header)
	var name := Label.new()
	name.text = Boot.NAME
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.add_theme_font_size_override("font_size", roundi(24 * s))
	_header.add_child(name)
	var sub := Label.new()
	sub.text = Boot.TAGLINE
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", roundi(12 * s))
	sub.modulate = Color(1, 1, 1, 0.55)
	_header.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, roundf(10 * s))
	_header.add_child(gap)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", roundi(8 * s))
	_header.add_child(row)
	search = LineEdit.new()
	search.placeholder_text = "Search notes"
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.custom_minimum_size = Vector2(0, roundf(38 * s))
	search.clear_button_enabled = true
	search.right_icon = Icons.texture("search", roundi(16 * s))
	search.add_theme_font_size_override("font_size", roundi(14 * s))
	for state in ["normal", "focus", "read_only"]:
		search.add_theme_stylebox_override(state, _pill(state == "focus"))
	search.text_changed.connect(func(_t: String) -> void: filter())
	search.text_submitted.connect(func(_t: String) -> void:
		var first := visible_paths()
		if not search.text.strip_edges().is_empty() and not first.is_empty():
			opened.emit(first[0]))
	search.gui_input.connect(func(e: InputEvent) -> void:
		var k := e as InputEventKey
		if k != null and k.pressed and k.keycode == KEY_ESCAPE and not search.text.is_empty():
			search.clear()
			filter()
			search.accept_event())
	row.add_child(search)
	actions = HBoxContainer.new()
	actions.add_theme_constant_override("separation", roundi(2 * s))
	row.add_child(actions)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# never shown and never needed (the tiles are laid out to fit), and unlike DISABLED it does not take the
	# tiles' width as the grid's least - the same trap as the header's
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(_scroll)
	var mid := CenterContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.use_top_left = false
	_scroll.add_child(mid)
	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", roundi(GAP * s))
	mid.add_child(_column)
	_empty = Label.new()
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty.add_theme_font_size_override("font_size", roundi(13 * s))
	_empty.modulate = Color(1, 1, 1, 0.55)
	_empty.visible = false
	_column.add_child(_empty)
	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", roundi(GAP * s))
	_grid.add_theme_constant_override("v_separation", roundi(GAP * s))
	_column.add_child(_grid)
	# room under the last row, so it scrolls clear of the bottom-right row of buttons
	var foot := Control.new()
	foot.custom_minimum_size = Vector2(0, Shell.ROW_TOP * s)
	_column.add_child(foot)


## Rebuild the tiles when the notes changed ([param force]: whether or not they did).
func refresh(force := false) -> void:
	var notes := NoteStore.list()
	var sig := JSON.stringify(notes)
	if sig == _seen and not force:
		return
	_seen = sig
	for t in _tiles:
		(t as Node).queue_free()
	_tiles.clear()
	var known := {}
	for n in notes:
		var p := String(n["path"])
		var m := int(n["mtime"])
		var was: Dictionary = _known.get(p, {})
		var summary: Dictionary = was["summary"] if int(was.get("mtime", -1)) == m else NoteStore.summary_of(p)
		known[p] = {"mtime": m, "summary": summary}
		var tile := NoteTile.new(p, summary, m, s, deletable)
		tile.set_meta("words", String(summary.get("words", "")))
		tile.opened.connect(func(q: String) -> void: opened.emit(q))
		tile.delete_asked.connect(func(q: String) -> void: delete_asked.emit(q))
		_grid.add_child(tile)
		_tiles.append(tile)
	_known = known
	_layout()
	filter()


## Show only the notes the search finds, and say so when none is left.
func filter() -> void:
	var terms := Array(search.text.to_lower().split(" ", false))
	var shown := 0
	for t in _tiles:
		var tile: NoteTile = t
		var words := String(tile.get_meta("words", ""))
		tile.visible = terms.all(func(w: String) -> bool: return words.contains(w))
		shown += 1 if tile.visible else 0
	if _tiles.is_empty():
		_empty.text = "No notes yet. The + above makes one."
	elif shown == 0:
		_empty.text = "No note says \"%s\"." % search.text.strip_edges()
	_empty.visible = shown == 0
	_grid.visible = shown > 0


## The notes the grid shows, in its order.
func visible_paths() -> Array:
	return _tiles.filter(func(t: NoteTile) -> bool: return t.visible).map(func(t: NoteTile) -> String: return t.path)


## The tile for [param path], or null.
func tile_of(path: String) -> NoteTile:
	for t in _tiles:
		if (t as NoteTile).path == path:
			return t
	return null


## AS MANY COLUMNS AS FIT, each tile as big as it may be: from [constant MOST_COLS] down, the first count
## whose tiles are at least [constant TILE_LEAST], never under [constant LEAST_COLS] (narrower than that, the
## tiles shrink instead).
func _layout() -> void:
	if size.x <= 0.0:
		return
	var gap := GAP * s
	var room := size.x - 2.0 * MARGIN * s
	var cols := MOST_COLS
	while cols > LEAST_COLS and cols * TILE_LEAST * s + (cols - 1) * gap > room:
		cols -= 1
	var px := maxf(floorf(minf(TILE * s, (room - (cols - 1) * gap) / cols)), 40.0)
	columns = cols
	side = px
	_grid.columns = cols
	for t in _tiles:
		(t as NoteTile).set_side(px)
	var w := cols * px + (cols - 1) * gap
	_header.custom_minimum_size = Vector2(w, 0)
	_empty.custom_minimum_size = Vector2(w, 0)
	_place_header()


## The header centered over the tiles, as wide as they are; its row as tall as it is.
func _place_header() -> void:
	var h := _header.get_combined_minimum_size()
	_top.custom_minimum_size = Vector2(0, h.y)
	_header.size = h
	_header.position = Vector2(floorf((_top.size.x - h.x) / 2.0), 0)


func _pill(focused: bool) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = Color(1, 1, 1, 0.07 if focused else 0.05)
	b.border_color = Color(1, 1, 1, 0.28 if focused else 0.1)
	b.set_border_width_all(1)
	b.set_corner_radius_all(roundi(8 * s))
	b.content_margin_left = roundf(14 * s)
	b.content_margin_right = roundf(10 * s)
	b.content_margin_top = roundf(6 * s)
	b.content_margin_bottom = roundf(6 * s)
	return b
