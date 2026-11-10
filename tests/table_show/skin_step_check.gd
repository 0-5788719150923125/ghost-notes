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
## - THE PAINTER AT THE TABLE ([method _painter]): its tools, its handing in, the acts its painting makes - and the controls.
## - A COTTON SWAB FOR THE PAINTER'S SWAB AND FOR NOTHING ELSE ([method _swab]; feedback 0020): a brush whose tuft is a bud is found as a tool
##   with that tip, lifts the host's spills ([method TableProducer._table_tool] "bud") and is never the brush nearest a round's width -
##   the control, a table with no swab, gives the lift to the brush nearest its width.
## - EVERY PROMPT RENDERS WHOLE: the painter's; the decorator's, with tools and without; the puppeteer's told the design; the set dresser's told what is
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
	_face()
	_surfaces()
	await _tools()
	await _painter()
	_swab()
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
	_ok(ep.needs("skin") == ["plan", "table", "image:face", "check:face", "layers"], "the design needs the plan, the table and the face painted first, looked at, and its layers: %s" % [ep.needs("skin")])
	_ok(ep.needs("acts").has("skin"), "the work needs the design")
	_ok(ep.dependents("skin").has("acts"), "designing again throws the work away")
	_ok(not _episode(2, "").steps().has("skin"), "control: a plan that paints nothing designs nothing")
	var made := _episode(3, "a face")
	made.write_json("acts", {"acts": []})
	_ok(not made.steps().has("skin"), "control: an episode whose work was blocked before goes on as it was made")
	# THE FACE PAINTED FIRST (feedback 0023): painted after the table is set, looked at, then copied - and repainting it throws the design
	# and the work away. THE CONTROLS: an episode designed before there were paintings goes on as it was made; designed again, it starts
	# from one
	var fi := steps.find("image:face")
	_ok(fi > steps.find("table") and steps.find("check:face") == fi + 1 and steps.find("skin") > fi + 1, "the face is painted after the table and looked at before the design: %s" % [steps])
	_ok(ep.needs("image:face") == ["plan", "table"] and ep.needs("check:face") == ["image:face"], "painted from the plan on the table, and looked at: %s %s" % [ep.needs("image:face"), ep.needs("check:face")])
	_ok(ep.dependents("image:face").has("skin") and ep.dependents("image:face").has("check:face"), "painting it again throws its check and the design away")
	var before := _episode(6, "a face")
	before.write_json("skin", {"designs": []})
	_ok(not before.steps().has("image:face") and before.needs("skin") == ["plan", "table"], "control: an episode designed before there were paintings goes on as it was made: %s" % [before.steps()])
	before.invalidate("skin")
	_ok(before.steps().has("image:face") and before.needs("skin").has("check:face"), "control: and designed again, it starts from one")
	# ...AND AGAIN IN LAYERS (2026-11-09): the order written after the picture is passed, then each layer painted over the one before -
	# listed once the order is written; painting one again throws the layers after it away, and painting the picture again all of them
	_ok(steps.find("layers") == steps.find("check:face") + 1 and not steps.has("image:layer:1"),
		"the order is written once the picture is passed, its layers listed only once it is: %s" % [steps])
	_ok(ep.needs("layers") == ["image:face", "check:face"], "written from the picture, passed: %s" % [ep.needs("layers")])
	var lay := _episode(7, "a face")
	lay.write_json("layers", {"layers": [{"name": "ground", "add": "the ground", "soft": false}, {"name": "tone", "add": "the tone", "soft": true},
		{"name": "lines", "add": "the lines", "soft": false}]})
	var ls := lay.steps()
	_ok(lay.layer_count() == 3 and ls.find("image:layer:1") == ls.find("layers") + 1 and ls.find("image:layer:3") == ls.find("layers") + 3,
		"written, its three layers are steps in order: %s" % [ls])
	_ok(lay.needs("image:layer:1") == ["layers", "image:face"] and lay.needs("image:layer:3") == ["layers", "image:face", "image:layer:2"],
		"each painted over the one before, the picture its guide: %s %s" % [lay.needs("image:layer:1"), lay.needs("image:layer:3")])
	_ok(lay.dependents("image:layer:2").has("image:layer:3") and not lay.dependents("image:layer:2").has("image:layer:1"),
		"painting a layer again throws the ones after it away, never the ones before")
	_ok(lay.dependents("image:face").has("layers") and lay.dependents("image:face").has("image:layer:1"), "painting the picture again throws all of them away")
	_ok(lay.file_of("image:layer:2").ends_with("layer_2.png") and lay.file_of("layers").ends_with("layers.json"), "kept as layers.json and layer_K.png")
	_ok(lay.needs("skin").has("image:layer:3") and lay.dependents("image:layer:3").has("skin"),
		"the painter at the table lays every layer: the design waits for the last, and painting one again lays them again")
	_ok(not _episode(8, "").steps().has("layers"), "control: a plan that paints nothing has no layers")


