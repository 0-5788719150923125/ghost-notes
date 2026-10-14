extends SceneTree

## A SHOW OF ANY KIND OF CARD, from its document alone: a box of cards shown off, a deck the producer
## chooses each episode - and a tarot reading, told by the same rules.
##
##   godot --headless --path . --script res://tests/cards/cards_choose_check.gd
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
## - A CARD GOES BACK IN THE BOX ONLY WHEN IT WAS PASSED OVER (the user, 2026-10-13: "Don't spend a full
##   minute talking about the card, just to put it back"): in a spread where cards stay out, a plan that
##   gives a card a story and puts it back lands with that card kept out, a card put back is looked at
##   briefly, and its reader is told it is passed over and asked for a few words. Two-sided: a spread
##   that puts every card back is left as planned, and a kept card's reader is told nothing of the kind.
## - THE DRAW KEEPS WHAT IT LEFT IN A BOX, for the table to print the cards nobody drew as - and no
##   reader is handed one of them (the no-cheating check reads the prompts of an episode that has them).

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
	for check in [_chooses, _framing, _box, _put_back, _no_cheating, _painter]:
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
	_ok(short_prompt.contains("Write 35 to 75 words"), "mixed pacing asks for a short comment")
	# control: the same plan for a show that does not choose keeps no box
	ep.invalidate("plan")
	var fixed := CardProducer.new(ep, {"title": "S", "brief": "B", "deck": FixtureDeck.cards(), "draw": [4, 4]})
	_ok(fixed._land_plan(_plan_with(12)).is_empty() and not (ep.read_json("plan") as Dictionary).has("deck"),
		"control: a show with its own deck kept a producer's box")
	ep.invalidate("plan")
	print("cards_choose_check: box - at least twice the spread, and the draw comes from it")
	return true


