extends VBoxContainer
class_name ScriptWriter

## ScriptWriter - where a voice panel's script is written: a card in the panel, and an editor
## window it opens.
##
## THE TEXT BOX OUTGREW THE PANEL. A script carries speaker cues, hesitations, picture
## markers, pronunciations, macros and emphasis, and a 380-pixel box with a tooltip was the
## only place any of that was written down - so an author who had not read the source had no
## way to find out what ghost understands. The panel now holds a CARD (where the words come
## from, how many there are, how many voices and pictures they ask for) and the writing
## happens in a centered window: the text on the left, highlighted by what the panel will make
## of it ([ScriptHighlighter]), and on the right a palette of every mark this panel honors
## ([ScriptMarks]), each one a click away from being inserted at the caret.
##
## THE FRONTMATTER IS NOT IN THE EDITOR. It is metadata the panel owns - the voice, the look -
## and every field in it is a control on the panel already, so the editor shows the body and
## [DocSource] keeps the frontmatter on disk exactly as it was, ghost's block written by the
## panel and everything else untouched.
##
## The window's [CodeEdit] IS the panel's text box: the panel reads `text_edit.text` and
## listens to its `text_changed` exactly as it did the old one, and [member doc] drives it.
##
## WHERE IT IS SAVED IS ON THE CARD (2026-10-12): the file's name, a [SaveMark] that turns while a
## change waits and ticks when it is in the file, and Save…, which always asks for a file. It was
## "Sync to…" inside the editor window, where a note's script could be sent to a file the note
## itself never followed (see [DocSource]). OPEN… IS THE OTHER DIRECTION, and a note has it too
## (the user, the same day: "I need to load a file from disk, and there's no way to do that
## currently. The 'Save' button would just overwrite the file on disk"): Save… puts what is here
## into a file, Open… takes what is in a file and writes nothing.

## The document's own metadata - top-level frontmatter keys, not ghost's block - edited on the
## card, never in the editor. Each is read by something: the label, its tooltip, the panels
## that use it. A row stands in its `modes`, and in any other once what reads it shows it ([method
## show_field]: a YouTube card shows Title and Episode, the names its title is made of).
##
## THE NOTE'S NAMES ARE HERE (2026-10-25, the user: "the YouTube card specifies an upload title of
## '%title%: %episode%' - however nowhere is an episode title actually an option here"): Title and
## EPISODE, what this video is called. A note read as it is written keeps its own (`episode:`); a show
## that names its episodes hands the row its picked one's ([method hand_field]: Cards' plan, Proof's
## problem), so its Episode is edited here too, never on a card of its own.
const FIELDS := {
	"title": {"label": "Title", "modes": ["generative", "table", "proof", "note"],
		"tip": "The chapter's title. Read aloud first, by the voice that opens the chapter, and set at the head of the chapter in the Novel and Notebook. For a card show or a Proof note, the channel's name: on the title screen while the intro holds. The %title% of the YouTube title."},
	"byline": {"label": "Byline", "modes": ["table", "proof"],
		"tip": "A line under the channel's name on the title screen while the intro holds - \"with Pen & Ink\". Empty, the name stands alone."},
	"episode": {"label": "Episode", "modes": ["table", "proof"],
		"wait": "named with the episode",
		"tip": "What this video is called: the %episode% of the YouTube title. A card show's or a Proof note's is the picked episode's - its writer names it as it plans the episode, an edit here is written into the episode, and it names the export; an episode needs one. A note read as it is written names its own here."},
	"author": {"label": "Author", "modes": ["generative"],
		"tip": "Who wrote it. Printed on the cover in the Novel and Notebook."},
	"book": {"label": "Book", "modes": ["generative"],
		"tip": "The book this chapter belongs to. Printed on the cover in the Novel and Notebook."},
}

