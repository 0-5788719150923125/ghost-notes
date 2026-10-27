extends Node

## THE PUPPETEER'S TOOLS ([PuppeteerTools], next/table_work.md) on a table stood as the set dresser's is -
## built on a worker thread by [TablePreview], over an episode under a root of its own:
##
##   - `parts` names every working part of the set table, where its points are on it, and which thing holds
##     a flame;
##   - `act` keeps a grinding act and answers that nothing in it passes through anything - and says it of an
##     act driving the pestle through the bowl's wall (the control), and says what could not be kept (an act
##     naming a thing the table does not have);
##   - `watch` hands back a sheet of six frames of an act, each a picture of the table (not one flat color),
##     and the frames differ as the pestle goes round (the control: two pictures of one moment do not);
##   - `submit` asks once for what was never watched, then hands the acts in - `submitted.json`, which the
##     producer lands as `acts.json` ([method TableProducer._land_acts]).
##
##   GHOST_PROBE_GPU=1 tests/run_boot_probe.sh tests/table_show/puppeteer_tools_check.gd 400
##
## A BOOT probe (the medium reaches the Director) on the GPU (a picture needs a real renderer).

const Live := preload("res://tests/table/table_work_live_check.gd")
const ROOT := "user://puppeteer_tools_check"

var _fails := 0


func _ready() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + what)
	if not cond:
		_fails += 1


func _run() -> void:
	if not TablePreview.can_set() or not TablePreview.can_see():
		_ok(false, "this run cannot stand a table or take a picture (GHOST_PROBE_GPU=1, under a ghost boot)")
		_done()
		return
	TableEpisode.root = ROOT
	var ep := TableEpisode.open("puppeteer-check", 5151)
	DirAccess.make_dir_recursive_absolute(ep.dir)
	for f in DirAccess.get_files_at(ep.dir):
		DirAccess.remove_absolute(ep.dir.path_join(f))
	var positions := [{"name": "the base", "work": "the ink is poured in"}, {"name": "the heart", "work": "the herbs are ground"}]
	ep.write_json("plan", {"episode_title": "A Brew", "spread": {"name": "Two", "positions": positions},
		"look": CardTable.sanitize_look({"deck_name": "The Test Deck", "candles": 1})})
	ep.write_json("draw", {"seed": ep.seed, "cards": CardDeck.shuffled(preload("res://tests/fixture_deck.gd").cards(), ep.seed, false).slice(0, 2)})
	var table := Live._table()
	ep.write_json("table", table)
	var tools := PuppeteerTools.new(ep, ep.read_json("plan"), ep.job_dir("acts"), table)
	# PARTS
	var parts: Dictionary = await tools.call_tool("parts", {})
	var said := String(parts.get("text", ""))
	_ok(said.contains("\"cauldron\"") and said.contains("part \"brew\"") and said.contains("mouth") and said.contains("free joint"),
		"parts does not name the bench's working parts and points:\n%s" % said)
	# ACT: kept, nothing through anything; the control through the bowl's wall; a thing not there
	var acts: Array = (Live._acts()["acts"] as Array).duplicate(true)
	acts.append({"name": "smash", "beat": 2, "about": "x", "length": 3, "tracks": [{"thing": "pestle", "part": "pestle", "law": "aim",
		"tip": {"point": "tip", "around": "mortar.floor", "lift": -4.0, "radius": 5.0, "period": 3.0},
		"grip": {"point": "grip", "around": "mortar.floor", "lift": 9, "radius": 6, "period": 3.0}}]})
	acts.append({"name": "ghost-jar", "beat": 1, "about": "x", "length": 2, "tracks": [{"thing": "a jar nobody built", "law": "carry", "to": [0, 0, 0]}]})
	var put: Dictionary = await tools.call_tool("act", {"acts": acts})
	var answer := String(put.get("text", ""))
	var grind_line := _block(answer, "grind")
	var smash_line := _block(answer, "smash")
	_ok(grind_line.contains("Nothing passes through anything"), "act says the grinding passes through something: %s\n%s" % [grind_line, answer])
	_ok(smash_line.contains("PASSES THROUGH"), "the control: act does not catch the pestle driven through the bowl: %s" % smash_line)
	_ok(answer.contains("a jar nobody built"), "act does not say an act naming a thing the table lacks was left out:\n%s" % answer)
	await tools.call_tool("remove", {"names": ["smash", "ghost-jar"]})
	# WATCH: six frames of the grinding, each a picture, and they differ
	var watched: Dictionary = await tools.call_tool("watch", {"name": "grind"})
	var sheet: Image = (watched.get("images", []) as Array)[0] if not (watched.get("images", []) as Array).is_empty() else null
	_ok(sheet != null, "watch handed back no picture: %s" % String(watched.get("text", "")))
	if sheet != null:
		var tiles: Array = []
		for i in 6:
			var tw := sheet.get_width() / 3
			var th := sheet.get_height() / 2
			tiles.append(sheet.get_region(Rect2i((i % 3) * tw + 2, (i / 3) * th + 2, tw - 4, th - 4)))
		var spread := _spread(tiles[0])
		_ok(spread > 0.02, "a watched frame is one flat color (spread %s)" % spread)
		var moved := _diff(tiles[1], tiles[2])
		_ok(moved > 0.0005, "the grinding's frames do not differ as the pestle goes round (%s)" % moved)
		var same := _diff(tiles[1], tiles[1])
		_ok(same == 0.0, "the control: a frame differs from itself")
	# SUBMIT: asks once for what was never watched, then hands the work in
	var first: Dictionary = await tools.call_tool("submit", {})
	_ok(bool(first.get("error", false)) and String(first["text"]).contains("Not watched"), "submit does not ask for the acts never watched: %s" % String(first.get("text", "")))
	var second: Dictionary = await tools.call_tool("submit", {})
	_ok(not bool(second.get("error", false)) and tools.submitted, "submit did not hand the work in: %s" % String(second.get("text", "")))
	var prod := TableProducer.new(ep, {"title": "Brews", "brief": "A brief."})
	var err := prod._land_acts(FileAccess.get_file_as_string(ep.job_dir("acts").path_join(PuppeteerTools.SUBMITTED)))
	_ok(err.is_empty() and ep.has("acts"), "the handed-in acts did not land: %s" % err)
	tools.release()
	_done()


