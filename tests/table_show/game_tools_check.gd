extends SceneTree

## game_tools_check - the table, live: a scene played through the tools, the players answered by a stand-in, and what comes out is a script the rest of the show reads (next/tabletop.md). It holds that the tools write the script in the order things happened, that a line can only be someone at the table saying words, that nothing rolled can be hidden or thrown again, that a player's question reaches them with nothing the game master keeps from them, and that a game can end early and the scenes left are nothing. It holds it on a d20 game, a wargame's bucket of sixes on a board measured in inches, and a percentile game with no map. No game is named in the code: this gate is where the three stand. The controls are the refused calls.
##
##     timeout 300 godot --headless --path . --script tests/table_show/game_tools_check.gd

const ROOT := "user://_game_tools_check"
var fails := 0
var people := PackedStringArray(["Dell", "Bea", "Milo"])


func _check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		printerr("FAIL: ", what)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	TableEpisode.root = ROOT
	await _d20()
	await _wargame()
	await _percentile()
	_prep()
	_gather()
	_prompts()
	_steps()
	_clean()
	print("game_tools_check: ", "ok" if fails == 0 else "%d failed" % fails)
	quit(1 if fails > 0 else 0)


func _tools(scene := "1", sheets := {"Bea": {"hit points": 12}, "Milo": {"hit points": 9, "pack": ["rope"]}}) -> GameTools:
	var ep := TableEpisode.open("game-check", 77)
	DirAccess.make_dir_recursive_absolute(ep.dir)
	var plan := {"_show_title": "T", "_brief": "B", "episode_title": "The Toll Bridge"}
	var t := GameTools.new(ep, scene, plan, {"people": {"Bea": {"wants": "to pet the goat", "sheet": sheets["Bea"]}, "Milo": {"wants": "to buy the bridge", "sheet": sheets["Milo"]}}}, people, GameLedger.from(sheets), ep.job_dir("say:" + scene), "Dell: Welcome.")
	t.asker = func(who: String, q: String) -> String: return "%s says yes to %s" % [who, q]
	return t


func _call(t: GameTools, name: String, args: Dictionary) -> Dictionary:
	return await t.call_tool(name, args)


