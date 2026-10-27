extends SceneTree

## The gate of A SHOW THAT DRAWS NO CARDS (the user, 2026-10-26: "that card dependency shouldn't exist. In
## instances like this, we should start with a mask every time - and just paint it while talking"): a plan of
## beats - the producer's, for a brief whose show draws no cards - is an episode in BEATS: the words and the work
## at the table, nothing drawn. No renderer, no writer.
##
##   godot --headless --path . --script res://tests/table_show/cardless_check.gd
##
## - ITS STEPS ARE A TABLE'S AND ITS WORDS': the plan, the draw (of none), the cloth, the room, the table, the
##   acts, the intro, a passage per beat, the close and the script - no design, back, painting or check, and no
##   work passage of a card's: a beat's own passage waits for the one before it and its acts. The control: the
##   same plan staged from a deck has every card's steps.
## - ITS PLAN LANDS IN BEATS: a plan of `beats` lands them as the spread's positions, staged from nowhere
##   ([constant TableActions.SOURCES] `none`), with no deck, whatever else it says; a plan of cards that names
##   `none` is staged from a deck instead (the control), and a plan of neither is refused.
## - ITS SCRIPT BEGINS AND WORKS: `begin`, then `work K` before each beat's passage, then the spread and the
##   close - walked, it draws no card, comes from nowhere, and is chaptered at each beat.
## - ITS AGENTS ARE TOLD OF BEATS: the producer is offered beats beside a spread, how many cards and whether any
##   the brief's to say (the user, 2026-10-26: no Draw knob), never a count of the code's; a beat's
##   reader is told its beat and handed its own acts, and no card; the set dresser keeps no room for cards; the
##   puppeteer's beats are the plan's. Every prompt renders whole.
## - ITS WORK IS KEPT: acts on every beat survive [method Motions.sanitize_acts] at the episode's beat count.

const FixtureDeck := preload("res://tests/fixture_deck.gd")
const ROOT := "user://cardless_check"

var _fails := 0


func _init() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + what)
	if not cond:
		_fails += 1


func _run() -> void:
	await process_frame
	Rules.clear()
	for check in [_steps, _lands, _script, _prompts, _work]:
		var done: Variant = (check as Callable).call()
		_ok(done == true, "%s ran to its end (a script error stops it - see above)" % (check as Callable).get_method())
	_ok(Rules.missing.is_empty(), "every prompt rendered whole: %s" % ", ".join(Rules.missing))
	_clean()
	print("cardless_check: %s (%d failure%s)" % ["ALL OK" if _fails == 0 else "FAILED", _fails, "" if _fails == 1 else "s"])
	quit(1 if _fails > 0 else 0)


## A show's plan of three beats - beat 1 and 3 with work, the intro's too - staged from nowhere, or (the
## control, [param from] "deck") from a deck.
static func _plan(from := "none") -> Dictionary:
	var positions: Array = [{"name": "The Hook", "asks": "what catches you", "work": "the base is laid on"},
		{"name": "The Turn", "asks": "what turns"}, {"name": "The Resolve", "asks": "what holds", "work": "the lines are drawn"}]
	return {"episode_title": "They Never Saw It", "audience": "you", "topic": "quiet", "premise": "the premise", "reader_mood": "calm",
		"spread": {"name": "", "positions": positions}, "work_intro": "the sponge is wetted",
		"staging": {"source": from}, "look": CardTable.sanitize_look({})}


## An episode on disk under the test root, its plan [method _plan]'s.
func _episode(seed: int, from := "none") -> TableEpisode:
	TableEpisode.root = ROOT
	var ep := TableEpisode.open("bare-show", seed)
	if DirAccess.dir_exists_absolute(ep.dir):
		for f in DirAccess.get_files_at(ep.dir):
			DirAccess.remove_absolute(ep.dir.path_join(f))
	ep.write_json("plan", _plan(from))
	return ep


