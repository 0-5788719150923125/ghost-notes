extends Node

## episode_props_check - a table show's props on the Props card ([EpisodeProps], [PropsCard]) and in 3D ([PropViewer]), and the
## library reaching its set dresser ([SetDresserTools]), on an episode, a library and episodes of its own.
##
##   tests/run_boot_probe.sh tests/table_show/episode_props_check.gd 90
##
## - The section's rows are the table's things, ticked; unticked, a thing moves to the table's `aside` (a hand's version, kept) and
##   the table stood from it stands it no more - the control, before, it does; ticked again it stands again. The card draws a row
##   for each.
## - An entry's × takes a thing off the table for good, from Used or Set aside (the control: one not there cannot be).
## - The groups are Used and Set aside, and a game's land and figures (empty for a show with no game), and no row offers Always. Keep puts a thing in the library, and its row says Kept; only a used
##   thing offers Select. A row's prop whole is its table's thing and materials ([method EpisodeProps.prop_of]), built whole to be
##   turned ([method EpisodeProps.model_of]); the viewer holds it, a drag turns it and Set straight puts it back (the control: a
##   key with no prop builds nothing). With no table yet there is nothing to add to.
## - Landing a table, a brief's fixed thing written with no `at` stays where the set dresser put it and as the brief built it,
##   whatever was written of it; the control, one with an `at`, stays where the brief puts it.
## - The set dresser starts with a fixed thing to place, places it with blueprint (its size never changed) and can neither put it
##   again nor take it away; the control, a thing of its own, is put again. `library` finds a kept prop by words (the control: words
##   it shares none of find nothing), and put's `{kept}` stands one on the draft with its materials.
## - The Seen shelf reads every episode's things once each by what it is; Add puts a kept prop on the open episode's table; a kept
##   prop is exported to a file and imported again.
## - A prop's picture kept on the shelf is read, never taken again. The pictures wanted are taken before those only made ready, in
##   the order wanted; made ready ones stop when the shelf asks for none (the control: not stopped, every one is taken).

const ROOT := "user://episode_props_check"

var _fails := 0


func _ready() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		print("  FAIL: " + what)