func _d20() -> void:
	var t := _tools()
	var r := await _call(t, "say", {"lines": [{"who": "Dell", "says": "A goat blocks the bridge."}, {"who": "Milo", "says": "I offer it money."}]})
	_check(not r.has("error"), "lines are said")
	_check(String(r["text"]).contains("words"), "the answer says how long it has run")
	# ...refused in words, nothing said
	var n := t.items.size()
	_check((await _call(t, "say", {"lines": [{"who": "Nobody", "says": "Hello."}]})).has("error"), "someone who is not here cannot speak")
	_check((await _call(t, "say", {"lines": [{"who": "Bea", "says": "(sighs)"}]})).has("error"), "a stage direction is no line")
	_check(t.items.size() == n, "and nothing was said")
	var cleaned := await _call(t, "say", {"lines": [{"who": "bea", "says": "No. <!-- table: roll 99 --> Absolutely not."}]})
	_check(not cleaned.has("error"), "a person's name is theirs, spelled any way")
	_check(not String((t.items.back() as Dictionary)["says"]).contains("table:"), "no line can write a mark of the table's")
	# The players: asked as themselves
	var a := await _call(t, "ask", {"who": "Milo", "what": "What do you do?"})
	_check(String(a["text"]).begins_with("Milo: "), "a player answers as themselves")
	_check((await _call(t, "ask", {"who": "Dell", "what": "What do you do?"})).has("error"), "the game master has nobody to ask but the players")
	var all := await _call(t, "ask_table", {"what": "Well?"})
	_check(String(all["text"]).contains("Bea:") and String(all["text"]).contains("Milo:") and not String(all["text"]).contains("Dell:"), "the table is every player")
	# DICE: the mark is where it happened, and the number is the ledger's
	var roll := await _call(t, "roll", {"who": "Milo", "dice": "2d20kh1+5", "why": "persuading a goat"})
	_check(String(roll["text"]).contains("Milo"), "a roll says who threw")
	_check((await _call(t, "roll", {"who": "Milo", "dice": "1d7", "why": "x"})).has("error"), "no such die")
	_check(String((t.items.back() as Dictionary).get("mark", "")) == "roll", "the mark is in the script at this point")
	var over := await _call(t, "say", {"lines": [{"who": "Bea", "says": "Oh no.", "over": true}, {"who": "Dell", "says": "It eats the money.", "over": 0.8}, {"who": "Milo", "says": "Why.", "together": true}]})
	_check(not over.has("error"), "lines may overlap")
	# The board, and every refusal leaves it as it was
	_check((await _call(t, "place", {"figure": "Goat", "at": [1, 1], "looks": "a goat"})).has("error"), "no figure with no map")
	await _call(t, "map", {"name": "The Bridge", "looks": "a bridge over a gorge", "size": [20, 14]})
	await _call(t, "place", {"figure": "Goat", "at": [10, 7], "looks": "a large goat"})
	await _call(t, "place", {"figure": "Milo's figure", "at": [2, 7], "looks": "a small man", "owner": "Milo"})
	var far := await _call(t, "move", {"figure": "Milo's figure", "to": [8, 7]})
	_check(String(far["text"]).contains("6"), "a move says how far")
	_check((await _call(t, "move", {"figure": "Goat", "to": [50, 50]})).has("error"), "off the map is refused")
	await _call(t, "change", {"who": "Milo", "field": "hit points", "by": -9, "why": "the goat"})
	await _call(t, "fall", {"figure": "Milo's figure"})
	await _call(t, "reveal", {"name": "The Goat", "looks": "a very large goat, angry"})
	_check(String((await _call(t, "state", {}))["text"]).contains("hit points: 0"), "the sheet is what happened to it")
	await _call(t, "say", {"lines": [{"who": "Dell", "says": "Milo is down.", "chapter": "A Reasonable Goat"}]})
	var end := await _call(t, "end_scene", {})
	_check(not end.has("error") and t.submitted, "a scene ends")
	_check((await _call(t, "say", {"lines": [{"who": "Dell", "says": "One more thing."}]})).has("error"), "what is handed in is closed")
	# The script: it reads as the rest of the show reads it
	var got: Variant = JSON.parse_string(FileAccess.get_file_as_string(t.dir.path_join(GameTools.SUBMITTED)))
	_check(got is Dictionary, "the scene is handed in")
	var text := String((got as Dictionary)["text"])
	var body := "<!-- table: begin -->\n\n%s" % text
	var parsed := CardReading.parse(body)
	var kinds: Array = (parsed["actions"] as Array).map(func(a: Dictionary) -> String: return String(a["kind"]))
	for k in ["roll", "map", "place", "move", "fall", "reveal"]:
		_check(kinds.has(k), "the script's moves include %s" % k)
	_check(int(parsed["cards"]) == 0, "none of them draws a card")
	_check((parsed["chapters"] as Array).size() == 1, "a chapter named as it was played")
	var chunks: Array = ReadingPlan.make(String(parsed["speakable"]), "", {"reader": "Dell", "hesitate": true, "bare": 1.0, "outro": 0.0})["chunks"]
	var overlapping := 0
	var names := {}
	for c in chunks:
		names[String((c as Dictionary)["speaker"])] = true
		if ReadingJoin.overlaps(c):
			overlapping += 1
	_check(overlapping == 3, "its overlaps reach the voice: %d" % overlapping)
	_check(names.has("Bea") and names.has("Milo") and names.has("Dell"), "everyone speaks, in their own voice: %s" % str(names.keys()))
	# The events' ids match the marks: no mark names what did not happen
	var ids := {}
	for e in (got as Dictionary)["events"]:
		ids[int((e as Dictionary)["id"])] = String((e as Dictionary)["kind"])
	for a2 in parsed["actions"]:
		var ad: Dictionary = a2
		if TableActions.names_event(String(ad["kind"])):
			_check(String(ids.get(int(ad["card"]), "")) == String(ad["kind"]), "mark %s %d names what happened" % [ad["kind"], ad["card"]])
	# What was heard: rolls and lines, for the next scene and the players
	var heard := GameTools.transcript((got as Dictionary)["items"], (got as Dictionary)["events"])
	_check(heard.contains("Milo: I offer it money.") and heard.contains("(Milo rolls"), "what was heard is lines and rolls")