## WHAT THE DOCUMENT IS CALLED, where it is not a script: a card show's body is the BRIEF its
## agents work from - written by hand, never read aloud. Its marks are its own ([ScriptMarks],
## "table"): what each does in a brief is the registry's `blurbs`.
const WORDING := {
	"table": {"window": "Brief",
		"edit_tip": "Open the show's brief in an editor, with every mark a brief understands listed beside it - the deck, other voices, notes to yourself - ready to insert at the cursor. The brief is what the show is, who reads it and by what rules, and every agent behind every episode is handed it.",
		"placeholder": "What is this show? Who reads it, how, and by what rules?",
		"speakers": "Voices in this brief"},
	# A PROOF NOTE'S BODY IS ITS PROBLEM: what the agents work, written by hand or by "Invent a
	# problem" - never read aloud (the voice reads the episode's lesson)
	"proof": {"window": "Problem",
		"edit_tip": "Open the problem in an editor. It is what every agent behind an episode works from: the problem in words, its precise statement, and anything you want stressed. Never read aloud - the voice reads the episode's lesson.",
		"placeholder": "What problem should the episode work? Write it, or press Invent a problem.",
		"speakers": "Voices"},
}

## How long typing must pause before the card's summary is recounted.
const SUMMARY_MS := 0.4

## Where the words come from (the file they are saved in, or none), built into the window's top bar.
var doc: DocSource
## The editor. The owning panel treats this as its text box.
var text_edit: CodeEdit

var _mode := "generative"
var _window: Window
var _name: Label
var _summary: Label
var _note: Label
var _help: Label
var _speakers: HFlowContainer
var _speakers_head: Label
var _timer: Timer
var _speaker_names := PackedStringArray()
var _field_edits := {}          # key -> LineEdit
var _field_rows := {}           # key -> [Label, LineEdit]: a row hidden outside its modes until shown
var _fields_grid: GridContainer
## Fields another part keeps, not the document: key -> {read: Callable, write: Callable} ([method hand_field]).
var _handed := {}
var _handed_t := 0.0
var _open_btn: Button
var _clear_btn: Button
var _save_btn: Button
var _in_note := false
## The card's own save mark (the editor window has another, on the same source).
var save_mark: SaveMark
var _mark_slot: Control


func _wording(key: String, dflt: String) -> String:
	return String((WORDING.get(_mode, {}) as Dictionary).get(key, dflt))


## Build the card, the window and the [DocSource] inside it. [param section] and [param blocks]
## are DocSource's (the Settings section, the blocks under `ghost:` its panel owns); [param mode] picks which
## marks the palette offers and the highlighter colors ("generative", "synthesis").
func setup(section: String, blocks: PackedStringArray, mode: String) -> void:
	_mode = mode
	add_theme_constant_override("separation", 4)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	add_child(row)
	_name = Label.new()
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name.add_theme_font_size_override("font_size", 14)
	row.add_child(_name)
	# the mark needs the source, which the window builds: its place is kept here
	_mark_slot = Control.new()
	_mark_slot.custom_minimum_size = Vector2(SaveMark.SIZE, SaveMark.SIZE)
	_mark_slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_mark_slot)
	var save := Button.new()
	_save_btn = save
	save.text = "Save…"
	save.pressed.connect(func() -> void: doc.save_dialog())
	row.add_child(save)
	var open := Button.new()
	_open_btn = open
	open.text = "Open…"
	open.pressed.connect(func() -> void:
		if _in_note:
			doc.ask_open(open_as_note)
		else:
			doc.open())
	row.add_child(open)
	row.move_child(open, save.get_index())      # Open…, then Save…: the order every editor has
	var clear := Button.new()
	_clear_btn = clear
	clear.text = "Clear"
	clear.pressed.connect(func() -> void: doc.clear())
	row.add_child(clear)
	var edit := Button.new()
	# "EDIT", WHATEVER THE TEXT IS (2026-10-06, the user: "I feel like this button should be renamed to
	# just 'Edit' globally"): a note's words, a chapter or a show's brief - the tooltip says which.
	edit.text = "Edit"
	edit.tooltip_text = String(_wording("edit_tip", "Open the text in an editor, with every mark "
		+ "this panel understands listed beside it - speakers, hesitations, pictures, "
		+ "pronunciations - ready to insert at the cursor."))
	edit.pressed.connect(open_editor)
	row.add_child(edit)
	_summary = Label.new()
	_summary.add_theme_font_size_override("font_size", 12)
	_summary.modulate = Color(1, 1, 1, 0.65)
	add_child(_summary)
	_build_fields()
	_note = Label.new()
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.add_theme_font_size_override("font_size", 11)
	_note.modulate = Color(1, 1, 1, 0.65)
	_note.visible = false
	add_child(_note)

	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = SUMMARY_MS
	_timer.timeout.connect(_refresh)
	add_child(_timer)

	_build_window(section, blocks)
	open.tooltip_text = DocSource.OPEN_TIP
	clear.tooltip_text = DocSource.CLEAR_TIP
	save.tooltip_text = DocSource.SAVE_TIP
	save_mark = preload("res://src/notes/save_mark.gd").new(doc)
	_mark_slot.add_child(save_mark)
	doc.dialog_host = self
	doc.noted.connect(func(msg: String) -> void:
		_note.text = msg
		_note.visible = not msg.is_empty())
	doc.mode_changed.connect(func(_sync: bool) -> void: _refresh())
	doc.opened.connect(func(_path: String) -> void: _refresh())
	text_edit.text_changed.connect(_recount_soon)
	text_edit.text_set.connect(_recount_soon)
	_refresh()