func _run() -> void:
	var was_root := TableEpisode.root
	var was_library := Library.root
	TableEpisode.root = ROOT.path_join("table")
	Library.root = ROOT.path_join("library")
	Library.discard = func(path: String) -> int: return DirAccess.remove_absolute(path)
	_clean(ProjectSettings.globalize_path(ROOT))
	var ed := ReadingPanel.new()
	ed.workspace = "table"
	ed._build_panel()
	ed._doc._sync = false
	var show: EpisodeCard = ed._block_cards["table"]
	show.set_process(false)
	show._knobs["show"] = "props"
	show._knobs["seed"] = 2
	show._open_episode()
	var ep := show._episode
	ep.write_json("plan", {"episode_title": "Props", "staging": {"source": "none"}, "spread": {"positions": [{"name": "One"}]},
		"look": CardTable.sanitize_look({})})
	ep.write_json("table", {"things": [
		{"name": "cup", "at": [10.0, -20.0], "why": "tea", "parts": [{"shape": "lathe", "profile": [[0, 0], [3, 0], [3, 8], [0, 8]], "material": "clay"}]},
		{"name": "candle", "at": [-20.0, -25.0], "parts": [{"shape": "lathe", "profile": [[0, 0], [2, 0], [2, 12], [0, 12]], "material": "wax", "wick": true}]}],
		"materials": {"clay": {"kind": "clay", "color": "#b5651d"}, "wax": {"kind": "wax", "color": "#f2e8c9"}}})
	var sec: EpisodeProps = null
	for s in ed.prop_sections:
		if s is EpisodeProps:
			sec = s
	_ok(sec != null, "the episode card hands the panel its props")
	if sec == null:
		_finish(ed, was_root, was_library)
		return

	# What stands, and set aside
	var rows := sec.rows()
	_ok(rows.size() == 2 and rows.all(func(r: Dictionary) -> bool: return r["on"] == true and String(r["group"]) == "table"),
		"the rows are the table's things, ticked (%s)" % str(rows.map(func(r: Dictionary) -> String: return String(r["key"]))))
	_ok(_stands(ep, "cup"), "the control: before it is set aside, the cup stands")
	_ok(sec.set_on("thing:cup", false).is_empty(), "the cup is set aside")
	var t: Dictionary = ep.read_json("table")
	_ok((t["things"] as Array).size() == 1 and (t.get("aside", []) as Array).size() == 1 and String((t["aside"] as Array)[0]["name"]) == "cup",
		"set aside, it moves to the table's aside list")
	_ok(not _stands(ep, "cup"), "and the table stood from it stands it no more")
	_ok(ep.kept("table"), "the table is a hand's version, kept")
	var aside_row: Array = sec.rows().filter(func(r: Dictionary) -> bool: return String(r["key"]) == "aside:cup")
	_ok(aside_row.size() == 1 and aside_row[0]["on"] == false and String(aside_row[0]["group"]) == "aside", "its row is unticked, under Set aside")
	_ok(sec.set_on("aside:cup", true).is_empty() and _stands(ep, "cup") and not (ep.read_json("table") as Dictionary).has("aside"),
		"ticked again, it stands again and the aside list goes")

	# The card draws them
	var card := PropsCard.new(func() -> Array: return ed.prop_sections)
	add_child(card)
	card.refresh(true)
	_ok(card.row_count() == 2, "the card draws a row for each (%d)" % card.row_count())

	# Used, Keep, Select
	_ok(sec.groups().map(func(g: Dictionary) -> String: return String(g["label"])) == ["Used", "Set aside", "The land", "Figures"],
		"the groups are Used and Set aside, and a game's land and figures")
	_ok(sec.rows().filter(func(r: Dictionary) -> bool: return String(r["group"]) in ["board", "figures"]).is_empty(),
		"a show with no game lists nothing under the land or figures")
	var verbs_of := func(key: String) -> Array:
		var row: Array = sec.rows().filter(func(r: Dictionary) -> bool: return String(r["key"]) == key)
		return (row[0]["verbs"] as Array).map(func(v: Dictionary) -> String: return String(v["key"])) if not row.is_empty() else []
	_ok(not verbs_of.call("thing:cup").has("always") and verbs_of.call("thing:cup").has("select"), "a used row offers Select, never Always")
	_ok(sec.act("thing:cup", "keep").is_empty() and ThingLibrary.names() == ["cup"], "Keep puts it in the library (%s)" % str(ThingLibrary.names()))
	sec.library.refresh()
	var kept_row: Dictionary = sec.rows().filter(func(r: Dictionary) -> bool: return String(r["key"]) == "thing:cup")[0]
	_ok(String((kept_row["verbs"] as Array)[0]["label"]) == "Kept" and bool((kept_row["verbs"] as Array)[0]["off"]), "and its row says Kept")
	sec.set_on("thing:candle", false)
	_ok(not verbs_of.call("aside:candle").has("select"), "the control: a thing set aside offers no Select")
	sec.set_on("aside:candle", true)

	# A prop whole, in 3D
	var whole := sec.prop_of("thing:candle")
	_ok(String(whole.get("name", "")) == "candle" and ((whole["thing"] as Dictionary)["parts"] as Array).size() == 1
		and (whole["materials"] as Dictionary).has("wax") and not String(whole["hash"]).is_empty(), "a row's prop whole is its thing and materials")
	var model: Dictionary = await sec.model_of("thing:candle")
	_ok(model.get("node") is Node3D and (model["box"] as AABB).size.y > 0.1 and String(model["size"]).ends_with(" cm"),
		"built whole, it is a node with its bounds and size (%s)" % str(model.get("size", "")))
	if model.get("node") is Node:
		(model["node"] as Node).free()
	_ok((await sec.model_of("thing:nothing")).is_empty(), "the control: a key with no prop builds nothing")
	var viewer := PropViewer.new()
	card.add_child(viewer)
	await viewer.open(sec, "thing:cup", "cup")
	_ok(viewer.held() != null and viewer.title == "cup", "the viewer holds the prop it was opened on")
	var straight := viewer.turned()
	viewer.turn_by(Vector2(120, -40))
	_ok(not viewer.turned().is_equal_approx(straight), "a drag turns it")
	viewer.turn_by(Vector2(80, 0), true)
	var rolled := viewer.turned()
	viewer.set_straight()
	_ok(not rolled.is_equal_approx(straight) and viewer.turned().is_equal_approx(straight), "a roll turns it too, and Set straight puts it back")
	viewer._close()
	_ok(viewer.held() == null, "closed, it lets the prop go")


	# Landing a table
	var both := {"things": [{"name": "stand", "at": [0.0, -30.0], "parts": [{"shape": "box", "size": [5, 5, 5]}]},
		{"name": "candle", "parts": [{"shape": "lathe", "profile": [[0, 0], [2, 0], [2, 12], [0, 12]], "material": "wax"}]}], "materials": {}}
	var written := {"things": [{"name": "candle", "at": [33.0, -12.0], "turn": 45.0, "scale": 2.0, "parts": [{"shape": "box", "size": [1, 1, 1]}]},
		{"name": "stand", "at": [50.0, 50.0], "parts": []}]}
	var landed := FixedTable.merge(written, both)
	var lc: Dictionary = {}
	var ls: Dictionary = {}
	for x in landed["things"]:
		if String((x as Dictionary)["name"]) == "candle":
			lc = x
		elif String((x as Dictionary)["name"]) == "stand":
			ls = x
	_ok(lc.get("at") == [33.0, -12.0] and float(lc.get("turn", 0.0)) == 45.0 and not lc.has("scale")
		and String(((lc["parts"] as Array)[0] as Dictionary)["shape"]) == "lathe",
		"a fixed thing with no place stays where the set dresser put it, built and sized as the brief writes it (%s)" % str(lc))
	_ok(ls.get("at") == [0.0, -30.0], "the control: a brief's fixed thing stays where the brief puts it")

	# The set dresser
	var tools := SetDresserTools.new(ep, ep.read_json("plan"), ep.job_dir("table"), "", "", both)
	_ok(tools._index_of("candle") >= 0, "the set dresser starts with the fixed thing to place")
	var r: Dictionary = await tools.call_tool("put", {"things": [{"name": "candle", "parts": [{"shape": "box", "size": [3, 3, 3]}]},
		{"name": "bowl", "parts": [{"shape": "lathe", "profile": [[0, 0], [6, 0], [6, 4], [0, 4]]}]}]})
	_ok(String(r["text"]).contains("fixed things") and _shape_of(tools, "candle") == "lathe", "it cannot put a fixed thing again")
	r = await tools.call_tool("put", {"things": [{"name": "bowl", "parts": [{"shape": "box", "size": [6, 3, 6]}]}]})
	_ok(_shape_of(tools, "bowl") == "box", "the control: a thing of its own is put again")
	r = await tools.call_tool("blueprint", {"things": [{"name": "candle", "at": [-30.0, -20.0], "turn": 10.0, "scale": 1.7}, {"name": "stand", "at": [9.0, 9.0]}]})
	var cd: Dictionary = tools._things[tools._index_of("candle")]
	_ok(cd.get("at") == [-30.0, -20.0] and float(cd.get("turn", 0.0)) == 10.0 and not cd.has("scale") and String(r["text"]).contains("size the brief writes"),
		"it places a fixed thing with no place, its size never changed (%s)" % str(cd))
	var sd: Dictionary = tools._things[tools._index_of("stand")]
	_ok(sd.get("at") == [0.0, -30.0], "the control: a brief's fixed thing is not placed")
	r = tools._remove({"names": ["candle"]})
	_ok(tools._index_of("candle") >= 0, "it cannot take a fixed thing away")
	ThingLibrary.keep({"name": "brass bell", "parts": [{"shape": "lathe", "profile": [[0, 0], [4, 0], [2, 6], [0, 6]], "material": "brass"}]},
		{"brass": {"kind": "metal", "color": "#b08d57"}}, "a small hand bell")
	r = tools._library({"need": "a bell to ring"})
	_ok(String(r["text"]).contains("brass bell") and String(r["text"]).contains(" cm"), "library finds a kept prop by words, with its size")
	r = tools._library({"need": "velvet umbrella"})
	_ok(String(r["text"]).begins_with("Nothing kept"), "the control: words it shares none of find nothing")
	r = await tools.call_tool("put", {"things": [{"kept": "brass bell", "at": [20.0, -30.0]}]})
	var bi := tools._index_of("brass bell")
	_ok(bi >= 0 and (tools._things[bi] as Dictionary).get("at") == [20.0, -30.0] and tools._materials.has("brass"), "put's kept stands one on the draft with its materials")
	r = await tools.call_tool("put", {"things": [{"kept": "no such prop"}]})
	_ok(String(r["text"]).contains("nothing called \"no such prop\""), "a kept name not in the library says so")
	tools.release()

	# The shelves
	var other := TableEpisode.open("elsewhere", 7)
	other.write_json("table", {"things": [{"name": "teapot", "parts": [{"shape": "ball", "size": [10, 8, 10], "material": "glaze"}]},
		{"name": "teapot again", "at": [5, 5], "parts": [{"shape": "ball", "size": [10, 8, 10], "material": "glaze"}]}],
		"materials": {"glaze": {"kind": "ceramic", "color": "#336699"}}})
	var seen := LibraryProps.seen_in(ProjectSettings.globalize_path(TableEpisode.root))
	var names := seen.map(func(x: Dictionary) -> String: return String(x["name"]))
	_ok(names.has("teapot") and not names.has("teapot again") and names.has("cup"), "the Seen shelf has every thing once by what it is (%s)" % str(names))
	sec.library.refresh()
	var before := ((ep.read_json("table") as Dictionary)["things"] as Array).size()
	_ok(sec.add("kept:brass bell").is_empty() and ((ep.read_json("table") as Dictionary)["things"] as Array).size() == before + 1,
		"Add puts a kept prop on the open episode's table")
	var file := ProjectSettings.globalize_path(ROOT).path_join("bell.prop.json")
	_ok(sec.exportable("kept:brass bell") and not sec.exportable("seen:x/1/0") and sec.export_to("kept:brass bell", file).is_empty(),
		"a kept prop is exported to a file to hand on (the control: a Seen one is not offered)")
	ThingLibrary.remove("brass bell")
	_ok(sec.import_from(file).is_empty() and not ThingLibrary.read("brass bell").is_empty(), "and imported into the library again")

	# The Dex: the library on its own adds nothing, and the card's section offers its shelves to Use
	var lib := LibraryProps.new()
	_ok(lib.adds().is_empty() and lib.shelves().size() == 2 and lib.turns(), "the library's own shelves add nothing, and turn in 3D")
	var kept_offers: Array = lib.offers().filter(func(o: Dictionary) -> bool: return String(o["shelf"]) == "kept")
	_ok(kept_offers.map(func(o: Dictionary) -> String: return String(o["name"])).has("brass bell"), "the Kept props shelf has what is kept")
	var dex := DexWindow.new()
	card.add_child(dex)
	dex.open([sec])
	_ok(String(dex.adds_label()) == "Use", "opened from the card, the Dex offers Use (%s)" % dex.adds_label())
	dex.open([lib, LibraryVoices.new()])
	_ok(dex.adds_label().is_empty() and dex.shelf_labels().size() == 3, "opened on its own, it has every shelf and adds nothing (%s)" % str(dex.shelf_labels()))
	dex.free()
	lib.settle()
	sec.library.settle()
	await _pictures()
	show._episode = null
	_ok(sec.adds().is_empty() and not sec.add("kept:brass bell").is_empty(), "with no table yet there is nothing to add to")
	show._episode = ep
	# Taken off: an entry's × takes a thing off the table for good, from either list
	var used: Array = sec.rows().filter(func(r: Dictionary) -> bool: return String(r["key"]).begins_with("thing:"))
	_ok(used.size() >= 2 and sec.rows().all(func(r: Dictionary) -> bool: return r.has("remove_tip")), "every entry has its ×")
	if used.size() >= 2:
		var first := String(used[0]["name"])
		var second := String(used[1]["name"])
		var nowhere := func(n: String) -> bool:
			var tab: Dictionary = ep.read_json("table")
			return not ((tab.get("things", []) as Array) + (tab.get("aside", []) as Array)).any(func(x: Dictionary) -> bool: return String(x["name"]) == n)
		_ok(sec.remove("thing:" + first).is_empty() and nowhere.call(first) and not sec.rows().any(func(r: Dictionary) -> bool: return String(r["name"]) == first),
			"its × takes %s off the table for good - not set aside" % first)
		sec.set_on("thing:" + second, false)
		_ok(sec.remove("aside:" + second).is_empty() and nowhere.call(second), "and a thing set aside, off its list")
	_ok(not sec.remove("thing:nothing").is_empty(), "the control: a thing not on the table cannot be taken off")
	card.free()
	_finish(ed, was_root, was_library)


