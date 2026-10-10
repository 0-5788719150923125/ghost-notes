extends SceneTree

## A SHOW OF ANY KIND OF CARD, from its document alone: a box of cards shown off, a deck the producer
## chooses each episode - and a tarot reading, told by the same rules.
##
##   godot --headless --path . --script res://tests/cards_choose_check.gd
##
## - THE PRODUCER CHOOSES THE DECK when the brief lists no card - a Cards section of prose, or none
##   ([method CardDeck.chooses]); a listed deck is the show's (the control). No deck is built in.
## - THE BOX IS BIGGER THAN THE DRAW: a plan's deck lands only with at least twice the spread (and
##   [constant CardPrompts.BOX]'s least), so the seed, not the producer, decides what comes out; a
##   box the size of the spread is refused. The draw comes from that box.
## - NO CHEATING holds for a chosen deck: the reader of card K is handed cards 1..K and no other
##   card of the box. Two-sided: the close names every card drawn.
## - THE RULES ARE EVERY SHOW'S (the user, 2026-10-08: "there shouldn't be ANY tarot-gated rules"): the
##   shared context is the same words around any brief, and "tarot" reaches the producer, the designer
##   and the painter only from the brief or the deck's `kind` the producer named - two-sided: a look whose
##   kind is a tarot deck is painted and designed as one, and a brief that says tarot is handed whole.

var _fails := 0
const ROOT := "user://cards_choose_check"

const FixtureDeck := preload("res://tests/fixture_deck.gd")

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
	_ok(CardDeck.chooses("# A show\n\nNo cards here.") and CardDeck.of("No cards here.").is_empty(),
		"a show with no Cards section was given a deck the app keeps")
	print("cards_choose_check: chooses - a brief that lists no card leaves the deck to the producer")
	return true