func _put_back() -> bool:
	var st := {"source": "box", "pace": "mixed"}
	# THE REPORTED PLAN (the-shoebox 65803): a quick look put back, two kept on a pile, a story put back
	var reported := [{"comment": "brief", "destination": "box"}, {"destination": "stack"},
		{"comes": "searched", "comment": "story", "destination": "stack", "on": true}, {"comment": "story", "destination": "box"}]
	CardProducer.back_only_passed(reported, st)
	_ok(String(reported[3].get("destination", "")) == "stack" and String(reported[3]["comment"]) == "story",
		"a card given a story was still put back in the box while others stay out: %s" % str(reported[3]))
	_ok(String(reported[0]["destination"]) == "box" and String(reported[0]["comment"]) == "brief",
		"a quick look was not put back as planned: %s" % str(reported[0]))
	# no keep pile in the spread: the storied card is laid in its place; a card put back with no length
	# asked for is looked at briefly
	var row := [{"destination": "box"}, {}, {"comment": "story", "destination": "box"}, {"comment": "none", "destination": "box"}]
	CardProducer.back_only_passed(row, st)
	_ok(not (row[2] as Dictionary).has("destination") and String(row[0].get("comment", "")) == "brief"
		and String(row[0]["destination"]) == "box" and String(row[3]["comment"]) == "none" and String(row[3]["destination"]) == "box",
		"a spread laid in a row did not keep its storied card out, or its returns quick: %s" % str(row))
	# a quick pace is already a few words: nothing to shorten
	var quick := [{"destination": "box"}, {}]
	CardProducer.back_only_passed(quick, {"source": "box", "pace": "quick"})
	_ok(not (quick[0] as Dictionary).has("comment") and String(quick[0]["destination"]) == "box", "a quick episode's return was rewritten: %s" % str(quick[0]))
	# control: every card put back is a pattern of its own, stories and all
	var all_back := [{"comment": "story", "destination": "box"}, {"destination": "box"}, {"comment": "brief", "destination": "box"}]
	var before := all_back.duplicate(true)
	CardProducer.back_only_passed(all_back, st)
	_ok(all_back == before, "control: a spread that puts every card back was rewritten: %s" % str(all_back))
	# no box to go back into, and no hand to go back from
	var deck := [{"destination": "box"}, {"destination": "stack"}]
	CardProducer.back_only_passed(deck, {"source": "deck"})
	var dealt := [{"comes": "dealt", "destination": "box"}, {"comes": "swept", "destination": "box"}, {"destination": "box", "comment": "brief"}]
	CardProducer.back_only_passed(dealt, st)
	_ok(not (deck[0] as Dictionary).has("destination") and String(deck[1]["destination"]) == "stack"
		and not (dealt[0] as Dictionary).has("destination") and not (dealt[1] as Dictionary).has("destination")
		and String(dealt[2]["destination"]) == "box",
		"a card went back into a box from a deck, or from where it was dealt: %s %s" % [str(deck), str(dealt)])
	# AS A PLAN LANDS: the reported one, whole - the storied card joins the pile it follows
	CardEpisode.root = ROOT
	var ep := CardEpisode.open("choose-show", 6565)
	ep.invalidate("plan")
	var prod := CardProducer.new(ep, {"title": "S", "brief": BRIEF, "chooses": true, "draw": [4, 4]})
	var box: Array = []
	for i in 12:
		box.append({"name": "Card %c" % (65 + i), "group": "Set", "meaning": "number %d" % i})
	var err := prod._land_plan(JSON.stringify({"episode_title": "T", "staging": {"source": "box", "pace": "mixed", "text": "front"},
		"spread": {"name": "S", "positions": [
			{"name": "a", "asks": "?", "comment": "brief", "destination": "box"},
			{"name": "b", "asks": "?", "destination": "stack"},
			{"name": "c", "asks": "?", "comes": "searched", "comment": "story", "destination": "stack", "on": true},
			{"name": "d", "asks": "?", "comment": "story", "destination": "box"}]},
		"deck": box, "look": {"deck_name": "D", "kind": "baseball card set"}}))
	_ok(err.is_empty(), "the reported plan did not land: %s" % err)
	var plan: Dictionary = ep.read_json("plan")
	var pos: Array = (plan["spread"] as Dictionary)["positions"]
	_ok(String((pos[3] as Dictionary).get("destination", "")) == "stack" and bool((pos[3] as Dictionary).get("on", false))
		and String((pos[0] as Dictionary)["destination"]) == "box",
		"the landed plan still tells a story and puts the card back: %s" % str(pos[3]))
	prod._finish("draw", prod._make_draw())
	# THE DRAW KEEPS WHAT IT LEFT IN THE BOX: the eight nobody drew, by name, none of them drawn
	var draw: Dictionary = ep.read_json("draw")
	var drawn_names: Array = (draw["cards"] as Array).map(func(c: Dictionary) -> String: return String(c["name"]))
	var left: Array = draw.get("left", []) if draw.get("left") is Array else []
	_ok(left.size() == 8 and left.all(func(c: Dictionary) -> bool:
			return String(c["name"]).begins_with("Card ") and not drawn_names.has(String(c["name"])) and String(c["meaning"]).begins_with("number")),
		"the draw did not keep the cards it left in the box: %s" % str(left))
	_ok(((ep.document() as Dictionary).get("left", []) as Array).size() == 8, "the table is not handed the cards left in")
	# THE READER of the card put back is told it is passed over, in a few words; the kept cards' are not
	var back_prompt := String(prod.say_prompt("1")["prompt"]).replace("This card", "this card")
	var kept_prompt := String(prod.say_prompt("2")["prompt"]).replace("This card", "this card")
	var story_prompt := String(prod.say_prompt("4")["prompt"]).replace("This card", "this card")
	_ok(back_prompt.contains("THIS CARD IS PASSED OVER") and back_prompt.contains("Write 15 to 40 words")
		and back_prompt.contains("this card goes back into the box"),
		"the reader of a card put back is not told it is passed over, in a few words")
	_ok(not kept_prompt.contains("PASSED OVER") and not story_prompt.contains("PASSED OVER")
		and story_prompt.contains("this card joins a stack at the side"),
		"control: a kept card's reader is told it is passed over, or its story's card still goes back")
	# control: where every card goes back, none is "passed over" - there is nothing kept to set it against
	var every := {"spread": {"positions": [{"name": "a", "asks": "?", "destination": "box"}, {"name": "b", "asks": "?", "destination": "box"}]},
		"staging": {"source": "box", "text": "front"}, "look": {"deck_name": "D"}}
	var every_prompt := String(CardPrompts.reader("S", BRIEF, every, "1", ["Hello."], [{"name": "Card A"}], 2)["prompt"]).replace("This card", "this card")
	_ok(not every_prompt.contains("PASSED OVER") and every_prompt.contains("goes back into the box"),
		"control: in a spread that puts every card back, a card was called passed over")
	_ok(Rules.missing.is_empty(), "a reader's rule was handed a name it could not fill: %s" % ", ".join(Rules.missing))
	ep.invalidate("plan")
	print("cards_choose_check: put back - only a card passed over goes back in the box while others stay out")
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