func _steps() -> bool:
	var ep := _episode(11)
	_ok(ep.cardless() and ep.card_count() == 0 and ep.beat_count() == 3, "a plan staged from nowhere draws no card and has 3 beats (%d cards, %d beats)" % [ep.card_count(), ep.beat_count()])
	var want := ["plan", "draw", "image:surface", "image:backdrop", "table", "acts", "say:intro", "say:1", "say:2", "say:3", "say:close", "script"]
	_ok(ep.steps() == want, "its steps are the table's and the words': %s" % str(ep.steps()))
	_ok(ep.needs("say:1") == ["say:intro", "acts"] and ep.needs("say:2") == ["say:1"] and ep.needs("say:3") == ["say:2", "acts"],
		"a beat waits for the passage before it and, with work, its acts (%s, %s, %s)" % [str(ep.needs("say:1")), str(ep.needs("say:2")), str(ep.needs("say:3"))])
	_ok(ep.needs("say:close") == ["say:3"], "the close follows the last beat: %s" % str(ep.needs("say:close")))
	var after: Array = ep.dependents("acts")
	_ok(after.has("say:intro") and after.has("say:1") and after.has("say:close") and not after.has("table"),
		"the acts blocked again rewrite the words said over them and after, and keep the table: %s" % str(after))
	var prod := TableProducer.new(ep, {"title": "Show", "brief": "A brief.", "deck": []})
	prod._finish("draw", prod._make_draw())
	var draw: Variant = ep.read_json("draw")
	_ok(draw is Dictionary and ((draw as Dictionary)["cards"] as Array).is_empty() and int((draw as Dictionary)["deck_n"]) == 0,
		"its draw is of none: %s" % str(draw))
	_ok(ep.document()["cards"] == [] and TablePlan.deck_count(ep.document()) == 0, "the table is handed no card and stands no deck")
	var carded := _episode(12, "deck")
	_ok(carded.steps().has("design:1") and carded.steps().has("image:back") and carded.steps().has("image:card:3"),
		"the control: the same plan staged from a deck has every card's steps")
	_ok(TablePlan.deck_count(carded.document()) > 0, "the control: a deck's episode stands a deck")
	return true


func _lands() -> bool:
	var ep := _episode(13)
	DirAccess.remove_absolute(ep.file_of("plan"))
	var prod := TableProducer.new(ep, {"title": "Show", "brief": "A brief.", "deck": [], "chooses": true})
	var reply := JSON.stringify({"episode_title": "THEY STOPPED LAUGHING", "beats": [{"name": "The Hook", "asks": "x", "work": "  the base goes on  "},
		{"name": "The Turn", "asks": "y"}], "work_close": "the mask is turned", "look": {"surface": "dark oak", "candles": 1},
		"staging": {"source": "deck"}, "deck": [{"name": "a card nobody asked for"}]})
	var err := prod._land_plan(reply)
	_ok(err.is_empty(), "a plan of beats lands: %s" % err)
	var plan: Variant = ep.read_json("plan")
	_ok(plan is Dictionary and CardTable.cardless(plan) and CardTable.beats(plan) == 2, "it is staged from nowhere, in 2 beats")
	_ok(plan is Dictionary and not (plan as Dictionary).has("deck") and not (plan as Dictionary).has("beats"), "it keeps no deck, and its beats only as the spread's positions")
	_ok(ep.work_plan() == {"1": "the base goes on", "close": "the mask is turned"}, "its work lands beat by beat: %s" % str(ep.work_plan()))
	_ok(prod._land_plan(JSON.stringify({"episode_title": "x", "look": {}})) == "the plan has no spread and no beats", "a plan of neither beats nor a spread is refused")
	# the control: a plan of cards that says it draws from nowhere is staged from a deck
	var carded := _episode(14, "deck")
	DirAccess.remove_absolute(carded.file_of("plan"))
	var cprod := TableProducer.new(carded, {"title": "Show", "brief": "A brief.", "deck": FixtureDeck.cards()})
	err = cprod._land_plan(JSON.stringify({"episode_title": "x", "spread": {"name": "s", "positions": [{"name": "a", "asks": "x"}, {"name": "b", "asks": "y"}]},
		"staging": {"source": "none"}, "look": {"deck_name": "d"}}))
	_ok(err.is_empty() and String(CardTable.staging_of(carded.read_json("plan"))["source"]) == "deck",
		"the control: a plan of cards is never staged from nowhere (%s)" % (err if not err.is_empty() else String(CardTable.staging_of(carded.read_json("plan"))["source"])))
	return true