## THE FACE PAINTED FIRST, AS THE CODE HANDLES IT ([Skins], [TableProducer]): the bare surface in the middle of an upright 2:3 canvas,
## lit so its features show; a painting that lies on it fits and one moved or spilled past its edge does not; cut back to the surface's
## millimeters with the light taken out, the bare surface's own color comes back even across it (the control: cut with the light left in,
## its edge is darker); its colors told, most of it first. Landed, it is kept with what the surface wears of it, and one that does not lie
## on it is removed; sent back by the art director, it is painted again with what was wrong (the control: kept, it stands).
func _face() -> void:
	var skin: Dictionary = Skins.skins_of(Check.station())[0]
	var canvas := Skins.face_canvas(skin)
	var bare: Image = canvas["image"]
	var at: Vector2i = canvas["at"]
	var size: Vector2i = canvas["size"]
	_ok(absf(float(bare.get_width()) / float(bare.get_height()) - 2.0 / 3.0) < 0.01 and size == Vector2i(450, 630) and at.x >= 0 and at.y >= 0,
		"the bare surface is in an upright 2:3 canvas, 3 pixels a millimeter: %s at %s in %s" % [size, at, bare.get_size()])
	var mid := bare.get_pixel(at.x + size.x / 2, at.y + int(size.y * 0.4))
	_ok(mid.get_luminance() > 0.5 and bare.get_pixel(2, 2).get_luminance() < 0.02, "lit on black: %s, %s" % [mid, bare.get_pixel(2, 2)])
	# a painting of it: the bare picture with a red band across its middle
	var painted := bare.duplicate() as Image
	for y in range(at.y + 300, at.y + 330):
		for x in range(at.x + 120, at.x + 330):
			painted.set_pixel(x, y, Color(0.75, 0.08, 0.12))
	_ok(Skins.face_fit(bare, painted).is_empty(), "a painting on the surface lies on it: %s" % Skins.face_fit(bare, painted))
	var moved := Image.create(bare.get_width(), bare.get_height(), false, Image.FORMAT_RGBA8)
	moved.blit_rect(painted, Rect2i(Vector2i.ZERO, painted.get_size()), Vector2i(0, 70))
	_ok(not Skins.face_fit(bare, moved).is_empty(), "control: moved down 23 mm, it does not")
	var spilled := painted.duplicate() as Image
	spilled.fill_rect(Rect2i(0, 0, bare.get_width(), at.y + 40), Color(0.2, 0.5, 0.9))
	_ok(Skins.face_fit(bare, spilled).contains("edge"), "control: painted onto the black round it, it does not: %s" % Skins.face_fit(bare, spilled))
	var big := painted.duplicate() as Image
	big.resize(painted.get_width() / 2, painted.get_height() / 2)
	_ok(Skins.face_fit(bare, big).is_empty(), "a painting handed back at another size is read at the canvas's: %s" % Skins.face_fit(bare, big))
	# ...cut back to the surface, the light taken out
	var ref := Skins.face_reference(bare, bare, canvas, skin)
	var base := Color.html(String(skin.get("color", "#e8e2d6")))
	var spread := 0.0
	var raw_spread := 0.0
	for p in [Vector2i(225, 250), Vector2i(60, 320), Vector2i(390, 320), Vector2i(225, 560)]:
		var c := ref.get_pixel(p.x, p.y)
		var r := bare.get_pixel(at.x + p.x, at.y + p.y)
		spread = maxf(spread, absf(c.get_luminance() - base.get_luminance()))
		raw_spread = maxf(raw_spread, absf(r.get_luminance() - base.get_luminance()))
	_ok(ref.get_size() == size and spread < 0.05, "cut back, the bare surface is its own color across it (%.3f off at most)" % spread)
	_ok(raw_spread > spread + 0.03, "control: with the light left in, it is %.3f off" % raw_spread)
	var pal := Skins.face_palette(Skins.face_reference(painted, bare, canvas, skin))
	_ok(pal.size() >= 2 and Color.html(String((pal[0] as Dictionary)["hex"])).get_luminance() > 0.5 and pal.any(func(c: Dictionary) -> bool: return Color.html(String(c["hex"])).r > Color.html(String(c["hex"])).g * 3.0)
		and not pal.any(func(c: Dictionary) -> bool: return Color.html(String(c["hex"])).get_luminance() < 0.1),
		"its colors, most of it first, the band's red among them and none of the room round it: %s" % [pal])
	# ...AS THE PRODUCER LANDS IT
	var ep := _episode(7, "a red band")
	ep.write_json("table", Check.station())
	var prod := TableProducer.new(ep, {"title": "Show", "brief": "A brief."})
	bare.save_png(ep.dir.path_join("face_bare.png"))
	TextGen.put(ep.dir.path_join("face.json"), JSON.stringify({"on": "mask/face", "at": [at.x, at.y], "size": [size.x, size.y], "px": 3.0}))
	painted.save_png(ep.file_of("image:face"))
	_ok(prod._land_face().is_empty() and FileAccess.file_exists(ep.dir.path_join("face_ref.png")), "a painting that lies on it lands, with what the surface wears of it")
	moved.save_png(ep.file_of("image:face"))
	_ok(not prod._land_face().is_empty() and not ep.has("image:face") and (ep.sent_back("face") as Array).size() == 1,
		"control: one that does not lie on it is removed, and the next painter told why")
	DirAccess.remove_absolute(ep.dir.path_join("sent_back_face.json"))
	painted.save_png(ep.file_of("image:face"))
	prod._land_face()
	var err := prod._land_check("check:face", JSON.stringify({"verdict": "repaint", "faults": ["the band is off the mouth"]}))
	_ok(err.is_empty() and not ep.has("image:face") and not FileAccess.file_exists(ep.dir.path_join("face_ref.png")) and (ep.sent_back("face") as Array).size() == 1,
		"sent back, it is painted again with what was wrong: %s %s" % [err, ep.sent_back("face")])
	_ok(TablePrompts.face_image({}, ep.read_json("plan"), skin, "/x.png", PackedStringArray(["the band is off the mouth"])).contains("the band is off the mouth"),
		"and the painter is told it")
	painted.save_png(ep.file_of("image:face"))
	_ok(prod._land_check("check:face", JSON.stringify({"verdict": "keep", "faults": []})).is_empty() and ep.has("check:face") and ep.has("image:face"), "control: kept, it stands")


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
	# (...handed back as the picture itself - AgentTools sends only an Image; handed its path, the decorator had looked at nothing)
	var shown: Variant = (got["images"] as Array)[0] if got.has("images") and not (got["images"] as Array).is_empty() else null
	_ok(shown is Image and not (shown as Image).is_empty(), "`look` draws it on the surface and hands the picture back: %s" % [typeof(shown)])
	_ok(Array(DirAccess.get_files_at(t.dir)).any(func(f: String) -> bool: return f.begins_with("look_") and f.ends_with(".jpg")), "and keeps it beside the job")
	if shown is Image:
		var img: Image = shown
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


