extends Node

## note_grid_check - the notes as a notes app shows them ([NoteGrid], [NoteTile]), on a notes folder of the gate's own
## (`NoteStore.root`) and with the author's added sources set aside in memory, so only the gate's notes are listed.
##
##   tests/run_boot_probe.sh tests/ui/note_grid_check.gd 120
##
## - Squares of one size, 2-3 columns, centered: on a desktop's 1920 three columns of tile squares and the
##   header as wide as they are; control: a 600-wide grid gives up a column; a phone's grid (1080
##   wide at the phone's scale) stands in two, with no x on its tiles.
## - What a tile bears: its note's title; its words with the frontmatter and every mark left out (control:
##   the file itself has both), and a first heading that only says the title again (control: one that says
##   something else stays); a chip for each component and none for the words; the notes in the list's
##   order, newest first.
## - The color is the note's own: it keeps it as components come and go; notes made of the same
##   things are many colors, two of one name in two folders among them (control: one note's path, many times, is one color);
##   a note of words alone is the paper's gray.
## - The search: a word of the title, of the words, a component's name or its Medium's format finds its notes; two words find only
##   the notes with both; a word no note has leaves none and says so; Escape brings every note back; Enter
##   opens the first note left. A tap opens a note and a drag does not (control: the same press, released
##   40 px away). The x asks to delete. A note made after the grid is up appears at its next look.

const ROOT := "user://note_grid_check"
var _fails: Array = []
var _opened: Array = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_clean()
	var keep_root := NoteStore.root
	var keep_sources := Array(NoteStore.sources())
	NoteStore.root = ROOT
	Settings.write(NoteStore.SECTION, "sources", [])
	var notes := _make_notes()
	await _check_layout()
	await _check_tiles(notes)
	_check_colors()
	await _check_search(notes)
	await _check_taps(notes)
	_check_icons()
	Settings.write(NoteStore.SECTION, "sources", keep_sources)
	NoteStore.root = keep_root
	_clean()
	if _fails.is_empty():
		print("note_grid_check: ALL OK")
		get_tree().quit(0)
		return
	print("note_grid_check: %d FAILURE(S)" % _fails.size())
	for f in _fails:
		print("   ", f)
	get_tree().quit(1)


func _make_notes() -> Dictionary:
	return {
		"plain": NoteStore.create("Groceries", "Milk, eggs, and the good bread.\n"),
		"letter": NoteStore.create("Dear Pen", "# To Pen\n\n<!-- sketch: a tree of dots -->I write to you **tonight** from the porch.\n",
			{"medium": {"format": "letter"}, "voice": {}, "youtube": {}}),
		"table": NoteStore.create("The Quiet Crucible", "# The Quiet Crucible\n\nGrind the salts, then read the cards.\n",
			{"table": {}, "voice": {}}),
		"actor": NoteStore.create("Primes Go On", "Show there is no largest prime.\n", {"actor": {}, "voice": {}}),
	}


func _grid(width: float, s := 1.0, deletable := true) -> NoteGrid:
	var g := NoteGrid.new(s, deletable)
	add_child(g)
	g.position = Vector2.ZERO
	g.size = Vector2(width, 1080.0 if s == 1.0 else 1920.0)
	await _frames(4)
	return g


func _check_layout() -> void:
	print("-- squares of one size, 2-3 columns, centered")
	var g := await _grid(1920.0)
	_ok(g.columns == 3 and is_equal_approx(g.side, NoteGrid.TILE), "a desktop's grid: three columns of %d squares (%d of %.0f)" % [NoteGrid.TILE, g.columns, g.side])
	var sizes := {}
	for t in g._tiles:
		var tile: NoteTile = t
		sizes[str(tile.size.round())] = true
	_ok(sizes.size() == 1 and g._tiles.size() == 4 and absf((g._tiles[0] as NoteTile).size.x - (g._tiles[0] as NoteTile).size.y) < 0.5,
		"every tile is the same square (%s)" % str(sizes.keys()))
	var w := 3.0 * g.side + 2.0 * NoteGrid.GAP
	_ok(absf(g._header.size.x - w) < 1.0, "the search is as wide as the notes (%.0f, %.0f)" % [g._header.size.x, w])
	var r := g._grid.get_global_rect()
	_ok(absf(r.position.x - (1920.0 - r.end.x)) < 2.0 and r.position.x > 400.0, "the notes stand centered, with wide margins (%.0f left)" % r.position.x)
	g.size = Vector2(600.0, 1080.0)
	await _frames(3)
	_ok(g.columns == 2, "THE CONTROL: a narrow grid gives up a column (%d)" % g.columns)
	g.queue_free()
	var phone := await _grid(1032.0, PhoneShell.SCALE, false)
	_ok(phone.columns == 2 and phone.side > 400.0, "a phone's grid: two columns (%d of %.0f)" % [phone.columns, phone.side])
	_ok((phone._tiles[0] as NoteTile)._x == null, "...and no × on a phone's tile")
	phone.queue_free()
	await _frames(1)


