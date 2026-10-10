extends RefCounted
class_name CardPrompts

## CardPrompts - what each agent behind a card episode is told. Pure: strings in, strings out,
## so a gate can hold every prompt to the rules (see tests/cards_check.gd). THE WORDS ARE IN
## rules/cards/ (producer, designer, set_dresser, reader, painter, show - read by [Rules]); here is
## what decides which of them apply and what fills them in: who knows what, when, and how much of
## what the show has already made.
##
## THE RECIPE IS HERE; THE SHOW IS THE BRIEF. Here is how a show of cards at a table is made, the same
## for every show: who knows what when, what a spoken line may contain, what the painter must leave off
## a card. What THIS show is - its kind of cards, its premise, its humor, its rules, its catchphrases -
## is the brief, the body of the show's document, handed to every writer verbatim; the producer names
## the deck's `kind` from it, which is how the painter, who never reads the brief, learns it. Nothing
## here knows tarot (the user, 2026-10-08: "for anything else that tarot might need - declare it in the
## markdown files"): a tarot show is a brief that says it is one, and lists its 78.
##
## FIVE ROLES, and each is told only what its job needs:
##
##   producer - plans the episode BEFORE the shuffle: its title and angle, the spread, and a
##              whole deck's look. It knows no card, because no card has been drawn.
##   designer - the deck's creator, once per drawn card: that card's illustration and its entry in
##              the deck's little booklet. One card per run - it never learns what else was drawn.
##   reader   - the voice of the video, ONE PASSAGE AT A TIME, in drawing order: each run is shown
##              the reading so far and the cards turned over so far, and nothing else. The next
##              card does not exist anywhere in its input until it has been drawn. That is the
##              whole of "no cheating", and [method reader] is where it is kept: it is handed the
##              cards drawn so far, and has no other way to learn one.
##   painter  - the deck's pictures; never shown the reading.
##   set dresser - the reader's table: what stands on it, described to be built; knows no card.
##
## WHAT THE SHOW HAS ALREADY MADE ([method CardEpisode.archive]) reaches each role in the part
## it decides, cut short: the producer sees every earlier episode's angle, running bit, deck (what
## its cards pictured, and how) and cloth and room, and NAMES THE HABITS they share before it
## plans; the designer sees how earlier decks pictured the same card; the set dresser, what
## earlier tables held; a reader passage, how earlier episodes opened, met a card or closed. An
## agent told only to vary drifts back to the likeliest choice, because it cannot steer away from
## choices it has never seen - and the habits are in the form (every deck a human figure on every
## card, every running bit a status revised at each card), not in the subjects, which do vary.

## How many cards a producer who chooses the deck puts in the box, at least, and at most; never fewer
## than twice the cards drawn, so the seed, not the producer, decides which come out.
const BOX := [12, 30]

## How many words each passage runs to - the length of an episode comes from these.
const WORDS := {"intro": [130, 190], "card": [110, 170], "close": [90, 140]}

## How many earlier episodes the producer reads in full, and how many more in a line each.
const PAST_FULL := 10
const PAST_LINES := 30
## How many earlier decks' pictures of the same card the designer is shown.
const SAME_CARD := 6
## How many earlier openings, card reactions and closes a reader passage is shown, and how many
## words of each.
const HEARD := {"intro": [6, 40], "card": [10, 14], "jumper": [6, 24], "close": [6, 60]}

## THE PAINTINGS A READER STOPS ON: a share of an episode's cards, at least none and at most this many of
## every card drawn. Told the art was OPTIONAL and shown every painting, the reader of 834225 still
## walked into four pictures of five ("See that little ant", "Look at the old tortoise"); a card left out
## of this share reaches the reader without its painting or its description, so it cannot.
const REMARKS := Vector2(0.15, 0.4)

## What the producer is told about the show's own deck: its cards by name (their meanings reach a
## writer only as each is drawn).
static func deck_line(deck: Array) -> String:
	return Rules.say("cards/producer.own_deck", _deck_vars(deck))


static func _deck_vars(deck: Array) -> Dictionary:
	var names := PackedStringArray()
	for c in deck:
		names.append(String((c as Dictionary).get("name", "")))
	return {"deck_size": deck.size(), "deck_names": ", ".join(names)}


## THE PRODUCER MAKES THE DECK ([method CardDeck.chooses]): what it is told, for a spread of
## [param n] cards.
static func chosen_deck_line(n: int) -> String:
	return Rules.say("cards/producer.chosen_deck", _box_vars(n))


static func _box_vars(n: int) -> Dictionary:
	var r := box_range(n)
	return {"box_lo": int(r[0]), "box_hi": int(r[1]), "cards": n}


## How many cards a chosen deck holds for a spread of [param n]: `[least, most]`.
static func box_range(n: int) -> Array:
	var lo := maxi(int(BOX[0]), 2 * n)
	return [lo, maxi(lo, int(BOX[1]))]


## HOW AN EPISODE'S CARDS ARE STAGED, for the producer: where they come from, where their text is, and how
## each position's card comes and lies - the registries' own words ([constant TableActions.SOURCES],
## [constant CardTable.TEXTS], [constant TablePositions.COMES]).
static func staging_rule() -> String:
	return Rules.say("cards/producer.staging", _staging_vars())