## The pictures of props ([PropPictures]) on a taker of the gate's own, which records the order and takes a frame each.
func _pictures() -> void:
	var pics := PropPictures.new()
	var order: Array = []
	pics.take = func(_t: Dictionary, _m: Dictionary, h: String, _store: bool) -> Dictionary:
		order.append(h)
		await get_tree().process_frame
		return {"image": Image.create(4, 3, false, Image.FORMAT_RGB8), "size": "1 cm"}
	var kept := "0f0f0f"
	DirAccess.make_dir_recursive_absolute(Library.shelf(PropStudio.SHELF))
	Image.create(8, 6, false, Image.FORMAT_RGB8).save_png(PropStudio.kept_path(kept))
	var f := FileAccess.open(PropStudio.kept_path(kept).get_basename() + ".txt", FileAccess.WRITE)
	f.store_string("3 cm")
	f.close()
	_ok(pics.of(kept, {}, {}) == null, "a kept picture is read on a worker, not on the asking frame")
	for i in 120:
		if pics.image(kept) != null:
			break
		await get_tree().process_frame
	_ok(pics.image(kept) is Image and pics.size_of(kept) == "3 cm" and order.is_empty(),
		"a kept picture is read with its size, never taken again (%s, %s)" % [pics.size_of(kept), str(order)])
	pics.prepare([["r1", {}, {}], ["r2", {}, {}], ["r3", {}, {}]])
	pics.want([["w1", {}, {}], ["r3", {}, {}], [kept, {}, {}]])
	await _drained(pics)
	_ok(order == ["r1", "w1", "r3", "r2"], "the pictures wanted are taken first, then those made ready (%s)" % str(order))
	order.clear()
	pics.prepare([["s1", {}, {}], ["s2", {}, {}], ["s3", {}, {}]])
	pics.prepare([])
	await _drained(pics)
	_ok(order == ["s1"], "made ready ones stop when none are asked for (%s)" % str(order))
	order.clear()
	pics.prepare([["t1", {}, {}], ["t2", {}, {}]])
	await _drained(pics)
	_ok(order == ["t1", "t2"], "the control: made ready and not stopped, every one is taken (%s)" % str(order))


