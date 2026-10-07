extends SceneTree

## A SHOW THAT IS NOT A TAROT READING, from its document alone: a box of cards shown off, a deck
## the producer chooses each episode.
##
##   godot --headless --path . --script res://tests/cards_choose_check.gd
##
## - THE PRODUCER CHOOSES THE DECK when the brief's Cards section is prose and lists no card
##   ([method CardDeck.chooses]); a listed deck, or no section (the standard 78), is the show's.
## - THE BOX IS BIGGER THAN THE DRAW: a plan's deck lands only with at least twice the spread (and
##   [constant CardPrompts.BOX]'s least), so the seed, not the producer, decides what comes out; a
##   box the size of the spread is refused. The draw comes from that box.
## - NO CHEATING holds for a chosen deck: the reader of card K is handed cards 1..K and no other
##   card of the box. Two-sided: the close names every card drawn.
## - A FORMAT SECTION TAKES THE TAROT OUT of what every agent is told - the shared context, the
##   designer, the painter's card, back and room - and a show without one is told exactly what a
##   tarot show always was (the controls).

var _fails := 0
const ROOT := "user://cards_choose_check"

const BRIEF := """# Show and Tell

## The format

A collector shows off cards from a box, one at a time.

## Cards

Any kind of collectible card, chosen fresh each episode.
"""


func _init() -> void:
	for check in [_chooses, _framing, _box, _no_cheating, _painter]:
		_ok((check as Callable).call() == true, "%s stopped part way (a script error - see above)"
			% (check as Callable).get_method())
	_remove_tree(ROOT)
	print("cards_choose_check: %s (%d failure%s)" % ["ALL OK" if _fails == 0 else "FAILED", _fails,
		"" if _fails == 1 else "s"])
	quit(1 if _fails > 0 else 0)


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		print("  FAIL: " + what)


func _chooses() -> bool:
	_ok(CardDeck.chooses(BRIEF), "a Cards section of prose alone did not leave the deck to the producer")
	_ok(CardDeck.of(BRIEF).is_empty(), "a chosen deck was read as a deck of the show's own")
	_ok(CardDeck.strip(BRIEF) == BRIEF, "the prose that says what the cards are did not reach the agents whole")
	var listed := BRIEF + "\n- Ace: one.\n- Two: two.\n"
	_ok(not CardDeck.chooses(listed) and CardDeck.of(listed).size() == 2, "control: a listed deck was left to the producer")
	_ok(not CardDeck.chooses("# A show\n\nNo cards here.") and CardDeck.of("No cards here.").size() == 78,
		"control: a show with no Cards section does not read the standard 78")
	print("cards_choose_check: chooses - prose alone leaves the deck to the producer")
	return true


func _framing() -> bool:
	var shown := CardPrompts.show_context("Show and Tell", BRIEF)
	var tarot := CardPrompts.show_context("T", "A tarot brief.")
	_ok(not shown.to_lower().contains("tarot") and shown.contains("Format section"),
		"a show with a Format section is still told it is a tarot channel")
	_ok(tarot.contains("YouTube tarot channel"), "control: a show without a Format section is no longer told it is tarot")
	_ok(not CardPrompts.has_format("The format of a reading is fixed."), "a sentence about the format was taken for its section")
	var p := CardPrompts.producer("Show and Tell", BRIEF, 7, 4, false, CardTable.FACES, CardTable.FRAMES, [], [], true)
	var pr := String(p["prompt"])
	_ok(pr.contains("THE DECK is yours to choose") and pr.contains("\"deck\": [{") and pr.contains("\"kind\": \"what these cards are")
		and not pr.contains("tarot"), "the producer is not asked for its box and its kind, or still hears of tarot")
	var std := String(CardPrompts.producer("T", "B", 7, 4, true, CardTable.FACES, CardTable.FRAMES, [], CardDeck.standard())["prompt"])
	_ok(std.contains("standard tarot") and not std.contains("\"deck\": [{") and not std.contains("\"kind\": \"what these cards are"),
		"control: a tarot producer is asked for a box or a kind")
	var look := {"deck_name": "Sandlot", "kind": "minor-league baseball card set"}
	var card := {"name": "Rookie Shortstop", "meaning": "a kid with a glove"}
	var d := String(CardPrompts.designer("S", BRIEF, look, card, false)["prompt"])
	_ok(d.contains("minor-league baseball card set \"Sandlot\"") and not d.contains("traditional symbolism"),
		"the designer still designs a tarot card")
	var dt := String(CardPrompts.designer("S", "B", {"deck_name": "X"}, card, false)["prompt"])
	_ok(dt.contains("tarot deck \"X\"") and dt.contains("traditional symbolism"), "control: a tarot designer lost the tarot")
	print("cards_choose_check: framing - a Format section takes the tarot out; without one it stays")
	return true


