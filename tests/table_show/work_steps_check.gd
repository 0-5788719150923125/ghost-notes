extends SceneTree

## The gate of the WORK AT THE TABLE in an episode's steps (next/table_work.md): what the puppeteer and the
## readers of the work are made from, and what they are told. No renderer, no writer.
##
##   godot --headless --path . --script res://tests/table_show/work_steps_check.gd
##
## - A PLAN WITH WORK HAS ITS STEPS: the puppeteer's `acts` after the table, made from the plan, the draw and
##   the table; a work passage after each card that has work (`say:work:K`, made from the card's own passage
##   and the acts), the next card's passage after it; the intro and the close wait for the acts when they have
##   work. The control: a plan with none has exactly the steps every episode had.
## - THE SCRIPT HAS ITS MOVES: `work K` right after card K's passage, the card laid as it begins, its passage
##   after it.
## - NO CHEATING HOLDS FOR THE WORK: a work passage's reader is handed its own beat's acts and no later beat's
##   (the control: the later beat's own passage is handed them); the intro's reader sees no card's.
## - A READER'S CUE IS KEPT ONLY FOR ITS OWN ACTS: `<!-- act: grind -->` stays in a passage whose beat has a
##   `grind`, and goes with any other comment (the control: a passage with no acts keeps none).
## - A PLAN'S WORK LANDS: each position's `work`, the intro's and the close's, as the producer wrote them.

const FixtureDeck := preload("res://tests/fixture_deck.gd")

var _fails := 0


func _init() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		print("  FAIL: " + what)


func _run() -> void:
	await process_frame
	for check in [_steps, _script, _no_cheating, _cues, _lands]:
		var done: Variant = (check as Callable).call()
		_ok(done == true, "%s stopped part way (a script error - see above)" % (check as Callable).get_method())
	_clean()
	print("work_steps_check: %s (%d failure%s)" % ["ALL OK" if _fails == 0 else "FAILED", _fails, "" if _fails == 1 else "s"])
	quit(1 if _fails > 0 else 0)


## An episode on disk under a test root, as the producer writes one: three cards, card 2 with work, and the
## intro's work when [param worked] - none at all without it.
func _episode(worked: bool) -> TableEpisode:
	TableEpisode.root = "user://work_steps_check"
	var ep := TableEpisode.open("work-show", 777 if worked else 778)
	if DirAccess.dir_exists_absolute(ep.dir):
		for f in DirAccess.get_files_at(ep.dir):
			DirAccess.remove_absolute(ep.dir.path_join(f))
	var positions: Array = []
	for i in 3:
		positions.append({"name": "Stage %d" % (i + 1), "asks": "what stage %d asks" % (i + 1)})
	var plan := {"episode_title": "A Brew", "audience": "everyone", "topic": "a brew", "premise": "the premise", "reader_mood": "calm",
		"spread": {"name": "The Brew", "positions": positions}, "look": CardTable.sanitize_look({"deck_name": "The Test Deck"})}
	if worked:
		positions[1]["work"] = "what card 2 brings is ground and added"
		plan["work_intro"] = "the fire is stirred"
	ep.write_json("plan", plan)
	var cards: Array = []
	var deck := CardDeck.shuffled(FixtureDeck.cards(), ep.seed, false)
	for i in 3:
		var card := (deck[i] as Dictionary).duplicate()
		card["jumper"] = false
		cards.append(card)
		ep.write_json("design:%d" % (i + 1), {"art": "art %d" % (i + 1), "booklet": {"keywords": ["k"], "upright": "up %d" % (i + 1)}})
	ep.write_json("draw", {"seed": ep.seed, "cards": cards})
	ep.write_text("say:intro", "Hello, night owls.")
	for i in 3:
		ep.write_text("say:%d" % (i + 1), "Passage for card %d." % (i + 1))
	return ep