## THE CARD IS A NOTE'S (2026-10-06): the note IS the file, so Clear (let go of this one) is not
## offered. A panel started without a note (`--table`, `--synth`) keeps it. Save… moves the note to
## the file chosen ([signal DocSource.moved]); Open… (hidden here until 2026-10-12, which left no way
## to load a file from inside a note) opens the file chosen AS THE NOTE ([method open_as_note]).
func bind_note() -> void:
	_in_note = true
	_clear_btn.visible = false
	_open_btn.tooltip_text = DocSource.OPEN_NOTE_TIP
	_save_btn.tooltip_text = DocSource.SAVE_NOTE_TIP


## A NOTE'S OPEN…: [param path] becomes the note in this window, through the one way every note
## opens ([method main.open_file], reached through [Chrome]) - so what it is follows from its own
## blocks, and a file with none is a plain note. Nothing is written into it. What is waiting here
## is written into this note's own file first, which stays in the list; the file already open is
## simply read again.
func open_as_note(path: String) -> void:
	if not doc.settle():
		return
	if path.simplify_path() == doc.doc_path().simplify_path():
		if doc.reload():
			doc.tell("Read %s again." % path.get_file())
		return
	var ch := Shell.of(self)
	var why := ch.open_file(path) if ch != null else "Nothing here can open another note."
	if not why.is_empty():
		doc.tell("⚠  " + why)


## The FIELDS, as a two-column form under the summary: those of this panel's mode shown, the rest
## until something shows them ([method show_field]). An edit is committed on Enter or on leaving the box
## (not per keystroke - saved in a file, each commit is a write to it), and the box then shows what the
## source holds, so a refused write is visible as a revert.
func _build_fields() -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 2)
	add_child(grid)
	_fields_grid = grid
	grid.visible = false
	for k in FIELDS:
		var f: Dictionary = FIELDS[k]
		var l := Label.new()
		l.text = String(f["label"])
		l.add_theme_font_size_override("font_size", 12)
		l.tooltip_text = String(f["tip"])
		l.mouse_filter = Control.MOUSE_FILTER_STOP
		grid.add_child(l)
		var e := LineEdit.new()
		e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		e.add_theme_font_size_override("font_size", 12)
		e.tooltip_text = String(f["tip"])
		e.placeholder_text = "none"
		var key := String(k)
		e.text_submitted.connect(func(_t: String) -> void:
			_commit_field(key)
			e.release_focus())
		e.focus_exited.connect(_commit_field.bind(key))
		grid.add_child(e)
		_field_edits[key] = e
		_field_rows[key] = [l, e]
		l.visible = (f["modes"] as Array).has(_mode)
		e.visible = l.visible
		grid.visible = grid.visible or l.visible


