extends SceneTree

## script_whole_check - THE SCRIPT IS ONE TEXT (next/editing.md, design point 3; [method CardReading.split],
## [method TableProducer.write_script]).
##
##   godot --headless --path . --script res://tests/table_show/script_whole_check.gd
##
## On a cardless episode of its own (never the author's):
##   - what compose joined, split gives back: the marks and each passage's words;
##   - one passage's words edited inside the whole script are written to that passage alone - a hand's version, kept, what
##     stood a version back - and the script put together again is the text as edited;
##   - THE CONTROLS: a script with a mark taken out, and one with words before its first mark, are refused, and no passage
##     is written.

const ROOT := "user://script_whole_check"

var _fails := 0


func _initialize() -> void:
	AgentJobs.allow_for_tool(false)        # read-only: nothing here may start an agent
	TableEpisode.root = ROOT
	# (its whole folder cleared first: a run that died left an episode begun by hand, and the next run's begin was refused)
	_rmrf(ProjectSettings.globalize_path(ROOT))
	var ep := TableEpisode.open("whole-show", 5)
	ep.write_json("plan", {"episode_title": "Whole", "spread": {"name": "", "positions": [{"name": "One"}, {"name": "Two"}]},
		"staging": {"source": "none"}, "look": CardTable.sanitize_look({})})
	ep.write_text("say:intro", "Hello there.")
	ep.write_text("say:1", "The first beat's words.")
	ep.write_text("say:2", "The second beat's words.")
	ep.write_text("say:close", "Goodbye.")
	var prod := TableProducer.new(ep, {})
	_ok(prod._make_script().is_empty() and ep.has("script"), "the script is put together")
	var script := ep.read_text("script")
	var parts := CardReading.split(script)
	_ok(CardReading.compose(parts.slice(1)) == script and String((parts[0] as Dictionary)["text"]).is_empty(),
		"what compose joined, split gives back (%d marks)" % (parts.size() - 1))
	var edited := script.replace("The first beat's words.", "The first beat, said again by hand.")
	var before := ep.versions("say:1").size()
	_ok(prod.write_script(edited).is_empty(), "the script edited whole is taken")
	_ok(ep.read_text("say:1") == "The first beat, said again by hand." and ep.kept("say:1") and ep.versions("say:1").size() == before + 1,
		"one passage's words are written to it alone, kept, what stood a version back: %s" % ep.read_text("say:1"))
	_ok(ep.read_text("say:2") == "The second beat's words." and not ep.kept("say:2"), "the passages not edited are left as they were")
	_ok(ep.read_text("script") == edited, "the script put together again is the text as edited")
	# THE CONTROLS
	var marks := RegEx.create_from_string("(?m)^<!-- table: work 2 -->\\n")
	var cut := marks.sub(edited, "")
	_ok(cut != edited and not prod.write_script(cut).is_empty() and ep.read_text("say:2") == "The second beat's words.",
		"the control: a script with a mark taken out is refused, and nothing is written")
	_ok(not prod.write_script("Words first.\n\n" + edited).is_empty(), "the control: words before the first mark are refused")
	# ASKED AGAIN WITH A NOTE (next/editing.md step 9): the author's note goes on that step's prompt alone
	prod.asked = {"say:1": "Say it in half the words."}
	var p1 := prod._asked("say:1", "THE PROMPT")
	_ok(p1.begins_with("THE PROMPT") and p1.contains("Say it in half the words.") and p1.contains("ASKS FOR IT AGAIN"),
		"a step asked again with a note carries it on its own prompt")
	_ok(prod._asked("say:2", "THE PROMPT") == "THE PROMPT", "the control: another step's prompt is as it was")
	# BEGUN BY HAND (next/editing.md step 8): every part made by a hand and kept, the pictures it has not got waiting for one -
	# Generate passes them by; THE CONTROL a ⟳ asking for one, which it does not
	var hand := TableEpisode.open("whole-show", 6)
	var fixed := {"things": [{"name": "the mask", "shapes": []}]}
	_ok(hand.begin_by_hand(2, fixed).is_empty() and hand.has("plan") and hand.has("say:2") and hand.has("script") and hand.cardless(),
		"an episode begun by hand: a plan of two beats drawing no cards, its passages and its script")
	_ok(((hand.read_json("table") as Dictionary)["things"] as Array).size() == 1, "its table stands the brief's fixed things")
	_ok(hand.by_hand("say:1") and hand.kept("say:1") and String(hand.record("say:1")["by"]) == "hand" and not hand.by_hand("script"),
		"each part made by a hand, kept; the script put together, not a hand's")
	var hp := TableProducer.new(hand, {})
	_ok(not hand.has("image:surface") and hand.by_hand("image:surface") and hp.passes_by("image:surface"),
		"a picture it has not got waits for a hand: Generate passes it by")
	hp.again = ["image:surface"]
	_ok(not hp.passes_by("image:surface"), "the control: a ⟳ asking for it is not passed by")
	_ok(not hand.begin_by_hand().is_empty(), "an episode begun is not begun again")
	# THE WAY BACK, WHERE KEEP A COPY WAS (the Body card's Restore): a passage changed is listed among the episode's step versions,
	# and put back is the words as they were, kept, what changed since a version back - THE CONTROL: a version not there is refused
	ep.write_text("say:2", "Changed after the first words.")
	var listed := ep.step_versions().filter(func(v: Dictionary) -> bool: return String((v["key"] as Array)[0]) == "say:2")
	var back := ep.versions("say:2").size()
	_ok(not listed.is_empty() and float(listed[0]["at"]) > 0.0, "a passage changed is listed among the episode's step versions (%d)" % listed.size())
	_ok(not listed.is_empty() and ep.restore("say:2", int((listed[0]["key"] as Array)[1])).is_empty()
		and ep.read_text("say:2") == "The second beat's words." and ep.kept("say:2") and ep.versions("say:2").size() == back + 1,
		"put back: the words as they were, kept, what changed since a version back")
	_ok(not ep.restore("say:2", 99).is_empty(), "the control: a version that is not there is not put back")
	# THE HOST'S MAPS ONE BACK (TableProducer.swap_paint): the new put in place, the old kept, the one before that gone
	for pass_n in [1, 2, 3]:
		var fresh := ep.dir.path_join(TableProducer.PAINT_NEXT)
		DirAccess.make_dir_recursive_absolute(fresh)
		var m := FileAccess.open(fresh.path_join("elements.json"), FileAccess.WRITE)
		m.store_string("{\"pass\": %d}" % pass_n)
		m.close()
		_ok(prod.swap_paint(fresh).is_empty(), "the host's maps put in place (pass %d)" % pass_n)
	var prev := ep.dir.path_join("versions/_paint_prev/elements.json")
	_ok(FileAccess.get_file_as_string(ep.dir.path_join("paint/elements.json")).contains("3") and FileAccess.get_file_as_string(prev).contains("2")
		and not DirAccess.dir_exists_absolute(ep.dir.path_join(TableProducer.PAINT_NEXT)), "the new maps stand, the last kept one back, the one before that gone")
	# ONE LAYER LAID AGAIN (TableProducer.lay_layer): refused where there is no such layer; THE CONTROL a start without one lays the whole
	_ok(not prod.lay_layer(1).is_empty() and prod.skin_layer == -1, "a layer the episode has not got is not laid again")
	# (the agents' queue read-only here, as a gate's must be: the start lands nothing and starts no agent - bedrock_check's seam)
	AgentJobs.allow_for_tool(false)
	prod.skin_layer = 3
	prod.start(["say:1"], true)
	prod.stop()
	AgentJobs.allow_for_tool(false)
	_ok(prod.skin_layer == -1, "the control: any other start lays the whole painting, never a layer left over")
	# ...AND THE DESIGN AFTER IT (TableProducer.merged_layer): the other layers as they stood, a hand's edits kept, this one's anew
	var stood := {"designs": [{"elements": [{"id": "a", "stage": "base"}, {"id": "b2", "stage": "rust", "plan": {"seconds": 3.0}},
		{"id": "c", "stage": "lines"}]}]}
	var fresh := [{"id": "a", "stage": "base"}, {"id": "n1", "stage": "rust"}, {"id": "n2", "stage": "rust"}, {"id": "c", "stage": "lines"},
		{"id": "x", "stage": "lines"}]
	var merged := TableProducer.merged_layer(stood, fresh, [{"name": "base"}, {"name": "rust"}, {"name": "lines"}], 1)
	_ok(merged.map(func(e: Dictionary) -> String: return String(e["id"])) == ["a", "n1", "n2", "c"],
		"the other layers as they stood (a hand's edits kept), this one's new elements in its place: %s" % str(merged.map(func(e: Dictionary) -> String: return String(e["id"]))))
	_rmrf(ProjectSettings.globalize_path(ROOT))
	TableEpisode.root = TableEpisode.ROOT
	if _fails == 0:
		print("script_whole_check: ALL OK")
		quit(0)
		return
	print("script_whole_check: %d FAILED" % _fails)
	quit(1)


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
