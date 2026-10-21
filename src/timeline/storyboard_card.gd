extends VBoxContainer
class_name StoryboardCard

## StoryboardCard - the note's storyboard: the show written down, on a note with a Picture. What
## plays, in what order, for how long - and where nothing is written, the seed still chooses. The
## card says what the note holds and lists its entries, one a click away; the writing is done in
## the [StoryboardEditor] it opens along the bottom of the frame ("Timeline…").
##
## THE STORYBOARD IS THE NOTE'S, kept in its `scenes:` block ([method Storyboard.of_block]) and
## written there by the autosave every card's block goes through ([DocSource]): the note is the
## project. A note may instead NAME a file (`storyboard: default`, or a path) - then the card plays
## that file as it is, changes nothing in it, and offers to take it into the note.
##
## IT STARTS FROM SOMETHING ("Start from"): the seeded show itself, written down as this song's
## seed plays it ([method Director.forecast]) - so "automatic" is a first draft, an edit away from
## being authored - or one of the storyboards in `storyboards/`, copied in with its defs.
##
## THE SHOW FOLLOWS THE WRITING. An edit is handed to the Director a moment after the hand stops
## ([constant SETTLE]), and the entry being worked on is put back on screen ([method
## Director.goto_entry]); an entry picked - here or on the editor's strip - is shown at once, and
## where the storyboard follows the song (`loop` off) the song goes to that entry's place too, so
## picture and sound stay the pair they will be in the export.

## The block this card keeps under a note's `ghost:` key.
const KEY := "scenes"
## How many scenes of the seeded show are written down when a note starts from it.
const AHEAD := 12
## Seconds an edit waits before the show takes it: a number being dragged is many edits.
const SETTLE := 0.25

## A line for the panel's status ("Storyboard: 7 entries.").
signal noted(msg: String)
## The storyboard is another one now - an edit, a file taken in, another start.
signal changed

var _kind := "own"                 # "own": the note's; "file": one it names
var _file := ""
var _data := {"sequence": []}      # the raw tree: the note's own, or the file's as it is written
var _state: Label
var _fault: Label
var _timeline: Button
var _start: MenuButton
var _take: Button
var _list: VBoxContainer
var _scroll: ScrollContainer
var _editor: StoryboardEditor = null
var _settle := -1.0
var _poll := 0.0
var _shown_entry := -2


## This card for a note's panel, from what the panel says of itself ([method NoteCards.make]):
## it asks nothing of it.
static func for_note(_ctx: Dictionary) -> StoryboardCard:
	return StoryboardCard.new()


func _init() -> void:
	add_theme_constant_override("separation", 6)
	_state = Label.new()
	_state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_state.add_theme_font_size_override("font_size", 12)
	_state.modulate = Color(1, 1, 1, 0.75)
	add_child(_state)
	_fault = Label.new()
	_fault.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_fault.add_theme_font_size_override("font_size", 12)
	_fault.add_theme_color_override("font_color", Color(1.0, 0.6, 0.5))
	_fault.visible = false
	add_child(_fault)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	add_child(row)
	_timeline = Button.new()
	_timeline.text = "Timeline…"
	_timeline.toggle_mode = true
	_timeline.focus_mode = Control.FOCUS_NONE
	_timeline.tooltip_text = ("Open the storyboard's editor along the bottom of the frame: the entries on a "
		+ "ruler, a stage's actors and what they do under it, and whatever is picked set at the right.")
	_timeline.toggled.connect(_toggle_editor)
	row.add_child(_timeline)
	_start = MenuButton.new()
	_start.text = "Start from ▾"
	_start.flat = false
	_start.tooltip_text = ("Fill this note's storyboard: with the seeded show written down, or with a copy of "
		+ "one of the storyboards that come with Ghost Notes.")
	_start.about_to_popup.connect(_fill_start)
	_start.get_popup().index_pressed.connect(_on_start)
	row.add_child(_start)
	_take = Button.new()
	_take.text = "Take it into this note"
	_take.focus_mode = Control.FOCUS_NONE
	_take.tooltip_text = ("Copy the file's storyboard into this note, where it can be changed. The file is left "
		+ "exactly as it is.")
	_take.pressed.connect(func() -> void: _become(_data, "Taken into this note."))
	add_child(_take)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 1)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	_show()


