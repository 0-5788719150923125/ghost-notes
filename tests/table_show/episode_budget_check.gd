extends SceneTree

## Episode budgets and content history, without a writer or renderer. New plans default to 10-15 minutes; a brief's
## explicit range survives. The word budget covers the whole show at the selected voice's pace, including a card's separate
## work passage. Controls: legacy passage sizes remain unchanged; short replies and voice marks do not satisfy a budget.
## Written cards with no art reach the producer's history with their contents, and never leak into an opening reader's prompt.
##
##   godot --headless --path . --script tests/table_show/episode_budget_check.gd

const ROOT := "user://episode_budget_check"
var _fails := 0


func _init() -> void:
	_run.call_deferred()


func _ok(condition: bool, what: String) -> void:
	print(("  ok    " if condition else "  FAIL  ") + what)
	if not condition:
		_fails += 1


func _run() -> void:
	TableEpisode.root = ROOT
	_clean(ProjectSettings.globalize_path(ROOT))
	Rules.clear()
	for check in [_budgets, _landed, _history]:
		var done: Variant = (check as Callable).call()
		_ok(done == true, "%s completes" % (check as Callable).get_method())
	_ok(Rules.missing.is_empty(), "every prompt renders whole: %s" % str(Rules.missing))
	_clean(ProjectSettings.globalize_path(ROOT))
	TableEpisode.root = TableEpisode.ROOT
	print("episode_budget_check: %s" % ("ALL OK" if _fails == 0 else "%d FAILED" % _fails))
	quit(0 if _fails == 0 else 1)


static func _plan(n: int, work := false, bare := false) -> Dictionary:
	var positions: Array = []
	for i in n:
		var p := {"name": "Part %d" % (i + 1), "asks": "what happens"}
		if work:
			p["work"] = "something is prepared and used"
		positions.append(p)
	return {"minutes": [10, 15], "episode_title": "A Show", "spread": {"positions": positions},
		"staging": {"source": "none" if bare else "box", "pace": "reflective"}, "look": {}}


func _budgets() -> bool:
	for n in [1, 3, 10]:
		for work in [false, true]:
			for bare in [false, true]:
				for pace in [0.36, 0.52, 0.75]:
					var plan := _plan(n, work, bare)
					var ranges := TablePrompts.passage_words(plan, pace)
					var total := Vector2.ZERO
					for span: Vector2i in ranges.values():
						total += Vector2(span) * pace
					_ok(absf(total.x - 600.0) < 5.0 and absf(total.y - 900.0) < 5.0,
						"%d parts, work %s, bare %s, %.2fs/word: %.1f-%.1fs" % [n, work, bare, pace, total.x, total.y])
	var plan := _plan(1, true)
	var draw := [{"name": "Today's Card", "meaning": "a story", "writing": {"title": "A Card", "lines": ["some work"]}}]
	var act := [{"name": "prepare", "about": "the work is prepared", "length": 67.0}]
	var passage := TablePrompts.reader("Show", "A brief", plan, "work:1", [], draw, 1, false, [], [], [], true, false, [], act)
	var words: Vector2i = passage["words"]
	_ok(words.x > 700 and String(passage["prompt"]).contains("whole episode is planned for 10 to 15 minutes"),
		"a short animation gets a full story budget (%s words): %s" % [str(words), String(passage["prompt"]).substr(String(passage["prompt"]).find("The whole episode"), 100)])
	var slower := TablePrompts.reader("Show", "A brief", plan, "work:1", [], draw, 1, false, [], [], [], true, false, [], act, 0.75)
	_ok((slower["words"] as Vector2i).x < words.x, "a slower voice needs fewer words")
	var long_act := act.duplicate(true)
	long_act[0]["length"] = 1200.0
	var long_work := TablePrompts.reader("Show", "A brief", plan, "work:1", [], draw, 1, false, [], [], [], true, false, [], long_act)
	_ok((long_work["words"] as Vector2i).x >= floori(1200.0 / TablePrompts.SAID_WORD), "a runtime budget never shortens work that needs longer")
	plan.erase("minutes")
	var legacy := TablePrompts.reader("Show", "A brief", plan, "work:1", [], draw, 1, false, [], [], [], true, false, [], act)
	_ok((legacy["words"] as Vector2i).y < 300 and TablePrompts.passage_words(plan).is_empty(), "control: an existing plan keeps its original passage sizes")
	plan["minutes"] = [2, 3]
	var small := TablePrompts.passage_words(plan)
	var small_total := Vector2.ZERO
	for span: Vector2i in small.values():
		small_total += Vector2(span) * TablePrompts.SAID_WORD
	_ok(absf(small_total.x - 120.0) < 3.0 and absf(small_total.y - 180.0) < 3.0, "an explicitly short show keeps its duration")
	plan["minutes"] = [10, 15]
	plan["quiet"] = 0.5
	var quiet := TablePrompts.passage_words(plan)
	var quiet_total := Vector2.ZERO
	for key in quiet:
		quiet_total += Vector2(quiet[key]) * TablePrompts.SAID_WORD / (0.5 if key == "work:1" else 1.0)
	_ok(absf(quiet_total.x - 600.0) < 5.0 and absf(quiet_total.y - 900.0) < 5.0, "quiet time counts toward the episode budget")
	var quiet_passage := TablePrompts.reader("Show", "A brief", plan, "work:1", [], draw, 1, false, [], [], [], true, false, [], act)
	var silence := Manuscript._rx("About (\\d+) of those seconds").search(String(quiet_passage["prompt"]))
	_ok((quiet_passage["words"] as Vector2i).x < words.x and silence != null and int(silence.get_string(1)) > 100,
		"a quiet passage's prompt budgets actual silence beside its reduced word count")
	_ok(TablePrompts.minutes_of({"minutes": [-1, 0]}) == TablePrompts.MINUTES
		and TablePrompts.minutes_of({"minutes": [15, 10]}) == TablePrompts.MINUTES
		and TablePrompts.minutes_of({"minutes": "ten minutes"}) == TablePrompts.MINUTES, "invalid ranges use the default")
	return true