static func _staging_vars() -> Dictionary:
	var sources: Array = []
	for k in TableActions.SOURCES:
		sources.append({"key": k, "about": String((TableActions.SOURCES[k] as Dictionary)["about"])})
	var texts: Array = []
	for k in CardTable.TEXTS:
		texts.append({"key": k, "about": String(CardTable.TEXTS[k])})
	return {"sources": sources, "texts": texts}


## THE PRINTED CARD, for the producer: what a deck's printer chooses beyond its painting - the frame's
## rules, the window's shape, the corners, an ornament round the edge, the booklet's page - each registry's
## own words ([constant CardTable.FRAMES], [constant CardTable.WINDOWS], [constant CardTable.CORNERS],
## [constant CardTable.ORNAMENTS], [constant CardTable.PAGES]).
static func printed_card_rule() -> String:
	return Rules.say("cards/producer.printed_card", _printed_vars())


static func _printed_vars() -> Dictionary:
	var printed: Array = []
	for reg in [["`frame.style`, the rules round the picture", CardTable.FRAMES], ["`frame.window`, the picture's shape", CardTable.WINDOWS],
			["`frame.ornament`, printed round the card's edge", CardTable.ORNAMENTS], ["`page`, how the booklet's page is set", CardTable.PAGES]]:
		var opts := PackedStringArray()
		for k in reg[1]:
			opts.append("\"%s\" (%s)" % [k, String((reg[1] as Dictionary)[k])])
		printed.append({"what": reg[0], "options": "; ".join(opts)})
	var corners := PackedStringArray()
	for k in CardTable.CORNERS:
		corners.append("\"%s\" (%s)" % [k, String((CardTable.CORNERS[k] as Dictionary)["about"])])
	return {"printed": printed, "corner_options": "; ".join(corners)}


## What the deck is, for a picture or a role: the kind the producer named from the brief ("tarot deck",
## "baseball card set"), or a plain "deck" for a look that names none.
static func deck_noun(look: Dictionary) -> String:
	var kind := _s(look.get("kind", ""))
	return kind if not kind.is_empty() else "deck"


## The context every agent shares: which show, and its brief - the same words for every show.
static func show_context(title: String, brief: String) -> String:
	return Rules.say("cards/show.context", {"title": title, "brief": brief.strip_edges()})


## THE DICE: numbers drawn from the seed that push an episode somewhere the show has not been.
## Numbers, not word lists - a place, a year, a hue, an hour - so the space they draw from is
## the whole world rather than a list someone typed.
static func dice(seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed, "tarot-dice"])
	var lat := snappedf(rng.randf_range(-55.0, 70.0), 0.1)
	var lon := snappedf(rng.randf_range(-180.0, 180.0), 0.1)
	return {
		"place": "%.1f°%s %.1f°%s" % [absf(lat), "N" if lat >= 0.0 else "S", absf(lon),
			"E" if lon >= 0.0 else "W"],
		"year": rng.randi_range(-2400, 2150),
		"hue": rng.randi_range(0, 359),
		"hour": rng.randi_range(0, 23),
		"direction": rng.randi_range(1, 12),
	}


