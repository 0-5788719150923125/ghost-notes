extends SceneTree

## episode_script_check - a game's script read and edited ([EpisodeScript], [method TableProducer.readable_script], [method
## TableProducer.write_game_script]), on an episode of the gate's own (no agent, no renderer). It holds:
##
## - read, every table mark says what it is: a picture its name and what it shows, a throw what came of it;
## - a picture's words changed are the session's (every stretch's events, and the picture list) and stale that page alone; the
##   control, a page whose picture is the same, stays fresh;
## - words changed go back to their passage, kept as the author's, and nothing made from them goes stale (the stretch after it,
##   the figures made from the script): only a page whose picture changed does;
## - a picture added ("picture new") is the session's last, so no page painted already changes its number;
## - every other mark stands: a throw's mark taken out is refused (the control), and its words after the bar are only read.
##
##   godot --headless --path . --script tests/table_show/episode_script_check.gd

const ROOT := "user://episode_script_check"
var _fails := 0
var _checks := 0


func _init() -> void:
	var was := TableEpisode.root
	TableEpisode.root = ROOT
	_wipe(ProjectSettings.globalize_path(ROOT))
	var ep := TableEpisode.open("script-check", 5)
	ep.write_json("plan", {"game": true, "episode_title": "The Mill", "staging": {"source": "none"}, "spread": {"positions": [{"name": "Part 1"}]}, "look": {}})
	ep.write_text("say:intro", "<!-- speaker: Narrator -->\nYou come to the mill.\n\n<!-- table: picture 1 -->\n\nIt is very quiet.\n\n<!-- table: roll 2 -->\n\n<!-- speaker: Bea -->\nSeven.")
	ep.write_text("say:1", "<!-- speaker: Narrator -->\nThe wheel turns.\n\n<!-- table: picture 3 -->\n\nSomething moves in the race.")
	ep.write_text("say:close", "<!-- speaker: Bea -->\nMistakes were made.")
	var e1: Array = [{"id": 1, "kind": "picture", "name": "The mill", "looks": "a mill by a river at dusk", "shows": []},
		{"id": 2, "kind": "roll", "who": "Bea", "notation": "1d20", "why": "listening", "words": "7", "total": 7, "thrown": []}]
	_events(ep, "say:intro", e1)
	_events(ep, "say:1", e1 + [{"id": 3, "kind": "picture", "name": "The wheel", "looks": "the wheel turning, dark water", "shows": []}])
	for st in ["plan", "say:intro", "say:1", "say:close"]:
		ep.note_made(st, "gate")
	var mf := FileAccess.open(ep.file_of("minis"), FileAccess.WRITE)
	mf.store_string("{}")
	mf.close()
	var p := TableProducer.new(ep, {"voices": ["Dell", "Bea"], "writer": "claude", "brief": "a game"})
	_ok(p._make_script().is_empty() and ep.has("script") and (ep.game().get("pages", []) as Array).size() == 2, "the script and its two pictures are put together")
	ep.note_made("script", "gate")
	ep.note_made("minis", "gate")
	for k in [1, 2]:
		var f := FileAccess.open(ep.file_of("image:page:%d" % k), FileAccess.WRITE)
		f.store_string("page %d" % k)
		f.close()
		ep.note_made("image:page:%d" % k, "painter")
	var read := p.readable_script()
	_ok(read.contains("<!-- table: picture 1 | The mill: a mill by a river at dusk -->"), "a picture's mark says its name and what it shows")
	_ok(read.contains("<!-- table: roll 2 | Bea throws 1d20 for listening: 7 -->"), "a throw's says what came of it")
	# ...a picture's words, and a passage's
	var edited := read.replace("a mill by a river at dusk", "a mill in the rain, one lamp lit").replace("Something moves in the race.", "Something swims in the race.")
	edited = edited.replace("roll 2 | Bea throws 1d20 for listening: 7", "roll 2 | a natural twenty")
	_ok(p.write_script(edited).is_empty(), "the script written back")
	_ok(String((ep.game()["pages"] as Array)[0]["looks"]) == "a mill in the rain, one lamp lit", "a picture's new words are the session's")
	var both := true
	for st in ["say:intro", "say:1"]:
		for e in JSON.parse_string(FileAccess.get_file_as_string(ep.events_file(st))):
			if int(e["id"]) == 1 and String(e["looks"]) != "a mill in the rain, one lamp lit":
				both = false
	_ok(both, "...in every stretch's events")
	_ok(ep.stale("image:page:1") and not ep.stale("image:page:2"), "that page alone is stale; the control, a page whose picture is the same, is not")
	_ok(ep.read_text("say:1").contains("Something swims") and ep.kept("say:1"), "words changed go back to their passage, kept as the author's")
	_ok(not ep.stale("say:close") and not ep.stale("minis") and not ep.stale("script"),
		"an edit is no step's making: the stretch after a passage changed, and what is made from the script, stay fresh")
	var roll_said := false
	for e in JSON.parse_string(FileAccess.get_file_as_string(ep.events_file("say:1"))):
		if int(e["id"]) == 2:
			roll_said = String(e["words"]) == "7"
	_ok(roll_said, "a throw's words after the bar are only read: what was thrown stands")
	# ...a picture added
	var added := p.readable_script().replace("Something swims in the race.", "Something swims in the race.\n\n<!-- table: picture new | The eel: an eel in the mill race -->")
	_ok(p.write_script(added).is_empty(), "a picture added is written back")
	var pages: Array = ep.game().get("pages", [])
	_ok(pages.size() == 3 and String(pages[2]["name"]) == "The eel" and String(pages[0]["name"]) == "The mill" and String(pages[1]["name"]) == "The wheel",
		"it is the session's last picture: no page painted already changes its number")
	_ok(ep.read_text("say:1").contains("<!-- table: picture 4 -->"), "its mark takes its number in its passage")
	# ...the control: what happened stands
	var cut := p.readable_script()
	var rx := RegEx.create_from_string("<!-- table: roll 2[^>]*-->")
	_ok(not p.write_script(rx.sub(cut, "")).is_empty(), "control: a throw's mark taken out is refused")
	TableEpisode.root = was
	_wipe(ProjectSettings.globalize_path(ROOT))
	print("episode_script_check: %d checks, %d failed" % [_checks, _fails])
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