func _framing() -> bool:
	# THE SAME WORDS AROUND ANY BRIEF: take each brief out of its context and nothing else differs
	var tarot_brief := "# True Tarot\n\nA tarot channel that tells the truth."
	var shown := CardPrompts.show_context("S", BRIEF)
	var tarot := CardPrompts.show_context("S", tarot_brief)
	_ok(shown.replace(BRIEF.strip_edges(), "") == tarot.replace(tarot_brief, "") and not shown.to_lower().contains("tarot"),
		"the shared context is not the same words for every show")
	_ok(tarot.contains("A tarot channel that tells the truth."), "control: a tarot brief did not reach the agents whole")
	var plain_brief := "A collector opens a big lidded shoebox, then puts some cards back and makes a small pile of the rest."
	var plain := CardPrompts.producer("S", plain_brief, 7, 4, false, CardTable.FACES, CardTable.FRAMES, [], [], true)
	var plain_context := String(plain["system"])
	var plain_prompt := String(plain["prompt"])
	_ok(plain_context.contains(plain_brief) and plain_context.contains("Read your role's instructions")
		and not plain_context.contains("deck of cards is shuffled"),
		"a natural-language show brief is not framed as the creator's intent")
	_ok(plain_prompt.contains("box_style: \"shoebox\"") and plain_prompt.contains("destination: \"box\""),
		"the producer is not told how to translate a shoebox brief into available presentation choices")
	var aside_plan := {"spread": {"positions": [{"name": "First", "asks": "?"},
		{"name": "Second", "asks": "?", "comment": "aside", "destination": "box"}]},
		"staging": {"source": "box", "text": "front"}, "look": {"deck_name": "D"}}
	var aside_prompt := String(CardPrompts.reader("S", BRIEF, aside_plan, "2", ["I was telling you about the old alley."],
		[{"name": "Earlier"}, {"name": "HIDDEN CARD", "booklet": {"upright": "HIDDEN DETAILS"}}], 2)["prompt"])
	_ok(aside_prompt.contains("Continue the thought") and not aside_prompt.contains("HIDDEN CARD")
		and not aside_prompt.contains("HIDDEN DETAILS"),
		"an aside leaves the held card entirely out of the writer's prompt")
	# THE PRODUCER asks every show for its kind of cards, and names none of its own
	var chosen := String(CardPrompts.producer("Show and Tell", BRIEF, 7, 4, false, CardTable.FACES, CardTable.FRAMES, [], [], true)["prompt"])
	var listed := String(CardPrompts.producer("T", "B", 7, 4, true, CardTable.FACES, CardTable.FRAMES, [], FixtureDeck.cards())["prompt"])
	for pr in [chosen, listed]:
		_ok(String(pr).contains("\"kind\": \"what these cards are") and not String(pr).to_lower().contains("tarot"),
			"a producer is not asked for its deck's kind, or is told of tarot by the rules")
	_ok(chosen.contains("THE DECK is yours to choose") and chosen.contains("\"deck\": [{"), "the producer is not asked for its box")
	_ok(not listed.contains("\"deck\": [{") and listed.contains("78 cards: The Fool, The Magician"),
		"control: a show with its own deck is asked for a box, or not told its cards")
	# THE DESIGNER takes the kind the producer named; no suit's element is the code's
	var card := {"name": "Ace of Wands", "group": "Wands", "meaning": "a spark"}
	var d := String(CardPrompts.designer("S", BRIEF, {"deck_name": "Sandlot", "kind": "minor-league baseball card set"}, card, false)["prompt"])
	_ok(d.contains("minor-league baseball card set \"Sandlot\"") and not d.to_lower().contains("tarot") and not d.contains("element"),
		"the designer still designs a tarot card, or is told a suit's element by the code")
	var dt := String(CardPrompts.designer("S", "B", {"deck_name": "X", "kind": "tarot deck"}, card, true)["prompt"])
	_ok(dt.contains("tarot deck \"X\"") and dt.contains("Ace of Wands (Wands)"), "control: a look whose kind is a tarot deck lost it")
	print("cards_choose_check: framing - one set of rules; the brief and the deck's kind say what the cards are")
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
	(plan["spread"]["positions"][0] as Dictionary)["comment"] = "none"
	plan["staging"] = {"source": "box", "pace": "mixed"}
	ep.write_json("plan", plan)
	prod._make_say("1")
	_ok(ep.has("say:1") and ep.read_text("say:1").is_empty(),
		"a card with no comment passes silently without a writer job")
	var short_prompt := String(prod.say_prompt("2")["prompt"])
	_ok(short_prompt.contains("Write 8 to 40 words"), "mixed pacing asks for a short comment")
	# control: the same plan for a show that does not choose keeps no box
	ep.invalidate("plan")
	var fixed := CardProducer.new(ep, {"title": "S", "brief": "B", "deck": FixtureDeck.cards(), "draw": [4, 4]})
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
	var bare := {"deck_name": "Sandlot", "setting": "a garage"}
	var all := CardPrompts.card_image(bare, {"name": "Rookie"}, "a kid", "/x.png", false, 0) + CardPrompts.back_image(bare, "/x.png") \
		+ CardPrompts.backdrop_image(bare, "/x.png") + CardPrompts.surface_image(bare, "/x.png")
	_ok(not all.to_lower().contains("tarot") and all.contains("the deck \"Sandlot\""), "a look with no kind is painted as tarot")
	var tarot := {"deck_name": "Sandlot", "kind": "tarot deck", "setting": "a garage"}
	_ok(CardPrompts.card_image(tarot, {"name": "Rookie"}, "a kid", "/x.png", false, 0).contains("tarot deck \"Sandlot\""),
		"control: a look whose kind is a tarot deck is not painted as one")
	print("cards_choose_check: painter - the card, back and room take the deck's kind, and only it")
	return true


func _remove_tree(path: String) -> int:
	for d in DirAccess.get_directories_at(path):
		_remove_tree(path.path_join(d))
	for f in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	return DirAccess.remove_absolute(path)
