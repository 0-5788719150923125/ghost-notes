extends Node

## storyboard_editor_check - a note's storyboard, written in the app (next/storyboard.md): through
## the real main scene, with notes of the gate's own (`NoteStore.root`) and a song that is a
## fixture of silence.
##
##   tests/run_boot_probe.sh tests/timeline/storyboard_editor_check.gd 300
##
## THE FIELDS' TABLES AGREE WITH THE REGISTRIES THEY DESCRIBE. [Storyboard] writes its choices out
## (it names no autoload, so it loads under `--script`); here, with everything loaded, each list is
## held to its owner - motions to GhostScene.BEHAVIORS, shots to Shots.REGISTRY, kinds to
## Cast.REGISTRY, verbs to Actions.REGISTRY, eases and cues to what Track and the Director make of
## each name - and every kind and verb with a table of its own is one the registry has. The
## control for the name checks: a name nothing knows is told apart from one something does.
##
## THE SEEDED SHOW IS A STORYBOARD NOBODY WROTE DOWN. `Director.forecast` says, before a frame is
## played, which scenes this session's seed will play, with what motion and from what seed; the
## Director is then cut through that many scenes for real, and the two lists are the same - asking
## in between changes nothing. The control: another seed's forecast is a different list.
##
## WRITTEN DOWN, IT IS THE SAME SHOW. "Start from the seeded show" makes those entries the note's
## own, the Director takes them, and what is on screen is the scene the seed opened on, built from
## the same seed.
##
## THE EDITOR EDITS A TREE, AND THE SHOW FOLLOWS. An entry picked is on screen; an entry added,
## an actor, a span, a rename (its spans follow), a retiming, a hold dragged longer, an entry moved -
## each is a new tree, the one before it left exactly as it was (held to a copy), and each is one
## step back. The source view takes a storyboard back as YAML, and refuses text that does not
## make one, leaving the tree as it was (the control). With everything deleted the seed chooses
## again.
##
## THE NOTE KEEPS IT: the tree reaches the note's `scenes:` block through the autosave every card
## uses, and the note left and opened again shows and walks the same storyboard. A note that NAMES
## a file plays it as it is and cannot change it here, until it is taken into the note.
##
## A VOICE WALKS ONE TOO: a note with a voice, a Picture and a storyboard hands the same plan to
## main as a song's does - the pairing is no panel's feature.
##
## THE ROWS ARE THE TABLES ([SchemaForm]): a row per field, a choice picked or a line typed raises
## one edit with the value read (a range typed `0.3..0.4` is a range), ↺ unsets, text that cannot
## be read is put back and raises nothing, and a form that may not change raises nothing at all.
## In the editor, a row moved in the inspector lands in the tree at the entry it was built for -
## and a line still being typed when another entry is picked is committed to the entry it was
## typed in, the inspector rebuilt once. The control, measured by taking the editor's guard out:
## the second set of rows is built in the middle of the rebuild that was freeing the first, the
## tree refuses it, and 102 nodes are left outside the tree - so the check counts orphans.
##
## THE DOCK TAKES ITS ROOM AND GIVES IT BACK: open, the frame is fitted above it; closed, and when
## the note is left, the claims are gone.

const ROOT := "user://storyboard_editor_check"
const FixtureAudio := preload("res://tests/fixture_audio.gd")
const CUTS := 6

var _fails: Array = []
var _main: Node


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_clean()
	NoteStore.root = ROOT
	NoteStore.discard = func(p: String) -> int: return DirAccess.remove_absolute(p)
	_tables()
	await _form()
	_main = preload("res://scenes/main.tscn").instantiate()
	add_child(_main)
	await _frames(20)
	await _settle_probe()
	var song: String = FixtureAudio.silence(20.0)
	await _forecast(song)
	await _write_and_edit(song)
	await _file_board(song)
	await _voice(song)
	NoteStore.discard = Callable()
	_clean()
	_report()


# --- the tables ----------------------------------------------------------------------------------