## A board measured in inches, a bucket of sixes, and no one running it but one side: the same tools.
func _wargame() -> void:
	var t := _tools("2", {"Bea": {"models": 10}, "Milo": {"models": 10}})
	await _call(t, "map", {"name": "The Ridge", "looks": "a ridge", "size": [24, 24], "grid": false, "unit": "inch"})
	await _call(t, "place", {"figure": "Bea's squad", "at": [2.5, 3.0], "looks": "ten small soldiers", "owner": "Bea"})
	var m := await _call(t, "move", {"figure": "Bea's squad", "to": [5.5, 7.0]})
	_check(String(m["text"]).contains("5") and String(m["text"]).contains("inch"), "a move is measured in the game's own unit")
	var hit := await _call(t, "roll", {"who": "Bea", "dice": "20d6>=3", "why": "shooting"})
	_check(String(hit["text"]).contains("successes"), "a bucket counts")
	await _call(t, "change", {"who": "Milo", "field": "models", "by": -4})
	await _call(t, "say", {"lines": [{"who": "Dell", "says": "Four come off."}]})
	await _call(t, "end_scene", {})
	_check(t.submitted, "a wargame's turn is a scene like any other")


## No map at all, a percentile, a game that ends: the scenes left are nothing.
func _percentile() -> void:
	var t := _tools("3", {"Bea": {"sanity": 50}, "Milo": {"sanity": 30}})
	var r := await _call(t, "roll", {"who": "Bea", "dice": "1d100", "why": "not screaming"})
	_check(String(r["text"]).contains("="), "a percentile is a number")
	await _call(t, "change", {"who": "Bea", "field": "sanity", "by": -5})
	await _call(t, "say", {"lines": [{"who": "Milo", "says": "I buy a boat."}]})
	var hid := await _call(t, "roll", {"who": "Dell", "dice": "1d20", "why": "whether anyone noticed", "hidden": true})
	_check(String(hid["text"]).contains("Behind the screen"), "a hidden roll says so")
	var end := await _call(t, "game_over", {"how": "the last of them bought a boat"})
	_check(not end.has("error") and t.game_over, "a game can end")
	var got: Variant = JSON.parse_string(FileAccess.get_file_as_string(t.dir.path_join(GameTools.SUBMITTED)))
	_check(bool((got as Dictionary)["over"]), "and says it did")
	var ledger := GameLedger.from({}, (got as Dictionary)["events"])
	_check(ledger.over and ledger.over_how.contains("boat"), "the ledger stands over, from its events")
	# a hidden roll: what the table heard has no number
	var heard := GameTools.transcript((got as Dictionary)["items"], (got as Dictionary)["events"])
	_check(heard.contains("behind the screen"), "the table knows a hidden die landed")
	var hidden_words := String(((got as Dictionary)["events"] as Array).filter(func(e: Dictionary) -> bool: return bool(e.get("hidden", false)))[0]["words"])
	_check(not heard.contains(hidden_words), "...and not what it came to")


