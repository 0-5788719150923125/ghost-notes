extends Node

## note_grid_check - the notes as a notes app shows them ([NoteGrid], [NoteTile]; 2026-10-31), on a notes
## folder of the gate's own (`NoteStore.root`) and with the author's added sources set aside in memory (a
## probe never writes Settings), so only the gate's notes are listed.
##
##   tests/run_boot_probe.sh tests/ui/note_grid_check.gd 120
##
## SQUARES OF ONE SIZE, 2-3 COLUMNS, CENTERED: on a desktop's 1920 three columns of TILE squares and the
## header as wide as they are; THE CONTROL, a 600-wide grid, gives up a column; and a phone's grid (1080
## wide at the phone's scale) stands in two, with no × on its tiles.
##
## WHAT A TILE BEARS: its note's title; its words with the frontmatter and every mark left out (the control:
## the file itself has both), and a first heading that only says the title again (the control: one that says
## something else stays); a chip for each component and none for the words; the notes in the list's
## order, newest first.
##
## THE COLOR IS THE COMPONENTS': the same components make the same color whatever order they are named in;
## a Table and a Proof are near (the producers' violet) and still apart; a Letter is far from both; what
## shows the note counts most (a Letter read by a Voice is nearer the Letter's own hue than the Voice's); and
## a note of words alone is the paper's gray.
##
## THE SEARCH: a word of the title, of the words, or a component's name finds its notes; two words find only
## the notes with both; a word no note has leaves none and says so; Escape brings every note back; Enter
## opens the first note left. A TAP OPENS A NOTE AND A DRAG DOES NOT (the control: the same press, released
## 40 px away). The × asks to delete. A note made after the grid is up appears at its next look.

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
			{"letter": {}, "voice": {}, "youtube": {}}),
		"table": NoteStore.create("The Quiet Crucible", "# The Quiet Crucible\n\nGrind the salts, then read the cards.\n",
			{"table": {}, "voice": {}}),
		"proof": NoteStore.create("Primes Go On", "Show there is no largest prime.\n", {"proof": {}, "voice": {}}),
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
	_ok(chips == ["Voice", "Letter", "YouTube"], "a chip for each component, in the order their cards stand (%s)" % str(chips))
	var plain := g.tile_of(notes["plain"])
	_ok(plain != null and plain._chips.get_child_count() == 0, "a note of words alone has no chips")
	_ok(plain != null and plain.color == Card.PAPER and letter.color != Card.PAPER, "...and is the paper's gray, where the letter is not")
	g.queue_free()
	await _frames(1)


func _check_colors() -> void:
	print("-- the color is the components'")
	var letter := NoteTile.color_of(["text", "letter", "voice", "youtube"])
	_ok(letter == NoteTile.color_of(["youtube", "voice", "text", "letter"]), "the same components make the same color, in any order")
	var table := NoteTile.color_of(["text", "table", "voice"])
	var proof := NoteTile.color_of(["text", "proof", "voice"])
	var d_tp := _hue_apart(table, proof)
	_ok(d_tp > 8.0 and d_tp < 60.0, "a Table and a Proof are near and still apart (%.0f degrees)" % d_tp)
	_ok(_hue_apart(table, letter) > 90.0 and _hue_apart(proof, letter) > 90.0,
		"a Letter is far from both (%.0f, %.0f)" % [_hue_apart(table, letter), _hue_apart(proof, letter)])
	var own := Color.from_hsv(NoteTile.hue_of("letter") / 360.0, Card.SAT, Card.VAL)
	var voice := Color.from_hsv(NoteTile.hue_of("voice") / 360.0, Card.SAT, Card.VAL)
	_ok(_hue_apart(letter, own) < _hue_apart(letter, voice) / 3.0,
		"what shows the note counts most: a read letter is near the Letter's hue (%.0f), far from the Voice's (%.0f)" % [_hue_apart(letter, own), _hue_apart(letter, voice)])
	_ok(NoteTile.color_of(["text"]) == Card.PAPER and NoteTile.color_of([]) == Card.PAPER, "a note of words alone is the paper's gray")


func _check_search(notes: Dictionary) -> void:
	print("-- the search")
	var g := await _grid(1920.0)
	var cases := [["dear", [notes["letter"]], "a word of the title"], ["porch", [notes["letter"]], "a word of its words"],
		["proof", [notes["proof"]], "a component's name"], ["voice", [notes["letter"], notes["table"], notes["proof"]], "a component every reading has"],
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
	_ok(_opened == [notes["proof"]], "Enter opens the first note left")
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
