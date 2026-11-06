extends SceneTree

## The gate of WHAT IS PAINTED, DESIGNED ([DecoratorTools], [Skins], [FixedTable]; next/painted_surface.md), with no renderer.
##
##   godot --headless --path . --script res://tests/table_show/skin_step_check.gd
##
## - THE STEP: a plan that says what is `painted` designs it after the table is set and before the work is blocked (`skin`, needing the
##   plan and the table; the acts need it); redoing it throws the acts away. The controls: a plan that paints nothing has no such step,
##   and an episode whose work was blocked before there were designs goes on without one.
## - A TABLE'S SURFACES: a mask with `skin` is a surface 150 x 210 mm with its outline and its landmarks. The control: a table with no
##   `skin` has none.
## - THE DECORATOR'S TOOLS: `design` writes elements and replaces one of the same id where it stands; an element mostly off the surface is
##   said, and stops `submit` once; `look` draws the design on the surface on the processor; what is handed in lands as `skin.json` with its
##   surface's frame and outline, and the puppeteer is told it element by element. The controls: nothing written hands nothing in; a
##   design with no name is not handed in. An element in nearly the color and finish of what it is laid over is said HARDLY SEEN (a
##   base in the bare surface's own color, never a gloss over its own red); the control, a white base, is not.
## - A SHOW'S FIXED THINGS: the brief's fenced JSON under its heading is read, the agents read a line in its place, and a table handed in
##   is given them whatever it wrote - a thing of the same name replaced. The set dresser starts with them standing and can neither put
##   them again, move them nor take them away. The control: a brief with no such heading fixes nothing and reads as it was.
## - EVERY PROMPT RENDERS WHOLE: the decorator's, with tools and without; the puppeteer's told the design; the set dresser's told what is
##   painted and what stands fixed.
## - WHAT THE TABLE READS REACHES A PREVIEW: every file the table reads from its episode's folder (`path_join("...")` in table.gd) is
##   written by the preview (the table, the acts) or copied into it from the episode ([constant TablePreview.PICTURES]) - the designs
##   had not been, and a puppeteer's mask had none (joker-motivation 856886, 2026-11-05). The control: the list without `skin.json` misses it.

const ROOT := "user://skin_step_check"
const Check := preload("res://tests/table/paint_check.gd")

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
	_surfaces()
	await _tools()
	await _fixed()
	_prompts()
	_preview_files()
	_empty(ProjectSettings.globalize_path(ROOT))
	TableEpisode.root = TableEpisode.ROOT
	print("skin_step_check: %s (%d failure%s)" % ["ALL OK" if _fails == 0 else "FAILED", _fails, "" if _fails == 1 else "s"])
	quit(1 if _fails > 0 else 0)


static func _empty(path: String) -> void:
	for d in DirAccess.get_directories_at(path):
		_empty(path.path_join(d))
	for f in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	DirAccess.remove_absolute(path)


func _episode(seed: int, painted: String) -> TableEpisode:
	var ep := TableEpisode.open("skin-show", seed)
	if DirAccess.dir_exists_absolute(ep.dir):
		for f in DirAccess.get_files_at(ep.dir):
			DirAccess.remove_absolute(ep.dir.path_join(f))
	ep.write_json("plan", {"episode_title": "A Face", "painted": painted, "premise": "x", "look": {}, "staging": {"source": "none"},
		"spread": {"positions": [{"name": "the base", "asks": "x", "work": "the base goes on"}]}, "work_intro": "begins", "work_close": "ends"})
	return ep


func _steps() -> void:
	var ep := _episode(1, "a white face with a red mouth")
	var steps := ep.steps()
	_ok(steps.has("skin") and steps.find("skin") > steps.find("table") and steps.find("skin") < steps.find("acts"), "the design comes after the table and before the work: %s" % [steps])
	_ok(ep.needs("skin") == ["plan", "table"], "the design needs the plan and the table: %s" % [ep.needs("skin")])
	_ok(ep.needs("acts").has("skin"), "the work needs the design")
	_ok(ep.dependents("skin").has("acts"), "designing again throws the work away")
	_ok(not _episode(2, "").steps().has("skin"), "control: a plan that paints nothing designs nothing")
	var made := _episode(3, "a face")
	made.write_json("acts", {"acts": []})
	_ok(not made.steps().has("skin"), "control: an episode whose work was blocked before goes on as it was made")


