extends SceneTree

## model_step_check: AN EPISODE THAT BUILDS DESIGNS WHAT IT BUILDS FIRST ([AssemblyModel], [ModelTools], next/assembly.md "The model"; the user, 2026-11-03: "We probably need a proper modeling step ... I just want to have a proper model built by the end of every video"). No renderer, no writer.
##
##   godot --headless --path . --script res://tests/table_show/model_step_check.gd
##
## - THE STEP: a plan that builds has `model` before its table and its acts, which are made from it. Control: a plan that builds nothing has none.
## - AN EPISODE ALREADY MADE GOES ON AS IT WAS: its work was blocked with no model, and it wants none, until its work is blocked again.
## - THE TOOLS: `shape` says what parts it comes to and what floats; a section written again replaces it; `submit` refuses what floats until told twice, too many parts always, and no name; what it hands in lands as `model.json`.
## - WHAT IS HANDED IN STANDS: the table takes the model into itself; the acts begin their last act by finishing it, whatever was written. Control: an episode with no model has neither.
## - ALL OF IT IS IN THE PICTURE: how far a model's top is cut off by the frame is known where its plate stands, part by part, the modeler is told what the lens sees, and the set dresser is asked to move a plate that cuts it. Control: a low one is not cut.
## - WORDS: whoever comes after is told what it is.

const ROOT := "user://model_step_check"
const COLORS := {"red": "#b3261e", "tan": "#c9b185"}

var _fails := 0


func _init() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + what)
	if not cond:
		_fails += 1


func _run() -> void:
	await process_frame
	TableEpisode.root = ROOT
	_steps()
	await _tools()
	_lands()
	_clean()
	TableEpisode.root = TableEpisode.ROOT
	print("model_step_check: %s (%d failure%s)" % ["ALL OK" if _fails == 0 else "FAILED", _fails, "" if _fails == 1 else "s"])
	quit(1 if _fails > 0 else 0)


func _clean() -> void:
	_empty(ProjectSettings.globalize_path(ROOT))


static func _empty(path: String) -> void:
	for d in DirAccess.get_directories_at(path):
		_empty(path.path_join(d))
	for f in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	DirAccess.remove_absolute(path)


func _episode(seed: int, builds: bool) -> TableEpisode:
	var ep := TableEpisode.open("model-show", seed)
	if DirAccess.dir_exists_absolute(ep.dir):
		for f in DirAccess.get_files_at(ep.dir):
			DirAccess.remove_absolute(ep.dir.path_join(f))
	ep.write_json("plan", {"episode_title": "A Thing", "assembly": builds, "build": "a thing", "premise": "x", "look": {}, "staging": {"source": "none"},
		"spread": {"positions": [{"name": "one", "asks": "x", "work": "goes up"}]}, "work_intro": "begins", "work_close": "ends"})
	return ep


const SMALL := {"name": "a block", "size": [16, 16], "colors": COLORS, "base_color": "tan", "sections": [{"name": "the block", "shapes": [{"shape": "box", "from": [2, 2, 0], "to": [9, 9, 8], "color": "red"}]}]}


func _steps() -> void:
	var ep := _episode(1, true)
	var steps := ep.steps()
	_ok(steps.has("model"), "a plan that builds has a model to design: %s" % str(steps))
	_ok(steps.find("model") < steps.find("table") and steps.find("model") < steps.find("acts"), "before its table and its work")
	_ok(ep.needs("table").has("model") and ep.needs("acts").has("model") and ep.needs("model") == ["plan"], "which are made from it")
	_ok(ep.dependents("model").has("table") and ep.dependents("model").has("acts"), "and go with it, when it is designed again")
	var none := _episode(2, false)
	_ok(not none.steps().has("model") and not none.needs("table").has("model"), "control: one that builds nothing has none")
	# ...ALREADY MADE
	var old := _episode(3, true)
	old.write_json("acts", {"acts": [{"name": "a", "beat": "intro", "tracks": [{"law": "assemble", "ops": [{"do": "put", "part": "brick 2x4 red", "at": [0, 0]}]}]}]})
	_ok(not old.steps().has("model") and old.model_words().is_empty(), "an episode whose work was blocked with no model goes on as it was made")
	DirAccess.remove_absolute(old.file_of("acts"))
	_ok(old.steps().has("model"), "and blocking its work again begins from one")