## WHICH CARDS' PAINTINGS THE READER MAY STOP ON in episode [param seed]'s reading of [param n]: one bool per
## card, in drawing order - a [constant REMARKS] share of them, seeded, and never most of them.
static func remarks(seed: int, n: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed, "cards-remarks"])
	var count := clampi(roundi(float(n) * rng.randf_range(REMARKS.x, REMARKS.y)), 0, (n + 1) / 2)
	var order: Array = range(n)
	for i in range(n - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = order[i]
		order[i] = order[j]
		order[j] = tmp
	var out: Array = []
	out.resize(n)
	out.fill(false)
	for i in count:
		out[int(order[i])] = true
	return out


## The registry keys a look may name, for the producer to choose from: the faces the card titles
## are set in and the frames round them. Passed in by the caller so this file names no asset.
## [param history] is the show's other episodes, newest first ([method CardEpisode.archive]).
static func producer(title: String, brief: String, seed: int, cards: int, reversals: bool,
		faces: Dictionary, frames: Dictionary, history: Array, deck: Array = [], chooses := false) -> Dictionary:
	var d := dice(seed)
	var past := PackedStringArray()
	for i in mini(history.size(), PAST_FULL + PAST_LINES):
		past.append(_past(_d(history[i])) if i < PAST_FULL else _past_line(_d(history[i])))
	var vars := {"seed": seed, "cards": cards, "reversals": reversals, "chooses": chooses,
		"habits": not past.is_empty(), "past": "\n".join(past),
		"place": String(d["place"]), "year": int(d["year"]), "hue": int(d["hue"]), "hour": int(d["hour"]), "direction": int(d["direction"]),
		"frame_styles": ", ".join(frames.keys()), "windows": ", ".join(CardTable.WINDOWS.keys()), "corners": ", ".join(CardTable.CORNERS.keys()),
		"ornaments": ", ".join(CardTable.ORNAMENTS.keys()), "pages": ", ".join(CardTable.PAGES.keys()), "faces": ", ".join(faces.keys())}
	for part in [_deck_vars(deck), _box_vars(cards), _staging_vars(), _printed_vars()]:
		vars.merge(part, true)
	return {"system": show_context(title, brief), "prompt": Rules.say("cards/producer.prompt", vars), "dice": d}


## The deck's creator, for ONE card: its illustration and its booklet entry. [param history] is
## the show's other episodes ([method CardEpisode.archive]), for how their decks pictured it.
static func designer(title: String, brief: String, look: Dictionary, card: Dictionary,
		reversals: bool, history: Array = [], text := "booklet") -> Dictionary:
	var group := String(card.get("group", ""))
	var on_back := text == "back"
	var on_front := text == "front"
	var ledger := String(look.get("page", "")) == "ledger"
	var vars := {"deck_noun": deck_noun(look), "deck_name": String(look.get("deck_name", "")), "deck_style": String(look.get("deck_style", "")),
		"palette": ", ".join(PackedStringArray(look.get("palette", []))), "name": String(card.get("name", "")), "group": group,
		"meaning": String(card.get("meaning", "")).strip_edges(), "on_back": on_back, "on_front": on_front,
		"in_booklet": not on_back and not on_front, "ledger": ledger, "ledger_booklet": ledger and not on_back and not on_front,
		"plain_booklet": not ledger and not on_back and not on_front, "reversals": reversals,
		"before": "\n".join(_pictured_before(history, String(card.get("name", ""))))}
	return {"system": show_context(title, brief), "prompt": Rules.say("cards/designer.prompt", vars)}


## THE SET DRESSER: sets the reader's table before the camera rolls - every thing that stands on
## it, described in parts exactly enough to be built ([Props]), and where it stands. It knows the
## episode's plan and look, and no card: none has been drawn. [param headroom] is how tall a thing
## can stand in each zone and be seen whole (centimeters, [method CardTable.headroom]);
## [param seen] are the things earlier episodes' tables held; [param cloth] says the cloth's
## picture goes with the prompt. [param looks] > 0: the set dresser works with tools and SEES what it
## builds ([SetDresserTools], that many pictures) - it is told how to work, and hands the table in
## with a tool instead of replying with it. [param airs]: earlier episodes' effects, to vary from.
## [param byline]: the show's, under its name at the opening ([method title_rule]). [param tables]:
## earlier episodes' tables themselves ([method Tables.summary]), to build otherwise. [param lights]:
## earlier episodes' light ([method Lights.summary]), to light otherwise; [param room] says the room's
## painting goes with the prompt. [param jumps]: a card leaps out of this episode's shuffle
## ([method CardProducer.jumps]) - without one, a burst has no `jumper` moment to mark, and is not offered it.
static func set_dresser(title: String, brief: String, plan: Dictionary, seed: int, headroom: Dictionary,
		seen: Array, cloth: bool, looks := 0, airs: Array = [], byline := "", tables: Array = [], lights: Array = [],
		room := false, jumps := true) -> Dictionary:
	var look: Dictionary = plan.get("look", {}) if plan.get("look") is Dictionary else {}
	var light: Dictionary = look.get("light", {}) if look.get("light") is Dictionary else {}
	var candles := clampi(int(look.get("candles", 1)), 0, CardTable.MAX_CANDLES)
	var size := table_size(seed)
	var zones: Array = []
	for z in CardTable.ZONES:
		zones.append({"zone": z, "about": String((CardTable.ZONES[z] as Dictionary)["about"]), "cm": int(headroom.get(z, 12))})
	var moments := CardTable.MOMENTS.duplicate()
	if not jumps:
		moments.erase("jumper")
	var vars := {
		"seed": seed, "episode_title": String(plan.get("episode_title", "")), "audience": String(plan.get("audience", "")),
		"topic": String(plan.get("topic", "")), "premise": String(plan.get("premise", "")),
		"deck_name": String(look.get("deck_name", "")), "deck_style": String(look.get("deck_style", "")),
		"palette": ", ".join(PackedStringArray(look.get("palette", []))), "surface": String(look.get("surface", "")),
		"setting": String(look.get("setting", "")), "light_kind": String(light.get("kind", "candlelight")),
		"cloth": cloth, "room": room, "jumps": jumps, "tools": looks > 0, "looks": looks,
		"box": String(CardTable.staging_of(plan)["source"]) == "box",
		"candles": candles, "one_candle": candles == 1, "lo": size.x, "hi": size.y, "zones": zones,
		"max_parts": Props.MAX_PARTS, "check": Rules.say("cards/set_dresser.check"),
		"tables": Tables.describe(), "props": Props.describe(), "air": Effects.describe(air_regions(), moments),
		"lights": Lights.describe(), "sounds": Soundscape.describe(),
		"title": title.strip_edges(), "byline": byline.strip_edges(),
		"seen": ", ".join(PackedStringArray(seen)), "airs": ", ".join(PackedStringArray(airs)),
	}
	vars.merge(_box_size(String(CardTable.staging_of(plan)["box_style"]) == "shoebox",
		String(CardTable.staging_of(plan)["contents"])))
	# earlier episodes' tables and lights, each cut short
	var earlier_tables: Array = []
	for t in tables:
		earlier_tables.append(clip(String(t), 60))
	var earlier_lights: Array = []
	for l in lights:
		earlier_lights.append(clip(String(l), 50))
	vars["earlier_tables"] = earlier_tables
	vars["earlier_lights"] = earlier_lights
	return {"system": show_context(title, brief), "prompt": Rules.say("cards/set_dresser.prompt", vars)}


## The thing a set dresser is shown as the shape to copy ([method set_dresser]).
static func set_example() -> String:
	return Rules.say("cards/set_dresser.thing_example")


## THE TITLE, as the set dresser is told it: the show's [param title] (and [param byline]) over its
## table at the opening, and the color it chooses for it ([method CardTable.title_ink]).
static func title_rule(title: String, byline: String) -> String:
	return Rules.say("cards/set_dresser.title", {"title": title.strip_edges(), "byline": byline.strip_edges()})


## The table's [constant CardTable.AIR] as the set dresser reads it: each place, and what it is.
static func air_regions() -> Dictionary:
	var out := {}
	for r in CardTable.AIR:
		out[r] = String((CardTable.AIR[r] as Dictionary)["about"])
	return out


## How many things besides its lit ones a set dresser is asked for on episode [param seed]'s table:
## (fewest, most).
static func table_size(seed: int) -> Vector2i:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed, "tarot-table-size"])
	var lo := rng.randi_range(3, 4)
	return Vector2i(lo, lo + 2)


