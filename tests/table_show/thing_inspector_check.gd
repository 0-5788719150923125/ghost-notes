extends Node

## thing_inspector_check - one thing picked, one inspector, on an episode (next/editing.md steps 5 to 8: [EpisodeCard.open_dock],
## [TableRows], [TablePlanView], [ThingLibrary]).
##
##   tests/run_boot_probe.sh tests/table_show/thing_inspector_check.gd 90
##
## On an episode and a library of its own (never the author's), the Episode card's timeline docked:
##   - an act picked is its rows; a field set is written into `acts.json` as a hand's version, kept, and Undo puts back what it
##     was. The control: a field the acts would be read otherwise than written (a track with no such law) is refused and said;
##   - a track picked is its law's rows ([method TableRows.law_fields]: the puppeteer's own sentences; the control an unknown law
##     has only what every track names), a field written where it lives, a law that is none refused;
##   - a thing picked on the stage is its rows, its parts each a press, the part picked as its own rows; a thing's field and a
##     part's are written into `table.json` where they live, and Undo takes the last back; a part of a shape there is and a new
##     thing are put on and picked. The control: a thing not in the
##     table's data says so;
##   - the table from above: a thing's foot picked by a click, and a drag hands back where it would stand, in centimeters from
##     the middle of the reading. The control: a click on bare table picks nothing;
##   - the library keeps a thing with the materials its parts use (the control: not one it does not), and puts it on a table
##     named its own there, only the materials that table lacks added;
##   - an agent asked about what is picked needs a note, and a read-only session asks none (no agent is ever started here);
##   - an Undo with nothing changed says so.

const ROOT := "user://thing_inspector_check"