func _tools() -> void:
	var dir := ProjectSettings.globalize_path(ROOT).path_join("job")
	var t := ModelTools.new(dir)
	var got: Dictionary = await t.call_tool("submit", {})
	_ok(got.has("error"), "nothing written, nothing handed in: %s" % String(got["text"]).left(60))
	got = await t.call_tool("shape", {"size": [16, 16], "colors": COLORS, "base_color": "tan", "sections": [{"name": "the block", "about": "a block", "shapes": [{"shape": "box", "from": [2, 2, 0], "to": [9, 9, 8], "color": "red"}]}]})
	_ok(String(got["text"]).contains("parts") and String(got["text"]).contains("the block") and String(got["text"]).contains("straight above"), "`shape` says what it comes to")
	got = await t.call_tool("submit", {})
	_ok(got.has("error") and String(got["text"]).contains("`name`"), "it needs a name")
	await t.call_tool("shape", {"name": "a block"})
	# ...FLOATS
	got = await t.call_tool("shape", {"sections": [{"name": "a cloud", "shapes": [{"shape": "box", "from": [10, 10, 30], "to": [13, 13, 35], "color": "red"}]}]})
	_ok(String(got["text"]).contains("HOLD ON TO NOTHING"), "what floats is said")
	got = await t.call_tool("submit", {})
	_ok(got.has("error") and not t.submitted, "and it is not handed in")
	got = await t.call_tool("shape", {"sections": [{"name": "a cloud", "shapes": [{"shape": "box", "from": [4, 4, 9], "to": [7, 7, 14], "color": "red"}]}]})
	_ok(not String(got["text"]).contains("HOLD ON TO NOTHING") and (t.draft()["sections"] as Array).size() == 2, "a section written again replaces it, where it stands")
	# ...TOO MANY
	var many := ModelTools.new(ProjectSettings.globalize_path(ROOT).path_join("many"))
	await many.call_tool("shape", {"name": "a lot", "size": [48, 48], "colors": COLORS, "base_color": "tan", "sections": [{"name": "dots", "shapes": [{"shape": "where", "if": "mod(x+z, 2) - 0.5", "from": [0, 0, 0], "to": [47, 47, 0], "color": "red", "step": 1}]}]})
	got = await many.call_tool("submit", {})
	_ok(got.has("error") and String(got["text"]).contains("the most anyone could build"), "too many parts is never handed in: %s" % String(got["text"]).left(70))
	got = await t.call_tool("remove", {"names": ["a cloud"]})
	_ok((t.draft()["sections"] as Array).size() == 1, "`remove` takes a section out")
	got = await t.call_tool("submit", {})
	_ok(not got.has("error") and t.submitted, "and what holds is handed in: %s" % String(got["text"]).left(70))
	# ...AS THE PRODUCER LANDS IT
	var ep := _episode(4, true)
	var prod := TableProducer.new(ep, {"title": "Show", "brief": "A brief."})
	var err := prod._land_model(FileAccess.get_file_as_string(dir.path_join(ModelTools.SUBMITTED)))
	_ok(err.is_empty() and ep.has("model"), "what it hands in lands: %s" % err)
	_ok(String(ep.model().get("name", "")) == "a block" and not (ep.model().get("parts", []) as Array).is_empty(), "with its parts, so nothing need work them out again")
	_ok(ep.model_words().contains("THE MODEL: a block") and ep.model_words().contains("\"the block\""), "and whoever comes after can be told what it is: %s" % ep.model_words().get_slice("\n", 0))
	_ok(String(prod._plan().get("model_words", "")).contains("a block"), "and is")
	var empty := prod._land_model("{\"name\": \"nothing\", \"colors\": {\"red\": \"#ff0000\"}, \"sections\": []}")
	_ok(not empty.is_empty(), "control: what comes to no parts does not land: %s" % empty.left(60))
	var one_reply := _episode(4, true)
	var p2 := TableProducer.new(one_reply, {"title": "Show", "brief": "A brief."})
	_ok(p2._land_model(JSON.stringify(SMALL)).is_empty() and not (one_reply.model().get("parts", []) as Array).is_empty(), "a writer with no tools hands it in as one reply, and it is made there")