func _surfaces() -> void:
	var s := Skins.skins_of(Check.station())
	_ok(s.size() == 1 and String((s[0] as Dictionary)["thing"]) == "mask" and String((s[0] as Dictionary)["part"]) == "face", "the mask's face is the table's surface: %s" % [s.map(func(x: Dictionary) -> String: return "%s/%s" % [x["thing"], x["part"]])])
	if s.is_empty():
		return
	var fr: Vector2 = (s[0] as Dictionary)["frame"]
	_ok(absf(fr.x - 150.0) < 1.0 and absf(fr.y - 210.0) < 1.0, "the surface is 150 x 210 mm: %s" % fr)
	_ok(not String((s[0] as Dictionary)["outline"]).is_empty() and ((s[0] as Dictionary)["landmarks"] as Dictionary).size() > 10, "with its outline and landmarks")
	_ok(Skins.told(s[0]).contains("left eye") and Skins.told(s[0]).contains("150 mm across"), "and is told: %s" % Skins.told(s[0]).get_slice("\n", 0))
	_ok(Skins.skins_of({"things": [{"name": "a cup", "parts": [{"shape": "lathe", "profile": [[0, 0], [3, 0], [3, 5], [0, 5]]}]}]}).is_empty(), "control: a table with no `skin` has no surface")


func _tools() -> void:
	var surfaces := Skins.skins_of(Check.station())
	var dir := ProjectSettings.globalize_path(ROOT).path_join("job")
	var t := DecoratorTools.new(dir, surfaces)
	var got: Dictionary = await t.call_tool("submit", {})
	_ok(got.has("error"), "control: nothing written, nothing handed in")
	got = await t.call_tool("design", {"elements": [{"id": "base", "stage": "base", "paint": "#f4f1ea", "fill": "all"},
		{"id": "mouth", "stage": "color", "paint": "#b3122a", "finish": "gloss", "fill": "M 55 152 Q 75 140 95 152 Q 75 164 55 152 Z"},
		{"id": "far off", "stage": "detail", "paint": "#000000", "fill": "M -40 -40 L -10 -40 L -10 -10 L -40 -10 Z"}]})
	_ok(String(got["text"]).contains("\"mouth\"") and String(got["text"]).contains("MOSTLY OFF THE SURFACE") and String(got["text"]).contains("far off"), "`design` says what it is and what is off the surface:\n%s" % got["text"])
	got = await t.call_tool("design", {"elements": [{"id": "mouth", "stage": "color", "paint": "#990000", "finish": "gloss", "fill": "M 55 152 Q 75 140 95 152 Q 75 164 55 152 Z"}]})
	var raw: Dictionary = t._raw[0]
	_ok((raw["elements"] as Array).size() == 3 and String(((raw["elements"] as Array)[1] as Dictionary)["paint"]) == "#990000", "an element written again replaces it where it stands")
	got = await t.call_tool("submit", {})
	_ok(got.has("error") and String(got["text"]).contains("Name"), "control: a design with no name is not handed in")
	await t.call_tool("design", {"name": "a red mouth"})
	got = await t.call_tool("submit", {})
	_ok(got.has("error") and String(got["text"]).contains("off the surface"), "what is off the surface stops it once")
	got = await t.call_tool("look", {})
	_ok(got.has("images") and FileAccess.file_exists(String((got["images"] as Array)[0])), "`look` draws it on the surface")
	if got.has("images"):
		var img := Image.load_from_file(String((got["images"] as Array)[0]))
		var mouth := img.get_pixel(int(75 * 3), int(153 * 3))
		var corner := img.get_pixel(3, 3)
		_ok(mouth.r > mouth.g * 2.0 and mouth.r > 0.3, "and the mouth is red where it is drawn: %s" % mouth)
		_ok(corner.r < 0.3, "and the room round the surface is dark: %s" % corner)
	got = await t.call_tool("design", {"remove": ["far off"]})
	got = await t.call_tool("submit", {})
	_ok(not got.has("error") and t.submitted, "and it is handed in: %s" % String(got["text"]).left(60))
	# WHAT GOES ON MUST SHOW GOING ON: a base in nearly the bare surface's color is said hardly seen; a gloss over its own red is a
	# change of finish, and is not - THE CONTROL: a base well apart from the bare surface is not said
	var u := DecoratorTools.new(dir.path_join("unseen"), surfaces)
	var red := "M 55 152 Q 75 140 95 152 Q 75 164 55 152 Z"
	got = await u.call_tool("design", {"elements": [{"id": "pale", "stage": "base", "paint": "#efe9de", "fill": "all"},
		{"id": "red", "stage": "color", "paint": "#b3122a", "fill": red},
		{"id": "shine", "stage": "finish", "paint": "#b3122a", "finish": "gloss", "fill": red}]})
	var unseen := _line_of(String(got["text"]), "HARDLY SEEN")
	_ok(unseen.contains("\"pale\"") and not unseen.contains("\"red\"") and not unseen.contains("\"shine\""), "a base in the bare surface's own color is said hardly seen, and only it: %s" % unseen)
	got = await u.call_tool("design", {"elements": [{"id": "pale", "stage": "base", "paint": "#ffffff", "fill": "all"}]})
	_ok(_line_of(String(got["text"]), "HARDLY SEEN").is_empty(), "control: a white base over the bare surface is not said hardly seen")
	# ...AS THE PRODUCER LANDS IT
	var ep := _episode(4, "a red mouth")
	ep.write_json("table", Check.station())
	var prod := TableProducer.new(ep, {"title": "Show", "brief": "A brief."})
	var err := prod._land_skin(FileAccess.get_file_as_string(dir.path_join(DecoratorTools.SUBMITTED)))
	_ok(err.is_empty() and ep.has("skin"), "what it hands in lands: %s" % err)
	var doc: Variant = ep.read_json("skin")
	var d0: Dictionary = ((doc as Dictionary)["designs"] as Array)[0] if doc is Dictionary else {}
	_ok(String(d0.get("thing", "")) == "mask" and (d0.get("frame", []) as Array).size() == 2 and not String(d0.get("outline", "")).is_empty(), "with where it goes, its frame and its outline")
	_ok(String(prod._plan().get("painted_design", "")).contains("\"mouth\""), "and the puppeteer is told it element by element")
	var one := _episode(5, "a face")
	one.write_json("table", Check.station())
	var p2 := TableProducer.new(one, {"title": "Show", "brief": "A brief."})
	_ok(p2._land_skin(JSON.stringify({"name": "a face", "elements": [{"id": "base", "paint": "#ffffff", "fill": "all"}]})).is_empty() and one.has("skin"), "a writer with no tools hands it in in one reply")
	_ok(not p2._land_skin("{\"name\": \"none\", \"elements\": [{\"id\": \"x\", \"fill\": \"hello\"}]}").is_empty(), "control: a design with nothing paintable does not land")