func _script() -> bool:
	var plan := _plan()
	var moves := TableProducer.choreography(plan, [])
	var kinds: Array = moves.map(func(m: Dictionary) -> String: return "%s %d %s" % [String(m["kind"]), int(m.get("card", 0)), String(m.get("say", ""))])
	_ok(kinds == ["begin 0 say:intro", "work 1 say:1", "work 2 say:2", "work 3 say:3", "spread 0 say:close"], "it begins, works each beat and closes: %s" % str(kinds))
	var passages: Array = []
	for m in moves:
		passages.append({"kind": m["kind"], "card": m.get("card", 0), "text": "Some words of %s, said at an easy pace." % String(m["say"])})
	var script := CardReading.compose(passages)
	var parse := CardReading.parse(script)
	_ok(String(parse["source"]) == "none" and int(parse["cards"]) == 0, "walked, it comes from nowhere and draws no card (%s, %d)" % [String(parse["source"]), int(parse["cards"])])
	var acted: Array = (parse["actions"] as Array).map(func(a: Dictionary) -> String: return String(a["kind"]))
	_ok(acted == ["begin", "work", "work", "work", "spread"], "its marks: %s" % str(acted))
	# chaptered at each beat: the words timed as a voice says them
	var words: Array = []
	var t := 1.0
	for w in parse["spoken"]:
		words.append({"text": String(w), "t0": t, "t1": t + 0.3})
		t += 0.4
	var chapters: Array = CardReading.chapters(script, words).map(func(c: Dictionary) -> String: return "%s %d" % [String(c["kind"]), int(c["card"])])
	_ok(chapters == ["intro 0", "work 1", "work 2", "work 3", "spread 0"], "a chapter at each beat: %s" % str(chapters))
	# the control: a reading of cards is not chaptered at its work
	var carded := CardReading.compose([{"kind": "shuffle", "text": "Hello there everyone."}, {"kind": "draw", "card": 1, "text": "One card here."},
		{"kind": "work", "card": 1, "text": "Now we work it."}, {"kind": "spread", "text": "Goodbye now."}])
	var cw: Array = []
	t = 1.0
	for w in CardReading.parse(carded)["spoken"]:
		cw.append({"text": String(w), "t0": t, "t1": t + 0.3})
		t += 0.4
	_ok(not CardReading.chapters(carded, cw).any(func(c: Dictionary) -> bool: return String(c["kind"]) == "work"), "the control: a reading of cards has no chapter at its work")
	return true