func _plan_with(n_cards: int) -> String:
	var box: Array = []
	for i in n_cards:
		box.append({"name": "Card %c" % (65 + i), "group": "Set", "meaning": "number %d" % i})
	return JSON.stringify({"episode_title": "T", "spread": {"name": "S", "positions": ["a", "b", "c", "d"]},
		"deck": box, "look": {"deck_name": "D", "kind": "baseball card set"}})


func _box() -> bool:
	CardEpisode.root = ROOT
	var ep := CardEpisode.open("choose-show", 4242)
	ep.invalidate("plan")
	var prod := CardProducer.new(ep, {"title": "S", "brief": BRIEF, "chooses": true, "draw": [4, 4]})
	_ok(not prod._land_plan(_plan_with(4)).is_empty() and not ep.has("plan"),
		"a box the size of the spread landed: the producer would pick the cards")
	_ok(prod._land_plan(_plan_with(12)).is_empty(), "a box of twelve did not land")
	var plan: Dictionary = ep.read_json("plan")
	_ok((plan.get("deck", []) as Array).size() == 12 and String((plan["look"] as Dictionary).get("kind")) == "baseball card set",
		"the box or its kind did not land: %s" % str(plan.get("deck")))
	prod._finish("draw", prod._make_draw())
	_ok(ep.has("draw"), "no draw was made from the box: %s" % prod.error_of("draw"))
	var names: Array = []
	for c in plan["deck"] as Array:
		names.append(String((c as Dictionary)["name"]))
	var drawn: Array = (ep.read_json("draw") as Dictionary)["cards"]
	_ok(drawn.size() == 4 and drawn.all(func(c: Variant) -> bool: return names.has(String((c as Dictionary)["name"]))),
		"the draw did not come from the box: %s" % str(drawn))
	# control: the same plan for a show that does not choose keeps no box
	ep.invalidate("plan")
	var fixed := CardProducer.new(ep, {"title": "S", "brief": "B", "deck": CardDeck.standard(), "draw": [4, 4]})
	_ok(fixed._land_plan(_plan_with(12)).is_empty() and not (ep.read_json("plan") as Dictionary).has("deck"),
		"control: a show with its own deck kept a producer's box")
	ep.invalidate("plan")
	print("cards_choose_check: box - at least twice the spread, and the draw comes from it")
	return true


func _no_cheating() -> bool:
	CardEpisode.root = ROOT
	var ep := CardEpisode.open("choose-show", 5151)
	ep.invalidate("plan")
	var prod := CardProducer.new(ep, {"title": "S", "brief": BRIEF, "chooses": true, "draw": [4, 4]})
	_ok(prod._land_plan(_plan_with(12)).is_empty(), "the plan did not land")
	prod._finish("draw", prod._make_draw())
	var drawn: Array = (ep.read_json("draw") as Dictionary)["cards"]
	var box: Array = (ep.read_json("plan") as Dictionary)["deck"]
	var first := String((drawn[0] as Dictionary)["name"])
	var p1 := String(prod.say_prompt("1")["prompt"]) + String(prod.say_prompt("1")["system"])
	var leaked: Array = []
	for c in box:
		var nm := String((c as Dictionary)["name"])
		if nm != first and p1.contains(nm):
			leaked.append(nm)
	_ok(p1.contains(first) and leaked.is_empty(), "the reader of card 1 saw other cards of the box: %s" % str(leaked))
	var close := String(prod.say_prompt("close")["prompt"])
	_ok(drawn.all(func(c: Variant) -> bool: return close.contains(String((c as Dictionary)["name"]))),
		"control: the close does not name the cards drawn - the check above is blind")
	ep.invalidate("plan")
	print("cards_choose_check: no cheating - a reader sees only the cards drawn, never the rest of the box")
	return true


func _painter() -> bool:
	var look := {"deck_name": "Sandlot", "kind": "baseball card set", "setting": "a garage"}
	var face := CardPrompts.card_image(look, {"name": "Rookie"}, "a kid", "/x.png", false, 0)
	var back := CardPrompts.back_image(look, "/x.png")
	var room := CardPrompts.backdrop_image(look, "/x.png")
	_ok(not (face + back + room).to_lower().contains("tarot") and face.contains("baseball card set \"Sandlot\""),
		"the painter is still told it paints a tarot deck")
	var old := {"deck_name": "Sandlot", "setting": "a garage"}
	_ok(CardPrompts.card_image(old, {"name": "Rookie"}, "a kid", "/x.png", false, 0).contains("tarot deck \"Sandlot\"")
		and CardPrompts.backdrop_image(old, "/x.png").contains("a tarot reader"),
		"control: a look with no kind is no longer painted as tarot")
	print("cards_choose_check: painter - the card, back and room take the deck's kind")
	return true


func _remove_tree(path: String) -> int:
	for d in DirAccess.get_directories_at(path):
		_remove_tree(path.path_join(d))
	for f in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	return DirAccess.remove_absolute(path)