func _exit_tree() -> void:
	close_editor()


## Every storyboard in `storyboards/`, by name, once each whatever its format.
static func boards() -> Array:
	var names: Array = []
	var dir := DirAccess.open(Storyboard.DIR)
	if dir == null:
		return names
	for fn in dir.get_files():
		if fn.ends_with(".yaml") or fn.ends_with(".yml") or fn.ends_with(".json"):
			if not names.has(fn.get_basename()):
				names.append(fn.get_basename())
	names.sort()
	return names


## The block for a note: its own storyboard, or the name of the file it plays.
func capture() -> Dictionary:
	return Storyboard.file_block(_file) if _kind == "file" else Storyboard.own_block(_data)


## ...and back: what the note's block holds. A block with nothing in it is the note's own
## storyboard with nothing written yet.
func apply(block: Dictionary) -> void:
	var b := Storyboard.of_block(block)
	var kind := "file" if String(b["kind"]) == "file" else "own"
	var tree: Dictionary = b["data"] if String(b["kind"]) == "own" else {"sequence": []}
	var file := String(b["name"]) if kind == "file" else ""
	if kind == "file":
		var read := Storyboard.read_raw(file)
		tree = read["data"] if bool(read["ok"]) else {"sequence": []}
	tree = Storyboard.own_block(tree)
	if kind == _kind and file == _file and DataPath.same(tree, _data):
		return
	_kind = kind
	_file = file
	_data = tree
	_show()
	_sync_editor(true)
	_changed()


## WHAT THE SHOW WALKS: `board`, the storyboard in its loaded form ({} where nothing is written,
## or what is written does not load - the seed chooses), and `source`, the name a render can load
## a file's from ("" for the note's own).
func plan() -> Dictionary:
	if _kind == "file":
		var sb := Storyboard.load_file(_file)
		_say_fault("" if bool(sb.ok) else String(sb.error))
		return {"board": sb if bool(sb.ok) else {}, "source": _file}
	if (_data.get("sequence", []) as Array).is_empty():
		_say_fault("")
		return {"board": {}, "source": ""}
	var own := Storyboard.from_data(_data, Storyboard.IN_NOTE, "storyboard")
	_say_fault("" if bool(own.ok) else String(own.error))
	return {"board": own if bool(own.ok) else {}, "source": ""}


## The raw tree shown: the note's own, or the file's.
func raw() -> Dictionary:
	return _data


func _say_fault(msg: String) -> void:
	_fault.text = ("⚠  %s - until it is put right, the seed chooses the scenes." % msg) if not msg.is_empty() else ""
	_fault.visible = not msg.is_empty()


# --- the editor ------------------------------------------------------------------------------------

func _toggle_editor(on: bool) -> void:
	if on:
		open_editor()
	else:
		close_editor()


func open_editor() -> void:
	if _editor != null and is_instance_valid(_editor):
		return
	_editor = StoryboardEditor.new()
	_sync_editor(true)
	_editor.edited.connect(_on_edited)
	_editor.picked.connect(show_entry)
	_editor.closed.connect(close_editor)
	add_child(_editor)
	_timeline.set_pressed_no_signal(true)


func close_editor() -> void:
	if _editor != null and is_instance_valid(_editor):
		_editor.queue_free()
	_editor = null
	if _timeline != null:
		_timeline.set_pressed_no_signal(false)


## The editor, while it is open.
func editor() -> StoryboardEditor:
	return _editor if _editor != null and is_instance_valid(_editor) else null


## Hand the editor what the card holds. [param fresh]: another storyboard, so its history starts
## again; otherwise the one it has, changed from here.
func _sync_editor(fresh: bool) -> void:
	if editor() == null:
		return
	var written := not (_data.get("sequence", []) as Array).is_empty()
	if _kind == "file":
		_editor.open(_data, true, "Read from %s - take it into this note to change it." % _file)
	elif not written and Director.is_attached() and not Director.is_manual():
		# NOTHING WRITTEN: what the seed is going to play, as the storyboard it amounts to
		_editor.open({"sequence": Director.forecast(AHEAD)}, true,
			("Nothing is written yet, so the seed chooses: these are the first %d scenes it plays. + Scene "
			% AHEAD + "starts this note's own; Start from → \"The seeded show, written down\" makes these its first draft."), true)
	elif fresh or _editor.read_only:
		_editor.open(_data)
	else:
		_editor.replace(_data)