## A COTTON SWAB ON THE TABLE: a brush whose tuft is a bud, found with its tip; the painter's lifts go to it, and no brush's strokes do -
## and with none on the table, a lift goes to the brush nearest its width.
func _swab() -> void:
	var brush := func(nm: String, kind: String, width: float) -> Dictionary:
		return {"name": nm, "joint": {"kind": "free"}, "at": [0, 1, 0], "turn": [0, 0, 90], "parts": [
			{"shape": "tube", "path": [[0, 0, 0], [0, 7, 0]], "radii": [0.15, 0.12], "material": "stick"},
			{"shape": "tuft", "kind": kind, "length": 0.9 if kind == "bud" else 1.8, "width": width, "at": [0, 6.6, 0], "material": "hair"}]}
	var table := func(with_swab: bool) -> Dictionary:
		var parts: Array = [{"shape": "box", "size": [12, 1, 9], "material": "stick"}, brush.call("round brush", "round", 0.9)]
		if with_swab:
			parts.append(brush.call("swab", "bud", 0.55))
		return {"things": [{"name": "tray", "at": [20, 0], "parts": parts}],
			"materials": {"stick": {"kind": "wood", "color": "#e8e0d0"}, "hair": {"kind": "fabric", "color": "#f4f2ec"}}}
	var tools: Array = PainterTools.scan(table.call(true))["tools"]
	var tips := tools.map(func(t: Dictionary) -> String: return "%s:%s" % [t["part"], t.get("tip", "")])
	_ok(tips.has("swab:bud") and tips.has("round brush:round"), "each brush is found with its tip's kind: %s" % str(tips))
	_ok(String(TableProducer._table_tool("bud", tools).get("part", "")) == "swab", "the painter's lifts go to the swab: %s" % TableProducer._table_tool("bud", tools).get("part", ""))
	# (...a 5.5 mm swab is nearer a 6 mm round than a 9 mm brush is - and is still never it)
	_ok(String(TableProducer._table_tool("round", tools).get("part", "")) == "round brush", "and a round's strokes never do: %s" % TableProducer._table_tool("round", tools).get("part", ""))
	var plain: Array = PainterTools.scan(table.call(false))["tools"]
	_ok(String(TableProducer._table_tool("bud", plain).get("part", "")) == "round brush", "control: with no swab, a lift goes to the brush nearest its width")
	# A MIX OF A MIX IS TAKEN FROM THE POT MOST OF IT IS (feedback 0006): each paint after the first mixed in at its share
	var pots := [{"name": "amber cream", "pot": "amber pot"}, {"name": "olive cream", "pot": "olive pot"},
		{"name": "white paint", "pot": "white pot"}, {"name": "black paint", "pot": "black pot"}]
	_ok(TableProducer._pot_of_paint("amber cream+olive cream+white paint 0.75 0.75", pots) == "white pot",
		"a mix of a mix three quarters white is taken from the white pot: %s" % TableProducer._pot_of_paint("amber cream+olive cream+white paint 0.75 0.75", pots))
	_ok(TableProducer._pot_of_paint("amber cream+olive cream+white paint 0.75 0.25", pots) == "olive pot",
		"...and one a quarter white, from the olive's: %s" % TableProducer._pot_of_paint("amber cream+olive cream+white paint 0.75 0.25", pots))
	_ok(TableProducer._pot_of_paint("amber cream+black paint 0.25", pots) == "amber pot" and TableProducer._pot_of_paint("white paint", pots) == "white pot",
		"control: a mix of two, and a paint alone, as before")
	# THE WORDS KEPT WHEN THE WORK IS MADE AGAIN ([method TableProducer.recue_map]): a passage's cues, its beat's acts made again - its
	# first cue the first act, at its place, and the rest taken out, the acts after it following on by what each takes (2026-11-10: acts
	# cued where longer ones had been put their tools down and waited); the same acts, nothing
	var olds := ["s-1-a", "s-1-b", "s-1-c", "s-1-d", "s-1-e", "s-1-f", "s-1-g"]
	var m4 := TableProducer.recue_map(olds, ["s-1-p", "s-1-q", "s-1-r", "s-1-s"])
	_ok(m4.get("s-1-a") == "s-1-p" and m4.size() == 7 and m4.values().count("") == 6,
		"seven cues over four acts made again: the first names the first, six taken out: %s" % str(m4))
	var m3 := TableProducer.recue_map(["s-3-a", "s-3-b", "s-3-c"], ["s-3-x", "s-3-y", "s-3-z"])
	_ok(m3 == {"s-3-a": "s-3-x", "s-3-b": "", "s-3-c": ""}, "as many acts as cues, made again: the first kept, never each at a place another had: %s" % str(m3))
	var m1 := TableProducer.recue_map(["i-1-sponge"], ["i-1-sponge", "i-2-liner", "i-3-flat"])
	_ok(m1 == {"i-1-sponge": "i-1-sponge"}, "one cue over three acts: it names the first, the others following on: %s" % str(m1))
	_ok(TableProducer.recue_map(["i-1", "i-2"], ["i-1", "i-2"]).is_empty(), "control: cues that are their acts already are left")