func _steps() -> bool:
	var plain := _episode(false)
	var before := ["plan", "draw", "design:1", "design:2", "design:3", "image:back", "image:surface", "image:backdrop", "table",
		"image:card:1", "check:1", "image:card:2", "check:2", "image:card:3", "check:3", "say:intro", "say:1", "say:2", "say:3", "say:close", "script"]
	# (a card read already needs no check: these cards are read, so their checks drop out of both lists alike)
	var steps := plain.steps().filter(func(s: Variant) -> bool: return not String(s).begins_with("check:"))
	_ok(steps == before.filter(func(s: Variant) -> bool: return not String(s).begins_with("check:")),
		"the control: a plan with no work has other steps than every episode had: %s" % str(steps))
	var ep := _episode(true)
	var all := ep.steps()
	_ok(all.has("acts") and all.find("acts") > all.find("table"), "the puppeteer's step is not after the table: %s" % str(all))
	_ok(all.has("say:work:2") and all.find("say:work:2") == all.find("say:2") + 1, "card 2's work passage is not right after its own: %s" % str(all))
	_ok(not all.has("say:work:1") and not all.has("say:work:3"), "a card with no work has a work passage")
	_ok(ep.needs("acts") == ["plan", "draw", "table"], "the acts are made from %s" % str(ep.needs("acts")))
	_ok(ep.needs("say:work:2") == ["say:2", "acts"], "card 2's work passage is made from %s" % str(ep.needs("say:work:2")))
	_ok(ep.needs("say:3").has("say:work:2") and not ep.needs("say:3").has("say:2"), "card 3's passage does not follow card 2's work: %s" % str(ep.needs("say:3")))
	_ok(ep.needs("say:intro").has("acts"), "the intro with work does not wait for the acts")
	_ok(not ep.needs("say:close").has("acts"), "the close with no work waits for the acts")
	_ok(ep.file_of("say:work:2").ends_with("say_work_2.txt") and ep.file_of("acts").ends_with("acts.json"), "the work's files are misnamed")
	# a redo of the table clears the acts and the work's words
	_ok(ep.dependents("table").has("acts") and ep.dependents("table").has("say:work:2"), "a table set again keeps acts blocked on the old one")
	return true


func _script() -> bool:
	var ep := _episode(true)
	var prod := TableProducer.new(ep, {"title": "Brews", "brief": "A brief.", "deck": FixtureDeck.cards()})
	var moves := TableProducer.choreography(ep.read_json("plan"), prod._drawn(3))
	var kinds: Array = moves.map(func(m: Dictionary) -> String: return "%s %d" % [String(m["kind"]), int(m.get("card", 0))])
	var at := kinds.find("work 2")
	_ok(at >= 0 and kinds[at - 1] == "draw 2" and kinds[at + 1] == "draw 3", "the work is not right after card 2: %s" % str(kinds))
	_ok(at >= 0 and String((moves[at] as Dictionary)["say"]) == "say:work:2", "the work's passage is not card 2's work passage")
	var plain := _episode(false)
	_ok(not TableProducer.choreography(plain.read_json("plan"), prod._drawn(3)).any(func(m: Dictionary) -> bool: return String(m["kind"]) == "work"),
		"the control: a plan with no work has a work move")
	# composed and walked: the card shown is laid as the work begins
	var passages: Array = []
	for m in moves:
		passages.append({"kind": m["kind"], "card": m.get("card", 0), "text": "Words of %s." % String(m.get("say", "nothing"))})
	var parse := CardReading.parse(CardReading.compose(passages))
	var work: Dictionary = {}
	for a in parse["actions"]:
		if String((a as Dictionary)["kind"]) == "work":
			work = a
	_ok(not work.is_empty() and is_equal_approx(float(work["dur"]), TableActions.LAY + TableActions.WORK_LEAD),
		"the work's mark rests %s, not the lay and its lead" % str(work.get("dur", "nothing")))
	return true