static func _line_of(text: String, head: String) -> String:
	for l in text.split("\n"):
		if l.begins_with(head):
			return l
	return ""


const BRIEF := "# A Show\n\nWords.\n\n## The fixed table\n\nIt stands there.\n\n```json\n{\"things\": [{\"name\": \"stand\", \"at\": [0, 4], \"parts\": [{\"shape\": \"box\", \"size\": [4, 4, 4], \"material\": \"oak\"}]}], \"materials\": {\"oak\": {\"kind\": \"wood\", \"color\": \"#6a4a2a\"}}}\n```\n\nMore words.\n\n## Never\n\n- Never.\n"


func _fixed() -> void:
	var f := FixedTable.parse(BRIEF)
	_ok((f.get("things", []) as Array).size() == 1 and (f.get("materials", {}) as Dictionary).has("oak"), "the brief's fixed table is read: %s" % [f.keys()])
	var read := FixedTable.strip(BRIEF)
	_ok(not read.contains("```") and read.contains("\"stand\"") and read.contains("More words.") and read.contains("## Never"), "the agents read a line in its place:\n%s" % read)
	_ok(not TablePrompts.brief(BRIEF).contains("\"parts\""), "and the brief every agent is told has no JSON in it")
	var merged := FixedTable.merge({"things": [{"name": "Stand", "parts": [{"shape": "ball"}]}, {"name": "a cup"}], "materials": {"oak": {"kind": "stone"}}}, f)
	var names: Array = (merged["things"] as Array).map(func(t: Dictionary) -> String: return String(t["name"]))
	_ok(names == ["stand", "a cup"] and String((((merged["things"] as Array)[0] as Dictionary)["parts"] as Array)[0]["shape"]) == "box", "a table handed in is given them, one of the same name replaced: %s" % [names])
	_ok(String((merged["materials"]["oak"] as Dictionary)["kind"]) == "wood", "and their materials")
	var none := "# A Show\n\n## The table\n\n```json\n{\"things\": []}\n```\n"
	_ok(FixedTable.parse(none).is_empty() and FixedTable.strip(none) == none, "control: a brief with no fixed table fixes nothing and reads as it was")
	# THE SET DRESSER starts with them standing, and cannot touch them
	var ep := _episode(6, "")
	var sd := SetDresserTools.new(ep, ep.read_json("plan"), ProjectSettings.globalize_path(ROOT).path_join("table_job"), "Show", "", f)
	_ok((sd.draft()["things"] as Array).size() == 1, "the set dresser starts with them on the table")
	var put: Dictionary = await sd._put({"things": [{"name": "stand", "parts": [{"shape": "ball"}]}, {"name": "a lamp", "parts": [{"shape": "ball"}]}]})
	var after: Array = sd.draft()["things"]
	_ok(after.size() == 2 and String((((after[0] as Dictionary)["parts"] as Array)[0] as Dictionary)["shape"]) == "box" and String(put["text"]).contains("fixed"), "and cannot put them again: %s" % String(put["text"]).left(120))
	sd._remove({"names": ["stand"]})
	_ok((sd.draft()["things"] as Array).size() == 2, "or take them away")
	var moved: Dictionary = await sd._blueprint({"things": [{"name": "stand", "at": [20, 20]}]})
	var at: Array = ((sd.draft()["things"] as Array)[0] as Dictionary).get("at", [])
	_ok(at.size() == 2 and float(at[0]) == 0.0 and float(at[1]) == 4.0 and String(moved.get("text", "")).contains("fixed"), "or move them: %s" % String(moved.get("text", "")).left(120))
	sd.release()


