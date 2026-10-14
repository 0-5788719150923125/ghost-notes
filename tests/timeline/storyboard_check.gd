extends SceneTree

## storyboard_check - a storyboard as DATA a note keeps and an editor edits (next/storyboard.md):
## the pure half, with no autoload and no window.
##
##   godot --headless --path . --script tests/timeline/storyboard_check.gd
##
## AN EDIT IS A NEW TREE ([DataPath]): put, cut, insert and move each return a root of their own
## and leave the one they were handed exactly as it was - held to a copy made before, value for
## value - and the result shares no container with it (an edit made to the result in place never
## reaches the original). A path that leads nowhere changes nothing.
##
## A NOTE'S BLOCK IS READ THREE WAYS ([method Storyboard.of_block]): its own storyboard (a
## `sequence`, even an empty one), a file's name, or nothing written. The block a note writes
## round-trips through the YAML the frontmatter is written in, and through [method
## Storyboard.to_yaml] / [method Storyboard.from_yaml], which the editor's source view uses.
##
## A STORYBOARD TAKEN INTO A NOTE PLAYS AS THE FILE DID: the raw tree read from
## `storyboards/default.yaml`, kept as a note's block and loaded from there, is the loaded form
## the file gives - entry for entry. Loading never changes the raw tree it is handed. And the
## loaded form, written out for a render ([method Storyboard.raw_of]) and loaded there, is the
## same storyboard again.
##
## THE SCHEDULE is the arithmetic the Director walked before it moved here, held to numbers
## worked by hand: a fixed hold over its tempo, a cue's least hold, the unauthored fallback, and
## the half-second floor.
##
## THE CONTROLS, without which a pass proves nothing: a storyboard with a nameless entry is
## refused with a message that says where; YAML that does not parse is refused; a `use` of a def
## that is not there is refused; and a deliberately aliasing "edit" (the in-place write DataPath
## exists to prevent) is caught by the same comparison that passes the real ones.

var _fails: Array = []


func _initialize() -> void:
	_paths()
	_blocks()
	_library()
	_schedule()
	_timing()
	_schema()
	if _fails.is_empty():
		print("storyboard_check: ALL OK")
		quit(0)
		return
	print("storyboard_check: %d FAILURE(S)" % _fails.size())
	for f in _fails:
		print("   ", f)
	quit(1)


func _ok(cond: bool, msg: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + msg)
	if not cond:
		_fails.append(msg)


func _board() -> Dictionary:
	return {"loop": false, "sequence": [
		{"scene": "aurora", "hold": 4},
		{"scene": "stage", "hold": 6, "cast": [{"id": "a", "kind": "eye", "at": [0, 0, 0]}],
			"track": {"nominal": 6, "spans": [{"at": 1.0, "action": "blink", "target": "a"}]}},
		{"scene": "embers", "exit": "beat", "min_hold": 3, "max_hold": 9}]}


func _paths() -> void:
	print("-- an edit is a new tree")
	var root := _board()
	var before := root.duplicate(true)
	var put: Dictionary = DataPath.put(root, ["sequence", 0, "hold"], 9)
	_ok(DataPath.at(put, ["sequence", 0, "hold"]) == 9, "put writes the value at the path")
	_ok(DataPath.same(root, before), "...and leaves the tree it was handed as it was")
	(put["sequence"] as Array)[1]["hold"] = 99
	_ok(DataPath.same(root, before), "the result shares no container with the original")
	var deep: Dictionary = DataPath.put(root, ["sequence", 1, "track", "spans", 0, "at"], 2.5)
	_ok(is_equal_approx(float(DataPath.at(deep, ["sequence", 1, "track", "spans", 0, "at"])), 2.5),
		"a path five levels down is reached")
	var made: Dictionary = DataPath.put(root, ["sequence", 0, "camera", "fov"], 60)
	_ok(DataPath.at(made, ["sequence", 0, "camera", "fov"]) == 60, "put makes the maps a path names on its way down")
	var appended: Dictionary = DataPath.put(root, ["sequence", 3], {"scene": "rainfall"})
	_ok((appended["sequence"] as Array).size() == 4, "an index one past the end appends")
	var nowhere: Dictionary = DataPath.put(root, ["sequence", 9, "hold"], 1)
	_ok(DataPath.same(nowhere, before), "a path that leads nowhere changes nothing")
	var cut: Dictionary = DataPath.cut(root, ["sequence", 1])
	_ok((cut["sequence"] as Array).size() == 2 and String(cut["sequence"][1]["scene"]) == "embers",
		"cut removes a list's item")
	var cut_key: Dictionary = DataPath.cut(root, ["sequence", 0, "hold"])
	_ok(not (cut_key["sequence"][0] as Dictionary).has("hold"), "...and erases a map's key")
	_ok(DataPath.same(DataPath.cut(root, ["sequence", 7]), before), "cutting what is not there changes nothing")
	var ins: Dictionary = DataPath.insert(root, ["sequence"], 1, {"scene": "fog_bank"})
	_ok(String(ins["sequence"][1]["scene"]) == "fog_bank" and (ins["sequence"] as Array).size() == 4,
		"insert puts an item before an index")
	var ins_new: Dictionary = DataPath.insert(root, ["tail"], 0, {"scene": "motes"})
	_ok((ins_new.get("tail", []) as Array).size() == 1, "...and makes the list when there is none")
	var moved: Dictionary = DataPath.move(root, ["sequence"], 0, 2)
	_ok(String(moved["sequence"][2]["scene"]) == "aurora" and String(moved["sequence"][0]["scene"]) == "stage",
		"move takes an item to another place")
	_ok(DataPath.same(root, before), "after every edit above, the original is still as it was")
	_ok(DataPath.same({"a": 4, "b": [1, 2.0]}, {"b": [1.0, 2], "a": 4.0}), "same: maps by key, numbers by value")
	_ok(not DataPath.same([1, 2], [2, 1]), "same: lists in order")
	# THE CONTROL: an edit made in place IS seen by this comparison
	var aliased := root
	(aliased["sequence"] as Array)[0]["hold"] = 123
	_ok(not DataPath.same(root, before), "the control: an in-place write is caught as a changed original")