func _no_cheating() -> bool:
	var ep := _episode(true)
	var plan: Dictionary = ep.read_json("plan")
	(plan["spread"]["positions"][2] as Dictionary)["work"] = "what card 3 brings is poured in"
	ep.write_json("plan", plan)
	ep.write_json("acts", {"acts": [
		{"name": "stir-fire", "beat": "intro", "about": "ABOUT-INTRO the fire is stirred", "length": 4, "tracks": [{"thing": "a", "part": "b", "law": "to", "state": "glow", "value": 1}]},
		{"name": "grind", "beat": 2, "about": "ABOUT-TWO the second thing is ground", "length": "under", "tracks": [{"thing": "a", "part": "b", "law": "to", "state": "grow", "value": 0}]},
		{"name": "pour", "beat": 3, "about": "ABOUT-THREE the third is poured", "length": 5, "tracks": [{"thing": "a", "part": "b", "law": "to", "state": "fill", "value": 0}]}]})
	var prod := TableProducer.new(ep, {"title": "Brews", "brief": "A brief.", "deck": FixtureDeck.cards()})
	var two := String(prod.say_prompt("work:2")["prompt"])
	_ok(two.contains("ABOUT-TWO") and not two.contains("ABOUT-THREE"), "card 2's work passage is not handed its own acts alone")
	_ok(not two.contains("ABOUT-INTRO"), "card 2's work passage is handed the intro's acts")
	var name3 := String(prod._card(3)["name"])
	_ok(not two.contains(name3), "card 2's work passage names card 3, %s" % name3)
	var three := String(prod.say_prompt("work:3")["prompt"])
	_ok(three.contains("ABOUT-THREE"), "the control: card 3's work passage is not handed its own act")
	var intro := String(prod.say_prompt("intro")["prompt"])
	_ok(intro.contains("ABOUT-INTRO") and not intro.contains("ABOUT-TWO"), "the intro is not handed its own acts alone")
	# the card's own passage is told the work comes after it, and the work's passage what comes after that
	var card2 := String(prod.say_prompt("2")["prompt"])
	_ok(card2.contains("the work at the table begins"), "card 2's passage is not told the work begins after it")
	_ok(two.contains("next card is drawn"), "card 2's work passage is not told the next card comes after it")
	return true


func _cues() -> bool:
	var text := "We grind <!-- act: Grind --> slowly <!-- act: pour --> and <!-- table: draw 2 --> on."
	var kept := TableProducer.clean_spoken(text, ["grind"])
	_ok(kept.contains("<!-- act: grind -->") and not kept.contains("pour") and not kept.contains("table:"),
		"a reader's cue was not kept for its own act alone: %s" % kept)
	_ok(not TableProducer.clean_spoken(text).contains("act:"), "the control: a passage with no acts kept a cue")
	return true


func _lands() -> bool:
	var ep := _episode(true)
	var prod := TableProducer.new(ep, {"title": "Brews", "brief": "A brief.", "deck": FixtureDeck.cards()})
	var reply := JSON.stringify({"episode_title": "A Brew", "spread": {"name": "s", "positions": [
		{"name": "a", "asks": "x"}, {"name": "b", "asks": "y", "work": "  it is ground  "}, {"name": "c", "asks": "z"}]},
		"work_intro": "the fire is lit", "look": {"deck_name": "d"}})
	var err := prod._land_plan(reply)
	_ok(err.is_empty(), "a plan with work did not land: %s" % err)
	var works := ep.work_plan()
	_ok(works == {"intro": "the fire is lit", "2": "it is ground"}, "the plan's work landed as %s" % str(works))
	return true


func _clean() -> void:
	var base := ProjectSettings.globalize_path("user://work_steps_check")
	for show in (DirAccess.get_directories_at(base) if DirAccess.dir_exists_absolute(base) else PackedStringArray()):
		for ep in DirAccess.get_directories_at(base.path_join(show)):
			var d := base.path_join(show).path_join(ep)
			for f in DirAccess.get_files_at(d):
				DirAccess.remove_absolute(d.path_join(f))
	TableEpisode.root = TableEpisode.ROOT