## THE BOX THE CARDS ARE KEPT IN, for the set dresser of an episode whose cards come out of one: one of
## its things, marked `holds_cards`, open, big enough to file the cards upright in, stood where the deck
## would be ([method TableMedium._stand_box]).
static func box_rule() -> String:
	return Rules.say("cards/set_dresser.box", _box_size())


## The box's largest, in centimeters ([constant CardTable.BOX_MAX]), as the rules say it.
static func _box_size(shoebox := false, contents := "file") -> Dictionary:
	var most := (CardTable.SHOEBOX_MAX if shoebox else CardTable.BOX_MAX) * 100.0
	return {"box_x": roundi(most.x), "box_z": roundi(most.z), "box_y": roundi(most.y),
		"shoebox": shoebox, "filed": contents == "file", "piled": contents == "piles", "loose": contents == "loose"}


## THE READER, one passage. [param step] is "intro", "close", or a card's place in the reading
## ("1", "2", ...). [param said] is every passage read so far, in order; [param drawn] is every
## card turned over so far - for a card step, ENDING with the card just turned. Nothing in here
## knows the deck's order: a card not in [param drawn] has not been drawn, so it is nowhere in the
## prompt. That is the property the gate checks.
##
## [param pictured]: the paintings go with this prompt (see [method CardProducer.say_prompt]) -
## the card's own for a card, every card's for the close - so the words are told to be about
## what is painted, and the designer's plan for the painting is left out: where the painter
## went its own way, the picture on screen is the one the viewer is looking at.
##
## [param history] is the show's other episodes ([method CardEpisode.archive]): what the
## audience has already heard at this point of an episode. Every name in [param names] (the
## show's deck) is masked out of it, so no card reaches a reader through another episode either.
##
## [param voices] are the show's OTHER voices (a familiar on the reader's shoulder), by the names
## its document gives them: the reader writes their lines too and hands each one over with a
## speaker cue ([method voices_rule]). Who they are and when they speak is the brief's to say.
##
## [param remark]: this card is one of the few whose painting the reader may stop on ([method remarks]).
## A card that is not reaches it by name and meaning only - no painting, no description of one.
static func reader(title: String, brief: String, plan: Dictionary, step: String, said: Array,
		drawn: Array, spread_size: int, pictured := false, history: Array = [],
		names: Array = [], voices: Array = [], remark := true) -> Dictionary:
	var positions: Array = ((plan.get("spread", {}) as Dictionary).get("positions", [])) as Array
	var look: Dictionary = plan.get("look", {})
	var staging := CardTable.staging_of(plan)
	var boxed := String(staging["source"]) == "box"
	var inventory: Dictionary = plan.get("inventory", {}) if plan.get("inventory") is Dictionary else {}
	var box_count := int(inventory.get("count", 0)) if not inventory.is_empty() else \
		((plan.get("deck", []) as Array).size() if plan.get("deck") is Array else 0)
	var listed: Array = []
	for i in positions.size():
		var pos: Dictionary = positions[i] if positions[i] is Dictionary else {"name": str(positions[i])}
		listed.append({"n": i + 1, "name": String(pos.get("name", "")), "asks": String(pos.get("asks", "")), "how": _how_note(pos, i + 1)})
	var spoken: Array = []
	for t in said:
		spoken.append(String(t).strip_edges())
	# THIS CARD, and the others on the table - before it, and any swept out with it in one waterfall
	var at := int(step) if step.is_valid_int() else 0
	var on_table: Array = []
	for i in drawn.size():
		var where: Dictionary = positions[i] if i < positions.size() and positions[i] is Dictionary else {}
		if i + 1 != at and String(where.get("destination", "")) != "box":
			on_table.append({"line": _card_line(drawn[i] as Dictionary), "swept": at > 0 and i + 1 > at})
	var vars := {"title": title, "episode_title": String(plan.get("episode_title", "")), "audience": String(plan.get("audience", "")),
		"topic": String(plan.get("topic", "")), "premise": String(plan.get("premise", "")), "reader_mood": String(plan.get("reader_mood", "")),
		"running_bit": _s(plan.get("running_bit", "")), "spread_name": String((plan.get("spread", {}) as Dictionary).get("name", "")),
		"spread_size": spread_size, "positions": listed, "deck_name": String(look.get("deck_name", "")), "surface": String(look.get("surface", "")),
		"on_the_table": CardTable.on_the_table(look), "said": spoken, "on_table": on_table, "box": boxed, "pictured": pictured,
		"intro": step == "intro", "close": step == "close", "card": step != "intro" and step != "close", "voices": not voices.is_empty(),
		"box_count": box_count if boxed else 0}
	var lo_hi: Array = WORDS["card"]
	if step == "intro":
		lo_hi = WORDS["intro"]
		vars["after"] = after(plan, 0, spread_size)
	elif step == "close":
		lo_hi = WORDS["close"]
	else:
		vars.merge(_card_now(plan, positions, drawn, int(step), spread_size, boxed, pictured, remark, String(staging["text"])))
		var p: Dictionary = positions[int(step) - 1] if int(step) - 1 < positions.size() and positions[int(step) - 1] is Dictionary else {}
		var comment := String(p.get("comment", ""))
		var pace := String(staging.get("pace", "reflective"))
		if comment == "brief" or (comment.is_empty() and pace == "quick"):
			lo_hi = [5, 35]
		elif comment.is_empty() and pace == "mixed" and int(step) % 3 == 0:
			lo_hi = [55, 110]
		elif comment.is_empty() and pace == "mixed":
			lo_hi = [8, 40]
	var kind := step if step == "intro" or step == "close" \
		else ("jumper" if not drawn.is_empty() and bool((drawn[drawn.size() - 1] as Dictionary).get("jumper", false)) else "card")
	var heard_before := _heard_before(history, kind, brief, names)
	vars["heard"] = "\n".join(heard_before)
	vars["heard_" + kind] = not heard_before.is_empty()
	if not voices.is_empty():
		vars.merge(_voices_vars(voices))
	vars["lo"] = int(lo_hi[0])
	vars["hi"] = int(lo_hi[1])
	return {"system": show_context(title, brief), "prompt": Rules.say("cards/reader.prompt", vars)}