func _check_tiles(notes: Dictionary) -> void:
	print("-- what a tile bears")
	var g := await _grid(1920.0)
	_ok(g.visible_paths() == NoteStore.list().map(func(n: Dictionary) -> String: return String(n["path"])),
		"the tiles stand in the list's order, newest first")
	var letter := g.tile_of(notes["letter"])
	var raw := FileAccess.get_file_as_string(notes["letter"])
	_ok(raw.contains("<!--") and raw.contains("ghost:"), "(the letter's file has frontmatter and a mark)")
	_ok(letter != null and letter._title.text == "Dear Pen", "a tile bears its note's title")
	var words := letter._words.text if letter != null else ""
	_ok(words == "To Pen\nI write to you tonight from the porch.",
		"its words without the frontmatter, the marks or markdown's markers (%s)" % JSON.stringify(words))
	var table := g.tile_of(notes["table"])
	_ok(table != null and table._words.text == "Grind the salts, then read the cards.",
		"a heading that only says the title again is left out (%s)" % JSON.stringify(table._words.text if table != null else ""))
	_ok(words.begins_with("To Pen"), "THE CONTROL: a heading that says something else stays")
	var chips := letter._chips.get_children().map(func(c: Node) -> String: return (c as Label).text) if letter != null else []
	_ok(chips == ["Voice", "Medium", "YouTube"], "a chip for each component, in the order their cards stand (%s)" % str(chips))
	var plain := g.tile_of(notes["plain"])
	_ok(plain != null and plain._chips.get_child_count() == 0, "a note of words alone has no chips")
	_ok(plain != null and plain.color == Card.PAPER and letter.color != Card.PAPER, "...and is the paper's gray, where the letter is not")
	g.queue_free()
	await _frames(1)


func _check_colors() -> void:
	print("-- the color is the note's own")
	var letter := NoteTile.color_of("notes/dear-friend.md", ["text", "medium", "voice"])
	_ok(letter == NoteTile.color_of("notes/dear-friend.md", ["text", "table", "voice", "medium", "youtube"]),
		"a note keeps its color as components come and go")
	_ok(letter != NoteTile.color_of("elsewhere/books/dear-friend.md", ["text", "medium", "voice"]),
		"two notes of one name in two folders are two colors")
	var same := ["text", "table", "voice", "medium"]
	var names := ["algebra", "binary", "circles", "dice", "euler", "fractions", "graphs", "halving", "induction", "jumps",
		"knots", "limits"]
	var hues := {}
	var widest := 0.0
	for a in names:
		var ca := NoteTile.color_of("notes/%s.md" % a, same)
		hues[snappedf(ca.h, 0.01)] = true
		for b in names:
			widest = maxf(widest, _hue_apart(ca, NoteTile.color_of("notes/%s.md" % b, same)))
	_ok(hues.size() >= 10 and widest > 120.0,
		"twelve notes made of the same things are many colors (%d hues, %.0f degrees apart at most)" % [hues.size(), widest])
	var one := {}
	for _i in names.size():
		one[snappedf(NoteTile.color_of("notes/algebra.md", same).h, 0.01)] = true
	_ok(one.size() == 1, "THE CONTROL: one note's path twelve times is one color")
	_ok(NoteTile.color_of("notes/plain.md", ["text"]) == Card.PAPER and NoteTile.color_of("notes/plain.md", []) == Card.PAPER,
		"a note of words alone is the paper's gray")