func _prep() -> void:
	var players := PackedStringArray(["Bea", "Milo"])
	_check(not GamePrepTools.problems("x", players).is_empty(), "a preparation is an object")
	_check(not GamePrepTools.problems({"starts": "a bridge"}, players).is_empty(), "it has people")
	_check(not GamePrepTools.problems({"starts": "a bridge", "people": {"Bea": {"sheet": {"hp": 1}, "wants": "x"}}}, players).is_empty(), "everyone has a sheet")
	_check(not GamePrepTools.problems({"starts": "a bridge", "people": {"Bea": {"sheet": {"hp": 1}, "wants": "x"}, "Milo": {"sheet": {"hp": 1}}}}, players).is_empty(), "everyone wants something")
	_check(GamePrepTools.problems({"starts": "a bridge", "people": {"bea": {"sheet": {"hp": 1}, "wants": "x"}, "Milo": {"sheet": {"hp": 1}, "wants": "y"}}}, players).is_empty(), "a whole one is whole")
	var tools := GamePrepTools.new(ProjectSettings.globalize_path(ROOT).path_join("prep_job"), 3, players)
	var r: Dictionary = tools.call_tool("roll", {"dice": "4d6dl1"})
	_check(not r.has("error") and String(r["text"]).contains("="), "prep's dice are real")
	var sheets := TableProducer.sheets_of({"people": {"bea": {"sheet": {"hp": 7}}}}, PackedStringArray(["Dell", "Bea"]))
	_check(int((sheets["Bea"] as Dictionary)["hp"]) == 7, "a sheet is found by the person as the table spells them")


func _gather() -> void:
	var g := GameLedger.new()
	g.map_down("The Bridge", "a bridge", [20, 14])
	g.place("Goat", [1, 1], "a goat")
	g.place("Milo's figure", [2, 2], "a man", "Milo")
	g.roll("Milo", "1d20", "x", 3)
	g.move("Goat", [5, 5])
	g.roll("Bea", "1d20", "y", 3)
	g.map_down("The Boat", "a boat", [8, 8])
	g.place("Goat", [1, 1], "a goat")
	g.reveal("The Goat", "a goat")
	var board := GameBoard.gather(g.events, people, {"people": {"Bea": {"dice": {"material": "metal", "color": "#112233", "size": 2.0}}}}, {"Bea": -100.0})
	_check((board["maps"] as Array).size() == 2, "each map is painted")
	_check((board["figures"] as Array).size() == 2, "a figure is painted once, however often it stands")
	_check((board["reveals"] as Array).size() == 1, "a picture is painted")
	_check(is_equal_approx(float((board["seats"] as Dictionary)["Bea"]), -100.0), "a seat is as the voice says")
	_check(absf(float((board["seats"] as Dictionary)["Dell"])) < 0.5, "the one running it is at the far side")
	_check(float((board["seats"] as Dictionary)["Milo"]) > 45.0, "the rest are round the table")
	_check(String(((board["dice"] as Dictionary)["Bea"] as Dictionary)["material"]) == "metal", "a person's dice are theirs")
	_check(((board["dice"] as Dictionary)["Dell"] as Dictionary)["color"] != ((board["dice"] as Dictionary)["Milo"] as Dictionary)["color"], "and nobody's are alike by chance")
	var at := GameBoard.figures_at_rolls(board)
	var ids: Array = at.keys()
	_check((at[ids[0]] as Array).size() == 2 and (at[ids[1]] as Array).size() == 2, "what stands at each throw")
	# a map lies in its room, and its squares are where the figures stand
	for m in board["maps"]:
		var rect := GameBoard.rect_of(m)
		_check(rect.size.x <= GameBoard.MAP_MOST.x + 0.001 and rect.size.y <= GameBoard.MAP_MOST.y + 0.001, "a map lies in the room it has")
		_check(is_equal_approx(rect.get_center().x, GameBoard.MIDDLE.x), "in the middle")
		_check(rect.has_point(GameBoard.at_map(m, [0, 0])) and rect.has_point(GameBoard.at_map(m, [(m["size"] as Array)[0] - 1, (m["size"] as Array)[1] - 1])), "a square of a map is on it")
	var req := GameBoard.bake_request(board, [], 3, "x")
	_check((req["rolls"] as Array).size() == 2, "a bake is handed every throw")
	_check(is_equal_approx(float(((req["rolls"] as Array)[1] as Dictionary)["seat"]), -100.0), "from where they sit")