func _tables() -> void:
	print("-- the fields' tables and their registries")
	_same(Storyboard.ENTRY["behavior"]["options"], GhostScene.BEHAVIORS.keys(), "an entry's motions are GhostScene's behaviors")
	var shots: Array = (Storyboard.ENTRY["shot"]["options"] as Array).duplicate()
	shots.erase("")
	_same(shots, Shots.REGISTRY.keys(), "its shots are the Shots registry's")
	_same(Storyboard.ACTOR["kind"]["options"], Cast.REGISTRY.keys(), "an actor's kinds are the Cast registry's")
	_same(Storyboard.SPAN["action"]["options"], Actions.REGISTRY.keys(), "a span's verbs are the Actions registry's")
	for kind in Cast.REGISTRY:
		_ok(Cast.PARAMS.has(kind), "the kind '%s' has a table of what it can be told" % kind)
	for kind in Cast.PARAMS:
		_ok(Cast.REGISTRY.has(kind), "Cast.PARAMS['%s'] is a kind there is" % kind)
	for verb in Actions.ARGS:
		_ok(Actions.REGISTRY.has(verb), "Actions.ARGS['%s'] is a verb there is" % verb)
	for table in [Cast.PARAMS, Actions.ARGS]:
		for owner in table:
			for key in (table[owner] as Dictionary):
				var row: Dictionary = table[owner][key]
				_ok(row.has("label") and row.has("type") and row.has("default") and not String(row.get("blurb", "")).is_empty(),
					"%s.%s says what it is" % [owner, key])
	# eases: each name the table offers is one Track tells apart from the rest
	var track := Track.new({"nominal": 1, "spans": []}, RandomNumberGenerator.new())
	var seen := {}
	for ease in (Storyboard.SPAN["ease"]["options"] as Array):
		seen[snappedf(track._eased(0.25, String(ease)), 0.0001)] = ease
	_ok(seen.size() == (Storyboard.SPAN["ease"]["options"] as Array).size(), "every ease is one Track knows (%s)" % str(seen))
	_ok(is_equal_approx(track._eased(0.25, "nonsense"), track._eased(0.25, "smooth")),
		"the control: a name Track does not know is not told apart")
	# cues: each name is a trigger of its own
	var triggers := {}
	for cue in (Storyboard.TIMING_FIELDS["exit"]["options"] as Array):
		triggers[Director._trigger_from_name(String(cue))] = cue
	_ok(triggers.size() == 3, "every cue an entry can leave on is a trigger of its own (%s)" % str(triggers))
	for cue in (Storyboard.SPAN["on"]["options"] as Array):
		_ok(String(cue).is_empty() or (Storyboard.TIMING_FIELDS["exit"]["options"] as Array).has(cue), "a span waits for a cue there is ('%s')" % cue)
	_ok(StoryboardEditor.scene_names()[0] == "stage" and StoryboardEditor.scene_names().size() > 20,
		"an entry can name the stage and the whole catalog (%d scenes)" % StoryboardEditor.scene_names().size())


func _same(a: Variant, b: Variant, msg: String) -> void:
	var x: Array = (a as Array).duplicate()
	var y: Array = (b as Array).duplicate()
	x.sort()
	y.sort()
	_ok(x == y, "%s (%s / %s)" % [msg, str(x), str(y)])


# --- the rows ------------------------------------------------------------------------------------