## CARD [param k] AS THE READER MEETS IT: which way it came (the first that holds of a jumper, dealt, the
## first of a waterfall, the next of one, out of a box, drawn), what may be said of its picture, and its
## printed text - the flags and words of rules/cards/reader.yaml's `card`.
static func _card_now(plan: Dictionary, positions: Array, drawn: Array, k: int, n: int, boxed: bool, pictured: bool,
		remark: bool, text_side: String) -> Dictionary:
	var c: Dictionary = drawn[k - 1] if k - 1 < drawn.size() else drawn[drawn.size() - 1]
	var pos: Dictionary = positions[k - 1] if k - 1 < positions.size() and positions[k - 1] is Dictionary else {}
	var comes := String(pos.get("comes", "drawn"))
	var held := comes != "dealt"
	var out := {"k": k, "card_line": _card_line(c), "meaning": String(c.get("meaning", "")).strip_edges(),
		"position": String(pos.get("name", "")), "asks": String(pos.get("asks", "")), "held": held,
		"reversed": bool(c.get("reversed", false)), "art": String(c.get("art", "")).strip_edges(), "not_first": k > 1,
		"after": after(plan, k, n)}
	var first_swept := comes == "swept" and (k == 1 or String((positions[k - 2] as Dictionary).get("comes", "") if k - 2 < positions.size() and positions[k - 2] is Dictionary else "") != "swept")
	if bool(c.get("jumper", false)):
		out["now_jumper"] = true
	elif comes == "dealt":
		out["now_dealt"] = true
	elif first_swept:
		var last := k
		while last < positions.size() and positions[last] is Dictionary and String((positions[last] as Dictionary).get("comes", "")) == "swept":
			last += 1
		out["now_swept_first"] = true
		out["last"] = mini(last, n)
	elif comes == "swept":
		out["now_swept"] = true
	elif boxed:
		out["now_boxed"] = true
	else:
		out["now_drawn"] = true
	if not remark:
		out["pic_quiet"] = true
	elif pictured and not held:
		out["pic_lying"] = true
	elif pictured:
		out["pic_held"] = true
	elif not String(out["art"]).is_empty():
		out["pic_art"] = true
	var b: Dictionary = c.get("booklet", {}) if c.get("booklet") is Dictionary else {}
	if not b.is_empty():
		out["on_back" if text_side == "back" else ("on_front" if text_side == "front" else "in_booklet")] = true
		out["keywords"] = ", ".join(strings(b.get("keywords", [])))
		out["text"] = String(b.get("upright", "")) if text_side != "booklet" \
			else String(b.get("reversed" if bool(c.get("reversed", false)) and b.has("reversed") else "upright", ""))
	return out


