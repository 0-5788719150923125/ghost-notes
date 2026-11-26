extends Node

## episode_environment_check - a table show's environment on the Environment card ([EpisodeEnvironment], [EnvironmentCard]): what the
## open episode's table is heard with and what lasts in its air, listed, tuned, set aside, kept and added to, on an episode and a
## library of its own.
##
##   tests/run_boot_probe.sh tests/table_show/episode_environment_check.gd 90
##
## - A table show brings the Environment card. While its episode is at its table the card lists the episode's (the control: an
##   episode at the desk lists the note's own).
## - A row each for the sound's parts and the lasting air, never a burst; a sound has Test, every row Keep, none Roll.
## - A property changed is the table's, as a hand's version, kept; the burst stays (the control: before, the level is the set
##   dresser's).
## - Unticked, an element is set aside and the table plays it no more; ticked, it plays again. Its × takes it off for good.
## - Keep puts it in the library and its row says Kept. Added from the Dex, rain is heard on the table and fireflies drift over it;
##   a light is refused (the table's light is its set dresser's). The Dex's shelves for a table hold no light.
## - Test plays a sound alone and stops when pressed again (the control: the haze has none).
## - At the desk, where the episode has no table, the reading hears the Environment card's sound; at the table, the episode's.

const ROOT := "user://episode_environment_check"

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
	var env_card: EnvironmentCard = ed._block_cards.get("environment")
	_ok(env_card != null, "a table show brings the Environment card")
	if env_card == null:
		_finish(ed, was_root, was_library)
		return
	show._knobs["show"] = "weather"
	show._knobs["seed"] = 3
	show._open_episode()
	var ep := show._episode
	ep.write_json("plan", {"episode_title": "Weather", "staging": {"source": "deck"}, "spread": {"positions": [{"name": "One"}]},
		"look": CardTable.sanitize_look({})})
	ep.write_json("table", {"things": [], "materials": {},
		"sound": {"why": "a porch in a storm", "wind": {"through": "trees", "level": 0.5}, "insects": {"kind": "crickets", "strength": 0.4}},
		"effects": [{"name": "mist", "kind": "fog", "where": "beyond the table", "density": 0.3},
			{"name": "pop", "kind": "burst", "look": "sparks", "on": "close"}]})
	var sec: EpisodeEnvironment = show._environment
	_ok(sec != null and ed.environment.call() == sec, "at its table, the episode hands the panel its environment")
	_ok(env_card.sections() == [sec], "and the Environment card lists it")

	# The rows
	var rows := sec.rows()
	var kinds := rows.map(func(r: Dictionary) -> String: return String(r["name"]))
	_ok(rows.size() == 3, "a row each for the wind, the insects and the haze, never the burst (%s)" % str(kinds))
	var verbs_of := func(name: String) -> Array:
		var r: Array = sec.rows().filter(func(x: Dictionary) -> bool: return String(x["name"]) == name)
		return (r[0]["verbs"] as Array).map(func(v: Dictionary) -> String: return String(v["key"])) if not r.is_empty() else []
	_ok(verbs_of.call("Wind").has("test") and verbs_of.call("Wind").has("keep") and not verbs_of.call("Wind").has("roll"),
		"a sound has Test and Keep, and no Roll (%s)" % str(verbs_of.call("Wind")))
	_ok(not verbs_of.call("Haze").has("test"), "the haze has no Test")

	# A property changed
	var key_of := func(name: String) -> String:
		var r: Array = sec.rows().filter(func(x: Dictionary) -> bool: return String(x["name"]) == name)
		return String(r[0]["key"]) if not r.is_empty() else ""
	_ok(is_equal_approx(_wind_level(ep), 0.5), "the control: before, the wind's level is the set dresser's")
	_ok(sec.set_field(key_of.call("Wind"), "level", 0.8).is_empty(), "the wind's level is set")
	_ok(is_equal_approx(_wind_level(ep), 0.8), "the table hears it (%s)" % str(_wind_level(ep)))
	_ok(ep.kept("table"), "the table is a hand's version, kept")
	_ok(_effects(ep).any(func(f: Dictionary) -> bool: return String(f["kind"]) == "burst"), "the burst stays")

	# Set aside, used again, taken off
	_ok(sec.set_on(key_of.call("Insects"), false).is_empty() and not _sound(ep).has("insects"), "unticked, the table plays the insects no more")
	var aside: Array = sec.rows().filter(func(x: Dictionary) -> bool: return String(x["group"]) == "aside")
	_ok(aside.size() == 1 and aside[0]["on"] == false, "its row is under Set aside, unticked")
	_ok(sec.set_on(String(aside[0]["key"]), true).is_empty() and _sound(ep).has("insects"), "ticked again, it plays again")
	_ok(sec.remove(key_of.call("Haze")).is_empty() and not _effects(ep).any(func(f: Dictionary) -> bool: return String(f["kind"]) == "fog"),
		"its × takes the haze off the table")

	# Keep, and from the Dex
	_ok(sec.act(key_of.call("Wind"), "keep").is_empty() and EnvironmentLibrary.entries().size() == 1, "Keep puts the wind in the library")
	var wind_row: Array = sec.rows().filter(func(x: Dictionary) -> bool: return String(x["name"]) == "Wind")
	_ok(not wind_row.is_empty() and ((wind_row[0]["verbs"] as Array).filter(func(v: Dictionary) -> bool: return String(v["key"]) == "keep")[0] as Dictionary)["label"] == "Kept",
		"and its row says Kept")
	_ok(sec.add("kind:rain").is_empty() and _sound(ep).has("rain"), "rain from the Dex is heard on the table")
	_ok(sec.add("kind:fireflies").is_empty() and _effects(ep).any(func(f: Dictionary) -> bool: return String(f.get("look", "")) == "firefly"),
		"fireflies from the Dex drift over it")
	_ok(not sec.add("preset:daylight").is_empty(), "a light is refused: the table's light is its set dresser's")
	_ok(sec.shelves().all(func(s: Dictionary) -> bool: return String(s["key"]) != "light"), "the Dex's shelves for a table hold no light")

	# Test
	var wi := int(String(key_of.call("Wind")).substr(3))
	_ok(sec.test(wi).is_empty() and sec.testing(wi), "Test plays the wind alone")
	_ok(sec.test(wi).is_empty() and not sec.testing(wi), "pressed again, it stops")

	# The bed: the episode's at its table
	var at_table: Dictionary = ed.bed.of()
	_ok(at_table.has("make"), "at its table the reading hears the episode's sound")
	env_card.apply({"elements": [{"kind": "rain", "seed": 5}]})
	var plan: Dictionary = ep.read_json("plan")
	plan["medium"] = "desk"
	plan["staging"] = {"source": "none"}
	ep.write_json("plan", plan)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ep.file_of("table")))
	_ok(ed.environment.call() == null and env_card.sections() == [env_card.section], "the control: at the desk the card lists the note's own")
	var at_desk: Dictionary = ed.bed.of()
	_ok(at_desk.has("make") and String(at_desk.get("key", "")).contains("rain"), "at the desk the reading hears the Environment card's (%s)" % str(at_desk.get("key", "")))
	_ok(is_equal_approx(ed.bed.level(), EnvironmentCard.Bed.new(env_card).level()), "at its level")
	_finish(ed, was_root, was_library)


func _sound(ep: TableEpisode) -> Dictionary:
	var t: Variant = ep.read_json("table")
	return Soundscape.sanitize((t as Dictionary).get("sound")) if t is Dictionary else {}


func _wind_level(ep: TableEpisode) -> float:
	return float((_sound(ep).get("wind", {}) as Dictionary).get("level", -1.0))


func _effects(ep: TableEpisode) -> Array:
	var t: Variant = ep.read_json("table")
	return ((t as Dictionary).get("effects", []) as Array) if t is Dictionary else []


func _finish(ed: ReadingPanel, was_root: String, was_library: String) -> void:
	ed.free()
	TableEpisode.root = was_root
	Library.root = was_library
	Library.discard = Callable()
	_clean(ProjectSettings.globalize_path(ROOT))
	print("episode_environment_check: %s" % ("ALL OK" if _fails == 0 else "%d FAILED" % _fails))
	get_tree().quit(0 if _fails == 0 else 1)


func _clean(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for d in DirAccess.get_directories_at(path):
		_clean(path.path_join(d))
	for f in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	DirAccess.remove_absolute(path)