func _blocks() -> void:
	print("-- what a note's block holds")
	_ok(String(Storyboard.of_block(null)["kind"]) == "none", "no block is nothing written")
	_ok(String(Storyboard.of_block({})["kind"]) == "none", "an empty block is nothing written")
	var file := Storyboard.of_block({"storyboard": "default"})
	_ok(String(file["kind"]) == "file" and String(file["name"]) == "default", "a name is a file's")
	var empty := Storyboard.of_block({"sequence": []})
	_ok(String(empty["kind"]) == "own", "an empty sequence is the note's own storyboard, with nothing in it yet")
	var own := Storyboard.of_block(Storyboard.own_block(_board()))
	_ok(String(own["kind"]) == "own" and DataPath.same(own["data"], _board()), "a block with a sequence is the note's own")
	_ok(Storyboard.own_block({"sequence": [], "junk": 1}).keys() == ["sequence"], "a block keeps the storyboard's keys and no others")
	_ok(Storyboard.own_block({"tail": [], "sequence": [], "loop": true}).keys() == ["loop", "sequence", "tail"],
		"...in the spec's order, whatever order they were given in")
	# through the YAML a note's frontmatter is written in
	var text := MiniYaml.emit({"ghost": {"scenes": Storyboard.own_block(_board())}})
	var back := MiniYaml.parse(text)
	_ok(back.ok and DataPath.same(back.data["ghost"]["scenes"], Storyboard.own_block(_board())),
		"the block round-trips through the frontmatter's YAML")
	var src := Storyboard.to_yaml(_board())
	var from := Storyboard.from_yaml(src)
	_ok(bool(from["ok"]) and DataPath.same(from["data"], _board()), "...and through the editor's source view")
	var bad := Storyboard.from_yaml("sequence:\n  - hold: 3\n")
	_ok(not bool(bad["ok"]) and String(bad["error"]).contains("sequence[0]") and String(bad["error"]).contains("scene"),
		"the control: an entry with no scene is refused, and the message says where (%s)" % String(bad["error"]))
	var unparsed := Storyboard.from_yaml("sequence: [unclosed\n")
	_ok(not bool(unparsed["ok"]), "the control: text that is not YAML is refused (%s)" % String(unparsed["error"]))
	var no_def := Storyboard.from_data({"sequence": [{"scene": "stage", "camera": {"use": "nope"}}]}, Storyboard.IN_NOTE)
	_ok(not bool(no_def["ok"]) and String(no_def["error"]).contains("nope"), "the control: a use of a def that is not there is refused")
	_ok(bool(Storyboard.from_yaml("sequence: []\n")["ok"]), "an empty storyboard is allowed: nothing is written in it yet")
	_ok(not bool(Storyboard.from_data({"sequence": []}, Storyboard.IN_NOTE)["ok"]), "...but it loads as no storyboard, so the seeded show plays")


func _library() -> void:
	print("-- a file taken into a note plays as the file did")
	for name in ["default", "showcase"]:
		var raw := Storyboard.read_raw(name)
		_ok(bool(raw["ok"]), "%s is read as it is written" % name)
		if not bool(raw["ok"]):
			continue
		var held: Dictionary = (raw["data"] as Dictionary).duplicate(true)
		var from_file := Storyboard.load_file(name)
		# as a note would keep it: its block, written to YAML and read back
		var block := Storyboard.own_block(raw["data"])
		var parsed := MiniYaml.parse(MiniYaml.emit({"scenes": block}))
		_ok(parsed.ok, "%s's block is YAML the frontmatter can hold" % name)
		var own := Storyboard.of_block(parsed.data["scenes"] if parsed.ok else {})
		var from_note := Storyboard.from_data(own["data"], Storyboard.IN_NOTE)
		_ok(bool(from_note["ok"]), "%s loads from a note's block (%s)" % [name, String(from_note["error"])])
		for k in ["name", "loop", "transition", "sensitivity", "sequence", "tail"]:
			_ok(DataPath.same(from_note.get(k), from_file.get(k)), "%s: '%s' is the file's, value for value" % [name, k])
		_ok(DataPath.same(raw["data"], held), "%s: loading left the raw tree as it was" % name)
		# what a render is handed: the loaded form, written out as a tree and loaded again
		var handed := Storyboard.from_yaml(Storyboard.to_yaml(Storyboard.raw_of(from_file)))
		var rendered := Storyboard.from_data(handed["data"], "a render's")
		_ok(bool(handed["ok"]) and bool(rendered["ok"]), "%s: the loaded form can be written out for a render" % name)
		for k in ["loop", "transition", "sensitivity", "sequence", "tail"]:
			_ok(DataPath.same(rendered.get(k), from_file.get(k)), "%s: a render's '%s' is the session's" % [name, k])
		_ok((raw["data"] as Dictionary).has("defs") == (block as Dictionary).has("defs"), "%s: its defs came along" % name)