func _lands() -> void:
	var ep := _episode(4, true)
	var prod := TableProducer.new(ep, {"title": "Show", "brief": "A brief."})
	prod._land_model(JSON.stringify(SMALL))
	var table := {"things": [{"name": "a mug", "at": [10, 10], "parts": [{"shape": "box", "size": [8, 8, 8], "material": "m"}]}], "materials": {"m": {"kind": "painted", "color": "#555555"}}, "assembly": {"stock": [{"name": "the pile", "at": [30, 0], "radius": 8}]}}
	var err := prod._land_table(JSON.stringify(table))
	_ok(err.is_empty(), "a table lands: %s" % err)
	var written: Variant = ep.read_json("table")
	_ok(((written as Dictionary)["assembly"] as Dictionary).has("model"), "with the model in it: every table anywhere stands from that one file")
	var made := Assembly.sanitize((written as Dictionary)["assembly"])
	_ok((made["base"] as Dictionary)["size"] == [16, 16] and (made["colors"] as Dictionary).has("red"), "and its plate and colors are the model's: %s" % str(made["base"]))
	err = prod._land_acts(JSON.stringify({"acts": [
		{"name": "start", "beat": "intro", "tracks": [{"law": "assemble", "ops": [{"do": "build", "parts": 3}]}]},
		{"name": "stop", "beat": "close", "tracks": [{"law": "assemble", "ops": [{"do": "pause", "seconds": 4}]}]}]}))
	_ok(err.is_empty(), "the work lands: %s" % err)
	var acts: Array = (ep.read_json("acts") as Dictionary)["acts"]
	var last_ops: Array = ((acts[1] as Dictionary)["tracks"][0] as Dictionary)["ops"]
	_ok(String((last_ops[0] as Dictionary)["do"]) == "finish", "its last act begins by finishing the model, whatever was written")
	# ...AND ALL OF IT IS IN THE PICTURE
	var lay := CardTable.layout_of(ep.seed)
	var tower := AssemblyModel.make({"name": "a tower", "size": [16, 16], "colors": COLORS, "base_color": "tan", "sections": [{"name": "t", "shapes": [{"shape": "box", "from": [6, 6, 0], "to": [9, 9, 140], "color": "red"}]}]})
	var far := Assembly.sanitize({"model": tower, "base": {"at": [0, -40]}, "stock": []})
	var near := Assembly.sanitize({"model": tower, "base": {"at": [0, 20]}, "stock": []})
	var cut_far := TableAssembly.model_cut_by(far, lay["camera"], float(lay["fov"]))
	var cut_near := TableAssembly.model_cut_by(near, lay["camera"], float(lay["fov"]))
	_ok(cut_far > 0.0, "a tall thing at the far side of the table is cut off by the frame, and it is known by how much: %.0f cm" % (cut_far * 100.0))
	_ok(cut_near < cut_far, "and less, nearer the viewer: %.0f cm" % (cut_near * 100.0))
	var low := Assembly.sanitize({"model": AssemblyModel.make(SMALL), "stock": []})
	_ok(TableAssembly.model_cut_by(low, lay["camera"], float(lay["fov"])) <= 0.0, "control: a low one in the middle of the picture is seen whole")
	_ok(TableAssembly.model_cut_by(Assembly.sanitize({"stock": []}), lay["camera"], float(lay["fov"])) == 0.0, "control: and nothing built is never cut")
	var words: String = TablePrompts.modeler("Show", "a brief", ep.read_json("plan"), ep.seed, [], 24)["prompt"]
	_ok(words.contains("levels up") and not words.contains("{{"), "the modeler is told how tall the lens sees")
	var set_tools := SetDresserTools.new(ep, ep.read_json("plan"), ProjectSettings.globalize_path(ROOT).path_join("set"), "Show", "")
	set_tools._assembly = {"base": {"at": [0, -40]}, "stock": []}
	_ok(set_tools._model_cut() == TableAssembly.model_cut_by(Assembly.sanitize({"base": {"at": [0, -40]}, "stock": [], "model": ep.model()}), lay["camera"], float(lay["fov"])), "and the set dresser's tools ask the same")
	set_tools.release()
	# CONTROL
	var other := _episode(2, false)
	var p3 := TableProducer.new(other, {"title": "Show", "brief": "A brief."})
	p3._land_table(JSON.stringify(table))
	_ok(not (((other.read_json("table") as Dictionary).get("assembly", {}) as Dictionary).has("model")), "control: one with no model has none on its table")
	p3._land_acts(JSON.stringify({"acts": [{"name": "stop", "beat": "close", "tracks": [{"law": "assemble", "ops": [{"do": "pause", "seconds": 4}]}]}]}))
	_ok(not str(other.read_json("acts")).contains("finish"), "and nothing to finish")
