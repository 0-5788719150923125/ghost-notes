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
## - In the 3D view: a seen prop refined is held as a draft, never kept - the library lists nothing new, the seen one says nothing
##   kept, an agent's search finds nothing, and the view offers Keep - and the version made is shown, 2 of 2, not yet used; Keep there
##   keeps it with both versions (the Dex then has one jug, the seen one says so, the view says Kept), and its rows have no Keep;
##   using a seen prop for a desk's part holds it as a draft too, never kept; stepping back shows the first; the version shown when the view is left (closed, or
##   opened on another prop) is the prop - only opened and closed, nothing changes (the control). There is no button for it. The
##   Dispatch desk's terminal offers Refine (next/working_props.md); the control, a prop with no parts, offers none.
## - Named: an answer that gives a name and a line puts them on its version, the prop keeping its own until that version is used;
##   used, the prop takes them, its file moves, and its former name still finds it (a desk choosing it by that name); the first
##   version used again takes its own name back; a name another prop has is passed over (the control); a new prop is never kept under
##   a former name. A person renames the version shown in the 3D view: one not used is only named, the one used renames the prop. The
##   agent is told it may rename.
## - Together: Refine closes its words' window and the agent works on with the view closed; a second prop refined meanwhile runs beside
##   it (the control: the same prop again is refused while one is at it); the view on a prop says what its agent is doing, with Stop,
##   and Refine… waits; a Props card row says it too, then that a new version is ready while nobody has looked, and the view opened on
##   it shows the version made (seen, so said once); Stop gives one up and the view says so, adding nothing.
## - What uses it follows: a table's thing takes the version used, where it stands and why kept (the control: the same version again
##   writes nothing); a Dispatch desk's part refined is played by the prop kept from it, its terminal too, and a version used that
##   has lost its screen is said to (the desk's own plays it); a Letter desk's thing refined is played by the version used, and its
##   Desk's own puts the number's back (the control).

const ROOT := "user://prop_refine_check"
const CUP := {"name": "cup", "parts": [{"shape": "lathe", "profile": [[0, 0], [3, 0], [3, 8], [0, 8]], "material": "clay"}]}
const CLAY := {"clay": {"kind": "ceramic", "color": "#b5651d"}}
const TALLER := "{\"thing\": {\"parts\": [{\"shape\": \"lathe\", \"profile\": [[0, 0], [3, 0], [3, 12], [0, 12]], \"material\": \"clay\"}]}, \"materials\": {\"clay\": {\"kind\": \"ceramic\", \"color\": \"#3355aa\"}}}"


## The library's versions with a stand-in agent: what it answers is [member answer], at once.
class Stand extends LibraryVersions:
	var answer := TALLER
	var asked := 0

	func refine(name: String, from: int, direction: String, pick: Dictionary, told: Callable, _scene := {}) -> Dictionary:
		asked += 1
		told.call("thinking")
		return land(name, answer, direction, by_of(pick), ThingLibrary.versions(name)[from]["thing"])


## A stand-in agent that works until the gate lets it finish ([member release]), or is stopped.
class Slow extends LibraryVersions:
	static var release := {}

	func refine(name: String, from: int, direction: String, pick: Dictionary, told: Callable, _scene := {}) -> Dictionary:
		_jobs[name] = ""
		told.call("drawing it")
		while not release.has(name):
			if not _jobs.has(name):
				return {"error": "stopped"}
			await PropStudio.tree().process_frame
		_jobs.erase(name)
		return land(name, TALLER, direction, by_of(pick), ThingLibrary.versions(name)[from]["thing"], from)


## A library whose versions are the slow stand-in's.
class SlowLibrary extends LibraryProps:
	func versions_of() -> PropVersions:
		return Slow.new(self)