## What `act` answered of act [param name]: its lines, from its own to the next act's.
static func _block(answer: String, name: String) -> String:
	var out := PackedStringArray()
	var mine := false
	for line in answer.split("\n"):
		if line.begins_with("\""):
			mine = line.begins_with("\"%s\"" % name)
		if mine:
			out.append(line)
	return "\n".join(out)


## How much a picture's colors spread (the standard deviation of its gray, 0-1, over a coarse grid).
static func _spread(img: Image) -> float:
	var vals: Array = []
	for y in range(0, img.get_height(), 8):
		for x in range(0, img.get_width(), 8):
			vals.append(img.get_pixel(x, y).get_luminance())
	var mean := 0.0
	for v in vals:
		mean += float(v)
	mean /= maxf(float(vals.size()), 1.0)
	var s := 0.0
	for v in vals:
		s += (float(v) - mean) * (float(v) - mean)
	return sqrt(s / maxf(float(vals.size()), 1.0))


## The mean difference of two pictures' gray, over a coarse grid.
static func _diff(a: Image, b: Image) -> float:
	var s := 0.0
	var n := 0
	for y in range(0, mini(a.get_height(), b.get_height()), 4):
		for x in range(0, mini(a.get_width(), b.get_width()), 4):
			s += absf(a.get_pixel(x, y).get_luminance() - b.get_pixel(x, y).get_luminance())
			n += 1
	return s / maxf(float(n), 1.0)


func _done() -> void:
	TableEpisode.root = TableEpisode.ROOT
	print("puppeteer_tools_check: %s (%d failure%s)" % ["ALL OK" if _fails == 0 else "FAILED", _fails, "" if _fails == 1 else "s"])
	get_tree().quit(1 if _fails > 0 else 0)