## WHAT THE TABLE DOES AFTER PASSAGE [param k] (0 the intro) of a reading of [param n] cards, in words:
## the moves the plan's position [param k] makes after its passage (`then`), the card held up going down,
## and the next card coming as its position says - never which card it is. The same order
## [method CardProducer.choreography] writes the moves in.
static func after(plan: Dictionary, k: int, n: int) -> String:
	var pos: Array = ((plan.get("spread", {}) as Dictionary).get("positions", [])) as Array if plan.get("spread") is Dictionary else []
	var at := func(i: int) -> Dictionary: return pos[i - 1] if i >= 1 and i <= pos.size() and pos[i - 1] is Dictionary else {}
	var comes := func(i: int) -> String: return String((at.call(i) as Dictionary).get("comes", "drawn"))
	var boxed := String(CardTable.staging_of(plan)["source"]) == "box"
	var parts := PackedStringArray()
	var held: bool = k >= 1 and comes.call(k) != "dealt"
	if held:
		var destination := String((at.call(k) as Dictionary).get("destination", "row"))
		parts.append("this card goes back into the box" if destination == "box" else
			("this card joins a stack at the side" if destination == "stack" else
			("this card goes back down into its place in the waterfall" if comes.call(k) == "swept" else "this card goes down into its place")))
	for m in (at.call(k) as Dictionary).get("then", []) if k >= 1 and (at.call(k) as Dictionary).get("then") is Array else []:
		var w := String(m).split(" ", false)
		if w.size() == 2:
			parts.append("card %s is turned %s where it lies" % [w[1], "sideways" if w[0] == "tap" else "back upright"])
	if k >= n:
		parts.append("the shown cards and the box settle" if boxed else "the whole spread lies on the table")
	else:
		var next := k + 1
		match String(comes.call(next)):
			"dealt":
				parts.append("the next card is %s straight down into its place, face up" % ("taken from the box and put" if boxed else "dealt"))
			"swept":
				if k >= 1 and comes.call(k) == "swept":
					parts.append("the next card of the waterfall is picked up to be shown")
				else:
					var last := next
					while last < n and comes.call(last + 1) == "swept":
						last += 1
					parts.append(("cards %d to %d are swept out together in one waterfall, and card %d is picked up" % [next, last, next])
						if last > next else "the next card is swept out and picked up")
			_:
				parts.append("the next card is pulled out of the box and held up to the camera" if boxed
					else "the next card is drawn, turned over and held up to the camera")
	var text := "; then ".join(parts)
	return text.substr(0, 1).to_upper() + text.substr(1) + "."


## How position [param p] (number [param i]) comes and lies, as a reader is told it beside its name.
static func _how_note(p: Dictionary, i: int) -> String:
	var notes := PackedStringArray()
	match String(p.get("comes", "drawn")):
		"dealt":
			notes.append("dealt straight down")
		"swept":
			notes.append("swept out in a waterfall")
	if String(p.get("lies", "")) == "sideways":
		notes.append("laid sideways")
	if p.get("on") == true and i > 1:
		notes.append("laid on card %d" % (i - 1))
	if String(p.get("destination", "")) in ["box", "stack"]:
		notes.append("goes to " + String(p["destination"]))
	if String(p.get("comment", "")) in ["none", "brief", "story"]:
		notes.append(String(p["comment"]) + " comment")
	if p.get("then") is Array and not (p["then"] as Array).is_empty():
		notes.append("then: " + ", ".join(PackedStringArray(p["then"] as Array)))
	return (" (" + "; ".join(notes) + ")") if not notes.is_empty() else ""


## HOW A PASSAGE HANDS A LINE TO ANOTHER VOICE: the same own-line cue a manuscript uses, back to
## the reader by name ([constant Manuscript.NARRATOR]), every passage opening in the reader's voice.
static func voices_rule(voices: Array) -> String:
	return Rules.say("cards/reader.voices", _voices_vars(voices))


static func _voices_vars(voices: Array) -> Dictionary:
	var names := PackedStringArray()
	var cues := PackedStringArray()
	for v in voices:
		names.append(String(v))
		cues.append("<!-- speaker: %s -->" % String(v))
	return {"names": ", ".join(names), "many": names.size() > 1, "cues": " or ".join(cues), "narrator": Manuscript.NARRATOR}


## A list a writer was asked for, as strings: a JSON array, or one comma-separated string -
## writers return both.
static func strings(v: Variant) -> PackedStringArray:
	var out := PackedStringArray()
	var items: Array = v if v is Array else (Array((v as String).split(",")) if v is String else [])
	for x in items:
		var t := str(x).strip_edges()
		if not t.is_empty():
			out.append(t)
	return out


static func _card_line(c: Dictionary) -> String:
	return "%s%s" % [String(c.get("name", "")), ", reversed (upside down)" if bool(c.get("reversed", false)) else ""]


# --- what the show has already made ----------------------------------------------------------

