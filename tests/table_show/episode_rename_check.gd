extends SceneTree

## episode_rename_check - a person of a table show called by another name ([EpisodeRename], [method EpisodeWalk.rename_read],
## [method KeptSteps.carry_over]), on two episodes of the gate's own (no agent, no renderer). It holds:
##
## - every word file of every episode names the new name: passages, the script, what was played, the session, the plan; the name
##   matched whole (a longer word that begins with it stays), and the take's record left to be said again;
## - nothing goes stale that was not: a page whose picture names the person stays fresh (the control: a page whose picture
##   changed for real is stale); a step stale before stays stale; a passage changed by a hand is still the author's;
## - each step whose file changed is kept a version back;
## - the brief's prose is renamed with it;
## - refused: a new name someone already has (the control, a new one, is taken), and a name with a mark's characters.
##
##   godot --headless --path . --script tests/table_show/episode_rename_check.gd

const ROOT := "user://episode_rename_check"
var _fails := 0
var _checks := 0


func _init() -> void:
	var was := TableEpisode.root
	TableEpisode.root = ROOT
	_wipe(ProjectSettings.globalize_path(ROOT))
	var ep := TableEpisode.open("rename-check", 5)
	ep.write_json("plan", {"game": true, "episode_title": "The Mill", "premise": "Dell has prepared a mill", "staging": {"source": "none"},
		"spread": {"positions": [{"name": "Part 1"}]}, "look": {}})
	ep.write_text("say:intro", "<!-- speaker: Narrator -->\nYou come to the mill, Bea. A beam of light.\n\n<!-- table: picture 1 -->\n\n"
		+ "<!-- table: roll 2 -->\n\n<!-- speaker: Bea -->\nSeven. Beatrix would have rolled better.")
	ep.write_text("say:1", "<!-- speaker: Narrator -->\nThe wheel turns.\n\n<!-- table: picture 3 -->\n\nBea's lamp gutters.")
	ep.write_text("say:close", "<!-- speaker: Bea -->\nMistakes were made.")
	var e1: Array = [{"id": 1, "kind": "picture", "name": "The mill", "looks": "Bea at the mill door at dusk", "shows": ["Bea"]},
		{"id": 2, "kind": "roll", "who": "Bea", "notation": "1d20", "why": "listening", "words": "7", "total": 7, "thrown": []}]
	_events(ep, "say:intro", e1)
	_events(ep, "say:1", e1 + [{"id": 3, "kind": "picture", "name": "The wheel", "looks": "the wheel turning, dark water", "shows": []}])
	for st in ["plan", "say:intro", "say:1", "say:close"]:
		ep.note_made(st, "gate")
	var p := TableProducer.new(ep, {"voices": ["Dell", "Bea"], "writer": "claude", "brief": "a game"})
	_ok(p._make_script().is_empty() and ep.has("script"), "the script is put together")
	ep.note_made("script", "gate")
	for k in [1, 2]:
		var f := FileAccess.open(ep.file_of("image:page:%d" % k), FileAccess.WRITE)
		f.store_string("page %d" % k)
		f.close()
		ep.note_made("image:page:%d" % k, "painter")
	_ok(ep.pages_own_pictures().is_empty(), "the pages are made from their own pictures")
	# ...a step stale before: the script, its last passage made again since
	ep.write_text("say:close", "<!-- speaker: Bea -->\nMistakes were made, Bea says.")
	ep.note_made("say:close", "gate")
	# ...a passage changed by a hand
	var f1 := FileAccess.open(ep.file_of("say:1"), FileAccess.WRITE)
	f1.store_string("<!-- speaker: Narrator -->\nThe wheel turns slowly.\n\n<!-- table: picture 3 -->\n\nBea's lamp gutters.")
	f1.close()
	var take := FileAccess.open(ep.take_file().get_basename() + ".json", FileAccess.WRITE)
	take.store_string("{\"words\": [{\"w\": \"Bea\"}]}")
	take.close()
	var other := TableEpisode.open("rename-check", 9)
	other.write_json("plan", {"game": true, "episode_title": "The Ford", "staging": {"source": "none"}, "spread": {"positions": []}, "look": {}})
	other.write_text("say:intro", "<!-- speaker: Bea -->\nThe ford again.")
	other.note_made("plan", "gate")
	other.note_made("say:intro", "gate")
	_ok(ep.stale("script") and not ep.stale("image:page:1") and not ep.stale("image:page:2") and ep.changed_by_hand("say:1"),
		"the fixture: the script stale, the pages fresh, a passage changed by a hand")
	var stale_before := {}
	for st in ep.steps():
		stale_before[String(st)] = ep.stale(String(st))
	var versions_before := ep.versions("say:intro").size()

	var eps := EpisodeRename.episodes_of(ep)
	var brief := "Dell runs the game. Bea plays a bard; Beatrix is her sister."
	_ok(eps.size() == 2, "every episode of the show is renamed: %d" % eps.size())
	_ok(not EpisodeRename.refused(eps, "Bea", "Dell", brief).is_empty(), "a name someone already has was taken")
	_ok(not EpisodeRename.refused(eps, "Bea", "B\"o", brief).is_empty() and not EpisodeRename.refused(eps, "Bea", "B|o", brief).is_empty(),
		"a name with a mark's characters was taken")
	_ok(EpisodeRename.refused(eps, "Bea", "Bo", brief).is_empty(), "control: a new name was refused")
	var walk := EpisodeWalk.new(func() -> TableEpisode: return ep)
	var told := [0]
	walk.renamed = func() -> void: told[0] += 1
	_ok(walk.rename_read("Bea", "Bo").is_empty() and told[0] == 1, "the rename was done, and the card told")
	_ok(walk.renamed_words(brief, "Bea", "Bo") == "Dell runs the game. Bo plays a bard; Beatrix is her sister.", "the brief's prose is renamed, whole words alone")

	var none_left := true
	for f in DirAccess.get_files_at(ep.dir):
		if ["json", "txt", "md"].has(String(f).get_extension()) and String(f) != "steps.json" and String(f) != "take.json" \
				and EpisodeRename.names(FileAccess.get_file_as_string(ep.dir.path_join(String(f))), "Bea"):
			none_left = false
			print("  still names Bea: " + String(f))
	_ok(none_left, "every word file names the new name")
	_ok(ep.script().contains("<!-- speaker: Bo -->") and ep.script().contains("A beam of light") and ep.script().contains("Beatrix would"),
		"the script's cues are renamed, and a longer word beginning with the name stays")
	_ok(String((ep.game()["pages"] as Array)[0]["looks"]) == "Bo at the mill door at dusk", "the session's picture names the new name")
	_ok(other.read_text("say:intro").contains("speaker: Bo"), "the show's other episode is renamed too")
	_ok(FileAccess.get_file_as_string(ep.take_file().get_basename() + ".json").contains("Bea"), "the take's record is left to be said again")
	var same := true
	for st in ep.steps():
		if ep.stale(String(st)) != bool(stale_before[String(st)]):
			same = false
			print("  %s was %s, now %s" % [st, stale_before[st], ep.stale(String(st))])
	_ok(same, "nothing went stale that was not, and what was stale still is")
	_ok(not ep.stale("image:page:1") and ep.stale("script") and ep.changed_by_hand("say:1") and ep.kept("say:1"),
		"a page whose picture names the person is fresh; the script still stale; the hand's passage still the author's")
	_ok(ep.versions("say:intro").size() == versions_before + 1, "a step whose file changed is kept a version back")
	# ...the control: a page's picture changed for real is stale
	var g := ep.game()
	(g["pages"] as Array)[0]["looks"] = "the mill on fire"
	ep.write_json("game", g)
	ep._changed()
	_ok(ep.stale("image:page:1") and not ep.stale("image:page:2"), "control: a page whose picture changed for real is stale")
	TableEpisode.root = was
	_wipe(ProjectSettings.globalize_path(ROOT))
	print("episode_rename_check: %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _events(ep: TableEpisode, step: String, list: Array) -> void:
	var f := FileAccess.open(ep.events_file(step), FileAccess.WRITE)
	f.store_string(JSON.stringify(list))
	f.close()


func _ok(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_fails += 1
		print("  FAIL: " + what)


func _wipe(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for f in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	for d in DirAccess.get_directories_at(path):
		_wipe(path.path_join(d))
	DirAccess.remove_absolute(path)