## THE FIELD [param key] IS SHOWN from now on, whatever the mode: something reads it (a YouTube card, the
## Title and Episode its title is made of).
func show_field(key: String) -> void:
	for c in _field_rows.get(key, []):
		(c as Control).visible = true
	_fields_grid.visible = _fields_grid.visible or _field_rows.has(key)


## Is the field [param key] shown?
func shows_field(key: String) -> bool:
	return _field_rows.has(key) and ((_field_rows[key] as Array)[1] as Control).visible


## A FIELD ANOTHER PART KEEPS, not the document - a show's Episode is its picked episode's: the box shows
## what [param read] returns (a String; null while there is nothing to name - the box empty, not
## editable, saying what it waits for), an edit goes to [param write] (the text; it returns "" once
## written, else why not, said on the card), and the row is shown. Looked at again twice a second: what
## it keeps changes with no word to this card (another episode picked, its plan written).
func hand_field(key: String, read: Callable, write: Callable) -> void:
	_handed[key] = {"read": read, "write": write}
	show_field(key)
	_refresh_handed()


## WHAT THE FIELD [param key] HOLDS NOW: the part's that keeps it ([method hand_field]), else the
## document's line; "" for none.
func field_value(key: String) -> String:
	if _kept(key):
		var v: Variant = (_handed[key]["read"] as Callable).call()
		return str(v).strip_edges() if v != null else ""
	return doc.field(key).strip_edges() if doc != null else ""


## THE NOTE'S NAME: its Title, else the name of the file it is kept in (as the notes list names it); ""
## for words kept in no file.
func title_or_name() -> String:
	var t := field_value("title")
	if t.is_empty() and doc != null and doc.is_sync():
		t = doc.doc_path().get_file().get_basename()
	return t


func _commit_field(key: String) -> void:
	var e: LineEdit = _field_edits[key]
	if _kept(key):
		var read: Variant = (_handed[key]["read"] as Callable).call()
		if read != null and e.text.strip_edges() != str(read).strip_edges():
			var why := str((_handed[key]["write"] as Callable).call(e.text))
			if not why.is_empty():
				doc.tell("⚠  " + why)
		var now: Variant = (_handed[key]["read"] as Callable).call()
		e.text = str(now) if now != null else ""
		return
	doc.set_field(key, e.text)
	e.text = doc.field(key)


## WHETHER A PART STILL KEEPS THE FIELD [param key]: one freed before this card (a panel taken down, its
## card's lambdas bound to it) keeps it no more, and the field is the document's again.
func _kept(key: String) -> bool:
	if not _handed.has(key):
		return false
	if (_handed[key]["read"] as Callable).is_valid() and (_handed[key]["write"] as Callable).is_valid():
		return true
	_handed.erase(key)
	return false


## The handed fields' boxes from what keeps them, unless one is being typed in.
func _refresh_handed() -> void:
	for k in _handed.keys():
		var e: LineEdit = _field_edits.get(k)
		if not _kept(k) or e == null or e.has_focus():
			continue
		var v: Variant = (_handed[k]["read"] as Callable).call()
		e.editable = v != null
		e.placeholder_text = "none" if v != null else String((FIELDS[k] as Dictionary).get("wait", "none"))
		var t := str(v) if v != null else ""
		if e.text != t:
			e.text = t


func _process(dt: float) -> void:
	if _handed.is_empty():
		return
	_handed_t -= dt
	if _handed_t > 0.0:
		return
	_handed_t = 0.5
	_refresh_handed()


func _recount_soon() -> void:
	if _timer.is_inside_tree():
		_timer.start()
	else:
		_refresh()


