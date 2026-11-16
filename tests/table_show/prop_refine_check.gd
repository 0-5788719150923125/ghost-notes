extends Node

## prop_refine_check - a prop refined and its versions ([ThingLibrary], [LibraryVersions], [PropViewer], [PropRefine]), on a library
## and an episode of its own; the agent is a stand-in that answers at once, never a real one:
##
##   tests/run_boot_probe.sh tests/table_show/prop_refine_check.gd 120
##
## - A kept prop's versions are kept in its own file: a new version is added beside it and not used until it is chosen; chosen, its
##   parts and hash are the prop's; it is found kept by the hash of any version; it is handed on as the version used alone. An entry
##   never refined is one version, itself. The control: a revision that builds nothing adds none.
## - The agent's answer becomes a version: the prop as `{thing, materials}` or bare parts, the refined version's scale kept where it
##   leaves it out; the controls: an answer that is no prop, or has no parts, adds nothing. Refining waits for words, and a session
##   that may not write refines nothing.
## - In the 3D view: a seen prop refined is kept first, once - the library gains one prop, and the seen one says Kept - and the
##   version made is shown, 2 of 2, not yet used; stepping back shows the first; Use this one makes the shown one the prop. A thing
##   built by code offers no Refine.
## - What uses it follows: a table's thing takes the version used, where it stands and why kept (the control: the same version again
##   writes nothing), and a Dispatch desk's part refined is played by the prop kept from it.

const ROOT := "user://prop_refine_check"
const CUP := {"name": "cup", "parts": [{"shape": "lathe", "profile": [[0, 0], [3, 0], [3, 8], [0, 8]], "material": "clay"}]}
const CLAY := {"clay": {"kind": "ceramic", "color": "#b5651d"}}
const TALLER := "{\"thing\": {\"parts\": [{\"shape\": \"lathe\", \"profile\": [[0, 0], [3, 0], [3, 12], [0, 12]], \"material\": \"clay\"}]}, \"materials\": {\"clay\": {\"kind\": \"ceramic\", \"color\": \"#3355aa\"}}}"


## The library's versions with a stand-in agent: what it answers is [member answer], at once.
class Stand extends LibraryVersions:
	var answer := TALLER
	var asked := 0

	func refine(name: String, from: int, direction: String, pick: Dictionary, told: Callable) -> Dictionary:
		asked += 1
		told.call("thinking")
		return land(name, answer, direction, by_of(pick), ThingLibrary.versions(name)[from]["thing"])


## A library whose versions are the stand-in's.
class StandLibrary extends LibraryProps:
	var stand: Stand

	func versions_of() -> PropVersions:
		if stand == null:
			stand = Stand.new(self)
		return stand


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
	_clean(ProjectSettings.globalize_path(ROOT))
	TableEpisode.root = ROOT.path_join("table")
	Library.root = ROOT.path_join("library")
	Library.discard = func(path: String) -> int: return DirAccess.remove_absolute(path)
	_versions()
	_land()
	await _viewer()
	await _scenes()
	TableEpisode.root = was_root
	Library.root = was_library
	Library.discard = Callable()
	_clean(ProjectSettings.globalize_path(ROOT))
	print("prop_refine_check: %s" % ("ALL OK" if _fails == 0 else "%d FAILED" % _fails))
	get_tree().quit(0 if _fails == 0 else 1)