func _form() -> void:
	print("-- rows from a table")
	_ok(SchemaForm.parse_num("0.3..0.4") == [0.3, 0.4] and SchemaForm.parse_num("[2, 5]") == [2, 5]
		and SchemaForm.parse_num("7") == 7 and SchemaForm.parse_num("1.5") == 1.5,
		"a number is read, and so is a range typed either way")
	_ok(SchemaForm.parse_num("soon") == null and SchemaForm.parse_num("1..x") == null, "the control: text that is neither is not read")
	_ok(SchemaForm.num_text([0.3, 0.4]) == "0.3..0.4" and SchemaForm.num_text(4.0) == "4", "...and written back as it is typed")
	_ok(SchemaForm.parse_vec3("0, 0, 4") == [0, 0, 4] and SchemaForm.parse_vec3("0, 1..2, 4") == [0, [1, 2], 4]
		and SchemaForm.parse_vec3("0, 0") == null, "three components, each a number or a range")
	_ok(SchemaForm.vec3_text([0, [1, 2], 4.0]) == "0, 1..2, 4", "...written back the same way")
	_ok(String(SchemaForm.infer("x", true)["type"]) == "bool" and String(SchemaForm.infer("x", [1, 2])["type"]) == "num"
		and String(SchemaForm.infer("x", [0, 0, 4])["type"]) == "vec3" and String(SchemaForm.infer("x", {"a": 1})["type"]) == "data",
		"a value no table describes still gets a row, by what it is")
	var form := SchemaForm.new()
	add_child(form)
	var got: Array = []
	form.edited.connect(func(key: String, value: Variant) -> void: got.append([key, value]))
	form.show_fields(Storyboard.ENTRY, {"scene": "aurora", "behavior": "drift"}, {"scenes": ["aurora", "embers", "stage"]})
	_ok(form.get_child_count() == Storyboard.ENTRY.size(), "a row for every field of the table (%d)" % form.get_child_count())
	var motion := _row_control(form, "Motion") as OptionButton
	_ok(motion != null and motion.get_item_metadata(motion.selected) == "drift", "a row shows the value written")
	var seed_line := _row_control(form, "Seed") as LineEdit
	_ok(seed_line != null and seed_line.text.is_empty(), "...and an unset one shows nothing written")
	if motion != null:
		motion.item_selected.emit(0)
		_ok(got == [["behavior", "static"]], "a choice picked is one edit, with its value (%s)" % str(got))
	got.clear()
	if seed_line != null:
		seed_line.text = "42"
		seed_line.text_submitted.emit("42")
		seed_line.focus_exited.emit()
		_ok(got == [["seed", 42]], "a line typed is one edit - Enter, then leaving it, is not two (%s)" % str(got))
		got.clear()
		seed_line.text = "soon"
		seed_line.text_submitted.emit("soon")
		_ok(got.is_empty() and seed_line.text == "42", "the control: text that cannot be read is put back, and nothing is edited")
	var reset := _row_reset(form, "Motion")
	if reset != null:
		reset.pressed.emit()
		_ok(got == [["behavior", null]], "↺ unsets the key (%s)" % str(got))
	got.clear()
	form.read_only = true
	form.show_fields(Storyboard.ENTRY, {"scene": "aurora", "behavior": "drift"}, {"scenes": ["aurora"]})
	motion = _row_control(form, "Motion") as OptionButton
	if motion != null:
		motion.item_selected.emit(0)
	_ok(got.is_empty() and motion != null and motion.disabled, "a form that may not change raises nothing")
	form.queue_free()
	await _frames(2)


## The control on the row of [param form] labeled [param label], or null.
func _row_control(form: Node, label: String) -> Control:
	for row in form.get_children():
		if row.get_child_count() >= 2 and (row.get_child(0) as Label).text == label:
			return row.get_child(1) as Control
	return null


func _row_reset(form: Node, label: String) -> Button:
	for row in form.get_children():
		if row.get_child_count() >= 3 and (row.get_child(0) as Label).text == label:
			return row.get_child(2) as Button
	return null


## The first form in the editor's inspector with a row labeled [param label].
func _inspector_form(ed: StoryboardEditor, label: String) -> SchemaForm:
	for c in ed._inspector.get_children():
		if c is SchemaForm and _row_control(c, label) != null:
			return c
	return null


# --- the seeded show, read ahead -------------------------------------------------------------------

