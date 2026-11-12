extends Node

## timeline_dock_check - any show's timeline, docked ([TimelineDock]; next/editing.md, "The Timeline").
##
##   tests/run_boot_probe.sh tests/timeline/timeline_dock_check.gd 60
##
## On an episode of its own (a cardless fixture under its own root), read as a Timeline
## ([method TableEpisode.timeline]) and docked:
##   - its groups are flags on the strip across the whole show, the first picked, its acts and cues on the lanes below;
##   - a group picked by its flag shows its own items; a moment scrubbed to picks the group it falls in, and is asked for;
##   - a group is read as a stage entry's track: a span from/to, a flag at, aimed at its lane;
##   - an act's block stretched is its length in `acts.json`, a cue's flag moved its place in the words, each
##     kept with what stood a version back (control: with no one to write it, the dock is read-only);
##   - one inspector: a block picked is shown at the right, by the owner where there is one (control: with none, the dock says
##     what the item is); what the owner picks elsewhere is shown there too; Undo is the owner's, what it could not do said;
##   - the playhead is the show's clock, the strip scrubbed moves the show; every item in order, a row a press
##     (the group picked, the item inspected, the show moved there); the panel's Timeline card lists them while a dock is open
##     (control: none open, no card); a flag's name is its tooltip, never drawn; the transport's Timeline button is the highest
##     offer standing (control: an offerer gone is not offered);
##   - control: a timeline with a fault says so over the strip, and a sound one says nothing.

const ROOT := "user://timeline_dock_check"

var _fails := 0