func _prompts() -> void:
	var surfaces := Skins.skins_of(Check.station())
	var plan := {"episode_title": "A Face", "premise": "x", "painted": "a white face with a red mouth", "look": {}, "staging": {"source": "none"},
		"spread": {"positions": [{"name": "the base", "asks": "x", "work": "the base goes on"}]},
		"painted_design": "\"a face\", painted on \"mask/face\":\n- \"base\" (base): a fill", "fixed_things": "\"mask\" at [0, 6]"}
	for looks in [0, DecoratorTools.LOOKS]:
		var p := TablePrompts.decorator("Show", "A brief.", plan, 7, surfaces, ["an old face"], looks)
		_ok(Rules.missing.is_empty() and String(p["prompt"]).contains("left eye") and String(p["prompt"]).contains("an old face"), "the decorator's prompt renders whole (%d looks)" % looks)
	var pp := TablePrompts.puppeteer("Show", "A brief.", plan, 7, [], "the parts", 4)
	_ok(Rules.missing.is_empty() and String(pp["prompt"]).contains("WHAT IS PAINTED THIS EPISODE"), "the puppeteer is told the design")
	var sp := TablePrompts.set_dresser("Show", "A brief.", plan, 7, {}, [], false, 4)
	_ok(Rules.missing.is_empty() and String(sp["prompt"]).contains("WHAT IS PAINTED HERE") and String(sp["prompt"]).contains("THE SHOW'S OWN THINGS"), "the set dresser is told what is painted and what stands fixed")


## The files table.gd reads from a folder by name, missing from [param copied] and not written by the preview itself.
static func _unreached(copied: Array) -> PackedStringArray:
	var src := FileAccess.get_file_as_string("res://src/table/table.gd")
	var rx := RegEx.create_from_string('path_join\\("([^"/]+\\.[a-z]+)"\\)')
	var out := PackedStringArray()
	for m in rx.search_all(src):
		var f := m.get_string(1)
		if not f in ["table.json", "acts.json"] and not copied.has(f) and not out.has(f):
			out.append(f)
	return out


func _preview_files() -> void:
	var src := FileAccess.get_file_as_string("res://src/table/table.gd")
	_ok(src.contains('path_join("skin.json")'), "the table reads its designs from its folder (the scan has something to find)")
	var missed := _unreached(Array(TablePreview.PICTURES))
	_ok(missed.is_empty(), "every file the table reads reaches a preview: %s missing" % [missed])
	var without := Array(TablePreview.PICTURES).filter(func(f: String) -> bool: return f != "skin.json")
	_ok(Array(_unreached(without)).has("skin.json"), "control: a list without the designs misses them")