## A section whose one prop has no parts: nothing to refine.
class Bare extends PropSection:
	func prop_of(_key: String) -> Dictionary:
		return {"name": "bare", "thing": {"name": "bare"}, "materials": {}, "hash": "bare"}

	func versions_of() -> PropVersions:
		return LibraryVersions.new(LibraryProps.new())


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
	_named()
	await _viewer()
	await _together()
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
	ThingLibrary.add_version("cup", CUP, CLAY, "paint it in zebra stripes", "codex")
	var striped: Dictionary = ThingLibrary.versions("cup").back()
	var next := LibraryVersions.prompt("cup", "a clay cup", striped["thing"], striped["materials"], "make the rim thicker", true)
	_ok(String(next["prompt"]).contains("make the rim thicker") and not String(next["prompt"]).contains("zebra"),
		"refined again, the agent is told this ask alone, never the one that made the version it starts from")
	var p := LibraryVersions.prompt("cup", "a clay cup", CUP, CLAY, "taller", true)
	_ok(String(p["prompt"]).contains("taller") and String(p["prompt"]).contains("\"lathe\"") and String(p["prompt"]).contains("PARTS")
		and not String(p["prompt"]).contains("{{"), "the agent is told the prop, the change asked and the prop language")


## A refinement that makes it something else names its version, and the prop takes the name when that version is used.
func _named() -> void:
	ThingLibrary.keep({"name": "bowl", "parts": [{"shape": "lathe", "profile": [[0, 0], [4, 0], [5, 3], [0, 3]], "material": "clay"}]}, CLAY, "a bowl")
	var renaming := "{\"name\": \"vase\", \"line\": \"a tall clay vase\", \"thing\": {\"parts\": [{\"shape\": \"lathe\", \"profile\": [[0, 0], [3, 0], [4, 14], [0, 14]], \"material\": \"clay\"}]}, \"materials\": {\"clay\": {\"kind\": \"ceramic\", \"color\": \"#b5651d\"}}}"
	var had := ThingLibrary.versions("cup").size()
	var got := LibraryVersions.land("cup", renaming, "make it a vase", "claude", {}, 0)
	var i := int(got.get("index", -1))
	var vs := ThingLibrary.versions("cup")
	_ok(i == had and String(got.get("name", "")) == "vase" and String(vs[i]["name"]) == "vase" and String(vs[i]["line"]) == "a tall clay vase"
		and String(vs[0]["name"]) == "cup" and ThingLibrary.names().has("cup"), "an answer's name and line are its version's, the prop keeping its own (%s)" % str(got))
	var h := String(vs[i]["hash"])
	_ok(ThingLibrary.use_version("cup", i).is_empty() and ThingLibrary.kept_as(h) == "vase" and ThingLibrary.names().has("vase")
		and not ThingLibrary.names().has("cup") and String(ThingLibrary.read("vase")["line"]) == "a tall clay vase",
		"used, the prop takes the version's name and line, its file moved (%s)" % str(ThingLibrary.names()))
	_ok(String(ThingLibrary.read("cup").get("name", "")) == "vase" and String(ThingLibrary.read("cup").get("hash", "")) == h,
		"its former name still finds it, as a desk choosing it by that name reads it")
	_ok(ThingLibrary.use_version("vase", 0).is_empty() and ThingLibrary.names().has("cup") and not ThingLibrary.names().has("vase"),
		"the first version used again takes its own name back")
	var bowl := LibraryVersions.land("cup", renaming.replace("\"vase\"", "\"bowl\""), "a bowl", "claude", {}, 0)
	_ok(ThingLibrary.use_version("cup", int(bowl["index"])).is_empty() and ThingLibrary.names().has("cup") and ThingLibrary.names().has("bowl")
		and ThingLibrary.kept_as(String(ThingLibrary.versions("cup")[int(bowl["index"])]["hash"])) == "cup",
		"the control: a name another prop has is passed over, the prop keeping its own")
	ThingLibrary.use_version("cup", 0)
	var lib := LibraryProps.new()
	lib.keep({"name": "vase", "parts": [{"shape": "lathe", "profile": [[0, 0], [2, 0], [2, 5], [0, 5]], "material": "clay"}]}, CLAY, "")
	_ok(ThingLibrary.names().has("vase 2") and not ThingLibrary.names().has("vase"), "a new prop is never kept under a former name: %s" % str(ThingLibrary.names()))
	ThingLibrary.remove("vase 2")
	ThingLibrary.remove("bowl")
	var p := LibraryVersions.prompt("cup", "a clay cup", CUP, CLAY, "make it a vase", false)
	_ok(String(p["prompt"]).contains("give it a new name") and String(p["prompt"]).contains("\"line\""), "the agent is told it may rename the prop")


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
	_ok(not viewer._refine_btn.disabled and not viewer._ver.visible and not "_use" in viewer, "a seen prop offers Refine, no versions yet, and no button to use one")
	viewer.open_refine()
	viewer._refine.set_direction("make it taller")
	viewer._refine._ask()
	for i in 30:
		await get_tree().process_frame
	_ok(ThingLibrary.names().size() == before and ThingLibrary.versions("jug").size() == 2 and bool(ThingLibrary.read("jug")["draft"])
		and lib.stand.asked == 1, "refined, it is held as a draft with its versions, never kept (%s)" % str(ThingLibrary.names()))
	_ok(viewer._ver.visible and viewer._ver.text == "2 / 2" and ThingLibrary.used_of(ThingLibrary.read("jug")) == 0,
		"the version made is shown, 2 of 2, not yet used (%s)" % viewer._ver.text)
	lib.refresh()
	var seen_offer: Array = lib.offers().filter(func(o: Dictionary) -> bool: return String(o["key"]) == seen_key)
	var jug_tiles := func() -> Array:
		return lib.offers().filter(func(o: Dictionary) -> bool: return String(o["shelf"]) == "kept" and String(o["name"]).begins_with("jug"))
	_ok(not seen_offer.is_empty() and not String(seen_offer[0]["line"]).contains("in your library") and (jug_tiles.call() as Array).is_empty()
		and ThingLibrary.search("jug").is_empty() and not seen_offer[0].has("verbs"),
		"the seen jug says nothing kept and has no Keep, the Dex has no jug, and an agent's search finds none")
	_ok(viewer._keep_btn.visible and not viewer._keep_btn.disabled and viewer._keep_btn.text == "Keep", "the view offers Keep")
	viewer.keep_prop()
	lib.refresh()
	seen_offer = lib.offers().filter(func(o: Dictionary) -> bool: return String(o["key"]) == seen_key)
	_ok(not bool(ThingLibrary.read("jug")["draft"]) and ThingLibrary.versions("jug").size() == 2 and (jug_tiles.call() as Array).size() == 1
		and String(seen_offer[0]["line"]).contains("in your library") and viewer._keep_btn.disabled and viewer._keep_btn.text == "Kept",
		"Keep keeps it with both versions: the Dex has one jug, the seen one says so, the view says Kept")
	viewer.step(-1)
	_ok(viewer._shown == 0 and viewer._ver.text == "1 / 2" and ThingLibrary.used_of(ThingLibrary.read("jug")) == 0,
		"stepping back shows the first, the one used; a step uses nothing")
	viewer.step(1)
	_ok(ThingLibrary.used_of(ThingLibrary.read("jug")) == 0, "stepping on to the second uses nothing yet")
	viewer._close()
	_ok(ThingLibrary.used_of(ThingLibrary.read("jug")) == 1, "the version shown when the view closes is the prop")
	var kept_key := String(((jug_tiles.call() as Array)[0] as Dictionary)["key"])
	viewer.open(lib, kept_key, "jug")
	viewer.step(-1)
	var dp := DispatchProps.new()
	viewer.open(dp, "role:terminal", "terminal")
	_ok(ThingLibrary.used_of(ThingLibrary.read("jug")) == 0, "and the one shown when it opens another prop")
	var other_ep := TableEpisode.open("yet another", 5)
	other_ep.write_json("table", {"things": [{"name": "bowl of salt", "parts": [{"shape": "lathe", "profile": [[0, 0], [5, 0], [5, 3], [0, 3]], "material": "tin"}]}],
		"materials": {"tin": {"kind": "metal", "color": "#bbbbbb"}}})
	var shelf_lib := LibraryProps.new()
	var bowl_key := ""
	for i in 200:
		var found: Array = shelf_lib.seen_list().filter(func(e: Dictionary) -> bool: return String(e["name"]) == "bowl of salt")
		if not found.is_empty():
			bowl_key = String(found[0]["key"])
			break
		await get_tree().process_frame
	var chose := {}
	var makes := MakeShelf.new("mug", 1, shelf_lib, func(c: Dictionary) -> String:
		chose.merge(c, true)
		return "", func() -> Dictionary: return {})
	_ok(not bowl_key.is_empty() and makes.add(bowl_key).is_empty() and String(chose.get("kept", "")) == "bowl of salt"
		and bool(ThingLibrary.read("bowl of salt")["draft"]) and not ThingLibrary.names().has("bowl of salt"),
		"a seen prop chosen for a desk's part plays it as a draft, never kept (%s)" % str(chose))
	shelf_lib.settle()
	viewer.open(lib, kept_key, "jug")
	viewer.step(1)
	viewer.open(lib, seen_key, "jug")
	_ok(ThingLibrary.used_of(ThingLibrary.read("jug")) == 1 and viewer._shown == 0, "the table's jug opens on the version it stands, the first")
	viewer.open(dp, "role:terminal", "terminal")
	_ok(ThingLibrary.used_of(ThingLibrary.read("jug")) == 1, "the control: only opened and left, nothing changes")
	# named: a refinement that makes it something else, and a person typing over the name
	lib.stand.answer = "{\"name\": \"pitcher\", \"line\": \"a tin pitcher\", \"thing\": {\"parts\": [{\"shape\": \"lathe\", \"profile\": [[0, 0], [4, 0], [4, 16], [0, 16]], \"material\": \"tin\"}]}, \"materials\": {\"tin\": {\"kind\": \"metal\", \"color\": \"#bbbbbb\"}}}"
	lib.refresh()
	viewer.open(lib, kept_key, "jug")
	viewer.open_refine()
	viewer._refine.set_direction("make it a pitcher")
	viewer._refine._ask()
	for i in 30:
		await get_tree().process_frame
	_ok(viewer._named.text == "pitcher" and viewer._named.editable and ThingLibrary.names().has("jug"),
		"the version a refinement renamed shows its name at the top, the prop still the jug (%s)" % viewer._named.text)
	viewer.step(-1)
	_ok(viewer._named.text == "jug", "stepping back shows the jug's own name")
	viewer.name_shown("tin jug")
	_ok(ThingLibrary.names().has("tin jug") and not ThingLibrary.names().has("jug") and viewer._kept == "tin jug",
		"typed over on the version used, the prop is renamed and the view follows (%s)" % str(ThingLibrary.names()))
	viewer.step(1)
	viewer.name_shown("tall pitcher")
	_ok(ThingLibrary.names().has("tin jug") and String(ThingLibrary.versions("tin jug")[2]["name"]) == "tall pitcher",
		"typed over on a version not used, only the version is named")
	viewer._close()
	_ok(ThingLibrary.names().has("tall pitcher") and not ThingLibrary.names().has("tin jug") and String(ThingLibrary.read("jug").get("name", "")) == "tall pitcher",
		"closed on it, the prop takes its name, and its former names still find it (%s)" % str(ThingLibrary.names()))
	viewer.open(dp, "role:terminal", "terminal")
	var terminal_refines := not viewer._refine_btn.disabled
	viewer.open(Bare.new(), "bare", "bare")
	_ok(terminal_refines and viewer._refine_btn.disabled, "the desk's terminal offers Refine; the control, a prop with no parts, does not")
	viewer._close()
	viewer.queue_free()
	lib.settle()
	dp.settle()