var _fails := 0
var _ed: Object
var _show: Object


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	TableEpisode.root = ROOT
	ThingLibrary.root = ROOT.path_join("library")
	_ed = load("res://src/reading/reading_panel.gd").new()
	_ed.workspace = "table"
	_ed._build_panel()
	_ed._doc._sync = false
	_show = _ed._block_cards["table"]
	_show._knobs["show"] = "inspect"
	_show._knobs["seed"] = 3
	_show._open_episode()
	var ep: TableEpisode = _show._episode
	ep.write_json("plan", {"episode_title": "Inspected", "spread": {"name": "", "positions": [{"name": "The Hook"}]},
		"staging": {"source": "none"}, "look": CardTable.sanitize_look({})})
	ep.write_text("say:1", "One two <!-- act: base --> three.")
	ep.write_json("acts", {"acts": [{"name": "base", "beat": "1", "length": 5.0, "tracks": [{"law": "to", "thing": "mask"}]}]})
	ep.write_json("table", {"things": [
		{"name": "mask", "at": [0.0, 6.0], "parts": [{"shape": "box", "material": "walnut", "size": [20.0, 2.0, 18.0]},
			{"name": "face", "shape": "mask", "material": "face form", "size": [15.0, 21.0, 8.0]}]},
		{"name": "cup", "at": [10.0, 0.0], "parts": [{"shape": "lathe", "material": "tin"}]}],
		"materials": {"walnut": {"color": "#5a3b22"}, "face form": {"color": "#e8dccb"}, "tin": {"color": "#9a9a9a"}}})

	_ok(_show._take_back() == "nothing has been changed here yet", "an Undo with nothing changed says so")
	var dock: TimelineDock = _show.open_dock()
	# (the card is out of the tree, as a panel built by hand is: the dock is given a place in it to be built)
	dock.get_parent().remove_child(dock)
	add_child(dock)
	await get_tree().process_frame
	_ok(dock != null and dock.inspector.is_valid() and dock.undo.is_valid(), "the episode's timeline docks with an inspector and an Undo")

	# An act
	dock.inspect({"item": {"source": ["acts", 0], "label": "base", "kind": "span"}, "group": 1})
	var forms := dock._inspector.find_children("*", "SchemaForm", true, false)
	_ok(forms.size() == 1, "an act picked is its rows (%d forms)" % forms.size())
	if not forms.is_empty():
		(forms[0] as SchemaForm).edited.emit("length", 9.0)
	var acts: Dictionary = ep.read_json("acts")
	_ok(is_equal_approx(float(acts["acts"][0]["length"]), 9.0) and ep.kept("acts"), "a field set is written into acts.json, kept (%s)" % dock._said.text)
	_ok(_show._take_back().is_empty() and is_equal_approx(float((ep.read_json("acts") as Dictionary)["acts"][0]["length"]), 5.0),
		"Undo puts back what it was")
	var refused: String = _show.set_act_field(0, "tracks", [{"law": "levitate", "thing": "mask"}])
	_ok(refused.contains("levitate") and String((ep.read_json("acts") as Dictionary)["acts"][0]["tracks"][0]["law"]) == "to",
		"the control: a track with no such law is refused, said, the acts unchanged (%s)" % refused)

	# What is kept of the note, on its body card ([NoteKept]): Cache and Restore…, Restore listing the episode's step versions beside the
	# note's saves; a version put back is the step as it stood - the control: a read-only session puts nothing back
	var kept: NoteKept = _ed.get("_kept")
	var names: Array = kept.find_children("*", "Button", true, false).map(func(b: Node) -> String: return (b as Button).text) if kept != null else []
	var listed: Array = kept.entries().filter(func(e: Dictionary) -> bool:
		return String(e["where"]) == "The episode" and String((e["key"] as Array)[0]) == "acts" and String(e["said"]).contains("yours")) if kept != null else []
	_ok(names.has("Cache") and names.has("Restore…") and not listed.is_empty(),
		"the Body card keeps Cache and Restore…, Restore listing the episode's step versions (%d: %s)" % [listed.size(), String(listed[0]["said"]) if not listed.is_empty() else ""])
	var length_now := float((ep.read_json("acts") as Dictionary)["acts"][0]["length"])
	_ok(not listed.is_empty() and not kept.put_back(listed[0]).is_empty(), "the control: a read-only session puts nothing back")
	var put: String = _ed.episode_feed().put_back(listed[0]["key"]) if not listed.is_empty() else "none listed"
	_ok(put.is_empty() and float((ep.read_json("acts") as Dictionary)["acts"][0]["length"]) != length_now,
		"a version put back is the step as it stood (%s -> %s)" % [length_now, (ep.read_json("acts") as Dictionary)["acts"][0]["length"]])
	_show._take_back()

	# A track: its law's rows, the puppeteer's own sentences - the control an unknown law has only what every track names
	var rows := TableRows.law_fields("turn")
	var said_rate := String((Motions.LAWS["turn"]["fields"] as Array)[0][1])
	_ok(rows.has("rate") and String(rows["rate"]["blurb"]) == said_rate and rows.has("tick"), "a law's fields are rows, each the sentence the puppeteer reads")
	_ok(TableRows.law_fields("levitate").keys() == ["law", "thing", "part"], "the control: an unknown law has only what every track names")
	dock.inspect({"item": {"source": ["acts", 0], "label": "base", "kind": "span"}, "track": 0})
	forms = dock._inspector.find_children("*", "SchemaForm", true, false)
	if not forms.is_empty():
		(forms[0] as SchemaForm).edited.emit("value", 0.5)
	var track: Dictionary = (ep.read_json("acts") as Dictionary)["acts"][0]["tracks"][0]
	_ok(forms.size() == 1 and float(track.get("value", -1.0)) == 0.5, "a track picked is its law's rows, a field written where it lives (%s)" % str(track))
	if not forms.is_empty():
		(forms[0] as SchemaForm).edited.emit("law", "levitate")
	_ok(String((ep.read_json("acts") as Dictionary)["acts"][0]["tracks"][0]["law"]) == "to" and dock._said.text.contains("levitate"),
		"the control: a law that is none is refused, and said (%s)" % dock._said.text)
	_show._take_back()

	# A thing and its part
	dock.inspect({"thing": "mask", "part": "face"})
	forms = dock._inspector.find_children("*", "SchemaForm", true, false)
	var presses := dock._inspector.find_children("*", "Button", true, false).filter(func(b: Node) -> bool:
		return (b as Button).toggle_mode and not (b is OptionButton) and not (b is CheckBox) and not (b is MenuButton) and not (b is CheckButton))
	_ok(forms.size() == 2 and presses.size() == 2 and (presses[1] as Button).button_pressed,
		"a thing picked is its rows, its parts each a press, the part picked as its own rows (%d forms, %d parts)" % [forms.size(), presses.size()])
	if forms.size() == 2:
		(forms[0] as SchemaForm).edited.emit("turn", 30.0)
		dock.inspect({"thing": "mask", "part": "face"})
		forms = dock._inspector.find_children("*", "SchemaForm", true, false)
		(forms[1] as SchemaForm).edited.emit("material", "walnut")
	var mask: Dictionary = (ep.read_json("table") as Dictionary)["things"][0]
	_ok(float(mask.get("turn", 0.0)) == 30.0 and String(mask["parts"][1]["material"]) == "walnut" and ep.kept("table"),
		"a thing's field and a part's are written where they live in table.json, kept")
	_show._take_back()
	mask = (ep.read_json("table") as Dictionary)["things"][0]
	_ok(String(mask["parts"][1]["material"]) == "face form" and float(mask.get("turn", 0.0)) == 30.0, "Undo takes the last back")
	# ...more from what there is: a part of a shape there is, a new thing of its own
	dock.inspect({"thing": "mask"})
	var adds := dock._inspector.find_children("*", "MenuButton", true, false).filter(func(m: Node) -> bool: return (m as MenuButton).text.begins_with("+ Part"))
	if not adds.is_empty():
		(adds[0] as MenuButton).get_popup().index_pressed.emit(1)
	var newb := dock._inspector.find_children("*", "Button", true, false).filter(func(b: Node) -> bool: return (b as Button).text == "+ New thing")
	if not newb.is_empty():
		(newb[0] as Button).pressed.emit()
	var after: Dictionary = ep.read_json("table")
	_ok(((after["things"][0] as Dictionary)["parts"] as Array).size() == 3 and String((after["things"][0] as Dictionary)["parts"][2]["shape"]) == String(Props.SHAPES.keys()[1])
		and TableRows.thing_index(after, "new thing") >= 0 and dock.inspected.get("thing", "") == "new thing",
		"a part of a shape there is, and a new thing of its own, each put on and picked")
	dock.inspect({"thing": "candle"})
	_ok(dock._inspector.find_children("*", "Label", true, false).any(func(l: Node) -> bool: return (l as Label).text.contains("not written")),
		"the control: a thing not in the table's data says so")

	# An agent asked about what is picked - never started from a gate: refused with no note, and in a session that may not write
	_ok(_show.ask_about("table", "the mask", "  ") == "write what should change first", "an ask with no note is refused")
	_ok(_show.ask_about("table", "the mask", "make it smaller") == "this session is read-only" and not _show._producer.running,
		"the control: a read-only session asks no agent")

	# The table from above
	var plan := TablePlanView.new()
	var foot := PackedVector2Array([Vector2(-0.05, -0.05), Vector2(0.05, -0.05), Vector2(0.05, 0.05), Vector2(-0.05, 0.05)])
	plan.show_plan({"things": [{"name": "mask", "foot": foot, "bb": Rect2(-0.05, -0.05, 0.1, 0.1), "at": Vector2.ZERO}]})
	plan.size = Vector2(400, 300)
	plan._fit()
	var moved: Array = []
	var picked: Array = []
	plan.moved.connect(func(n: String, at: Vector2) -> void: moved.append([n, at]))
	plan.picked.connect(func(n: String) -> void: picked.append(n))
	var bare := plan.to_control(Vector2(0.3, 0.3))
	plan._gui_input(_press(bare, true))
	plan._gui_input(_press(bare, false))
	_ok(picked.is_empty() and moved.is_empty(), "the control: a click on bare table picks nothing")
	var at := plan.to_control(Vector2.ZERO)
	var to := plan.to_control(Vector2(0.02, 0.0))
	plan._gui_input(_press(at, true))
	var mm := InputEventMouseMotion.new()
	mm.position = to
	plan._gui_input(mm)
	plan._gui_input(_press(to, false))
	var want := TablePlanView.at_cm(Vector2(0.02, 0.0))
	_ok(picked == ["mask"] and moved.size() == 1 and String(moved[0][0]) == "mask" and (moved[0][1] as Vector2).distance_to(want) < 0.2,
		"a thing's foot picked by a click, and a drag hands back where it would stand (%s, want %s)" % [str(moved), want])
	plan.free()

	# The library
	var table: Dictionary = ep.read_json("table")
	_ok(ThingLibrary.keep(table["things"][0], table).is_empty() and ThingLibrary.names() == ["mask"], "a thing is kept in the library")
	var entry := ThingLibrary.read("mask")
	var mats: Dictionary = entry.get("materials", {})
	_ok(mats.has("walnut") and mats.has("face form") and not mats.has("tin"), "with the materials its parts use - the control: not one it does not")
	var on := ThingLibrary.put_on(table, entry, Vector2(-12.0, 4.0))
	var added: Dictionary = (on["things"] as Array).back()
	_ok((on["things"] as Array).size() == (table["things"] as Array).size() + 1 and String(added["name"]) == "mask 2" and added["at"] == [-12.0, 4.0]
		and (on["materials"] as Dictionary).size() == 3, "put on a table it is named its own there, nothing added the table has")
	var bare_table := ThingLibrary.put_on({}, entry)
	_ok((bare_table["materials"] as Dictionary).has("walnut") and String((bare_table["things"][0] as Dictionary)["name"]) == "mask",
		"on a table without its materials, they come with it")

	dock.queue_free()
	_ed.free()
	_rmrf(ProjectSettings.globalize_path(ROOT))
	TableEpisode.root = TableEpisode.ROOT
	ThingLibrary.root = ThingLibrary.DIR
	print("thing_inspector_check: %s" % ("ALL OK" if _fails == 0 else "%d FAILED" % _fails))
	get_tree().quit(0 if _fails == 0 else 1)


func _press(at: Vector2, down: bool) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = at
	return e


func _rmrf(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for d in DirAccess.get_directories_at(path):
		_rmrf(path.path_join(d))
	for f in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	DirAccess.remove_absolute(path)


func _ok(cond: bool, msg: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + msg)
	if not cond:
		_fails += 1