## ONE EARLIER EPISODE as the producer reads it: what it was about and how it was told, what its
## deck pictured (the designs, so the cast as painted, not as planned) and how it was painted, and
## what it was printed and read on - every field cut short, so ten read at a glance.
static func _past(e: Dictionary) -> String:
	var p := _d(e.get("plan"))
	var look := _d(p.get("look"))
	var frame := _d(look.get("frame"))
	var light := _d(look.get("light"))
	var lines := PackedStringArray()
	lines.append("- \"%s\"" % _s(p.get("episode_title", "")))
	lines.append("  For: %s" % clip(_s(p.get("audience", "")), 18))
	lines.append("  Topic: %s | Angle: %s" % [clip(_s(p.get("topic", "")), 12), clip(_s(p.get("premise", "")), 40)])
	lines.append("  The reader: %s" % clip(_s(p.get("reader_mood", "")), 60))
	if not _s(p.get("running_bit", "")).is_empty():
		lines.append("  Running bit: %s" % clip(_s(p.get("running_bit", "")), 30))
	lines.append("  Spread: %s" % _s(_d(p.get("spread")).get("name", "")))
	if p.get("staging") is Dictionary:
		var st := CardTable.staging_of(p)
		var moves := PackedStringArray()
		var listed: Array = _d(p.get("spread")).get("positions", []) if _d(p.get("spread")).get("positions") is Array else []
		for i in listed.size():
			var how := _how_note(_d(listed[i]), i + 1).strip_edges().trim_prefix("(").trim_suffix(")")
			if not how.is_empty() and not moves.has(how):
				moves.append(how)
		var where := "in a booklet" if st["text"] == "booklet" else ("on the fronts" if st["text"] == "front" else "on the backs")
		lines.append("  Staged: from a %s, %s box, %s contents, %s pace, text %s%s" % [st["source"],
			st["box_style"], st["contents"], st["pace"], where,
			("; " + "; ".join(moves)) if not moves.is_empty() else ""])
	lines.append("  Card size: %s" % _s(look.get("card_size", "large")))
	lines.append("  Deck \"%s\": %s" % [_s(look.get("deck_name", "")), clip(_s(look.get("deck_style", "")), 40)])
	if not _s(look.get("kind", "")).is_empty():
		lines.append("  Its cards were a %s%s" % [_s(look.get("kind", "")), (": " + clip(", ".join(_box_names(p)), 30)) if not _box_names(p).is_empty() else ""])
	var pictured := PackedStringArray()
	for c in e.get("cards", []) if e.get("cards") is Array else []:
		var art := _s(_d(c).get("art", ""))
		if not art.is_empty():
			pictured.append("%s - %s" % [_s(_d(c).get("name", "")), clip(art, 26)])
	if not pictured.is_empty():
		lines.append("  Its cards pictured: %s" % "; ".join(pictured))
	lines.append("  Card stock %s, ink %s, accent %s; %s frame, %s window, %s corners, ornament %s, booklet page %s, titles in %s, foil %s; palette %s" % [
		_s(frame.get("stock", "")), _s(frame.get("ink", "")), _s(frame.get("accent", "")),
		_s(frame.get("style", "")), _s(frame.get("window", "rect")), _s(frame.get("corners", "rounded")),
		_s(frame.get("ornament", "none")), _s(look.get("page", "classic")), _s(look.get("title_face", "")), _s(look.get("foil", "")),
		" ".join(strings(look.get("palette", [])))])
	lines.append("  Cloth: %s | Room: %s | Light: %s, %s lit on the table" % [clip(_s(look.get("surface", "")), 14),
		clip(_s(look.get("setting", "")), 16), clip(_s(light.get("kind", "")), 12), _s(look.get("candles", ""))])
	return "\n".join(lines)