func _versions() -> void:
	ThingLibrary.keep(CUP, CLAY, "a clay cup")
	var first := ThingLibrary.read("cup")
	_ok(ThingLibrary.versions("cup").size() == 1 and ThingLibrary.used_of(first) == 0, "a prop never refined is one version, itself")
	var taller := CUP.duplicate(true)
	(taller["parts"] as Array)[0]["profile"] = [[0, 0], [3, 0], [3, 12], [0, 12]]
	var i := ThingLibrary.add_version("cup", taller, CLAY, "taller", "claude")
	var now := ThingLibrary.read("cup")
	_ok(i == 1 and ThingLibrary.versions("cup").size() == 2 and String(now["hash"]) == String(first["hash"]) and ThingLibrary.used_of(now) == 0,
		"a new version is added beside it, the first still used")
	_ok(String(ThingLibrary.versions("cup")[1]["note"]) == "taller" and String(ThingLibrary.versions("cup")[1]["by"]) == "claude", "it says what made it and who")
	_ok(ThingLibrary.use_version("cup", 1).is_empty() and String(ThingLibrary.read("cup")["hash"]) == String(ThingLibrary.versions("cup")[1]["hash"])
		and ThingLibrary.used_of(ThingLibrary.read("cup")) == 1, "chosen, the new version is the prop")
	_ok(ThingLibrary.kept_as(String(first["hash"])) == "cup" and ThingLibrary.names() == ["cup"], "it is found kept by its first version's hash, one prop")
	var file := ProjectSettings.globalize_path(ROOT).path_join("cup.prop.json")
	ThingLibrary.export_to("cup", file)
	var handed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(file))
	_ok(not handed.has("versions") and String(handed["hash"]) == String(ThingLibrary.versions("cup")[1]["hash"]), "it is handed on as the version used alone")
	var none := ThingLibrary.add_version("cup", {"name": "cup", "parts": []}, CLAY, "nothing", "claude")
	_ok(none == -1 and ThingLibrary.versions("cup").size() == 2, "the control: a revision that builds nothing adds no version")
	ThingLibrary.use_version("cup", 0)


func _land() -> void:
	var got := LibraryVersions.land("cup", "```json\n" + TALLER + "\n```", "taller and blue", "codex")
	_ok(int(got.get("index", -1)) == 2, "the agent's answer is a version (%s)" % str(got))
	var bare := LibraryVersions.land("cup", "{\"parts\": [{\"shape\": \"lathe\", \"profile\": [[0, 0], [4, 0], [4, 8], [0, 8]], \"material\": \"clay\"}], \"materials\": {\"clay\": {\"kind\": \"ceramic\", \"color\": \"#aa3333\"}}}",
		"wider", "codex", {"scale": 1.5})
	var vs := ThingLibrary.versions("cup")
	_ok(int(bare.get("index", -1)) == 3 and is_equal_approx(float((vs[3]["thing"] as Dictionary).get("scale", 1.0)), 1.5),
		"bare parts are a version too, the scale of the one refined kept")
	_ok(LibraryVersions.land("cup", "I could not do that.", "x", "codex").has("error") and LibraryVersions.land("cup", "{\"materials\": {}}", "x", "codex").has("error")
		and ThingLibrary.versions("cup").size() == 4, "the controls: an answer that is no prop, or has no parts, adds nothing")
	var lib := LibraryProps.new()
	var pv := lib.versions_of()
	var empty: Dictionary = await pv.refine("cup", 0, "  ", {}, Callable())
	_ok(empty.has("error"), "refining waits for words")
	var p := LibraryVersions.prompt("cup", "a clay cup", CUP, CLAY, "taller", true)
	_ok(String(p["prompt"]).contains("taller") and String(p["prompt"]).contains("\"lathe\"") and String(p["prompt"]).contains("PARTS")
		and not String(p["prompt"]).contains("{{"), "the agent is told the prop, the change asked and the prop language")


## The 3D view: a seen prop refined.
func _viewer() -> void:
	var seen_ep := TableEpisode.open("elsewhere", 4)
	seen_ep.write_json("table", {"things": [{"name": "jug", "parts": [{"shape": "lathe", "profile": [[0, 0], [4, 0], [3, 14], [0, 14]], "material": "tin"}]}],
		"materials": {"tin": {"kind": "metal", "color": "#bbbbbb"}}})
	var lib := StandLibrary.new()
	for i in 200:
		if not lib.seen_list().is_empty():
			break
		await get_tree().process_frame
	var seen_key := String(lib.seen_list()[0]["key"])
	var before := ThingLibrary.names().size()
	var viewer := PropViewer.new()
	add_child(viewer)
	viewer.open(lib, seen_key, "jug")
	_ok(not viewer._refine_btn.disabled and not viewer._use.visible, "a seen prop offers Refine, and no versions yet")
	viewer.open_refine()
	viewer._refine.set_direction("make it taller")
	viewer._refine._ask()
	for i in 30:
		await get_tree().process_frame
	_ok(ThingLibrary.names().size() == before + 1 and ThingLibrary.versions("jug").size() == 2 and lib.stand.asked == 1,
		"refined, it is kept once and a version is made (%s)" % str(ThingLibrary.names()))
	_ok(viewer._ver.visible and viewer._ver.text == "2 / 2" and viewer._use.text == "Use this one" and ThingLibrary.used_of(ThingLibrary.read("jug")) == 0,
		"the version made is shown, 2 of 2, not yet used (%s)" % viewer._ver.text)
	lib.refresh()
	var seen_offer: Array = lib.offers().filter(func(o: Dictionary) -> bool: return String(o["key"]) == seen_key)
	var kept_tiles: Array = lib.offers().filter(func(o: Dictionary) -> bool: return String(o["shelf"]) == "kept" and String(o["name"]).begins_with("jug"))
	_ok(not seen_offer.is_empty() and String((seen_offer[0]["verbs"] as Array)[0]["label"]) == "Kept" and kept_tiles.size() == 1,
		"the seen jug says Kept, and the Dex has one jug, not one a version")
	viewer.step(-1)
	_ok(viewer._shown == 0 and viewer._ver.text == "1 / 2" and viewer._use.text == "In use", "stepping back shows the first, the one used")
	viewer.step(1)
	viewer.use_shown()
	_ok(ThingLibrary.used_of(ThingLibrary.read("jug")) == 1 and viewer._use.text == "In use", "Use this one makes the version shown the prop")
	var dp := DispatchProps.new()
	viewer.open(dp, "built:terminal", "terminal")
	_ok(viewer._refine_btn.disabled, "a thing built by code offers no Refine")
	viewer._close()
	viewer.queue_free()
	lib.settle()
	dp.settle()