func _on_edited(tree: Dictionary) -> void:
	if _kind != "own":
		return
	_data = tree
	_show()
	_changed()


# --- starting from something ------------------------------------------------------------------------

func _fill_start() -> void:
	var pop := _start.get_popup()
	pop.clear()
	pop.add_item("The seeded show, written down")
	pop.set_item_metadata(0, "")
	var why := ""
	if not Spectrum.has_audio():
		why = "The seeded show is drawn from the note's sound: load its song, or start its reading, first."
	pop.set_item_disabled(0, not why.is_empty())
	pop.set_item_tooltip(0, ("The %d scenes this note's seed plays first, each with its motion and the seed that "
		% AHEAD + "rolls its look, as entries of this note's own. Their timing stays the music's until a hold is set.")
		+ ("\n\n" + why if not why.is_empty() else ""))
	pop.add_separator("A copy of")
	for name in boards():
		pop.add_item(String(name))
		pop.set_item_metadata(pop.item_count - 1, String(name))
		pop.set_item_tooltip(pop.item_count - 1, "storyboards/%s, copied into this note with its defs." % name)


func _on_start(i: int) -> void:
	var pop := _start.get_popup()
	if pop.is_item_disabled(i) or pop.is_item_separator(i):
		return
	var name := String(pop.get_item_metadata(i))
	var next := {}
	var said := ""
	if name.is_empty():
		next = {"transition": "dip", "sequence": Director.forecast(AHEAD)}
		said = "The seeded show's first %d scenes are this note's storyboard now." % AHEAD
	else:
		var read := Storyboard.read_raw(name)
		if not bool(read["ok"]):
			noted.emit("⚠  " + String(read["error"]))
			return
		next = Storyboard.own_block(read["data"])
		said = "A copy of %s is this note's storyboard now." % name
	if _kind == "own" and not (_data.get("sequence", []) as Array).is_empty():
		_ask_replace(next, said)
	else:
		_become(next, said)


## What is written here is replaced only when asked: it is the author's work.
func _ask_replace(next: Dictionary, said: String) -> void:
	var ask := ConfirmationDialog.new()
	ask.title = "Replace this note's storyboard?"
	ask.dialog_autowrap = true
	ask.dialog_text = ("This note's storyboard has %d entries written in it. Starting from something else "
		% (_data["sequence"] as Array).size() + "replaces them. (With the Timeline open, Ctrl+Z brings them back.)")
	ask.ok_button_text = "Replace"
	ask.confirmed.connect(func() -> void:
		ask.queue_free()
		_become(next, said))
	ask.canceled.connect(ask.queue_free)
	add_child(ask)
	ask.popup_centered(Vector2i(520, 0))


## [param next] is the note's own storyboard from here on.
func _become(next: Dictionary, said: String) -> void:
	_kind = "own"
	_file = ""
	_data = Storyboard.own_block(next)
	_show()
	_sync_editor(false)
	_changed()
	noted.emit(said)


# --- the show --------------------------------------------------------------------------------------

func _changed() -> void:
	_settle = SETTLE
	changed.emit()


func _process(delta: float) -> void:
	if _settle >= 0.0:
		_settle -= delta
		if _settle < 0.0:
			_take_to_show()
	_poll -= delta
	if _poll > 0.0:
		return
	_poll = 0.1
	var cur := Director.cursor()
	var entry := int(cur["entry"])
	if editor() != null:
		_editor.set_cursor(entry, float(cur["elapsed"]))
	if entry != _shown_entry:
		_shown_entry = entry
		_mark_playing()


## Hand what is written to the show that is up: the Director walks it from the next cut, and the
## entry being worked on is put back on screen. With nothing written the show is the seed's again.
func _take_to_show() -> void:
	if not Director.is_attached():
		return
	var p := plan()
	var board: Dictionary = p["board"]
	if board.is_empty():
		if Director.is_manual():
			Director.clear_storyboard()
			Director.next()
		_sync_editor(true)
		return
	var was_manual := Director.is_manual()
	if not Director.load_board(board, String(p["source"])):
		return
	var at := editor().selected() if editor() != null else -1
	if at >= 0:
		Director.goto_entry(at)
	elif not was_manual:
		Director.goto_entry(0)