## Two props refined at once, the view closed and turned from one to the other while their agents work.
func _together() -> void:
	PropRefining.clear()
	for n in ["lamp", "kettle"]:
		var tall := 6 if n == "lamp" else 9
		ThingLibrary.keep({"name": n, "parts": [{"shape": "lathe", "profile": [[0, 0], [3, 0], [3, tall], [0, tall]], "material": "clay"}]}, CLAY, "")
	var lib := SlowLibrary.new()
	var viewer := PropViewer.new()
	add_child(viewer)
	var ask := func(key: String, name: String, words: String) -> void:
		viewer.open(lib, key, name)
		viewer.open_refine()
		viewer._refine.set_direction(words)
		viewer._refine._ask()
	viewer.open(lib, "kept:lamp", "lamp")
	for i in 5:
		await get_tree().process_frame
	var quiet_size := viewer._view.size
	ask.call("kept:lamp", "lamp", "give it a shade")
	for i in 5:
		await get_tree().process_frame
	_ok(viewer._status_box.visible and viewer._view.size == quiet_size and viewer._status_box.get_parent() == viewer._view.get_parent(),
		"what the view says lies over the foot of the 3D view: the view keeps its size (%s, was %s)" % [viewer._view.size, quiet_size])
	_ok(not viewer._refine.visible and PropRefining.busy("lamp") and viewer._status.text.contains("drawing it") and viewer._stop_btn.visible
		and viewer._refine_btn.disabled, "Refine closes its words' window, and the view says what the agent is doing, with Stop (%s)" % viewer._status.text)
	viewer._close()
	ask.call("kept:kettle", "kettle", "give it a spout")
	for i in 5:
		await get_tree().process_frame
	_ok(PropRefining.busy("lamp") and PropRefining.busy("kettle"), "closed and turned to another prop, both are refined at once")
	_ok(not lib.versions_of().start_refine("kettle", 0, "again", {}).is_empty(), "the control: the same prop again is refused while one is at it")
	var card := PropsCard.new(func() -> Array: return [lib])
	var row := card._with_refining(lib, {"key": "kept:lamp", "line": "6 cm"})
	var said: Array = card._refining.get("%d:kept:lamp" % lib.get_instance_id(), [])
	_ok(String(row.get("refining", "")) == "working" and not said.is_empty() and String(said[1]).contains("drawing it"),
		"a Props card row says what its agent is doing (%s)" % str(said))
	_ok(not card._with_refining(lib, {"key": "kept:cup", "line": ""}).has("refining"), "the control: a row nothing refines is as it was")
	Slow.release["lamp"] = true
	for i in 5:
		await get_tree().process_frame
	card._refining.clear()
	card._with_refining(lib, {"key": "kept:lamp", "line": ""})
	_ok(String(PropRefining.of("lamp").get("state", "")) == "ready" and String((card._refining.values()[0] as Array)[1]).contains("new version is ready"),
		"its version made while nobody looks, the row says a new version is ready")
	viewer.open(lib, "kept:lamp", "lamp")
	for i in 5:
		await get_tree().process_frame
	_ok(viewer._ver.text == "2 / 2" and viewer._shown == 1 and PropRefining.of("lamp").is_empty() and viewer._status.text.contains("Version 2 is new"),
		"the view opened on it shows the version made, said once (%s)" % viewer._ver.text)
	viewer.open(lib, "kept:kettle", "kettle")
	viewer.stop_refining()
	for i in 5:
		await get_tree().process_frame
	_ok(not PropRefining.busy("kettle") and ThingLibrary.versions("kettle").size() == 1 and viewer._status.text.contains("stopped"),
		"Stop gives it up, adding nothing, and the view says so (%s)" % viewer._status.text)
	card.free()
	# the writer picked is kept for the next window, in another session too (ghost.cfg, written in memory by this read-only run)
	viewer._refine._pick.set_choice("codex", "a-model", "high")
	viewer._refine._remember()
	var kept := AgentPick.last_for("refine_prop")
	var fresh := PropRefine.new()
	_ok(String(kept.get("agent", "")) == String(fresh.pick().get("agent", "x")) and String(kept.get("agent", "")) == String(viewer._refine.pick()["agent"]),
		"the writer picked is kept between sessions, and a new Refine window starts with it (%s)" % str(kept))
	fresh.free()
	viewer._close()
	viewer.queue_free()
	lib.settle()
	Slow.release.clear()
	PropRefining.clear()


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
	_ok(dp.refined("role:mug", String(dk.get("name", ""))).is_empty() and fmt.things().get("mug") == PropMakes.chosen({"kept": String(dk.get("name", ""))}),
		"a desk's part refined is played by the prop kept from it (%s)" % str(fmt.things()))
	var tk := String(dp.versions_of().keep(dp.prop_of("role:terminal")).get("name", ""))
	_ok(not tk.is_empty() and dp.refined("role:terminal", tk).is_empty() and fmt.things().get("terminal") == PropMakes.chosen({"kept": tk}),
		"the desk's terminal refined is played by the prop kept from it (%s)" % str(fmt.things()))
	var blind: Dictionary = (ThingLibrary.read(tk)["thing"] as Dictionary).duplicate(true)
	blind["parts"] = (blind["parts"] as Array).slice(0, 7)
	ThingLibrary.add_version(tk, blind, ThingLibrary.read(tk)["materials"], "no screen", "claude")
	ThingLibrary.use_version(tk, 1)
	_ok(not dp.refined("role:terminal", tk).is_empty() and not PropMakes.fits("terminal", ThingLibrary.read(tk)["thing"]),
		"a version used that has lost its screen is said to: the desk's own plays it")
	dp.settle()
	fmt.free()
	# a Letter desk's thing refined
	var rows := DeskRows.new()
	rows.apply({"seed": 7, "things": ["cards", "pencil"], "card_text": "Send letters to:"})
	var dsec := rows.props()
	var own: Dictionary = dsec.prop_of("cards")
	var ck := String(dsec.versions_of().keep(own).get("name", ""))
	var blue: Dictionary = (ThingLibrary.read(ck)["materials"] as Dictionary).duplicate(true)
	for m in blue:
		(blue[m] as Dictionary)["color"] = "#2244aa"
	ThingLibrary.add_version(ck, ThingLibrary.read(ck)["thing"], blue, "blue cards", "claude")
	ThingLibrary.use_version(ck, 1)
	_ok(dsec.refined("cards", ck).is_empty() and rows.desk_makes() == {"cards": PropMakes.chosen({"kept": ck})}
		and String(dsec.prop_of("cards").get("name", "")) == ck, "a desk's thing refined is played by the prop kept from it (%s)" % str(rows.desk_makes()))
	var on_desk := _desk_thing(rows, "cards")
	_ok(String((on_desk.get("materials", {}) as Dictionary).values()[0]["color"]) == "#2244aa" and String(on_desk.get("kind", "")) == "cards"
		and String((on_desk.get("writing", {}) as Dictionary).get("text", "")) == "Send letters to:",
		"the desk draws it as the version used, the words on its cards its own (%s)" % str(on_desk.get("writing", {})))
	_ok(dsec.act("cards", "own").is_empty() and rows.desk_makes().is_empty()
		and ThingLibrary.hash_of(_desk_thing(rows, "cards")["thing"], _desk_thing(rows, "cards")["materials"]) == String(own["hash"]),
		"the control: Desk's own puts back the one the number draws")
	dsec.settle()
	rows.free()
	ed.free()


## Thing [param kind] as desk [param rows] draws it ([method DeskLook.of]).
static func _desk_thing(rows: DeskRows, kind: String) -> Dictionary:
	for t in DeskLook.of(rows.desk_seed(), DeskLook.picks_of(rows.picks()))["things"]:
		if String((t as Dictionary)["kind"]) == kind:
			return t
	return {}


func _clean(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for d in DirAccess.get_directories_at(path):
		_clean(path.path_join(d))
	for f in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	DirAccess.remove_absolute(path)