func _ready() -> void:
	TableEpisode.root = ROOT
	var ep := TableEpisode.open("dock-show", 3)
	_rmrf(ep.dir)
	ep.write_json("plan", {"episode_title": "Docked", "spread": {"name": "", "positions": [{"name": "The Hook"}, {"name": "The Turn"}]},
		"staging": {"source": "none"}, "look": CardTable.sanitize_look({})})
	ep.write_text("say:intro", "We begin here today.")
	ep.write_text("say:1", "One two <!-- act: base --> three.")
	ep.write_json("acts", {"acts": [{"name": "base", "beat": "1", "length": 6.0, "tracks": [{"law": "to", "thing": "sponge"}]},
		{"name": "rinse", "beat": "1", "length": 2.0, "tracks": [{"law": "to", "thing": "cup"}]},
		{"name": "wipe", "beat": "2", "length": 4.0, "tracks": [{"law": "to", "thing": "towel"}]}]})
	var tl := ep.timeline()
	var dock := TimelineDock.new()
	dock.open(tl, "Docked")
	add_child(dock)
	await get_tree().process_frame
	_ok(dock._flags.size() == 4 and dock.picked == 0, "its groups are flags across the show, the first picked (%d flags)" % dock._flags.size())
	dock._groups.marker_picked.emit(dock._flags[1])
	var spans: Array = dock._lanes.spans
	_ok(dock.picked == 1 and spans.size() == 3 and dock._lanes._rows.size() == 2 and dock._lanes._flags.size() == 1,
		"beat 1 picked by its flag: two acts as blocks, its cue a flag (%d spans, %d blocks, %d flags)" % [spans.size(), dock._lanes._rows.size(), dock._lanes._flags.size()])
	var sought: Array = []
	dock.sought.connect(func(t: float) -> void: sought.append(t))
	var g2: Dictionary = tl["groups"][2]
	dock._groups.scrubbed.emit(float(g2["start"]) + 1.0)
	_ok(dock.picked == 2 and sought.size() == 1, "a moment scrubbed to picks the beat it falls in, and is asked for")
	var tr := TimelineDock.as_track(tl["groups"][1])
	_ok((tr["actors"] as Array).has("sponge") and (tr["spans"] as Array).any(func(s: Dictionary) -> bool: return s.has("from") and String(s["target"]) == "sponge")
		and (tr["spans"] as Array).any(func(s: Dictionary) -> bool: return s.has("at") and String(s["target"]) == "words"),
		"a group read as a stage entry's track: spans from/to, flags at, aimed at their lanes")
	_ok(not dock._problems.visible, "a sound timeline says nothing over the strip")
	# Worked there (the owner writes): the act stretched to 9 s and the cue moved to the first word, each a hand's version
	_ok(dock._lanes.read_only, "the control: with no one to write it, the dock is read-only")
	dock.edit = func(it: Dictionary, from: float, to: float) -> String:
		var src: Array = it["source"]
		var err := ep.set_act_length(int(src[1]), to - from) if String(src[0]) == "acts" \
			else ep.move_cue(String(src[0]), int(src[2]), from - float(it.get("passage_at", 0.0)))
		if err.is_empty():
			dock.reload(ep.timeline())
		return err
	dock.pick(1)
	var base := -1
	var cue := -1
	for i in dock._items.size():
		if String((dock._items[i] as Dictionary)["label"]) == "base" and String((dock._items[i] as Dictionary)["kind"]) == "span":
			base = i
		if String((dock._items[i] as Dictionary)["kind"]) == "flag":
			cue = i
	dock._lanes.retimed.emit(base, 0.0, 9.0)
	var acts: Dictionary = ep.read_json("acts")
	_ok(not dock._lanes.read_only and is_equal_approx(float(acts["acts"][0]["length"]), 9.0) and ep.kept("acts") and not ep.versions("acts").is_empty(),
		"an act's block stretched is its length in acts.json, kept, what stood a version back")
	dock._lanes.retimed.emit(cue, 0.0, 0.0)
	_ok(ep.read_text("say:1").begins_with("<!-- act: base -->") and ep.kept("say:1") and dock.picked == 1,
		"a cue's flag moved to the start puts its mark before the first word, the passage kept: %s" % ep.read_text("say:1"))
	# One inspector: a block picked is shown at the right - by itself with no owner to fill it (control), else by the owner,
	# handed the item; what the owner picks elsewhere too; and undo is the owner's, what it could not do said over the timeline
	dock.pick(1)
	dock._lanes.picked.emit(base)
	var said_alone := dock._inspector.get_children().any(func(c: Node) -> bool: return c is Label and (c as Label).text.contains("base"))
	_ok(String((dock.inspected.get("item", {}) as Dictionary).get("label", "")) == "base" and said_alone,
		"the control: a block picked with no owner to fill the inspector says what it is")
	var asked: Array = []
	dock.inspector = func(what: Dictionary, box: VBoxContainer) -> void:
		asked.append(what)
		var l := Label.new()
		l.text = "the owner's"
		box.add_child(l)
	dock._lanes.picked.emit(cue)
	dock.inspect({"thing": "cup"})
	_ok(asked.size() == 2 and String(((asked[0] as Dictionary)["item"] as Dictionary)["kind"]) == "flag" and String((asked[1] as Dictionary).get("thing", "")) == "cup",
		"the owner fills it: handed the flag picked, and the thing it picked elsewhere")
	var undone := [0]
	dock.undo = func() -> String:
		undone[0] += 1
		return "" if undone[0] == 1 else "nothing left"
	dock.reload(dock.timeline)
	_ok(dock._undo_b.visible and dock.take_back().is_empty() and undone[0] == 1 and not dock._said.visible, "Undo is the owner's, and done says nothing")
	_ok(dock.take_back() == "nothing left" and dock._said.visible and dock._said.text.contains("nothing left"),
		"the control: what it could not take back is said over the timeline")
	# The show's time: the playhead is the show's clock, on the strip and inside the group picked; the strip scrubbed moves the show
	var g1: Dictionary = dock.timeline["groups"][1]
	dock.clock = func() -> float: return float(g1["start"]) + 1.0
	await get_tree().process_frame
	await get_tree().process_frame
	_ok(is_equal_approx(dock.playhead, float(g1["start"]) + 1.0) and (dock.picked != 1 or is_equal_approx(dock._lanes.playhead, 1.0)),
		"the playhead is the show's own (%.2f), and inside the group picked (%.2f)" % [dock.playhead, dock._lanes.playhead])
	var asked_t: Array = []
	dock.seek = func(t: float) -> void: asked_t.append(t)
	dock._groups.scrubbed.emit(2.5)
	_ok(asked_t == [2.5], "the strip scrubbed moves the show there (%s)" % str(asked_t))
	# Every item in order, a row a press: the group picked, the item in the inspector, the show moved to it
	var all := dock.timeline_items()
	var ordered := true
	for k in range(1, all.size()):
		if int(all[k]["group"]) == int(all[k - 1]["group"]) and float(all[k]["at"]) < float(all[k - 1]["at"]):
			ordered = false
	var first_item := -1
	for k in all.size():
		if String(all[k]["kind"]) != "group" and int(all[k]["group"]) == 2:
			first_item = k
			break
	asked_t.clear()
	dock.pick_item(first_item)
	_ok(ordered and first_item >= 0 and dock.picked == 2 and dock.inspected.get("item") == all[first_item]["item"] and asked_t.size() == 1
		and is_equal_approx(asked_t[0], float(all[first_item]["at"])), "every item in the order it comes; a row picks it and moves the show to it")
	# The panel's Timeline card: the open editor's items, a row a press - control: no editor open, no card
	var card := Card.new("check.timeline", "Timeline", &"picture")
	add_child(card)
	var list := TimelineList.new()
	card.body.add_child(list)
	list.refresh()
	_ok(card.visible and list.row_count() == all.size(), "the panel's Timeline card lists the open timeline (%d rows)" % list.row_count())
	asked_t.clear()
	list.press(first_item)
	_ok(asked_t.size() == 1, "a row of it pressed goes there")
	# A flag's name is its tooltip, never drawn beside it
	var f0: Dictionary = dock._flags[1]
	var tip := dock._groups._get_tooltip(Vector2(dock._groups.tview.x_of(float(f0["time"])), 4.0))
	_ok(tip.contains(String(f0["label"])) and dock._groups._get_tooltip(Vector2(-500.0, 4.0)).is_empty(),
		"a flag's name is its tooltip (%s); the control: away from any flag, none" % tip)
	# The transport's button stands for the highest offer standing - control: an offerer gone is not offered
	var low := Node.new()
	var high := Node.new()
	add_child(low)
	add_child(high)
	Transport.offer_timeline(low, 1, func() -> void: pass, func() -> bool: return false, "low")
	Transport.offer_timeline(high, 3, func() -> void: pass, func() -> bool: return false, "high")
	var best := String(Transport.offered().get("tip", ""))
	high.queue_free()
	await get_tree().process_frame
	_ok(best == "high" and String(Transport.offered().get("tip", "")) == "low", "the timeline's button is the highest offer standing; one gone is not")
	Transport.withdraw_timeline(low)
	low.queue_free()
	var bad := tl.duplicate(true)
	(bad["groups"][0] as Dictionary)["engine"] = "dream"
	dock.open(bad, "Docked")
	_ok(dock._problems.visible and dock._problems.text.contains("dream"), "the control: a fault is said over the strip (%s)" % dock._problems.text)
	dock.queue_free()
	await get_tree().process_frame
	list.refresh()
	_ok(not card.visible, "the control: no timeline open, no Timeline card")
	card.queue_free()
	_rmrf(ProjectSettings.globalize_path(ROOT))
	TableEpisode.root = TableEpisode.ROOT
	if _fails == 0:
		print("timeline_dock_check: ALL OK")
		get_tree().quit(0)
		return
	print("timeline_dock_check: %d FAILED" % _fails)
	get_tree().quit(1)


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