## Show the editor, centered and sized to the window it opens over.
func open_editor() -> void:
	_refresh()
	var host := get_tree().root.get_visible_rect().size if is_inside_tree() \
		else Vector2(1600, 900)
	var want := Vector2i(int(host.x * 0.82), int(host.y * 0.82))
	want = want.max(_window.min_size)
	# THE SIZE IS SET AGAIN AFTER THE POPUP: measured, popup() and popup_centered() both
	# came back 1280 wide whatever was asked for (1574 on a 1080p window), which also left
	# popup_centered's window left of center.
	_window.popup(Rect2i((Vector2i(host) - want) / 2, want))
	_window.size = want
	text_edit.grab_focus()


func _build_window(section: String, blocks: PackedStringArray) -> void:
	_window = Window.new()
	_window.title = _wording("window", "Script")
	_window.visible = false
	_window.transient = true
	_window.min_size = Vector2i(760, 440)
	_window.close_requested.connect(_window.hide)
	_window.window_input.connect(func(e: InputEvent) -> void:
		if e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE:
			_window.hide())
	add_child(_window)

	var bg := PanelContainer.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_window.add_child(bg)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	bg.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	margin.add_child(col)

	doc = preload("res://src/notes/doc_source.gd").new()
	doc.setup(section, blocks)
	col.add_child(doc)

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(split)

	text_edit = CodeEdit.new()
	text_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_edit.custom_minimum_size = Vector2(420, 240)
	text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	text_edit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_edit.placeholder_text = String(_wording("placeholder", "Once upon a time..."))
	text_edit.highlight_current_line = true
	text_edit.caret_blink = true
	# Prose, not code: nothing may type a character the author did not.
	text_edit.auto_brace_completion_enabled = false
	text_edit.indent_automatic = false
	text_edit.code_completion_enabled = false
	text_edit.gutters_draw_line_numbers = false
	text_edit.add_theme_font_size_override("font_size", 16)
	text_edit.add_theme_constant_override("line_spacing", 6)
	text_edit.syntax_highlighter = ScriptHighlighter.new(_mode)
	split.add_child(text_edit)
	split.add_child(_build_palette())

	var foot := HBoxContainer.new()
	col.add_child(foot)
	var hint := Label.new()
	hint.text = ("Frontmatter is not shown here: the panel's settings are written into it on "
		+ "their own. The file takes your edits a moment after you stop typing - the mark "
		+ "beside its name turns while one waits and ticks when it is in.")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.add_theme_font_size_override("font_size", 11)
	hint.modulate = Color(1, 1, 1, 0.55)
	foot.add_child(hint)
	var close := Button.new()
	close.text = "Done"
	close.pressed.connect(_window.hide)
	foot.add_child(close)


## THE PALETTE: one button per mark this panel honors, grouped and colored as the
## highlighter colors them, with what each does shown below when it is pointed at.
func _build_palette() -> Control:
	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(270, 0)
	side.add_theme_constant_override("separation", 6)
	var head := Label.new()
	head.text = "Insert"
	head.add_theme_font_size_override("font_size", 16)
	side.add_child(head)
	var intro := Label.new()
	intro.text = "Click to insert at the cursor. A selection becomes the mark's text."
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_theme_font_size_override("font_size", 11)
	intro.modulate = Color(1, 1, 1, 0.6)
	side.add_child(intro)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 2)
	scroll.add_child(box)

	var keys := ScriptMarks.for_mode(_mode)
	for g in ScriptMarks.GROUPS:
		var color: Color = ScriptMarks.GROUPS[g]["color"]
		var mine: Array = []
		for k in keys:
			if String(ScriptMarks.REGISTRY[k]["group"]) == g:
				mine.append(k)
		if mine.is_empty():
			continue
		var gl := Label.new()
		gl.text = String(ScriptMarks.GROUPS[g]["label"])
		gl.add_theme_font_size_override("font_size", 12)
		gl.add_theme_color_override("font_color", color)
		if box.get_child_count() > 0:
			box.add_child(_gap(6))
		box.add_child(gl)
		for k in mine:
			box.add_child(_mark_button(String(k), color))
		if g == "voices":
			_speakers_head = Label.new()
			_speakers_head.text = _wording("speakers", "Speakers in this script")
			_speakers_head.add_theme_font_size_override("font_size", 11)
			_speakers_head.modulate = Color(1, 1, 1, 0.6)
			box.add_child(_speakers_head)
			_speakers = HFlowContainer.new()
			box.add_child(_speakers)

	_help = Label.new()
	_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_help.custom_minimum_size = Vector2(0, 110)
	_help.add_theme_font_size_override("font_size", 12)
	_help.text = "Point at a mark to see what it does."
	_help.modulate = Color(1, 1, 1, 0.8)
	side.add_child(HSeparator.new())
	side.add_child(_help)
	return side