## The cards a producer put in its box ([method chosen_deck_line]), by name.
static func _box_names(plan: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for c in plan.get("deck", []) if plan.get("deck") is Array else []:
		out.append(_s(_d(c).get("name", "")))
	return out


## An episode past the first [constant PAST_FULL], in a line.
static func _past_line(e: Dictionary) -> String:
	var p := _d(e.get("plan"))
	var look := _d(p.get("look"))
	return "- \"%s\" - %s; deck \"%s\": %s" % [_s(p.get("episode_title", "")), clip(_s(p.get("topic", "")), 10),
		_s(look.get("deck_name", "")), clip(_s(look.get("deck_style", "")), 14)]


## How earlier decks pictured the card named [param card_name], one line each.
static func _pictured_before(history: Array, card_name: String) -> PackedStringArray:
	var out := PackedStringArray()
	for e in history:
		var deck := _s(_d(_d(_d(e).get("plan")).get("look")).get("deck_name", ""))
		for c in _d(e).get("cards", []) if _d(e).get("cards") is Array else []:
			var art := _s(_d(c).get("art", ""))
			if _s(_d(c).get("name", "")) == card_name and not art.is_empty() and out.size() < SAME_CARD:
				out.append("- in \"%s\": %s" % [deck, clip(art, 45)])
	return out


## WHAT THE AUDIENCE HAS HEARD at this point of an episode ([param kind]: intro, card, jumper or
## close): the start of each earlier intro and card passage, the end of each close - past the words
## the brief gives every episode, which stay ([method unfixed]) - with every card name masked.
static func _heard_before(history: Array, kind: String, brief: String, names: Array) -> PackedStringArray:
	var out := PackedStringArray()
	var most := int((HEARD[kind] as Array)[0])
	var words := int((HEARD[kind] as Array)[1])
	for e in history:
		var texts: Array = []
		if kind == "intro" or kind == "close":
			texts.append(_s(_d(e).get(kind, "")))
		else:
			for c in _d(e).get("cards", []) if _d(e).get("cards") is Array else []:
				if bool(_d(c).get("jumper", false)) == (kind == "jumper"):
					texts.append(_s(_d(c).get("said", "")))
		for t in texts:
			var line := mask_cards(unfixed(heard(String(t)), brief), names)
			line = tail(line, words) if kind == "close" else clip(line, words)
			if not line.is_empty() and out.size() < most:
				out.append("- \"%s\"" % line)
	return out


## Spoken text as it is heard: no marks, no emphasis, one line.
static func heard(text: String) -> String:
	# who said a line stays with it: the familiar's quip is not the reader's opening
	var named := Manuscript._rx("<!--\\s*speaker\\s*:\\s*(.+?)\\s*-->").sub(text, " ($1:) ", true)
	return _one_line(Manuscript._rx("<!--[\\s\\S]*?-->").sub(named, " ", true).replace("*", ""))


## [param text] without the sentences [param brief] gives word for word (a greeting, a sign-off):
## those are the same in every episode by design, and the record is of what changes.
static func unfixed(text: String, brief: String) -> String:
	var fixed := " %s " % _bare(brief)
	var keep := PackedStringArray()
	for m in Manuscript._rx("[^.!?]+[.!?]*").search_all(text):
		var sentence := m.get_string().strip_edges()
		var bare := _bare(sentence)
		if sentence.is_empty() or (bare.split(" ", false).size() >= 3 and fixed.contains(" %s " % bare)):
			continue
		keep.append(sentence)
	return " ".join(keep)


## Every card name in [param names] out of [param text], as "[card]" - "The " before it included.
static func mask_cards(text: String, names: Array) -> String:
	var alts := PackedStringArray()
	for n in names:
		var bare := Manuscript._rx("(?i)^the\\s+").sub(String(n).strip_edges(), "")
		if not bare.is_empty():
			alts.append(_rx_escape(bare))
	if alts.is_empty():
		return text
	alts.sort()
	alts.reverse()          # the longer of two names sharing a start is tried first
	return Manuscript._rx("\\b(?:[Tt]he\\s+)?(?:%s)\\b" % "|".join(alts)).sub(text, "[card]", true)


## The first [param n] words of [param text], "..." where it was cut.
static func clip(text: String, n: int) -> String:
	var w := _one_line(text).split(" ", false)
	return " ".join(w) if w.size() <= n else " ".join(w.slice(0, n)) + "..."


## The last [param n] words of [param text], "..." where it was cut.
static func tail(text: String, n: int) -> String:
	var w := _one_line(text).split(" ", false)
	return " ".join(w) if w.size() <= n else "..." + " ".join(w.slice(w.size() - n))


static func _one_line(text: String) -> String:
	return Manuscript._rx("\\s+").sub(text, " ", true).strip_edges()


## Lowercase words and digits, single-spaced: what two spellings of one sentence share.
static func _bare(text: String) -> String:
	return Manuscript._rx("[^a-z0-9]+").sub(text.to_lower().replace("'", "").replace("’", ""), " ", true).strip_edges()


static func _rx_escape(s: String) -> String:
	var out := ""
	for ch in s:
		out += ("\\" + ch) if "\\.^$|?*+()[]{}".contains(ch) else ch
	return out


static func _d(v: Variant) -> Dictionary:
	return v if v is Dictionary else {}


## A field as text, whatever a writer made it (JSON numbers arrive as floats).
static func _s(v: Variant) -> String:
	if v is String:
		return (v as String).strip_edges()
	if v is float and is_equal_approx(v, roundf(v)):
		return str(int(v))
	return "" if v == null else str(v).strip_edges()


# --- the painter -----------------------------------------------------------------------------

## Every picture's prompt opens the same way: the painter is an agent, told in words to make one
## image and put it at an exact path (see [ImageGen.Codex]).
static func _paint_head(target: String) -> String:
	return Rules.say("cards/painter.head", {"target": target})


## What every picture of a look is told of it: the deck, its painting style, its palette and its places.
static func _look_vars(look: Dictionary, target: String) -> Dictionary:
	var light: Dictionary = look.get("light", {}) if look.get("light") is Dictionary else {}
	return {"target": target, "deck_noun": deck_noun(look), "deck_name": String(look.get("deck_name", "")),
		"deck_style": String(look.get("deck_style", "")), "palette": ", ".join(PackedStringArray(look.get("palette", []))),
		"card_back": String(look.get("card_back", "")),
		"surface": String(look.get("surface", "a reading cloth")), "setting": String(look.get("setting", "a quiet room")),
		"light_kind": String(light.get("kind", "low lamplight"))}


## A card's face: its illustration only - the engine prints the frame and the name around it.
static func card_image(look: Dictionary, card: Dictionary, art: String, target: String,
		has_back: bool, chain: int) -> String:
	var vars := _look_vars(look, target)
	vars.merge({"name": String(card.get("name", "")), "art": art.strip_edges(), "has_back": has_back, "chain": chain,
		"chain_many": chain > 1, "window": String(CardTable.WINDOWS.get(CardFaces.window_of(look), "a plain rectangle"))}, true)
	return Rules.say("cards/painter.card", vars)


## THE BACK: the side every card of a printing shows face down - EXACTLY SYMMETRIC under a half turn
## when cards come up [param reversed], and a plain middle when each card's text is [param printed] over it.
static func back_image(look: Dictionary, target: String, reversed := true, printed := false) -> String:
	var vars := _look_vars(look, target)
	vars.merge({"reversed": reversed, "printed": printed}, true)
	return Rules.say("cards/painter.back", vars)


## THE CLOTH: a texture at its true scale ([constant CardTable.CLOTH_PICTURE]), dry and bare.
static func surface_image(look: Dictionary, target: String) -> String:
	var vars := _look_vars(look, target)
	vars.merge({"width": int(CardTable.CLOTH_PICTURE.x), "height": int(CardTable.CLOTH_PICTURE.y)}, true)
	return Rules.say("cards/painter.surface", vars)


## THE PAINTING'S HEIGHT MAP: the same surface redrawn as depth, from the cloth's painting attached.
static func height_image(look: Dictionary, target: String) -> String:
	return Rules.say("cards/painter.height", _look_vars(look, target))


## THE ROOM past the table, through a level lens ([constant CardTable.BACKDROP_LENS]).
static func backdrop_image(look: Dictionary, target: String) -> String:
	var vars := _look_vars(look, target)
	vars["lens"] = int(CardTable.BACKDROP_LENS)
	return Rules.say("cards/painter.backdrop", vars)