func _check_search(notes: Dictionary) -> void:
	print("-- the search")
	var g := await _grid(1920.0)
	var cases := [["dear", [notes["letter"]], "a word of the title"], ["porch", [notes["letter"]], "a word of its words"],
		["actor", [notes["actor"]], "a component's name"], ["letter", [notes["letter"]], "the format its Medium names"], ["voice", [notes["letter"], notes["table"], notes["actor"]], "a component every reading has"],
		["voice cards", [notes["table"]], "two words: only the notes with both"]]
	for c in cases:
		g.search.text = String(c[0])
		g.search.text_changed.emit(g.search.text)
		var got := g.visible_paths()
		got.sort()
		var want: Array = (c[1] as Array).duplicate()
		want.sort()
		_ok(got == want, "\"%s\" - %s - finds %d (%d)" % [c[0], c[2], want.size(), got.size()])
	g.search.text = "zeppelin"
	g.search.text_changed.emit(g.search.text)
	_ok(g.visible_paths().is_empty() and g._empty.visible and g._empty.text.contains("zeppelin"), "a word no note has leaves none, and says so")
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	g.search.gui_input.emit(esc)
	_ok(g.search.text.is_empty() and g.visible_paths().size() == 4 and not g._empty.visible, "Escape brings every note back")
	_opened.clear()
	g.opened.connect(func(p: String) -> void: _opened.append(p))
	g.search.text = "primes"
	g.search.text_changed.emit(g.search.text)
	g.search.text_submitted.emit(g.search.text)
	_ok(_opened == [notes["actor"]], "Enter opens the first note left")
	g.queue_free()
	await _frames(1)


func _check_taps(notes: Dictionary) -> void:
	print("-- a tap opens, a drag does not; the ×; a new note appears")
	var g := await _grid(1920.0)
	_opened.clear()
	var asked: Array = []
	g.opened.connect(func(p: String) -> void: _opened.append(p))
	g.delete_asked.connect(func(p: String) -> void: asked.append(p))
	var tile := g.tile_of(notes["table"])
	tile._gui_input(_press(Vector2(60, 120), true))
	tile._gui_input(_press(Vector2(100, 120), false))
	_ok(_opened.is_empty(), "THE CONTROL: a press released 40 px away is a drag, and opens nothing")
	tile._gui_input(_press(Vector2(60, 120), true))
	tile._gui_input(_press(Vector2(62, 121), false))
	_ok(_opened == [notes["table"]], "a press released in place opens the note")
	tile._x.pressed.emit()
	_ok(asked == [notes["table"]], "the × asks to delete its note")
	var later := NoteStore.create("Made Later", "Words.\n")
	g._poll_t = 0.0
	await _frames(2)
	_ok(g.visible_paths().has(later), "a note made after the grid is up appears at its next look")
	g.queue_free()
	await _frames(1)


func _check_icons() -> void:
	print("-- icons")
	var a := Icons.texture("new", 24)
	var b := Icons.texture("existing", 43)
	_ok(a != null and a.get_size() == Vector2(24, 24) and b != null and b.get_size() == Vector2(43, 43), "an icon is drawn at the size asked")
	_ok(Icons.texture("no such icon", 24) == null, "a key with no row has no icon")
	var btn := Icons.button("new", 24, "New note")
	_ok(btn.text.is_empty() and btn.icon == a and btn.tooltip_text == "New note", "an icon button wears no words, its tooltip saying what it does")
	btn.free()


func _press(at: Vector2, down: bool) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = at
	return e


func _hue_apart(a: Color, b: Color) -> float:
	var d := absf(a.h - b.h) * 360.0
	return minf(d, 360.0 - d)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _clean() -> void:
	var abs := ProjectSettings.globalize_path(ROOT)
	if DirAccess.dir_exists_absolute(abs):
		for f in DirAccess.get_files_at(abs):
			DirAccess.remove_absolute(abs.path_join(f))
		DirAccess.remove_absolute(abs)


func _ok(cond: bool, msg: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + msg)
	if not cond:
		_fails.append(msg)