func _forecast(song: String) -> void:
	print("-- the seeded show is a storyboard nobody wrote down")
	var note := NoteStore.create("seeded", "", {"song": {"path": song}, "picture": {"medium": "full"}})
	_main._list._open(note)
	await _frames(24)
	_ok(Director.is_attached() and not Director.is_manual(), "a song and a Picture: the show is up, and the seed chooses")
	if not Director.is_attached():
		return
	var ahead := Director.forecast(CUTS)
	var played: Array = []
	for k in CUTS:
		var sc: GhostScene = Director._current
		played.append({"scene": sc.scene_name, "behavior": sc.behavior_name, "seed": sc.seed_value})
		if k == 2:
			Director.forecast(CUTS)                 # asked again in the middle: it changes nothing
		sc.transition_style = "cut"                 # a cut is taken at once, so the walk needs no clock
		Director.next()
		await _frames(2)
	for k in CUTS:
		_ok(DataPath.same(ahead[k], played[k]), "cut %d: %s, as forecast (%s)" % [k + 1, str(played[k]), str(ahead[k])])
	var keep: int = Director._session_seed
	Director._session_seed = keep + 1
	var other := Director.forecast(CUTS)
	Director._session_seed = keep
	_ok(not DataPath.same(other, ahead), "the control: another seed's forecast is another running order")
	_main._chrome._home_button.pressed.emit()
	await _frames(12)


# --- written down, and edited ---------------------------------------------------------------------