func _mark_button(key: String, color: Color) -> Button:
	var e: Dictionary = ScriptMarks.REGISTRY[key]
	var b := Button.new()
	b.text = String(e["label"])
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.flat = true
	b.add_theme_color_override("font_color", color)
	b.tooltip_text = "%s\n\n%s" % [ScriptMarks.example(key), ScriptMarks.blurb(key, _mode)]
	b.pressed.connect(func() -> void:
		ScriptMarks.insert(text_edit, key)
		text_edit.grab_focus())
	b.mouse_entered.connect(_explain.bind(key))
	b.focus_entered.connect(_explain.bind(key))
	return b


func _explain(key: String) -> void:
	var e: Dictionary = ScriptMarks.REGISTRY[key]
	_help.text = "%s\n%s\n\n%s" % [String(e["label"]), ScriptMarks.example(key),
		ScriptMarks.blurb(key, _mode)]


func _gap(px: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, px)
	return c


## Recount the card and refresh what depends on the text: the summary, the window title and
## the speakers already in the script (each a one-click cue).
func _refresh() -> void:
	if text_edit == null:
		return
	var text := text_edit.text
	var source := doc.doc_path().get_file() if doc.is_sync() \
		else "Unsaved %s" % _wording("window", "Script").to_lower()
	_name.text = source
	_name.tooltip_text = ("Saved in " + doc.doc_path()) if doc.is_sync() else \
		"Kept by Ghost Notes alone, in no file. Save… writes it into one."
	_window.title = "%s - %s" % [_wording("window", "Script"), source]
	for k in _field_edits:
		var e: LineEdit = _field_edits[k]
		if not e.has_focus() and not _handed.has(k):
			e.text = doc.field(k)
	_refresh_handed()
	var spoken := Manuscript.unspoken(text)
	var parts := PackedStringArray([_count(Manuscript._rx("\\S+").search_all(spoken).size(), "word")])
	if _mode in ["generative", "table"]:
		var names := Manuscript.speakers(text)
		parts.append(_count(names.size(), "voice"))
		var pics := Manuscript.images(text).size()
		if pics > 0:
			parts.append(_count(pics, "picture"))
		if names != _speaker_names:
			_speaker_names = names
			_rebuild_speakers()
	_summary.text = " · ".join(parts)


func _rebuild_speakers() -> void:
	if _speakers == null:
		return
	for c in _speakers.get_children():
		c.queue_free()
	var cued := _speaker_names.duplicate()
	if cued.size() > 0 and cued[0] == Manuscript.NARRATOR \
			and not ("speaker: " + Manuscript.NARRATOR) in text_edit.text:
		cued.remove_at(0)             # the narrator is implied, not cued - nothing to repeat
	_speakers_head.visible = not cued.is_empty()
	for n in cued:
		var b := Button.new()
		b.text = n
		b.tooltip_text = "Insert a cue handing the text after it to %s." % n
		b.add_theme_font_size_override("font_size", 12)
		b.pressed.connect(func() -> void:
			ScriptMarks.insert(text_edit, "speaker", n)
			text_edit.grab_focus())
		_speakers.add_child(b)


static func _count(n: int, noun: String) -> String:
	var digits := str(n)
	var out := ""
	for i in digits.length():
		if i > 0 and (digits.length() - i) % 3 == 0:
			out += ","
		out += digits[i]
	return "%s %s%s" % [out, noun, "" if n == 1 else "s"]