## What uses a refined prop follows.
func _scenes() -> void:
	var ed := ReadingPanel.new()
	ed.workspace = "table"
	ed._build_panel()
	ed._doc._sync = false
	var show: EpisodeCard = ed._block_cards["table"]
	show.set_process(false)
	show._knobs["show"] = "refine"
	show._knobs["seed"] = 2
	show._open_episode()
	var ep := show._episode
	ep.write_json("plan", {"episode_title": "Refine", "staging": {"source": "none"}, "spread": {"positions": [{"name": "One"}]},
		"look": CardTable.sanitize_look({})})
	ep.write_json("table", {"things": [{"name": "bowl", "at": [10.0, -20.0], "why": "fruit",
		"parts": [{"shape": "lathe", "profile": [[0, 0], [5, 0], [6, 5], [0, 5]], "material": "clay"}]}], "materials": CLAY.duplicate(true)})
	var sec: EpisodeProps = null
	for s in ed.prop_sections:
		if s is EpisodeProps:
			sec = s
	var pv := sec.versions_of()
	var k := pv.keep(sec.prop_of("thing:bowl"))
	var name := String(k.get("name", ""))
	var deeper := {"name": "bowl", "parts": [{"shape": "lathe", "profile": [[0, 0], [5, 0], [6, 9], [0, 9]], "material": "clay"}]}
	ThingLibrary.add_version(name, deeper, {"clay": {"kind": "ceramic", "color": "#225588"}}, "deeper", "claude")
	_ok(pv.use(name, 1).is_empty() and sec.refined("thing:bowl", name).is_empty(), "the bowl's second version is used")
	var t: Dictionary = ep.read_json("table")
	var bowl: Dictionary = (t["things"] as Array)[0]
	var mat := String(((bowl["parts"] as Array)[0] as Dictionary)["material"])
	_ok(str(((bowl["parts"] as Array)[0]["profile"] as Array)[2]) == str([6.0, 9.0]) and bowl["at"] == [10.0, -20.0] and String(bowl["why"]) == "fruit"
		and String((t["materials"] as Dictionary)[mat]["color"]) == "#225588" and ep.kept("table"),
		"the table's thing takes the version used, where it stands and why kept, as a hand's version (%s)" % str(bowl))
	var digest := ep.digest("table")
	_ok(sec.refined("thing:bowl", name).is_empty() and ep.digest("table") == digest, "the control: the same version again writes nothing")
	var fmt := DispatchFormat.for_note({})
	var dp := DispatchProps.new(fmt)
	var dk := dp.versions_of().keep(dp.prop_of("role:mug"))
	_ok(dp.refined("role:mug", String(dk.get("name", ""))).is_empty() and fmt.things().get("mug") == {"kept": String(dk.get("name", ""))},
		"a desk's part refined is played by the prop kept from it (%s)" % str(fmt.things()))
	dp.settle()
	fmt.free()
	ed.free()


func _clean(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for d in DirAccess.get_directories_at(path):
		_clean(path.path_join(d))
	for f in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	DirAccess.remove_absolute(path)