func _write_and_edit(song: String) -> void:
	print("-- written down, it is the same show")
	var ch: Chrome = _main._chrome
	var note := NoteStore.create("story", "Words.\n", {"song": {"path": song}, "picture": {"medium": "full"},
		"scenes": {"sequence": []}})
	_main._list._open(note)
	await _frames(24)
	var panel: NotePanel = _main._note_panel
	var card: StoryboardCard = panel._story if panel != null else null
	_ok(card != null, "a note with a storyboard attached has its card")
	if card == null:
		return
	_ok((panel.show_plan()["board"] as Dictionary).is_empty() and not Director.is_manual(),
		"nothing is written in it, so the seed chooses")
	var first: GhostScene = Director._current
	var opened := {"scene": first.scene_name, "seed": first.seed_value}
	var whole := _main._frame_rect() as Rect2
	card.open_editor()
	await _frames(4)
	var ed := card.editor()
	_ok(ed != null and ch._bottom_claims.has(StoryboardEditor.CLAIM) and ch.stage_bottom > 0.0,
		"the editor is docked, and has claimed its room")
	if ed == null:
		return
	var fitted := _main._frame_rect() as Rect2
	var vis: Vector2 = get_viewport().get_visible_rect().size
	# (a headless window is square, so the frame keeps its size and moves up; in a 16:9 window it shrinks)
	_ok(fitted.end.y <= vis.y - ch.stage_bottom + 1.0 and fitted.get_center().y < whole.get_center().y,
		"the frame is fitted above the dock (%s, in the whole window %s)" % [str(fitted), str(whole)])
	_ok(is_equal_approx(whole.get_center().y, vis.y * 0.5), "...and before it opened, the frame was the window's")
	_ok(ed.ghost and ed.read_only and ed._strip.rows.size() == StoryboardCard.AHEAD,
		"with nothing written it shows what the seed will play, grayed (%d entries)" % ed._strip.rows.size())
	card._fill_start()
	card._on_start(0)
	await _wait(0.6)
	var seq: Array = card.capture().get("sequence", [])
	_ok(seq.size() == StoryboardCard.AHEAD, "Start from the seeded show: %d entries, the note's own" % seq.size())
	_ok(Director.is_manual() and int(Director.cursor()["entry"]) == 0, "the Director walks them, from the first")
	var now: GhostScene = Director._current
	_ok(now.scene_name == String(opened["scene"]) and now.seed_value == int(opened["seed"]),
		"...and it is the scene the seed opened on, from the same seed (%s %d / %s %d)"
		% [now.scene_name, now.seed_value, opened["scene"], opened["seed"]])
	_ok(not ed.read_only and not ed.ghost and ed._strip.rows.size() == StoryboardCard.AHEAD, "the editor shows them, and they can be changed")

	print("-- the editor edits a tree, and the show follows")
	ed._pick(2)
	await _frames(3)
	_ok(int(Director.cursor()["entry"]) == 2 and Director._current.scene_name == String(seq[2]["scene"]),
		"an entry picked is on screen (entry %s, %s)" % [Director.cursor()["entry"], Director._current.scene_name])
	# each edit: the tree before it is left as it was, and is one step back
	var edits := [
		["a stage entry added after it", func() -> void: ed.add_entry("stage")],
		["an actor put on the stage", func() -> void: ed.add_actor("eye")],
		["something for it to do", func() -> void: ed.add_span("blink", "eye", 1.0)],
		["the moment moved", func() -> void: ed._retime(0, 2.0, 2.0)],
		["the moment made a window", func() -> void: ed._span_as(0, true)],
		["the actor renamed", func() -> void: ed._rename_actor(ed._path(ed.selected()), 0, "left")],
		["the entry's hold dragged longer", func() -> void: ed._resize(3, 11.0)],
		["the storyboard's own tempo set", func() -> void: ed._write(["sensitivity"], 2.0)],
	]
	for e in edits:
		var before: Dictionary = ed.data
		var held := before.duplicate(true)
		(e[1] as Callable).call()
		_ok(not DataPath.same(ed.data, held), "%s: the tree is another one" % e[0])
		_ok(DataPath.same(before, held), "...and the one before it is as it was")
		ed.undo()
		_ok(DataPath.same(ed.data, held), "...one step back")
		ed.redo()
	var stage: Dictionary = ed.data["sequence"][3]
	_ok(String(stage.get("scene", "")) == "stage" and (stage.get("cast", []) as Array).size() == 1,
		"the stage entry stands fourth, with its actor (%s)" % str(stage.get("cast")))
	var span: Dictionary = stage["track"]["spans"][0]
	_ok(String(span.get("target", "")) == "left" and span.has("from") and not span.has("at"),
		"its span is a window now, and followed the actor's new name (%s)" % str(span))
	_ok(is_equal_approx(float(stage.get("hold", 0.0)), 11.0), "its hold is the length it was dragged to (%s)" % str(stage.get("hold")))
	_ok(is_equal_approx(float(ed.data.get("sensitivity", 0.0)), 2.0)
		and is_equal_approx(float(ed._strip.rows[3]["length"]), 5.5),
		"at twice the tempo the strip draws it half as long (%.2f s)" % float(ed._strip.rows[3]["length"]))
	await _wait(0.6)
	_ok(int(Director.cursor()["entry"]) == 3 and Director._current.scene_name == "stage",
		"the show is on the entry being worked on (entry %s, %s)" % [Director.cursor()["entry"], Director._current.scene_name])
	ed._move(3, 0)
	_ok(String(ed.data["sequence"][0]["scene"]) == "stage" and ed.selected() == 0, "an entry moved stands where it was put, still picked")
	ed.shift_entry(1)
	_ok(String(ed.data["sequence"][1]["scene"]) == "stage", "...and one place later with ▶")
	ed.duplicate_entry()
	_ok((ed.data["sequence"] as Array).size() == StoryboardCard.AHEAD + 2, "Duplicate adds a copy")
	ed.remove_entry()
	_ok((ed.data["sequence"] as Array).size() == StoryboardCard.AHEAD + 1, "Delete removes the entry picked")

	print("-- the inspector's rows")
	ed._pick(2)
	var form := _inspector_form(ed, "Motion")
	var motion := _row_control(form, "Motion") as OptionButton if form != null else null
	_ok(motion != null, "an entry picked has its rows in the inspector")
	if motion != null:
		var want := String(motion.get_item_metadata(0))
		motion.item_selected.emit(0)
		_ok(String(ed.data["sequence"][2].get("behavior", "")) == want, "a row moved there lands in the tree, at that entry (%s)" % want)
	# a line still being typed when another entry is picked: committed where it was typed
	form = _inspector_form(ed, "Seed")
	var typed := _row_control(form, "Seed") as LineEdit if form != null else null
	if typed != null:
		typed.grab_focus()
		if not typed.has_focus():
			# no focus to lose in this window: leaving the tree is where a line commits, so say so
			typed.tree_exiting.connect(func() -> void: typed.focus_exited.emit())
		typed.text = "777"
		var other: Variant = (ed.data["sequence"][4] as Dictionary).get("seed")
		await _frames(3)
		var orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
		ed._pick(4)
		await _frames(3)
		_ok(int(ed.data["sequence"][2].get("seed", 0)) == 777 and (ed.data["sequence"][4] as Dictionary).get("seed") == other,
			"a line being typed when another entry is picked is kept, in the entry it was typed in (entry 3's seed %s, entry 5's %s)"
			% [str(ed.data["sequence"][2].get("seed")), str((ed.data["sequence"][4] as Dictionary).get("seed"))])
		var forms := ed._inspector.get_children().filter(func(c: Node) -> bool: return c is SchemaForm and not c.is_queued_for_deletion())
		var headings := ed._inspector.get_children().filter(func(c: Node) -> bool:
			return c is Label and not c.is_queued_for_deletion() and (c as Label).text.begins_with("Entry "))
		_ok(headings.size() == 1 and ed.selected() == 4, "...and the inspector is built once, for the entry picked (%d headings, %d forms)" % [headings.size(), forms.size()])
		# the control's measure: built in the middle of the rebuild that was freeing it, the second
		# set of rows is refused by the tree and left outside it (measured: 2 forms' worth of orphans)
		var after := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
		_ok(after <= orphans, "...with no row built and left outside the tree (%d orphan nodes, %d before)" % [after, orphans])

	print("-- the source view")
	ed.toggle_source()
	_ok(ed._source.text == Storyboard.to_yaml(ed.data), "Source shows the whole tree as YAML")
	var good: Dictionary = ed.data
	ed._source.text = "sequence:\n  - hold: 3\n"
	ed.apply_source()
	_ok(DataPath.same(ed.data, good) and ed._source_note.text.begins_with("⚠"),
		"the control: text that makes no storyboard is refused, and the tree is as it was (%s)" % ed._source_note.text)
	ed._source.text = Storyboard.to_yaml(good).replace("sensitivity: 2.0", "sensitivity: 1.5")
	ed.apply_source()
	_ok(is_equal_approx(float(ed.data.get("sensitivity", 0.0)), 1.5), "text that does is taken (tempo %s)" % str(ed.data.get("sensitivity")))
	ed.toggle_source()

	print("-- the note keeps it")
	_ok(DataPath.same(card.capture(), Storyboard.own_block(ed.data)), "the card holds what the editor shows")
	panel._writer.doc.allow_autosave_for_test()
	await _wait(2.4)
	var on_disk: Variant = NoteStore.blocks_of(note).get("scenes")
	_ok(on_disk is Dictionary and DataPath.same(on_disk, card.capture()), "the note's scenes: block is the storyboard, through the autosave")
	var walked := Director.storyboard_data()
	var again := Storyboard.from_yaml(Storyboard.to_yaml(walked))
	_ok(bool(again["ok"]) and DataPath.same(Storyboard.from_data(again["data"], "x")["sequence"], walked["sequence"]),
		"what a render is handed loads as the storyboard being walked")
	_ok(Director.storyboard_source().is_empty(), "...and it is in no file: the note's own")
	var kept: Dictionary = card.capture()
	ch._home_button.pressed.emit()
	await _frames(12)
	_ok(not ch._bottom_claims.has(StoryboardEditor.CLAIM) and is_zero_approx(ch.stage_bottom),
		"leaving the note closes the dock and gives its room back")
	_main._list._open(note)
	await _frames(24)
	panel = _main._note_panel
	card = panel._story if panel != null else null
	_ok(card != null and DataPath.same(card.capture(), kept), "opened again, the note shows the same storyboard")
	_ok(Director.is_manual() and Director._storyboard_seq.size() == (kept["sequence"] as Array).size(),
		"...and its show walks it (%d entries)" % Director._storyboard_seq.size())
	if card == null:
		return
	# everything deleted: the seed chooses again
	card.open_editor()
	await _frames(4)
	ed = card.editor()
	ed._edit(DataPath.put(ed.data, ["sequence"], []))
	await _wait(0.6)
	_ok(not Director.is_manual() and card.editor().ghost, "with every entry deleted the seed chooses again, and the editor shows its forecast")
	card.editor().add_entry("aurora")
	await _wait(0.6)
	_ok((card.capture()["sequence"] as Array).size() == 1 and Director.is_manual() and Director._current.scene_name == "aurora",
		"+ Scene over the forecast starts the note's own with that entry")
	card.close_editor()
	await _frames(3)
	_ok(not ch._bottom_claims.has(StoryboardEditor.CLAIM) and is_zero_approx(ch.stage_bottom), "closing the dock gives its room back")
	ch._home_button.pressed.emit()
	await _frames(12)