## Until [param pics] has no picture left to take, and the one being taken is in.
func _drained(pics: PropPictures) -> void:
	for i in 240:
		if pics.waiting() == 0 and not pics._pumping:
			return
		await get_tree().process_frame


func _finish(ed: ReadingPanel, was_root: String, was_library: String) -> void:
	ed.free()
	TableEpisode.root = was_root
	Library.root = was_library
	Library.discard = Callable()
	_clean(ProjectSettings.globalize_path(ROOT))
	print("episode_props_check: %s" % ("ALL OK" if _fails == 0 else "%d FAILED" % _fails))
	get_tree().quit(0 if _fails == 0 else 1)


## Whether thing [param name] stands on [param ep]'s table as the table would stand it ([method CardTable.sanitize_table]).
func _stands(ep: TableEpisode, name: String) -> bool:
	var t: Variant = ep.read_json("table")
	if not (t is Dictionary):
		return false
	for x in CardTable.sanitize_table(t as Dictionary, CardTable.sanitize_look({}))["things"]:
		if String((x as Dictionary).get("name", "")) == name:
			return true
	return false


func _shape_of(tools: SetDresserTools, name: String) -> String:
	var i := tools._index_of(name)
	return String(((tools._things[i] as Dictionary)["parts"] as Array)[0].get("shape", "")) if i >= 0 else ""


func _clean(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for d in DirAccess.get_directories_at(path):
		_clean(path.path_join(d))
	for f in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	DirAccess.remove_absolute(path)