## PUT ENTRY [param i] ON SCREEN (the tail's counted on from the sequence's end) - a click here, or
## on the editor's strip. Where the storyboard follows the song, the song goes to that entry's
## place in the schedule too.
func show_entry(i: int) -> void:
	if not Director.is_attached():
		noted.emit("Entry %d - it is shown once the note's show is up." % (i + 1))
		return
	if _settle >= 0.0:
		_settle = -1.0
		_take_to_show()
	if not Director.is_manual():
		return
	Director.goto_entry(i)
	var p := plan()
	var board: Dictionary = p["board"]
	if board.is_empty() or bool(board.get("loop", true)) or not Spectrum.conductor().is_empty() or not Spectrum.seekable():
		return
	var seq: Array = board["sequence"]
	if i >= seq.size():
		return
	var s := Storyboard.schedule(seq, Director.storyboard_sensitivity(), Director.unauthored_hold())
	var paused := Spectrum.paused
	Spectrum.seek(float(s["starts"][i]))
	Spectrum.set_paused(paused)


# --- showing ---------------------------------------------------------------------------------------

func _show() -> void:
	var seq: Array = _data.get("sequence", []) as Array
	var tail: Array = _data.get("tail", []) as Array if _data.get("tail") is Array else []
	_take.visible = _kind == "file"
	_start.visible = _kind == "own"
	if _kind == "file":
		_state.text = "Plays the file %s as it is (%d entries). Nothing here changes it." % [_file, seq.size()]
	elif seq.is_empty():
		_state.text = ("Nothing is written yet, so the seed chooses the scenes. Start from something, or open "
			+ "the Timeline and add the first entry.")
	else:
		var sched := Storyboard.schedule(_loaded_sequence(), float(_data.get("sensitivity", Director.sensitivity)),
			Director.unauthored_hold())
		_state.text = "This note's own: %d %s, %s%s%s." % [seq.size(), "entry" if seq.size() == 1 else "entries",
			Clock.text(float(sched["end"])),
			(" and %d in the tail" % tail.size()) if not tail.is_empty() else "",
			", looping" if bool(_data.get("loop", true)) else ", following the song"]
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	var i := 0
	for list in [seq, tail]:
		for e in list:
			var b := Button.new()
			b.flat = true
			b.focus_mode = Control.FOCUS_NONE
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.clip_text = true
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.add_theme_font_size_override("font_size", 12)
			b.set_meta("entry", i)
			b.set_meta("label", _entry_label(i, e, list == tail and not tail.is_empty() and i >= seq.size()))
			b.tooltip_text = "Show this entry now."
			b.pressed.connect(show_entry.bind(i))
			_list.add_child(b)
			i += 1
	# a long storyboard scrolls inside the card; a short one is as tall as it is
	_scroll.custom_minimum_size.y = minf(float(i) * 25.0, 176.0)
	_scroll.visible = i > 0
	_shown_entry = -2
	_mark_playing()


## The sequence as it loads (its `use` expanded), for its schedule; as written where it does not.
func _loaded_sequence() -> Array:
	var loaded := Storyboard.from_data(_data, Storyboard.IN_NOTE)
	return loaded["sequence"] if bool(loaded.ok) else (_data.get("sequence", []) as Array)


func _entry_label(i: int, e: Variant, in_tail: bool) -> String:
	var entry: Dictionary = e if e is Dictionary else {}
	var name := String(entry.get("scene", "?")).replace("_", " ")
	var stays := ""
	match Storyboard.timing_of(entry):
		"hold":
			stays = "%s s" % SchemaForm.num_text(entry.get("hold"))
		"cue":
			stays = "on a %s" % String(entry.get("exit", "beat"))
		_:
			stays = "its own length"
	return "%d  %s  ·  %s%s" % [i + 1, name, stays, "  ↻" if in_tail else ""]


func _mark_playing() -> void:
	for c in _list.get_children():
		var b := c as Button
		if b == null:
			continue
		var on := int(b.get_meta("entry")) == _shown_entry
		b.text = ("▶ " if on else "    ") + String(b.get_meta("label"))