func _prompts() -> bool:
	var producer := String(TablePrompts.producer("Show", "a brief", 7, CardTable.FACES, CardTable.FRAMES, [], [], true)["prompt"])
	_ok(producer.contains("AN EPISODE THAT DRAWS NO CARDS runs in BEATS") and producer.contains("\"beats\": [{")
		and producer.contains("AN EPISODE THAT DRAWS CARDS has a SPREAD") and producer.contains("\"spread\": {"),
		"the producer is not offered beats beside a spread")
	_ok(producer.contains("HOW MANY CARDS. The brief says") and producer.contains("at most %d either way" % TableProducer.SPREAD_MOST)
		and not producer.contains("has exactly"), "...how many cards, and whether any, are not the brief's to say")
	_ok(producer.contains("what follows of cards is for an episode that draws them"), "...the staging, deck and printing are not a carded episode's alone")
	var three := TableProducer.new(_episode(16), {"deck": FixtureDeck.cards().slice(0, 3)})
	var carded := String(TablePrompts.producer("Show", "a brief", 7, CardTable.FACES, CardTable.FRAMES, [], FixtureDeck.cards().slice(0, 3), false, "", three._spread_most())["prompt"])
	_ok(carded.contains("at most 3 either way") and not carded.contains("`source` \"none\""),
		"the control: a show's own deck of three bounds its count at three, and no show is offered to draw from nowhere")
	var ep := _episode(15)
	ep.write_json("draw", {"seed": ep.seed, "cards": [], "left": [], "deck_n": 0})
	ep.write_json("acts", {"acts": [
		{"name": "sponge", "beat": "intro", "about": "ABOUT-INTRO the sponge is wetted", "length": 4, "tracks": [{"thing": "a", "part": "b", "law": "to", "state": "glow", "value": 1}]},
		{"name": "base", "beat": 1, "about": "ABOUT-ONE the base is stippled on", "length": "under", "tracks": [{"thing": "a", "part": "b", "law": "to", "state": "grow", "value": 0}]},
		{"name": "lines", "beat": 3, "about": "ABOUT-THREE the lines are drawn", "length": 9, "tracks": [{"thing": "a", "part": "b", "law": "to", "state": "fill", "value": 0}]}]})
	ep.write_text("say:intro", "Some messages find you.")
	var prod := TableProducer.new(ep, {"title": "Show", "brief": "A brief.", "deck": []})
	var one := String(prod.say_prompt("1")["prompt"])
	_ok(one.contains("beat 1, \"The Hook\"") and one.contains("ABOUT-ONE") and not one.contains("ABOUT-THREE") and not one.contains("ABOUT-INTRO"),
		"beat 1's reader is told its beat and handed its own acts alone")
	_ok(not one.contains("drawn") and not one.contains("The spread:") and not one.contains("The deck:") and not one.contains("THE CARDS MOVE"),
		"...and no card, spread or deck")
	_ok(one.contains("The next beat begins: \"The Turn\""), "...and what comes after it")
	ep.write_text("say:1", "One.")
	ep.write_text("say:2", "Two.")
	ep.write_text("say:3", "Three.")
	var close := String(prod.say_prompt("close")["prompt"])
	_ok(close.contains("the last beat is done") and close.contains("Three."), "the close follows every beat said")
	var intro := String(prod.say_prompt("intro")["prompt"])
	_ok(intro.contains("ABOUT-INTRO") and not intro.contains("shuffling"), "the intro is handed its own acts and shuffles nothing")
	var dresser := String(TablePrompts.set_dresser("Show", "a brief", ep.read_json("plan"), 7, CardTable.headroom(7), [], true, 40, [], "",
		[], [], true, false)["prompt"])
	_ok(not dresser.contains("the deck is shuffled there") and not dresser.contains("The deck:") and dresser.contains("the work's")
		and not dresser.contains("no card leaps"), "the set dresser keeps no room for cards and no deck")
	var puppet := String(TablePrompts.puppeteer("Show", "a brief", ep.read_json("plan"), 7, [], "- \"a mask\": stands at [0, 0] cm", 30)["prompt"])
	_ok(puppet.contains("a beat's place (1 to 3)") and not puppet.contains("cards are drawn") and puppet.contains("during beat 1, \"The Hook\""),
		"the puppeteer's beats are the plan's")
	return true


func _work() -> bool:
	var acts := {"acts": [{"name": "a", "beat": 3, "about": "x", "length": 2, "tracks": [{"thing": "t", "law": "to", "state": "glow", "value": 1}]}]}
	_ok((Motions.sanitize_acts(acts, 3)["acts"] as Array).size() == 1, "an act on the last beat is kept at the episode's beat count")
	_ok((Motions.sanitize_acts(acts, 0)["acts"] as Array).is_empty(), "the control: counted by cards (none), it is left out")
	return true


func _clean() -> void:
	var base := ProjectSettings.globalize_path(ROOT)
	for show in (DirAccess.get_directories_at(base) if DirAccess.dir_exists_absolute(base) else PackedStringArray()):
		for ep in DirAccess.get_directories_at(base.path_join(show)):
			var d := base.path_join(show).path_join(ep)
			for f in DirAccess.get_files_at(d):
				DirAccess.remove_absolute(d.path_join(f))
	TableEpisode.root = TableEpisode.ROOT