func _schedule() -> void:
	print("-- the schedule")
	var seq := [{"scene": "a", "hold": 6}, {"scene": "b", "exit": "beat", "min_hold": 3},
		{"scene": "c"}, {"scene": "d", "hold": 6, "sensitivity": 3.0}, {"scene": "e", "hold": 0.1}]
	var s := Storyboard.schedule(seq, 2.0, 8.0)
	var want_len := [3.0, 1.5, 4.0, 2.0, 0.5]
	var want_start := [0.0, 3.0, 4.5, 8.5, 10.5]
	for i in seq.size():
		_ok(is_equal_approx(float(s["lengths"][i]), float(want_len[i])) and is_equal_approx(float(s["starts"][i]), float(want_start[i])),
			"entry %d: starts at %.1f and holds %.1f (got %.2f, %.2f)" % [i, want_start[i], want_len[i], s["starts"][i], s["lengths"][i]])
	_ok(is_equal_approx(float(s["end"]), 11.0), "the sequence ends at 11.0 (%.2f)" % float(s["end"]))
	_ok(is_equal_approx(float(Storyboard.schedule([], 1.0, 8.0)["end"]), 0.0), "an empty sequence has no length")


func _timing() -> void:
	print("-- how an entry is timed")
	_ok(Storyboard.timing_of({"scene": "a", "hold": 4}) == "hold", "a hold is a fixed time")
	_ok(Storyboard.timing_of({"scene": "a", "exit": "lull"}) == "cue", "an exit is a cue")
	_ok(Storyboard.timing_of({"scene": "a", "min_hold": 2}) == "own", "neither is the scene's own")
	var e := {"scene": "a", "hold": 4, "shot": "pan"}
	var cue := Storyboard.with_timing(e, "cue")
	_ok(not cue.has("hold") and String(cue.get("exit", "")) == "beat" and String(cue["shot"]) == "pan",
		"timed on a cue: the hold is dropped, a cue is named, and nothing else is touched (%s)" % str(cue))
	_ok(e.has("hold"), "...and the entry it was made from is as it was")
	var held := Storyboard.with_timing({"scene": "a", "exit": "beat", "min_hold": 2, "max_hold": 9}, "own")
	_ok(not held.has("exit") and held.has("min_hold") and held.has("max_hold"), "the scene's own keeps the bounds it shares with a cue")
	var fixed := Storyboard.with_timing(held, "hold")
	_ok(fixed.has("hold") and not fixed.has("min_hold") and not fixed.has("max_hold"), "a fixed time drops them")
	var stage := Storyboard.new_entry("stage")
	_ok(bool(Storyboard.from_data({"sequence": [stage]}, Storyboard.IN_NOTE)["ok"]), "a new stage entry is one that loads")
	_ok(Storyboard.new_entry("aurora") == {"scene": "aurora"}, "a new entry of any other scene is its name alone")


func _schema() -> void:
	print("-- the fields")
	for table in [["BOARD", Storyboard.BOARD], ["ENTRY", Storyboard.ENTRY], ["TIMING_FIELDS", Storyboard.TIMING_FIELDS],
			["STAGE", Storyboard.STAGE], ["CAMERA", Storyboard.CAMERA], ["ACTOR", Storyboard.ACTOR], ["SPAN", Storyboard.SPAN]]:
		for key in (table[1] as Dictionary):
			var row: Dictionary = table[1][key]
			var ok := row.has("label") and row.has("type") and row.has("default") and not String(row.get("blurb", "")).is_empty()
			if String(row["type"]) == "enum":
				ok = ok and row.get("options") is Array and not (row["options"] as Array).is_empty()
			if String(row["type"]) == "float":
				ok = ok and row.has("min") and row.has("max") and row.has("step")
			_ok(ok, "%s.%s says what it is" % [table[0], key])
	for key in Storyboard.BOARD:
		_ok(Storyboard.KEYS.has(key), "the storyboard's field '%s' is a key a note writes" % key)
	for t in Storyboard.TIMINGS:
		for k in (Storyboard.TIMINGS[t]["keys"] as Array):
			_ok(Storyboard.TIMING_FIELDS.has(k), "the %s timing's key '%s' has a field" % [t, k])