func _landed() -> bool:
	var ep := TableEpisode.open("budget", 1)
	var producer := TableProducer.new(ep, {"title": "Show", "brief": "A brief", "deck": [{"name": "A"}]})
	var plan := _plan(1)
	plan.erase("minutes")
	_ok(producer._land_plan(JSON.stringify(plan)).is_empty(), "a plan without a duration lands")
	_ok(ep.read_json("plan").get("minutes") == [10.0, 15.0], "new plans default to 10-15 minutes")
	plan["minutes"] = [2, 3]
	_ok(producer._land_plan(JSON.stringify(plan)).is_empty() and ep.read_json("plan").get("minutes") == [2.0, 3.0], "a requested range survives landing")
	var beats := {"beats": [{"name": "First", "asks": "what happens"}], "look": {}}
	_ok(producer._land_plan(JSON.stringify(beats)).is_empty() and ep.read_json("plan").get("minutes") == [10.0, 15.0], "a plan of beats gets the same default")
	var requested: Vector2i = producer.say_prompt("1")["words"]
	_ok(not TableProducer.short_passage("A tiny story.", requested).is_empty(), "a tiny story fails its requested budget")
	_ok(not TableProducer.short_passage("<!-- delivery: " + "many words ".repeat(1000) + "--> Tiny.", requested).is_empty(), "voice marks do not count as spoken words")
	producer._tries["say:1"] = TableProducer.RETRIES + 1
	producer._land("say:1", {"ok": true, "text": "A tiny story."})
	_ok(not ep.has("say:1") and not producer.error_of("say:1").is_empty(), "an undersized reply stays failed instead of making a short episode")
	producer._land("say:1", {"ok": true, "text": "word ".repeat(requested.x)})
	_ok(ep.has("say:1") and producer.error_of("say:1").is_empty(), "control: a full passage is accepted")
	return true


func _history() -> bool:
	var old := TableEpisode.open("history", 1)
	old.write_json("plan", _plan(1))
	old.write_json("draw", {"cards": [{"name": "Previous Card", "meaning": "OLD-CONTENTS ingredient-a and ingredient-b"}]})
	old.write_json("design:1", {"writing": {"title": "Previous Card", "lines": ["OLD-WRITING prepare ingredient-a", "use ingredient-b"]}})
	var history := TableEpisode.archive("history", 2)
	var prompt := String(TablePrompts.producer("Show", "A brief", 2, CardTable.FACES, CardTable.FRAMES, history, [], true)["prompt"])
	_ok(prompt.contains("OLD-CONTENTS") and prompt.contains("OLD-WRITING") and prompt.contains("THE CONTENT MATTERS TOO"), "a written card with no art reaches the producer with its contents")
	_ok(TablePrompts._past_line(history[0]).contains("OLD-CONTENTS"), "compact history also retains drawn contents")
	_ok(TableEpisode.archive("history", 1).is_empty(), "control: the episode never sees itself as history")
	var intro := String(TablePrompts.reader("Show", "A brief", _plan(1), "intro", [], [], 1, false, history)["prompt"])
	_ok(not intro.contains("OLD-CONTENTS") and not intro.contains("OLD-WRITING"), "producer content history never leaks through the opening reader")
	return true


static func _clean(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	for dir in DirAccess.get_directories_at(path):
		_clean(path.path_join(dir))
	DirAccess.remove_absolute(path)