# --- a file a note names ----------------------------------------------------------------------------

func _file_board(song: String) -> void:
	print("-- a note that names a file")
	var note := NoteStore.create("from a file", "", {"song": {"path": song}, "picture": {"medium": "full"},
		"scenes": {"storyboard": "showcase"}})
	_main._list._open(note)
	await _frames(24)
	var panel: NotePanel = _main._note_panel
	var card: StoryboardCard = panel._story if panel != null else null
	_ok(card != null and card.capture() == {"storyboard": "showcase"}, "its block is the file's name, as it was")
	if card == null:
		return
	_ok(Director.is_manual() and Director.storyboard_source() == "showcase", "the show walks the file, and a render is told its name")
	card.open_editor()
	await _frames(4)
	var ed := card.editor()
	var held: Dictionary = ed.data.duplicate(true)
	ed.add_entry("aurora")
	ed._write(["loop"], false)
	_ok(ed.read_only and DataPath.same(ed.data, held), "the editor shows it and changes nothing in it")
	card._take.pressed.emit()
	await _wait(0.6)
	var own := Storyboard.of_block(card.capture())
	_ok(String(own["kind"]) == "own" and (own["data"] as Dictionary).has("defs"), "taken into the note, it is the note's own - its defs with it")
	_ok(not card.editor().read_only, "...and can be changed")
	_ok(Director.is_manual() and Director.storyboard_source().is_empty(), "the show walks the note's copy")
	_ok(DataPath.same(Storyboard.from_data(own["data"], "x")["sequence"], Storyboard.load_file("showcase")["sequence"]),
		"which plays as the file did")
	_main._chrome._home_button.pressed.emit()
	await _frames(12)