static func _line_of(text: String, head: String) -> String:
	for l in text.split("\n"):
		if l.begins_with(head):
			return l
	return ""


const BRIEF := "# A Show\n\nWords.\n\n## The fixed table\n\nIt stands there.\n\n```json\n{\"things\": [{\"name\": \"stand\", \"at\": [0, 4], \"parts\": [{\"shape\": \"box\", \"size\": [4, 4, 4], \"material\": \"oak\"}]}], \"materials\": {\"oak\": {\"kind\": \"wood\", \"color\": \"#6a4a2a\"}}}\n```\n\nMore words.\n\n## Never\n\n- Never.\n"


## THE PAINTER AT THE TABLE ([PainterTools]; the user, 2026-11-08: "with an agent, we can peak at each step"): on the station's table and a
## picture of a white face with a black bar, it is told the episode's beats and the table's tools and paints; a look hands the picture back;
## an operation lays only where the picture asks and says what it took; one with no such tool, way or region is not laid; undo puts the
## canvas back as it was; what is handed in is an element an operation, its plan beside it; and its acts are a tool's run each, beat by
## beat, told the seconds its operations took. The controls: a design no painter laid makes no acts; a gloss is never the painting's ground.
func _painter() -> void:
	var dir := ProjectSettings.globalize_path(ROOT).path_join("painter")
	DirAccess.make_dir_recursive_absolute(dir)
	# (the picture: a white face, a black bar across its middle - 3 points a millimeter over the face's frame)
	var img := Image.create(450, 630, false, Image.FORMAT_RGBA8)
	for y in 630:
		for x in 450:
			var q := Vector2(float(x) + 0.5, float(y) + 0.5) / 3.0
			var inside := Vector2((q.x - 75.0) / 74.0, (q.y - 105.0) / 104.0).length() <= 1.0
			var bar := q.x > 40.0 and q.x < 110.0 and q.y > 100.0 and q.y < 106.0
			img.set_pixel(x, y, Color("#121214") if bar and inside else (Color("#f6f2ea") if inside else Color(0, 0, 0, 0)))
	img.save_png(dir.path_join("face_ref.png"))
	var table := Check.station()
	var plan := {"work_intro": "the ground", "work_close": "the finish", "spread": {"positions": [{"name": "the bar", "work": "a black bar"},
		{"name": "the rest", "work": "anything left"}]}}
	var pt := PainterTools.new(dir.path_join("job"), table, plan, dir.path_join("face_ref.png"))
	_ok(pt.ready(), "the painter has a picture to paint again and tools to paint it with")
	_ok(pt.beats().map(func(b: Dictionary) -> String: return String(b["key"])) == ["intro", "1", "2", "close"], "it is told the episode's beats: %s" % [pt.beats().map(func(b: Dictionary) -> String: return String(b["key"]))])
	var got: Dictionary = await pt.call_tool("look", {})
	_ok(got.has("images") and (got["images"] as Array)[0] is Image, "`look` hands the picture back: the painting, the canvas, what is off")
	_ok(pt._ground == Color("#f6f2ea") or pt._ground.get_luminance() > 0.8, "control: its ground is the painting's white, never a gloss: #%s" % pt._ground.to_html(false))
	var sponge := ""
	var liner := ""
	for t in pt._tools:
		if String((t as Dictionary)["kind"]) == "sponge" and sponge.is_empty():
			sponge = String((t as Dictionary)["name"])
		if String((t as Dictionary)["kind"]) == "brush" and (liner.is_empty() or float((t as Dictionary)["mm"]) < float((pt._tool_of(liner) as Dictionary).get("mm", 99.0))):
			liner = String((t as Dictionary)["name"])
	_ok(not sponge.is_empty() and not liner.is_empty(), "the table's sponge and finest brush are its tools: %s, %s" % [sponge, liner])
	got = await pt.call_tool("paint", {"beat": "intro", "tool": sponge, "paint": "white paint", "how": "sponge", "where": "all", "seconds": 200})
	_ok(not got.has("error") and int((pt._ops.back() as Dictionary)["marks"]) > 20, "the ground goes on: %s" % String(got["text"]).get_slice("
", 0))
	got = await pt.call_tool("paint", {"beat": "1", "tool": "a teapot", "paint": "black paint", "how": "line", "where": "all"})
	_ok(got.has("error") and String(got["text"]).contains("`tool`"), "control: no such tool, nothing laid")
	got = await pt.call_tool("paint", {"beat": "1", "tool": sponge, "paint": "black paint", "how": "line", "where": "all"})
	_ok(got.has("error"), "control: a sponge lays no fine lines")
	got = await pt.call_tool("paint", {"beat": "1", "tool": liner, "paint": "black paint", "how": "line", "where": "M -60 -60 L -20 -60 L -20 -20 Z"})
	_ok(got.has("error"), "control: a region off the surface lays nothing")
	var k_bar: int = pt._pl._k(Vector2(75.0, 103.0))
	var k_white: int = pt._pl._k(Vector2(75.0, 60.0))
	var bar_was: Vector3 = pt._pl.labs[k_bar]
	got = await pt.call_tool("paint", {"beat": "1", "tool": liner, "paint": "black paint", "how": "line", "where": "M 30 90 L 120 90 L 120 116 L 30 116 Z", "seconds": 60})
	var bar_now: Vector3 = pt._pl.labs[k_bar]
	_ok(not got.has("error") and bar_now.x < bar_was.x - 20.0, "the liner draws the bar where the picture has it: lightness %.0f, from %.0f" % [bar_now.x, bar_was.x])
	_ok(pt._pl.labs[k_white].x > 85.0, "and never on the white beside it: %.0f" % pt._pl.labs[k_white].x)
	got = await pt.call_tool("undo", {})
	_ok(not got.has("error") and pt._ops.size() == 1 and pt._pl.labs[k_bar].is_equal_approx(bar_was), "`undo` takes it back, the canvas as it was")
	await pt.call_tool("paint", {"beat": "1", "tool": liner, "paint": "black paint", "how": "line", "where": "M 30 90 L 120 90 L 120 116 L 30 116 Z", "seconds": 60})
	got = await pt.call_tool("submit", {})
	_ok(got.has("error") and String(got["text"]).contains("Name"), "control: a painting with no name is not handed in")
	got = await pt.call_tool("submit", {"name": "a white face with a bar"})
	_ok(pt.submitted and FileAccess.file_exists(dir.path_join("job").path_join(PainterTools.SUBMITTED)), "it is handed in")
	var doc: Dictionary = pt.designs()
	var els: Array = ((doc["designs"] as Array)[0] as Dictionary)["elements"]
	_ok(els.size() == 2 and (els[1] as Dictionary).get("plan") is Dictionary and String(((els[1] as Dictionary)["plan"] as Dictionary)["how"]) == "line",
		"an element an operation, its plan beside it: %s" % [els.map(func(e: Dictionary) -> String: return String(e["id"]))])
	var made := Skins.sanitize((doc["designs"] as Array)[0], Vector2(150, 210))
	_ok((made["elements"] as Array).size() == 2 and ((made["elements"] as Array)[1] as Dictionary).has("plan"), "and the plan lands with it")
	var acts := TableProducer.acts_from_painting(doc, table, 2)
	var list: Array = acts.get("acts", [])
	_ok(list.size() == 2 and str((list[0] as Dictionary)["beat"]) == "intro" and str((list[1] as Dictionary)["beat"]) == "1"
		and String((((list[1] as Dictionary)["tracks"] as Array)[0] as Dictionary)["manner"]) == "line", "its acts: a tool's run each, beat by beat: %s" % [list.map(func(a: Dictionary) -> String: return String(a["name"]))])
	var safe := Motions.sanitize_acts(acts, 2)
	var told := Skins.act_natural((safe["acts"] as Array)[1], doc, table, true)
	var took := float((((els[1] as Dictionary)["plan"]) as Dictionary)["seconds"])
	_ok((safe["acts"] as Array).size() == 2 and absf(told - took - TablePaint.FETCH - TablePaint.RETURN - TablePaint.MOVE - TablePaint.LOAD) < 1.0,
		"told what its operations took: %.0f s for %.0f s laid" % [told, took])
	var designed := {"designs": [{"thing": "mask", "part": "face", "elements": [{"id": "base", "paint": "#f4f1ea", "fill": "all"}]}]}
	_ok(TableProducer.acts_from_painting(designed, table, 2).is_empty(), "control: a design no painter laid makes no acts")


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
	# THE LAYERS' PROMPTS: the order asked of the art director with the table's paints and how many; a layer asked of the painter, only it
	var fl := TablePrompts.face_layers("A Show", "a brief", {"painted": "a white ground, a red mouth"}, {"thing": "mask"}, ["red paint #b3122a"])
	_ok(String(fl.get("prompt", "")).contains("a white ground, a red mouth") and String(fl["prompt"]).contains("red paint #b3122a")
		and String(fl["prompt"]).contains(str(TableProducer.LAYERS_MOST)), "the art director is asked for the order with what was painted, the paints and how many")
	var li := TablePrompts.layer_image({}, "THE MOUTH ONLY", "/tmp/x.png", 3, 7)
	_ok(li.contains("THE MOUTH ONLY") and li.contains("3 OF 7") and li.contains("/tmp/x.png"), "a layer is asked for alone, which of how many, and where it is saved")
	var painting := TablePrompts.painting("a title", "a brief", {"episode_title": "it", "premise": "a premise", "painted": "a face"},
		[{"key": "intro", "name": "intro", "work": "a ground"}, {"key": "1", "name": "the first", "work": ""}], PainterTools.BUDGET, PainterTools.LOOKS)
	_ok(not String(painting["prompt"]).contains("{{") and String(painting["prompt"]).contains("a ground") and String(painting["prompt"]).contains("`look`"),
		"the painter's prompt renders whole")
	var surfaces := Skins.skins_of(Check.station())
	var plan := {"episode_title": "A Face", "premise": "x", "painted": "a white face with a red mouth", "look": {}, "staging": {"source": "none"},
		"spread": {"positions": [{"name": "the base", "asks": "x", "work": "the base goes on"}]},
		"painted_design": "\"a face\", painted on \"mask/face\":\n- \"base\" (base): a fill", "fixed_things": "\"mask\" at [0, 6]"}
	for looks in [0, DecoratorTools.LOOKS]:
		var p := TablePrompts.decorator("Show", "A brief.", plan, 7, surfaces, ["an old face"], looks)
		_ok(Rules.missing.is_empty() and String(p["prompt"]).contains("left eye") and String(p["prompt"]).contains("an old face"), "the decorator's prompt renders whole (%d looks)" % looks)
	var copying := TablePrompts.decorator("Show", "A brief.", plan, 7, surfaces, [], DecoratorTools.LOOKS, [{"hex": "#f4f1ea", "share": 0.7}, {"hex": "#b3122a", "share": 0.1}])
	_ok(Rules.missing.is_empty() and String(copying["prompt"]).contains("A COPY OF IT") and String(copying["prompt"]).contains("#b3122a (10%)") and String(copying["prompt"]).contains("beside it"),
		"the decorator copying a painting is told so, and its colors")
	_ok(not String(TablePrompts.decorator("Show", "A brief.", plan, 7, surfaces, [], DecoratorTools.LOOKS)["prompt"]).contains("A COPY OF IT"), "control: with none, it is not")
	var fp := TablePrompts.face_image({}, plan, surfaces[0], "/tmp/x.png")
	_ok(Rules.missing.is_empty() and fp.contains("a white face with a red mouth") and fp.contains("150 mm across") and not fp.contains("{{"), "the painter's face renders whole")
	var fc := TablePrompts.face_check("Show", "A brief.", plan, surfaces[0])
	_ok(Rules.missing.is_empty() and String(fc["prompt"]).contains("a white face with a red mouth") and String(fc["prompt"]).contains("\"verdict\""), "the art director's look at it renders whole")
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