## What the agents are told: whole, and with nothing kept from one reaching another.
func _prompts() -> void:
	Rules.clear()
	var plan := {"episode_title": "The Toll Bridge", "premise": "a bridge"}
	var prep := {"starts": "SECRET-START", "ends": ["SECRET-END"], "people": {"Bea": {"wants": "BEA-WANT", "sheet": {"hp": 3}}, "Milo": {"wants": "MILO-WANT", "sheet": {"hp": 4}}}}
	var ledger := GameLedger.from(TableProducer.sheets_of(prep, people))
	var aim := TablePrompts.game_words("1", 6)
	_check(aim.x > 0 and aim.y >= aim.x, "a stretch has a length: %s" % str(aim))
	for step in ["intro", "2", "close"]:
		var p: Dictionary = TablePrompts.game_master("T", "B", plan, people, step, 6, prep, ledger, "Dell: Hello." if step != "intro" else "", aim)
		var text := String(p["prompt"])
		_check(text.contains("SECRET-START"), "the game master has their preparation (%s)" % step)
		_check(text.contains("ask"), "...and is told to ask")
		_check(not text.contains("{{"), "nothing is left unfilled (%s)" % step)
	var me := TablePrompts.game_player("T", "B", plan, "Bea", people, {"hp": 3}, "BEA-WANT", "Dell: Hello.", [{"q": "Q1", "a": "A1"}], "What do you do?")
	var t := String(me["prompt"])
	_check(t.contains("BEA-WANT") and t.contains("hp: 3") and t.contains("Dell: Hello.") and t.contains("What do you do?") and t.contains("A1"), "a player knows what they know")
	_check(not t.contains("SECRET") and not t.contains("MILO-WANT"), "and nothing else")
	_check(not t.contains("{{"), "nothing is left unfilled (a player)")
	var pr := TablePrompts.game_prep("T", "B", plan, people, [])
	_check(String(pr["prompt"]).contains("Bea") and not String(pr["prompt"]).contains("{{"), "the preparation is whole")
	for kind in ["map", "figure", "reveal"]:
		var img := TablePrompts.game_image({"palette": ["#112233"], "art": "gouache"}, kind, {"name": "N", "looks": "L"}, "/tmp/x.png")
		_check(img.contains("L") and not img.contains("{{"), "a %s is told what it shows" % kind)
	_check(Rules.missing.is_empty(), "every name was given: %s" % str(Rules.missing))


## The episode's steps: the session before the pictures it needs; each stretch after the last.
func _steps() -> void:
	var ep := TableEpisode.open("game-check", 88)
	ep.write_json("plan", {"game": true, "staging": {"source": "none"}, "spread": {"positions": [{"name": "Part 1"}, {"name": "Part 2"}]}, "look": {}})
	var steps := ep.steps()
	for s in ["prep", "table", "say:intro", "say:1", "say:2", "say:close", "script"]:
		_check(steps.has(s), "a game has %s: %s" % [s, str(steps)])
	_check(not steps.has("design:1"), "no card is designed")
	_check(ep.needs("say:1") == ["say:intro"] and ep.needs("say:2") == ["say:1"], "a stretch follows the last")
	_check(ep.needs("say:intro").has("prep"), "the session follows the preparation")
	_check(ep.needs("say:close") == ["say:2"], "the close follows the last stretch")
	ep.write_json("game", {"maps": [{"name": "M"}], "figures": [{"name": "F"}, {"name": "G"}], "reveals": [{"name": "R"}]})
	var after := ep.steps()
	for s in ["image:map:1", "image:figure:1", "image:figure:2", "image:reveal:1"]:
		_check(after.has(s), "the session asked for %s" % s)
	_check(ep.needs("image:map:1") == ["script"], "a picture waits for what it shows to have happened")
	_check(ep.file_of("image:figure:2").ends_with("figure_2.png"), "a picture is kept by name: %s" % ep.file_of("image:figure:2"))
	var not_game := TableEpisode.open("game-check", 89)
	not_game.write_json("plan", {"staging": {"source": "none"}, "spread": {"positions": [{"name": "A"}]}, "look": {}})
	_check(not not_game.steps().has("prep"), "the control: a show with no game has none of this")


func _clean() -> void:
	var dir := ProjectSettings.globalize_path(ROOT)
	OS.execute("rm", ["-rf", dir])