# --- a voice walks one too --------------------------------------------------------------------------

func _voice(_song: String) -> void:
	print("-- a voice with a picture and a storyboard")
	var home_procs := Subprocess.tracked()
	var note := NoteStore.create("narrated", "Words.\n", {"voice": {}, "picture": {"medium": "full"},
		"scenes": {"loop": true, "sequence": [{"scene": "aurora", "hold": 4}, {"scene": "embers", "hold": 4}]}})
	_main._list._open(note)
	await _frames(24)
	var reading: Node = _main._generative
	_ok(reading != null and is_instance_valid(reading), "it opens as a reading")
	if reading != null:
		var titles: Array = (reading._panel as SidePanel).cards().map(func(c: Node) -> String: return (c as Card).title)
		_ok(titles == ["Script", "Voice", "Picture", "Storyboard"], "its cards are the note's: %s" % str(titles))
		var plan: Dictionary = reading.show_plan()
		_ok(bool(plan["picture"]) and ((plan["board"] as Dictionary).get("sequence", []) as Array).size() == 2,
			"the plan it hands main is a song's: a picture, and the storyboard to walk")
	_main._chrome._home_button.pressed.emit()
	await _frames(12)
	for _i in 60:
		if Subprocess.tracked() <= home_procs:
			break
		await _frames(5)


# --- helpers ---------------------------------------------------------------------------------------

func _settle_probe() -> void:
	var env: DepsPanel = _main._chrome.environment
	for _i in 600:
		if not env._rows.is_empty():
			break
		await get_tree().process_frame
	await _frames(10)


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
	await _frames(2)


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


func _report() -> void:
	if _fails.is_empty():
		print("storyboard_editor_check: ALL OK")
		get_tree().quit(0)
		return
	print("storyboard_editor_check: %d FAILURE(S)" % _fails.size())
	for f in _fails:
		print("   ", f)
	get_tree().quit(1)
