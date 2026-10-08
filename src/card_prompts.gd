extends RefCounted
class_name CardPrompts

## CardPrompts - what each agent behind a card episode is told. Pure: strings in, strings out,
## so a gate can hold every prompt to the rules (see tests/cards_check.gd).
##
## THE RECIPE IS HERE; THE SHOW IS THE BRIEF. Everything here is the tarot's recipe - the only one the
## Cards mode has yet (moving it into a show's guide is next/notes.md step 9's open part): how a
## reading video is built, who knows what when, what a spoken line may contain, what the
## painter must leave off a card. What THIS show is - its premise, its humor, its rules, its
## catchphrases - is the brief, the body of the show's document, handed to every agent verbatim.
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

## A brief that says what its show is: a `## Format` or `## The format` section. Without one the show
## is a tarot reading, as every agent is told ([method show_context]); with one, every agent is told
## only that it is a show of cards at a table, and the brief says the rest.
const FORMAT_HEADING := "(?im)^#{1,6}\\s*(?:the\\s+)?format\\s*:?\\s*$"
## How many cards a producer who chooses the deck puts in the box, at least, and at most; never fewer
## than twice the cards drawn, so the seed, not the producer, decides which come out.
const BOX := [12, 30]

## How many words each passage runs to - the length of a tarot reading video comes from these.
const WORDS := {"intro": [130, 190], "card": [110, 170], "close": [90, 140]}

## How many earlier episodes the producer reads in full, and how many more in a line each.
const PAST_FULL := 10
const PAST_LINES := 30
## How many earlier decks' pictures of the same card the designer is shown.
const SAME_CARD := 6
## How many earlier openings, card reactions and closes a reader passage is shown, and how many
## words of each.
const HEARD := {"intro": [6, 40], "card": [10, 14], "jumper": [6, 24], "close": [6, 60]}

## The shape every reader passage must keep, said once for every reader prompt.
## WHEN THE CARDS MOVE, for every reader prompt. A passage is spoken whole and the table acts only
## after it, in the silence before the next - so a passage that ended "And there. That's the first
## one." announced a card the viewer had not seen yet (2026-10-05, "she's signaling the draw before
## it even happened"). AND NOBODY ANNOUNCES THEM: told to "lead into" the next move with "let me set
## this one down" as the example, every card passage of episode 834225 ended on that line, and opened
## on "Oh, the ..." (2026-10-07, "Real tarot readers don't do that ... never announcing their arrival
## or departure").
const MOVES := """THE CARDS MOVE ONLY BETWEEN PASSAGES. Your passage is spoken whole, and nothing on the table moves until your last word. Then, in silence, the table makes the moves that come after it - AFTER YOUR LAST WORD, below, says which - and the next passage begins with them done, in front of the viewer.
THE VIEWER WATCHES EVERY CARD COME AND GO, so nobody has to announce one. A real reader talks straight through the handling - pulling a card, showing it, setting it down - in one running train of thought, and almost never says what their hands are doing: no "let me set this one down", no "let's see what comes next", no "one card left", no "here it is". End your passage on your thought, not on the move. Never report a move before it happens either ("there", "that's the first one", "beside the others"): the viewer has not seen it yet. Do not try to time a move inside your passage with a pause: nothing moves until you finish."""

## THE PAINTINGS A READER STOPS ON: a share of an episode's cards, at least none and at most this many of
## every card drawn. Told the art was OPTIONAL and shown every painting, the reader of 834225 still
## walked into four pictures of five ("See that little ant", "Look at the old tortoise"); a card left out
## of this share reaches the reader without its painting or its description, so it cannot.
const REMARKS := Vector2(0.15, 0.4)

const SPOKEN_RULES := """FORMAT - everything you write is spoken aloud by a voice over the video, word for word:
- Spoken words only. No stage directions, no headings, no lists, no emoji, no markdown, no quotation marks around the passage, no sound effects in brackets.
- You may put single asterisks around ONE word you lean on - *this* - and only now and then. The voice says that word with stress, a touch longer and louder, so mark the word a reader would really hit ("it was *never* about the card"), never a whole phrase. Double asterisks - **this** - hit harder still; keep them for the rare word that has to land.
- Write numbers, symbols and abbreviations the way they are said ("eleven eleven", "twenty percent", "okay").
- Plain paragraphs. Short sentences land; vary the rhythm.
- The viewer sees the table, not you. Never describe your own hands or face.

HOW YOU SAY IT - the voice reading your words has a steady delivery of its own, and you can lean it a little, the way a real reader speeds up as they get going, goes graver for a hard card, or barely pauses when they are on a roll. Put a mark on a line of its own before the stretch: <!-- delivery: quicker, brighter -->. The words: quicker or slower; brighter or graver (a touch higher and livelier, or lower and flatter); tighter or looser (shorter pauses, as when you are on a roll, or longer ones, letting a moment sit); louder or softer (projecting, or leaning in); or one of excited, serious, hushed, urgent, playful, tender, dry. It lasts to the end of its paragraph and eases in and out over a few sentences. Where you would really stop - a beat before a reveal - put <!-- hesitation --> at that exact spot (<!-- hesitation: 2 --> for two seconds). Sparingly: most paragraphs carry no mark at all, and a passage seldom more than one or two. These marks are never read aloud, so never also describe the delivery in words."""


## THE TABLE ITSELF as the set dresser writes it, a shape to copy - a table no episode is set at.
const TABLE_EXAMPLE := """"top": {"shape": "polygon", "sides": 6, "size": [130, 110], "thickness": 4, "edge": "bead", "material": "slate",
  "inlay": {"width": 1.5, "inset": 4, "color": "#b08d57"}, "relief": {"kind": "natural", "depth": 0.6}, "why": "a word or two"},
"layers": [
  {"name": "a burlap runner", "what": "a market runner, front to back", "outline": "rect", "size": [200, 40], "at": [0, -6], "turn": 90,
   "fabric": "burlap", "pattern": {"kind": "ikat", "colors": ["#d9c7a0", "#3b4a6b"], "scale": 7}, "fringe": 6},
  {"name": "a quilted square", "outline": "rect", "size": [60, 60], "turn": 45, "fabric": "cotton",
   "pattern": {"kind": "painting"}, "relief": {"kind": "quilted", "depth": 2.5, "scale": 8}, "border": {"width": 3, "color": "#7a2e3a"}}
]"""


## THE LIGHT as the set dresser writes it, a shape to copy - a light no episode is lit by.
const LIGHT_EXAMPLE := """"light": {"why": "a glasshouse in winter, mid-afternoon: low sun through the panes, clouds now and then",
  "sky": {"color": "#dfe6ea", "strength": 0.6},
  "sun": {"look": "sun", "from": "back left", "height": 18, "color": "#ffd9a8", "strength": 0.75, "softness": 0.2},
  "through": [{"name": "the glasshouse panes", "kind": "window", "at": [0, -5], "size": [240, 200], "panes": [4, 3], "bars": 3}],
  "clouds": {"cover": 0.35, "size": 0.6, "speed": 0.3, "thickness": 0.8},
  "lamps": [{"name": "a paraffin heater's glow", "look": "fire", "from": "front left", "distance": 150, "height": 20, "strength": 0.2, "shadows": false}],
  "shadows": [
    {"name": "the iron crossbeam", "what": "the glasshouse's ridge beam", "parts": [{"shape": "box", "size": [500, 12, 18]}], "shadow": [10, -15], "height": 220, "turn": 20, "move": {"kind": "still"}},
    {"name": "a hanging fern", "what": "a wire basket on three chains", "parts": [
      {"shape": "ball", "size": [40, 26, 40], "at": [0, 13, 0]},
      {"parts": [{"shape": "tube", "path": [[14, 24, 0], [0, 70, 0]], "radius": 0.4}], "copies": {"around": {"count": 3}}}],
      "shadow": [-35, 5], "height": 130, "move": {"kind": "swing", "amount": 0.3}}]}"""


## The set dresser's reply, as a shape to copy - one thing no table would hold.
const SET_EXAMPLE := """{
  "idea": "two or three sentences: this table, and the reader who set it",
  "things": [
    {
      "name": "a boxwood chess pawn",
      "why": "the reader's reason for it, in a few words",
      "place": "back left",
      "group": "a",
      "turn": 0,
      "parts": [
        {"shape": "lathe", "smooth": true, "material": "boxwood",
         "profile": [[0,0],[1.6,0],[1.6,0.4],[1.1,0.8],[0.6,2.6],[1.0,2.9],[0.6,3.2],[0.9,4.0],[0,4.5]],
         "ornament": {"kind": "bands", "count": 2, "depth": 0.5, "from": 0.0, "to": 0.15}}
      ]
    }
  ],
  "materials": {
    "boxwood": {"kind": "wood", "color": "#d9b77a", "color2": "#a87d45", "polish": 0.5, "pattern": 0.3}
  }
}"""


## What the producer is told about the deck: the standard tarot, or the show's own cards by name
## (their meanings reach a writer only as each is drawn).
static func deck_line(deck: Array) -> String:
	if deck.is_empty() or (deck.size() == 78 and String((deck[0] as Dictionary).get("key", "")) == "major_00"):
		return "THE DECK is the standard tarot: the 78 cards of the Rider-Waite-Smith tradition."
	var names := PackedStringArray()
	for c in deck:
		names.append(String((c as Dictionary).get("name", "")))
	return "THE DECK is this show's own, %d cards: %s." % [deck.size(), ", ".join(names)]


## THE PRODUCER MAKES THE DECK ([method CardDeck.chooses]): what it is told, for a spread of
## [param n] cards.
static func chosen_deck_line(n: int) -> String:
	var r := box_range(n)
	return ("THE DECK is yours to choose for this episode: the brief's Cards section says what kind of cards "
		+ "this show shows. Choose one deck, box or collection that fits it and this episode, and list its "
		+ "cards in `deck` - between %d and %d of them, every one a card that collection would really hold, "
		+ "each with what it is. You choose what is in the box, never what comes out: the deck is shuffled "
		+ "from this episode's seed and %d cards come up, in an order nobody knows - so plan nothing that "
		+ "depends on any one card coming up.") % [int(r[0]), int(r[1]), n]


## How many cards a chosen deck holds for a spread of [param n]: `[least, most]`.
static func box_range(n: int) -> Array:
	var lo := maxi(int(BOX[0]), 2 * n)
	return [lo, maxi(lo, int(BOX[1]))]


## HOW AN EPISODE'S CARDS ARE STAGED, for the producer: where they come from, where their text is, and how
## each position's card comes and lies - the registries' own words ([constant TableActions.SOURCES],
## [constant CardTable.TEXTS], [constant TablePositions.COMES]).
static func staging_rule() -> String:
	var lines := PackedStringArray()
	lines.append("THE STAGING: how this episode's cards come to the table and are shown, in `staging`. Choose what this show's kind of cards calls for, and what the brief says.")
	for k in TableActions.SOURCES:
		lines.append("- `source` \"%s\": %s." % [k, String((TableActions.SOURCES[k] as Dictionary)["about"])])
	for k in CardTable.TEXTS:
		lines.append("- `text` \"%s\": %s." % [k, String(CardTable.TEXTS[k])])
	lines.append("EACH POSITION can say how its card comes and lies; leave these out for the usual, a card drawn, held up while it is read, and laid down in a row:")
	lines.append("- `comes` \"dealt\": put straight down in its place, face up, and read lying there - small on screen, so for a card that needs no close look. \"swept\": positions next to each other that are all swept go out together in one waterfall, overlapping in a line or an arc so the viewer sees the run at once; then each is picked up in turn and read.")
	lines.append("- `lies` \"sideways\": laid with a quarter turn, as a tapped card lies.")
	lines.append("- `on` true: laid on the card before it, a little behind so that card's name still shows - a stack, as a player keeps lands.")
	lines.append("- `then`: moves made after this card's passage - \"tap 2\" turns card 2 sideways where it lies, \"untap 2\" turns it back - naming a card already on the table.")
	lines.append("Use them when this kind of card is handled that way (a game's cards played, tapped and stacked; a collector fanning a run of a set out); a reading that needs none is the usual one.")
	return "\n".join(lines)


## THE PRINTED CARD, for the producer: what a deck's printer chooses beyond its painting - the frame's
## rules, the window's shape, the corners, an ornament round the edge, the booklet's page - each registry's
## own words ([constant CardTable.FRAMES], [constant CardTable.WINDOWS], [constant CardTable.CORNERS],
## [constant CardTable.ORNAMENTS], [constant CardTable.PAGES]).
static func printed_card_rule() -> String:
	var lines := PackedStringArray()
	lines.append("THE PRINTED CARD: real decks differ in how they are printed as much as in what they picture - choose what this deck's printer would, in `frame` and `page`:")
	for reg in [["`frame.style`, the rules round the picture", CardTable.FRAMES], ["`frame.window`, the picture's shape", CardTable.WINDOWS],
			["`frame.ornament`, printed round the card's edge", CardTable.ORNAMENTS], ["`page`, how the booklet's page is set", CardTable.PAGES]]:
		var opts := PackedStringArray()
		for k in reg[1]:
			opts.append("\"%s\" (%s)" % [k, String((reg[1] as Dictionary)[k])])
		lines.append("- %s: %s." % [reg[0], "; ".join(opts)])
	var corners := PackedStringArray()
	for k in CardTable.CORNERS:
		corners.append("\"%s\" (%s)" % [k, String((CardTable.CORNERS[k] as Dictionary)["about"])])
	lines.append("- `frame.corners`, how the card is cut: %s." % "; ".join(corners))
	return "\n".join(lines)


## The brief says what its show is ([constant FORMAT_HEADING]).
static func has_format(brief: String) -> bool:
	return Manuscript._rx(FORMAT_HEADING).search(brief) != null


## What the deck is, for a picture or a role: the kind the producer named ("baseball card set"), or
## the tarot deck a show with no Format section reads.
static func deck_noun(look: Dictionary) -> String:
	return _s(look.get("kind", "")) if kind_named(look) else "tarot deck"


## The producer named what kind of cards these are: the show is not a tarot reading.
static func kind_named(look: Dictionary) -> bool:
	return not _s(look.get("kind", "")).is_empty()


## The context every agent shares: which show, and its brief.
static func show_context(title: String, brief: String) -> String:
	if has_format(brief):
		return ("You are part of the team behind a YouTube channel called \"%s\". Each episode is one "
			+ "video filmed from the host's chair at a table: a deck of cards is shuffled on a cloth, cards "
			+ "come up one at a time and are held up to the camera beside a page of text about each, then laid "
			+ "down in a row or a pattern while the host talks. The brief's Format section says what kind of "
			+ "show this is. The team's working words are a card reader's, whatever the show: the READER is the "
			+ "host, the voice of the video; a READING is an episode; the SPREAD is the cards laid out, and its "
			+ "POSITIONS the order they come up in; the BOOKLET is the page of text shown beside each card. "
			+ "The brief says what each of those is on this show, and where it says otherwise, the brief wins.\n\n"
			+ "THE SHOW'S BRIEF, from its creator. It governs everything you write:\n<brief>\n%s\n</brief>") \
			% [title, brief.strip_edges()]
	return ("You are part of the team behind a YouTube tarot channel called \"%s\". Each episode is "
		+ "one tarot reading video, filmed from the reader's chair: the deck is shuffled on a cloth, "
		+ "cards are drawn one at a time and held up to the camera beside the deck's little booklet, "
		+ "then laid down into a spread while the reader talks.\n\n"
		+ "THE SHOW'S BRIEF, from its creator. It governs everything you write:\n<brief>\n%s\n</brief>") \
		% [title, brief.strip_edges()]


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
	var lines := PackedStringArray()
	lines.append("You are the PRODUCER. Plan episode #%d before the camera rolls. Nobody knows which cards will come up - the deck has not been shuffled - so plan nothing that depends on a card." % seed)
	lines.append("")
	lines.append("THE SPREAD has exactly %d positions. Name the spread and each position, and say in a short phrase what each position asks. Positions are asked in order: position 1 is the first card drawn." % cards)
	if reversals:
		lines.append("This show reads reversals: some cards will come up upside down.")
	lines.append("")
	lines.append(staging_rule())
	lines.append("")
	lines.append(chosen_deck_line(cards) if chooses else deck_line(deck))
	lines.append("")
	var shown := has_format(brief)
	lines.append(("THE LOOK is how this deck is drawn and printed - a printing that has never existed - and the table it is shown on." if shown
		else "THE LOOK is a tarot deck that has never existed, and the table it is read on.") + " Make it specific enough that an illustrator could paint every card in one consistent hand: what the cards picture (their cast) and how it is drawn, the medium and its influences, linework, texture, palette. Then the card back (a design that reads the same when the card is turned upside down - exactly symmetric under a half turn), how much of the deck is printed in metallic foil (`foil`, 0 for matte ink to 1 for gold leaf everywhere), the surface the cards lie on (seen from directly above: the bare material, dry and clean of anything spilled or strewn - the table's shape, any other cloth laid on it and whatever stands on it are set separately), the place the table stands in (seen past the far edge of the table, out of focus), the light - indoors or out, the hour and the weather, and what it comes through on its way to the table - and how many lights burn on the table - a candle in its holder, a candelabra, a dish of tea lights each count as one (what they are, and the rest of what stands on the table, is set separately). The card's frame, its name and its numeral are printed by the deck itself, so the illustrations carry no lettering.")
	lines.append(printed_card_rule())
	lines.append("THE CARD STOCK is the card's own color: it shows all round every picture and behind its name, and the deck's booklet is printed in the same colors. Decks are printed on stock of every color, dark and saturated as well as pale - choose the one that best sets off this deck's paintings, with an ink and accent that read on it.")
	if chooses or shown:
		lines.append("THE PRINTINGS: a box may mix printings - sets, years, generations, even games - and each prints its own front and its own back. If this deck does, list them in `look.series`, each with its `name` and what it prints otherwise (`deck_style`, `card_back`, `palette`, `frame`), and give every card of the deck its `series`%s. A deck of one printing leaves `series` out." % (" (a card listed in the brief belongs to the printing named like its group)" if not chooses else ""))
	if not past.is_empty():
		lines.append("")
		lines.append("EARLIER EPISODES of this show, newest first: what each was about and how it was told, what its deck pictured and how it was painted, and what it was printed and read on.")
		lines.append("\n".join(past))
		lines.append("")
		lines.append("THE SHOW'S HABITS. Read those episodes for what they share - not their subjects, which differ, but the formulas under them: the shape of the titles, the kind of angle, the kind of running bit, who or what the cards picture and how they are composed, the way the decks are painted, the way the cards are printed (frame, window, corners, ornament, booklet page), the card stocks, the cloths, the rooms, the hour and the light. Name each one in `habits`, with how many of the episodes fell into it. Then plan an episode that falls into none of them, in its form as well as its subject, and repeats none of their topics, title formulas, angles, running bits, casts, painting styles, palettes, card stocks, cloths or rooms.")
	lines.append("")
	lines.append("INSPIRATION. These numbers were drawn for this episode. Let them push the episode somewhere this show has never been - a culture, a period, a material, a mood - without being literal about them: a place %s; a year %d; a hue %d degrees; the hour %d:00. Before deciding, brainstorm twelve sharply different directions for the episode (topic, angle and look together)%s, then commit to direction number %d." % [String(d["place"]), int(d["year"]), int(d["hue"]), int(d["hour"]), ", none of them in one of the show's habits" if not past.is_empty() else "", int(d["direction"])])
	lines.append("")
	lines.append("Reply with ONLY a JSON object, no other text:")
	lines.append(("""{
  "habits": ["one habit of the earlier episodes per line, and how many of them fell into it"],""" if not past.is_empty() else "{") + """
  "brainstorm": ["twelve one-line directions"],
  "episode_title": "the video's title, as it appears on YouTube",
  "description": "the video's YouTube description, in the genre's own shape (a greeting, what this reading covers, the usual disclaimers and calls to action) and told the show's way; three short paragraphs, no emoji, no links",
  "tags": ["eight to twelve search tags, the genre's own"],
  "audience": "who this collective reading says it is for",
  "topic": "what the reading is about, in a few words",
  "premise": "the episode's angle, in one or two sentences",
  "reader_mood": "how the reader is today",
  "running_bit": "any running bit for this episode - a bit the reader SAYS, never a thing done or an object shown (the viewer sees the table and the cards, never the reader), and never a way of speaking (the show's voice is fixed: no whispering, accents or singing)",
  "staging": {"source": "deck or box", "text": "booklet or back"},
  "spread": {"name": "the spread's name", "positions": [{"name": "position name", "asks": "what it asks", "comes": "drawn, dealt or swept - optional", "lies": "sideways - optional", "on": false, "then": []}]},%s
  "look": {
    "deck_name": "the deck's name",%s
    "deck_style": "a paragraph an illustrator paints every card from",
    "palette": ["#rrggbb", "four to six colors"],
    "card_back": "the back design, symmetric under a half turn",
    "frame": {"style": "one of: %s", "window": "one of: %s", "corners": "one of: %s", "ornament": "one of: %s", "stock": "#rrggbb card stock", "ink": "#rrggbb border and lettering", "accent": "#rrggbb"},
    "page": "one of: %s",
    "title_face": "one of: %s",
    "foil": 0.6,
    "surface": "the cloth or tabletop the cards lie on, seen from above: the bare material, dry",
    "setting": "the place beyond the table",
    "light": {"kind": "what lights the table and how it moves: indoors or out, the hour, the weather (a clear sky, passing clouds, overcast, a storm), what the sun comes through (a window, blinds, leaves, an awning), any lamps or torches round the room", "color": "#rrggbb", "warmth": "warm or cool"},
    "candles": 2
  }
}""" % [("""
  "deck": [{"name": "the name printed on the card", "group": "its set, team, suit or type, if it has one", "series": "its printing's name, when the deck mixes printings", "meaning": "what the card is and why it is in this box, one or two sentences"}],""" if chooses else ""),
		("""
    "kind": "what these cards are, as a noun phrase with no article: baseball card set, flashcard deck, ...",""" if shown else ""),
		", ".join(frames.keys()), ", ".join(CardTable.WINDOWS.keys()), ", ".join(CardTable.CORNERS.keys()),
		", ".join(CardTable.ORNAMENTS.keys()), ", ".join(CardTable.PAGES.keys()), ", ".join(faces.keys())])
	return {"system": show_context(title, brief), "prompt": "\n".join(lines), "dice": d}


## The deck's creator, for ONE card: its illustration and its booklet entry. [param history] is
## the show's other episodes ([method CardEpisode.archive]), for how their decks pictured it.
static func designer(title: String, brief: String, look: Dictionary, card: Dictionary,
		reversals: bool, history: Array = [], text := "booklet") -> Dictionary:
	var lines := PackedStringArray()
	lines.append("You are the DESIGNER of the %s \"%s\", used on this show. Its look:" % [deck_noun(look), String(look.get("deck_name", ""))])
	lines.append(String(look.get("deck_style", "")))
	lines.append("Palette: %s." % ", ".join(PackedStringArray(look.get("palette", []))))
	lines.append("")
	var group := String(card.get("group", ""))
	var element := String(CardDeck.ELEMENTS.get(group, ""))
	lines.append("Design ONE card of the deck: %s%s." % [String(card.get("name", "")),
		(" (%s%s)" % [group, (", element of " + element) if not element.is_empty() else ""]) if not group.is_empty() else ""])
	var meaning := String(card.get("meaning", "")).strip_edges()
	if not meaning.is_empty():
		lines.append("What it means in this deck - grounding, not text to copy: %s" % meaning)
		if text != "back":
			lines.append("The keywords above are the traditional ones, for reference. Choose your own for this deck's entry, as many as the entry wants: keep some, and put a synonym or a fresher word in place of others now and then, so the entry is yours and not a copy.")
	lines.append("")
	lines.append("1. THE ILLUSTRATION: what this card shows, for the illustrator who paints the whole deck - subject, composition, %s. Whatever it pictures is its own, described so it could not be mistaken for another card's. Tall portrait format. No words, letters or numbers anywhere in the picture: the card's frame and name are printed separately." % (
		"what this card is, as this deck pictures it" if kind_named(look) else "the traditional symbolism of this card reinterpreted in this deck's world"))
	if text == "back":
		lines.append("2. WHAT IS PRINTED ON ITS BACK, which the viewer reads when the card is turned over - in `booklet`: its short facts in `keywords` (one each, as that kind of card's back lists them: a position and a team, a type and a weakness, a set number, a year), and its text in `upright` (a bio, rules, flavor text, an answer). Write it exactly the way that kind of card's back is written, as the brief says the backs read. It stands alone: never mention another card.")
	else:
		lines.append("2. ITS ENTRY IN THE DECK'S LITTLE BOOKLET, which is shown on screen beside the card, with its `keywords`%s. Write it the way the brief says this deck's booklet speaks (if it does not say, in the earnest, slightly old-fashioned voice decks' booklets use). It stands alone: never mention another card." % (
			" (this deck's page lists them in two columns: give an EVEN number, four or six)" if String(look.get("page", "")) == "ledger" else ""))
	var before := _pictured_before(history, String(card.get("name", "")))
	if not before.is_empty():
		lines.append("")
		lines.append("EARLIER DECKS on this show pictured this card like this. Picture it some other way, in its subject and its composition both:")
		lines.append("\n".join(before))
	lines.append("")
	lines.append("Reply with ONLY a JSON object, no other text:")
	lines.append("""{
  "art": "the illustration, in two to four sentences",
  "booklet": {
    "keywords": [%s],
    "upright": "the meaning, forty to seventy words"%s
  }
}""" % ["\"%s words or short phrases\"" % ("four or six" if text != "back" and String(look.get("page", "")) == "ledger" else "three to six" if text != "back" else "three to five"), ",\n    \"reversed\": \"the meaning reversed, twenty-five to forty-five words\"" if reversals else ""])
	return {"system": show_context(title, brief), "prompt": "\n".join(lines)}


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
	var lo := size.x
	var hi := size.y
	var lines := PackedStringArray()
	lines.append("You are the SET DRESSER. Before the camera rolls on episode #%d you set the reader's table: you build the table itself and lay its cloths, choose every thing that stands on it, describe each exactly enough for a model maker to build it, and say where it stands. The deck and the cards are not yours - only the table and what stands round them." % seed)
	lines.append("")
	lines.append("THIS EPISODE")
	lines.append("Title: %s" % String(plan.get("episode_title", "")))
	lines.append("For: %s" % String(plan.get("audience", "")))
	lines.append("Topic: %s" % String(plan.get("topic", "")))
	lines.append("Angle: %s" % String(plan.get("premise", "")))
	lines.append("The deck: \"%s\" - %s" % [String(look.get("deck_name", "")), String(look.get("deck_style", ""))])
	lines.append("Palette: %s." % ", ".join(PackedStringArray(look.get("palette", []))))
	lines.append("The surface, as the producer described it: %s%s" % [String(look.get("surface", "")), " - THE PAINTING attached, seen from above, painted for this episode" if cloth else ""])
	lines.append("The room past the table: %s%s" % [String(look.get("setting", "")), " - ITS PAINTING attached, as painted for this episode" if room else ""])
	lines.append("The light: %s." % String(light.get("kind", "candlelight")))
	lines.append("")
	lines.append("THE TABLE ITSELF")
	lines.append("The table is yours too: its top, and what is laid over it. Most readers read at a plain rectangular table; some at a round or an oval one, a few at an octagonal one; some tables are bare boards, some ornate - a molded edge, an inlaid band, a marble slab, a scalloped rim. Over the top go its LAYERS, from the bottom up: a tablecloth hanging over the edge, a runner across it, a square laid as a diamond, a mat or a tapestry under the cards - none, one, or several at different turns. A dressed table is most often more than one layer: a cloth or a runner, and something laid over it that lets it show round the edges - each in its own fabric and pattern; a single mat lying where the old cloth lay is the least a table can be. Build the table this reader of this world would own.")
	lines.append("THE PAINTING is this episode's surface, painted for it%s: give it its place - as the top itself (boards or a slab, as it is painted), as the tablecloth, or as a layer laid over the rest (pattern \"painting\") - and build the rest round it in colors that belong with it. A table that leaves `top` and `layers` out is the plain board table with the painting as a cloth on it, as every earlier table was." % (" (attached)" if cloth else ""))
	lines.append("DEPTH: the light is low and rakes across the table, so relief reads - the threads of a burlap, the grain of brushed oak, a quilt's puffed diamonds, a brocade's raised figures, the seams between boards. Give the surfaces that would really have it their relief; a smooth silk or a polished slab has little.")
	lines.append("The camera looks down across the top from the reader's chair: it sees the top's far edge and the room past it, and a little of the sides; what hangs over the near edge is under the lens.")
	lines.append("")
	lines.append(Tables.describe())
	lines.append("")
	var tarot := not kind_named(look)
	lines.append("THE TABLE A READER SETS")
	lines.append("A reader sets the table on purpose, before every reading, and each thing on it has a reason in the reading's world - light to read by, protection, the four elements the suits stand for, the reading's own subject, devotion, comfort. Give each thing its reason in a few words." if tarot
		else "The host sets the table on purpose, before every episode, and each thing on it has a reason in the show's world, as the brief tells it - light to see the cards by, the episode's own subject, what someone who keeps these cards keeps within reach, comfort. Give each thing its reason in a few words.")
	lines.append("This table belongs to this episode: its place, its era, its materials and its palette - the things a reader of that world would own and set out. Invent them; never reach for the same few things every time.")
	if tarot:
		lines.append("Many readers keep stones on the table: one large piece - a cluster, a geode, a sphere, a tower - or small tumbled ones of several kinds, set straight on the cloth in a loose handful, a row or an arc, or heaped in a dish or a shell; each for what it is said to hold. Give each stone its own colors, and its play of light if it has one.")
	lines.append("Exactly %d lit thing%s - a candle in its holder, a candelabra, a dish of tea lights: each burns as one light, however many flames it has (a flame is a wax part's `wick` or `wicks`) - and %d to %d other things." % [candles, "" if candles == 1 else "s", lo, hi])
	lines.append("Candles take every form a reader of this world would light: a taper in a tall stick, a squat pillar with two or three wicks, tea lights in their tins, a votive in glass, a church candle on a pricket, an oil lamp, a candelabra with a taper in each cup. Make this table's its own, not always a pillar.")
	lines.append("Compose it as a reader does: a few groups and a few things alone, never a row of things evenly spaced. Heights vary within a group, and odd numbers sit well. The middle of the cloth stays bare: the deck is shuffled there, and the cards drawn and laid.")
	lines.append("Every thing is a real object, set out in earnest. Nothing on the table carries words, letters, numbers or labels.")
	lines.append("WHAT THE PARTS CAN MAKE: things of solid form - vessels, teapots and cups, candles and their holders, lamps, tools, boxes, books, bottles, bowls and dishes, stones and crystals, shells, living plants in their pots (a cactus, a snake plant, a fern, a flower) and cut, dried flowers and herbs. Things that are LONG AND LIMP, as strands - a rope coiled down, a tangle of red thread, a wire, a vine trailing across the cloth with its leaves, a string of beads, a chain - laid neatly or thrown down, or draped across the table and over its edge. And BONES, as their own shapes: a skull (a person's, a horned beast's, a bird's), a femur, a rib, a wishbone, a heap of small bones - bone, bleached and dry. And whatever of solid form no other shape makes - a shell, an antler, a gnarled root, a seed pod, the skull or jaw of a creature the skull shape does not know - SCULPTED stroke by stroke, as clay is. They cannot make a BODY: nothing with a head or limbs, flesh, eyes or skin - no animal, fish, bird, insect or person, living or dead, no figurine, statue, doll or carving of one, and no fish or meat laid out as food. Built from balls and rods, a body reads as a crude toy or a monster. Bones are the one exception - bare bone only, built with the bone and skull shapes or sculpted. Where the reading's subject is a creature, a thing from its world stands for it - the tool that catches it, the vessel it is kept or served in, the stone named after it, its bones.")
	if String(CardTable.staging_of(plan)["source"]) == "box":
		lines.append("")
		lines.append(box_rule())
	lines.append("")
	lines.append("WHERE THINGS STAND - each thing's `place`, and the tallest a thing there can be and still be seen whole:")
	for z in CardTable.ZONES:
		lines.append("- \"%s\": %s; up to %d cm." % [z, String((CardTable.ZONES[z] as Dictionary)["about"]), int(headroom.get(z, 12))])
	lines.append("The camera is the reader's eye, about half a meter from the middle of the cloth and looking down across it; the top of the frame passes low over the back of the cloth, which is why the back holds only short things. Candles stand at the back or the sides, never by the deck.")
	lines.append("Things that share a `group` (any word) stand together, the tallest behind; a thing with no group stands on its own. `turn` (degrees) turns a thing about its middle; at 0 its front faces the reader.")
	lines.append("")
	lines.append("HOW A THING IS DESCRIBED")
	lines.append("In centimeters. Each thing has its own origin, the middle of its base on the cloth: y is up, x is the reader's right, and +z is toward the reader - the thing's front.")
	lines.append("A thing is one or more PARTS. A part is one SHAPE of one MATERIAL, placed by `at` [x, y, z] (where the shape's own origin goes - the middle of its base) and turned by `turn` ([x, y, z] degrees, or one number for a turn about the vertical).")
	lines.append("")
	lines.append(Props.describe())
	lines.append("")
	lines.append("DETAIL: the camera sees a thing 10 cm tall at about a sixth of the picture's height, so anything under a few millimeters is lost - engraving, glaze, grain and pattern belong in the material and its ornament, not in extra parts. Most things need 1 to 5 parts; none more than %d." % Props.MAX_PARTS)
	lines.append("SIZES are the real sizes of the real things. For scale, a card here is 7 x 12 cm, and the deck stands 3 cm high.")
	lines.append("")
	lines.append("THE AIR: beside its things, a table can have air that moves - fog rolling in behind it, a few points of light drifting through, a burst of sparks or glitter at a moment of the reading. It goes in `effects`, a list beside `things` and `materials`. The air is part of the table's world as its things are, and the brief says what this show wants of it; a table may have none.")
	var moments := CardTable.MOMENTS.duplicate()
	if not jumps:
		moments.erase("jumper")
	lines.append(Effects.describe(air_regions(), moments))
	lines.append("In this reading %s." % ("the first card leaps out of the deck on its own while it is shuffled - a jumper" if jumps
		else "no card leaps out of the deck: every one is drawn by hand"))
	lines.append("A burst is theater, and the genre makes theater of a few moments: a card leaping from the deck, a card twirled in the fingers, the first card up, the last card down, the close. Mark one of them now and then, never every card - a burst `on` a moment that comes with every card picks its time with `which`.")
	lines.append("The cards are always seen: fog lies behind the table or low on the cloth, never thick over the cards, and a burst is over in a second or two. Its colors belong to the deck's palette or to the light of the episode's world.")
	lines.append("")
	lines.append("THE LIGHT: what lights this table and how that light moves - the sky, the sun or the moon and what it falls through on its way, clouds and birds between it and the table, lamps round the room. It goes in `light`, beside `things`. The plan says what the light is (above): build that light, and make it agree with the room%s - where its windows are, which side its sun comes from, how bright its day is. Indoors or out, the hour and the weather decide it: outdoors by day a bright sky and a sun, its shadows crisp or hazy; a porch or a market stall the shade of an awning, the bright day beyond its edge; a room in the afternoon the sun slanting through a window onto the table, the rest in the room's own dim light; dusk a low red sun or none, and torches or lanterns round the edges; night the moon, or only the lamps and the candles." % (" (its painting attached)" if room else ""))
	lines.append("Light moves, as the world's does: a cloud crosses the sun and every shadow on the table fades and comes back, leaves stir, a bird's shadow flicks across, a torch's light dances, a sign stutters. Things out of the shot throw their shadows too, still or moving: a roof beam's bar of shade across the cloth, a pillar's long stripe, a rope or a lantern swinging on its chain, a chandelier's arms spread over the table, laundry rippling on a line, a ceiling fan's blades turning - build each in `shadows` from silhouettes, and aim where its shadow falls. Give this table the moving light of its world, sparingly - most tables take one or two moving things, some none, and never a light show. Every card must be read in it: the cards and the deck lie in light, never deep in a shade, and the light is never so strong it washes the table out. A table with no `light` is lit as every earlier table was - a lamp over it, candles in the room.")
	lines.append(Lights.describe())
	lines.append("")
	lines.append(title_rule(title, byline))
	if not seen.is_empty():
		lines.append("")
		lines.append("EARLIER EPISODES' TABLES held these. Set none of them again: %s." % ", ".join(PackedStringArray(seen)))
	if not airs.is_empty():
		lines.append("EARLIER EPISODES' AIR was this. Give this table its own, or none: %s." % ", ".join(PackedStringArray(airs)))
	if not tables.is_empty():
		lines.append("EARLIER EPISODES WERE READ AT THESE TABLES. Build this one otherwise - its shape, its wood or stone, its cloths and their patterns:")
		for t in tables:
			lines.append("- " + clip(String(t), 60))
	if not lights.is_empty():
		lines.append("EARLIER EPISODES WERE LIT LIKE THIS. Light this one as its own plan says, in a way of its own - what the sun falls through, what moves, the lamps:")
		for l in lights:
			lines.append("- " + clip(String(l), 50))
	lines.append("")
	var check := "it has no body - no head, no limbs, real or carved (a skull or a bone - made with its own shape, or sculpted as bare bone - is bone, not a body); every part rests on the cloth or on another part (nothing floats, nothing sinks through); it stands as it would really stand - a thing with a pointed or round bottom lies on its side or sits in a stand, a ring or a bowl, never balanced on its point; the lowest point is at height 0; the sizes are real and fit the place's height; a hollow vessel's profile goes up the outside and back down the inside; every candle's wax has `wick` or `wicks`, and a candle in a cup or a holder stands on its floor."
	if looks > 0:
		lines.append("HOW YOU WORK: you build this table with tools, and you SEE what you build. `put` builds the table itself (`top`, `layers`), puts things (and the materials they use, and the air's effects) on it and lights it (`light`), and answers with what was built - each thing's real size, anything the builder could not make as written, where the sun falls - and a picture of the things on a centimeter grid; `look` shows one thing close up from four sides; `overhead` shows the whole table from straight above - its top, its cloths as laid, the things and the cards - with the stretch the camera sees outlined; `set` stands everything on this episode's own table and photographs it from the camera's place, as the viewer will see it, its air with it, saying what was made smaller or left off for want of room and which light leads; `watch` shows one effect of the air, or a moving part of the light, in motion - a burst at the moment it marks, a cloud passing over the sun, a bird's shadow crossing, a lamp flickering; `title` chooses the color the show's name is printed in and shows you the opening with it, saying how far the color stands out from the table behind the name; `remove` takes things, effects, layers or parts of the light off; `submit` hands the table in.")
		lines.append("Build the table first - its top and its layers - and look at it from above; then make the things; then light the table (`put` its `light`), set it, and watch what moves in its light.")
		lines.append("Make a thing, look at it, and fix whatever does not read as the thing you meant - a part floating or sunk, a proportion off, a material that reads as another, anything that reads as a body. When the things read, set the table and look at the frame: fix what was made smaller or left off, a group hidden behind another, a light that should lead and does not. Set it again after a fix. Once the table is set, choose the title's color and look at the opening; submit when both are right. Every picture counts against the %d you have; put a few things at a time, and fix a thing by putting it again under the same name." % looks)
		lines.append("")
		lines.append("CHECK each thing as you look at it: " + check)
		lines.append("")
		lines.append("THE FORMAT of the things and materials you put - shown as a whole table with one thing, a chess pawn, which never belongs on this table:")
		lines.append(SET_EXAMPLE)
		lines.append("...and of the table itself, put as `top` and `layers` (a material the top names goes in `materials`) - a table no episode is set at, never this one:")
		lines.append(TABLE_EXAMPLE)
		lines.append("...and of its light, put as `light` - a light no episode is lit by, never this one's:")
		lines.append(LIGHT_EXAMPLE)
		lines.append("")
		lines.append("Finish by calling submit. After it, your last message can be a single line.")
	else:
		lines.append("CHECK each thing before you answer: " + check)
		lines.append("")
		lines.append("Reply with ONLY a JSON object, no other text. The format, shown with one thing - a chess pawn, which never belongs on this table:")
		lines.append(SET_EXAMPLE)
		lines.append("Beside `things` and `materials` go `top` and `layers` - shown here on a table no episode is set at, never this one (a material the top names goes in `materials`):")
		lines.append(TABLE_EXAMPLE)
		lines.append("...and `light` - shown here as a light no episode is lit by, never this one's:")
		lines.append(LIGHT_EXAMPLE)
		lines.append("Beside `things` and `materials` (and `effects`, if the table has air), the reply carries the name's color: `\"title\": {\"color\": \"#rrggbb\", \"why\": \"a few words: what it stands out against\"}`.")
	return {"system": show_context(title, brief), "prompt": "\n".join(lines)}


## THE TITLE, as the set dresser is told it: the show's [param title] (and [param byline]) over its
## table at the opening, and the color it chooses for it ([method CardTable.title_ink]).
static func title_rule(title: String, byline: String) -> String:
	var under := byline.strip_edges()
	return "THE TITLE: the video opens on this table thrown far out of focus - nothing on it can be made out, only its colors and the glow of its lights - with the show's name, \"%s\", set large across the middle of the frame%s. That frame is also the video's thumbnail, often seen no bigger than a stamp. Choose the color the name is printed in: one that stands out plainly from the colors of the table behind it - the cloth, its lights, what stands on it - and belongs to this episode's world. A soft shade is drawn round every letter, dark round a light color and light round a dark one." % [
		title.strip_edges(), (", and under it \"%s\"" % under) if not under.is_empty() else ""]


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
	var most := CardTable.BOX_MAX * 100.0
	return ("THE BOX THE CARDS ARE KEPT IN is yours to build too: this episode's cards come out of a box, not a deck, filed in it on edge the way collectors keep them. Make it one of your things, with \"holds_cards\": true - from this world: a shoebox, a cigar box, a recipe tin, a card-sleeve box, a wooden file drawer. OPEN, with no lid on it (a lid can lean beside it as a thing of its own): an `extrude` with a `wall`, its inside at least 8 cm across and 13 cm front to back and 8 to 11 cm tall, so the cards stand upright in it; no bigger than %d x %d cm and %d cm tall. It stands where the deck would, to one side of the cloth, its long side running front to back - its `place` is not used - and the cards are filed in it for you."
		% [roundi(most.x), roundi(most.z), roundi(most.y)])


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
	var lines := PackedStringArray()
	var positions: Array = ((plan.get("spread", {}) as Dictionary).get("positions", [])) as Array
	lines.append("You are the READER: the voice of the video. You speak every word of it." if voices.is_empty()
		else "You are the READER: the voice of the video. You write every word of it - your own, and the few lines the show's other voices say.")
	lines.append("")
	lines.append("THIS EPISODE")
	lines.append("Title: %s" % String(plan.get("episode_title", "")))
	lines.append("For: %s" % String(plan.get("audience", "")))
	lines.append("Topic: %s" % String(plan.get("topic", "")))
	lines.append("Angle: %s" % String(plan.get("premise", "")))
	lines.append("You today: %s" % String(plan.get("reader_mood", "")))
	var bit := _s(plan.get("running_bit", ""))
	if not bit.is_empty():
		lines.append("Your running bit: %s" % bit)
	lines.append("The spread: %s, %d cards:" % [String((plan.get("spread", {}) as Dictionary).get("name", "")), spread_size])
	for i in positions.size():
		var pos: Dictionary = positions[i] if positions[i] is Dictionary else {"name": str(positions[i])}
		lines.append("  %d. %s - %s%s" % [i + 1, String(pos.get("name", "")), String(pos.get("asks", "")), _how_note(pos, i + 1)])
	var staging := CardTable.staging_of(plan)
	var boxed := String(staging["source"]) == "box"
	var on_back := String(staging["text"]) == "back"
	var look: Dictionary = plan.get("look", {})
	lines.append("The deck: \"%s\". On the table: %s. Also on it: %s, set out before the reading. The viewer sees the table, never you." % [
		String(look.get("deck_name", "")), String(look.get("surface", "")), CardTable.on_the_table(look)])
	lines.append("")
	if not said.is_empty():
		lines.append("WHAT YOU HAVE SAID SO FAR, in order (the viewer heard all of it):")
		for i in said.size():
			lines.append("<said>\n%s\n</said>" % String(said[i]).strip_edges())
		lines.append("")
	# THIS CARD, and the others on the table - before it, and any swept out with it in one waterfall
	var at := int(step) if step.is_valid_int() else 0
	var earlier: Array = []
	for i in drawn.size():
		if i + 1 != at:
			earlier.append(drawn[i])
	if not earlier.is_empty():
		lines.append("CARDS ALREADY ON THE TABLE:")
		for i in drawn.size():
			if i + 1 != at:
				lines.append("  - %s%s" % [_card_line(drawn[i] as Dictionary), " (swept out with it, not read yet)" if at > 0 and i + 1 > at else ""])
		lines.append("")
	var lo_hi: Array = WORDS["card"]
	if step == "intro":
		lo_hi = WORDS["intro"]
		if boxed:
			lines.append("NOW: the video opens. The box the cards are kept in stands open beside you, the cards filed in it on edge. Welcome the viewer to \"%s\", and set up this episode and who it is for. You do not know which cards will come out - none has been pulled yet - so name none and predict none. The first card comes out after your last word, and the viewer sees it come: end on your thought, never on an announcement, and never say it is out." % title)
		else:
			lines.append("NOW: the video opens. You are shuffling the deck while you talk. Welcome the viewer to \"%s\", set up this episode and who it is for, and keep the patter going while the cards are mixed. You do not know any card yet - none has been drawn - so name none and predict none. The first card comes out after your last word, and the viewer sees it come: end on your thought, never on an announcement, and never say it is out." % title)
	if step == "intro":
		lines.append("AFTER YOUR LAST WORD: %s" % after(plan, 0, spread_size))
	elif step == "close":
		lo_hi = WORDS["close"]
		lines.append("NOW: the last card has just been laid down, and all %d cards are face up on the table. Pull the reading together - the whole spread, in the light of everything you have said - and close the episode the way the brief says the show closes." % spread_size)
		if pictured:
			lines.append("The paintings above are those cards as they lie on the table, in the order they were drawn (a reversed card upside down) - the viewer sees them as you do. The close is about what the cards said, not what they picture: most closes never mention a painting, and none tours them.")
		lines.append("AFTER YOUR LAST WORD: nothing moves - the episode ends.")
	else:
		var k := int(step)
		var c: Dictionary = drawn[k - 1] if k - 1 < drawn.size() else drawn[drawn.size() - 1]
		var pos: Dictionary = positions[k - 1] if k - 1 < positions.size() and positions[k - 1] is Dictionary else {}
		var comes := String(pos.get("comes", "drawn"))
		var held := comes != "dealt"
		if bool(c.get("jumper", false)):
			lines.append("NOW: before you could draw, a card flew out of the deck on its own while you were shuffling - a jumper. It landed on the table and you have picked it up. Readers treat a jumper as a card that insists. React to that first.")
		elif comes == "dealt":
			lines.append("NOW: you have just %s card %d of %d and put it straight down in its place, face up. It lies on the table while you talk about it - it is not held up, so the viewer sees it small." % ["taken" if boxed else "dealt", k, spread_size])
		elif comes == "swept" and (k == 1 or String((positions[k - 2] as Dictionary).get("comes", "") if k - 2 < positions.size() and positions[k - 2] is Dictionary else "") != "swept"):
			var last := k
			while last < positions.size() and positions[last] is Dictionary and String((positions[last] as Dictionary).get("comes", "")) == "swept":
				last += 1
			lines.append("NOW: you have just swept cards %d to %d out across the table in one waterfall, face up and overlapping - the viewer sees them all at once - and picked up card %d to show it. Say a word about the run if you like, then read this card." % [k, mini(last, spread_size), k])
		elif comes == "swept":
			lines.append("NOW: you have put the card before back in its place in the waterfall and picked up card %d of %d to show it." % [k, spread_size])
		elif boxed:
			lines.append("NOW: you have just pulled card %d of %d out of the box and turned it to the camera." % [k, spread_size])
		else:
			lines.append("NOW: you have just drawn card %d of %d and turned it over." % [k, spread_size])
		lines.append("It is %s." % _card_line(c))
		var means := String(c.get("meaning", "")).strip_edges()
		if not means.is_empty():
			lines.append("What it means in this deck: %s" % means)
		lines.append("It sits in position %d, \"%s\" - %s." % [k, String(pos.get("name", "")), String(pos.get("asks", ""))])
		var art := String(c.get("art", "")).strip_edges()
		if not remark:
			lines.append("The viewer is looking at its picture%s. This time you do not describe it or point at anything in it: read the card by its name, its meaning and its place in the spread, and carry your train of thought on - real readers stop on a detail of a picture only now and then, and this is not one of those cards." % (" lying on the table" if not held else ", held up to the camera"))
		elif pictured and not held:
			lines.append("The viewer sees it lying on the table: it is the painting above, so anything you say about it must be what is actually painted there. This is one of the few cards of the reading where you MAY stop on its picture, if a detail serves what you are saying - one detail, a sentence or two, never a tour of the painting.")
		elif pictured:
			lines.append("The viewer is looking at its picture, held up to the camera: it is the painting above%s, so anything you say about it must be what is actually painted there. This is one of the few cards of the reading where you MAY stop on its picture, if a detail serves what you are saying - one detail, a sentence or two, never a tour of the painting. If you have already remarked on a card's art in what you have said so far, let this one go by." % (", upside down, because it came up reversed" if bool(c.get("reversed", false)) else ""))
		elif not art.is_empty():
			lines.append("The viewer is looking at its picture, held up to the camera. For you, not to recite - this deck paints it as: %s. Mention one detail only if it serves what you are saying." % art)
		var b: Dictionary = c.get("booklet", {}) if c.get("booklet") is Dictionary else {}
		if not b.is_empty() and on_back:
			lines.append("Its back is printed with this - the viewer reads it when the card is turned over in your hand. Refer to it if you like, never read it all out:")
			lines.append("<back>")
			lines.append("Facts: %s" % ", ".join(strings(b.get("keywords", []))))
			lines.append(String(b.get("upright", "")))
			lines.append("</back>")
		elif not b.is_empty():
			lines.append("The deck's booklet entry for it is on screen beside the card - the viewer can read it. Refer to it or argue with it if you like, but never read it out:")
			lines.append("<booklet>")
			lines.append("Keywords: %s" % ", ".join(strings(b.get("keywords", []))))
			lines.append(String(b.get("reversed" if bool(c.get("reversed", false)) and b.has("reversed") else "upright", "")))
			lines.append("</booklet>")
		lines.append("Read this card for the viewer, in this position, carrying the story on from what you have already said - the reading builds as the cards come. You know only the cards on the table; never guess at what comes next.")
		if k > 1:
			lines.append("Meet it in your own way, not the way you met the card before: if your last passages opened alike (\"Oh, the ...\", \"Ooh, ...\") or ended alike, this one opens and ends otherwise - mid-thought, with what the position asks, with the card's name inside a sentence.")
		lines.append("AFTER YOUR LAST WORD: %s The viewer watches it happen, so you need not say it will - and never say it has: the next passage opens with it done." % after(plan, k, spread_size))
	var kind := step if step == "intro" or step == "close" \
		else ("jumper" if not drawn.is_empty() and bool((drawn[drawn.size() - 1] as Dictionary).get("jumper", false)) else "card")
	var heard_before := _heard_before(history, kind, brief, names)
	if not heard_before.is_empty():
		lines.append("")
		lines.append(String({
			"intro": "HOW EARLIER EPISODES OPENED, after the words the brief gives every episode. The audience has heard these: open this one some other way.",
			"card": "HOW EARLIER EPISODES MET A CARD - the first words as it was turned over ([card] stands for its name). The audience has heard these: meet this one some other way.",
			"jumper": "HOW EARLIER EPISODES MET A JUMPER - the first words as it flew out ([card] stands for its name). The audience has heard these: meet this one some other way.",
			"close": "HOW EARLIER EPISODES CLOSED, up to the words the brief gives every episode ([card] stands for a card's name). The audience has heard these: say what a close says some other way.",
		}[kind]))
		lines.append("\n".join(heard_before))
	lines.append("")
	lines.append(MOVES)
	if not voices.is_empty():
		lines.append("")
		lines.append(voices_rule(voices))
	lines.append("")
	lines.append("Write %d to %d words." % [int(lo_hi[0]), int(lo_hi[1])])
	lines.append("")
	lines.append(SPOKEN_RULES)
	return {"system": show_context(title, brief), "prompt": "\n".join(lines)}


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
		parts.append("this card goes back down into its place in the waterfall" if comes.call(k) == "swept" else "this card goes down into its place")
	for m in (at.call(k) as Dictionary).get("then", []) if k >= 1 and (at.call(k) as Dictionary).get("then") is Array else []:
		var w := String(m).split(" ", false)
		if w.size() == 2:
			parts.append("card %s is turned %s where it lies" % [w[1], "sideways" if w[0] == "tap" else "back upright"])
	if k >= n:
		parts.append("the whole spread lies on the table")
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
	if p.get("then") is Array and not (p["then"] as Array).is_empty():
		notes.append("then: " + ", ".join(PackedStringArray(p["then"] as Array)))
	return (" (" + "; ".join(notes) + ")") if not notes.is_empty() else ""


## HOW A PASSAGE HANDS A LINE TO ANOTHER VOICE: the same own-line cue a manuscript uses, back to
## the reader by name ([constant Manuscript.NARRATOR]), every passage opening in the reader's voice.
static func voices_rule(voices: Array) -> String:
	var names := PackedStringArray()
	var cues := PackedStringArray()
	for v in voices:
		names.append(String(v))
		cues.append("<!-- speaker: %s -->" % String(v))
	return ("THE SHOW'S OTHER VOICES: %s. The brief says who %s and when %s speak%s. You write %s lines too, and %s reads them. Before the words such a voice says, put its cue on a line of its own - %s - and where you take it back, <!-- speaker: %s --> on a line of its own. Every passage opens in your voice. The cues are never read aloud, and the words never say who is speaking (\"the familiar says\", \"a voice whispers\"): the change of voice says it."
		% [", ".join(names), "they are" if names.size() > 1 else "it is", "they" if names.size() > 1 else "it",
			"" if names.size() > 1 else "s", "their" if names.size() > 1 else "its",
			"each one's own voice" if names.size() > 1 else "its own voice", " or ".join(cues), Manuscript.NARRATOR])


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
		lines.append("  Staged: from a %s, text %s%s" % [st["source"], "in a booklet" if st["text"] == "booklet" else "on the backs",
			("; " + "; ".join(moves)) if not moves.is_empty() else ""])
	lines.append("  Deck \"%s\": %s" % [_s(look.get("deck_name", "")), clip(_s(look.get("deck_style", "")), 40)])
	if kind_named(look):
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
	return ("Use your built-in image generation tool to create exactly ONE image, then save it as a "
		+ "PNG at this exact path: %s\nDo not create or modify any other file. Reply with the saved path only." % target)


static func _deck_line(look: Dictionary) -> String:
	return "STYLE (the whole deck is painted in this one hand): %s Palette: %s." % [
		String(look.get("deck_style", "")), ", ".join(PackedStringArray(look.get("palette", [])))]


## A card's face: its illustration only - the engine prints the frame and the name around it.
static func card_image(look: Dictionary, card: Dictionary, art: String, target: String,
		has_back: bool, chain: int) -> String:
	var lines := PackedStringArray([_paint_head(target), ""])
	lines.append("THE PICTURE: the illustration for %s in the %s \"%s\": %s" % [
		String(card.get("name", "")), deck_noun(look), String(look.get("deck_name", "")), art.strip_edges()])
	lines.append("")
	lines.append(_deck_line(look))
	lines.append("FORMAT: PORTRAIT 2:3 (1024x1536). The card's picture only, composed for a tall card and running to every edge: no border, no frame, no panel, no title, no numbers, no letters or writing of any kind - the frame and the card's name are printed around it separately. Keep the important things away from the outer tenth on each side.")
	lines.append("The engine cuts the picture to the card's window (%s): paint the WHOLE rectangle, the scene running into every corner - never an arch, oval or panel of your own on a white or blank ground, no white or empty corners." % String(CardTable.WINDOWS.get(CardFaces.window_of(look), "a plain rectangle")))
	# The attachments arrive in this order - the back, then the earlier cards - so each group is
	# named by its place in it.
	if has_back:
		lines.append("THE FIRST ATTACHED IMAGE is the BACK of this deck: match its palette, materials and hand. Do NOT copy its pattern or its symmetry.")
	if chain > 0:
		var which := ("THE LAST %d ATTACHED IMAGE%s" if has_back else "THE %d ATTACHED IMAGE%s") \
			% [chain, "S ARE" if chain > 1 else " IS"]
		lines.append("%s %s from this same deck: match the rendering exactly - medium, palette, linework, texture, level of detail - so every card reads as one artist's. Do NOT reuse compositions or subjects; the content comes only from THE PICTURE above." % [
			which, "earlier cards" if chain > 1 else "an earlier card"])
	if chain > 0:
		lines.append("The earlier cards set the HAND, not the CAST: this card's people and creatures are its own, as the description gives them - a figure from an earlier card appears again only if the description asks for it.")
	lines.append("Every real animal named is drawn as that animal, with its true anatomy.")
	lines.append("ALWAYS: no text, no captions, no lettering, no numbers, no borders, no watermark, no signature.")
	return "\n".join(lines)


## THE BACK: the side every card of a printing shows face down - EXACTLY SYMMETRIC under a half turn
## when cards come up [param reversed] (one upside down must not be told from one the right way up), and,
## when each card's text is [param printed] over it ([constant CardTable.TEXTS] `back`), a design round a
## plain middle for that text.
static func back_image(look: Dictionary, target: String, reversed := true, printed := false) -> String:
	var lines := PackedStringArray([_paint_head(target), ""])
	lines.append("THE PICTURE: the BACK of the %s \"%s\" - the side every card shows face down. %s" % [
		deck_noun(look), String(look.get("deck_name", "")), String(look.get("card_back", ""))])
	if reversed:
		lines.append("It must be EXACTLY SYMMETRIC under a half turn (180 degrees), so a card lying upside down cannot be told from one the right way up.")
	if printed:
		lines.append("EACH CARD'S OWN TEXT IS PRINTED OVER THE MIDDLE of this back (its name, its facts, a few lines): keep the middle three quarters a calm, even field of one tone, the design round it - a border, a band, corner ornaments, a printer's mark.")
	lines.append("")
	lines.append(_deck_line(look))
	lines.append("FORMAT: PORTRAIT 2:3 (1024x1536). The design runs to every edge: no outer border or frame (the card's frame is printed separately), no text, no numbers, no watermark, no signature.")
	return "\n".join(lines)


## THE CLOTH: a texture, not a photograph of a moment - the table under it is lit by the scene's
## own lights, so anything the picture carries of light, wet or things lying on it is painted flat
## onto the cloth (feedback 0006: seawater beads that "have no depth"). Asked for at its true scale,
## landscape like the cloth ([constant CardTable.CLOTH_PICTURE]).
static func surface_image(look: Dictionary, target: String) -> String:
	var lines := PackedStringArray([_paint_head(target), ""])
	lines.append("THE PICTURE: a photograph looking STRAIGHT DOWN at %s, laid flat on a reading table and filling the whole frame edge to edge. True colors; the texture of the material sharp." % String(look.get("surface", "a reading cloth")))
	lines.append("THE SCALE: the frame shows %d cm of the surface from side to side and %d cm from top to bottom - as wide as the whole reading table, running on past every edge of the picture - so its weave, grain, boards, knots, scratches and stains are at their true size for that span, never a close-up." % [int(CardTable.CLOTH_PICTURE.x), int(CardTable.CLOTH_PICTURE.y)])
	lines.append("IT IS A TEXTURE: a 3D table is built under it and lit by the scene's own lamp and candles, so the picture holds the material and nothing else - lit flat and even from every side, with no reflections, highlights, glare, sheen, shadows or light falling off toward the edges, even where the material is metal, glass or polished.")
	lines.append("DRY AND BARE, whatever the description says: no water, droplets, beads, puddles, spills or wet patches, and nothing lying on it - no cards, objects, scraps, crumbs, petals, scales, string, hands or text.")
	lines.append("Its colors belong to this palette: %s." % ", ".join(PackedStringArray(look.get("palette", []))))
	lines.append("FORMAT: LANDSCAPE 3:2 (1536x1024). No border, no vignette, no watermark, no text.")
	return "\n".join(lines)


## THE PAINTING'S HEIGHT MAP: the same surface redrawn as depth, from the cloth's painting attached -
## for the relief the table's light rakes ([method Tables.height_fit] checks it lies under it).
static func height_image(look: Dictionary, target: String) -> String:
	var lines := PackedStringArray([_paint_head(target), ""])
	lines.append("THE ATTACHED IMAGE is a texture photographed straight down: %s. Make its HEIGHT MAP - the depth map a 3D renderer lays under that texture." % String(look.get("surface", "a reading cloth")))
	lines.append("THE SAME IMAGE, REDRAWN AS HEIGHT: every board, seam, thread, knot, crack, stitch, carving and pattern exactly where it is in the attached image, the same size and the same shape - the frame unmoved: no crop, no zoom, no turn, no flip, nothing added or left out. Laid over the attached image, every edge must fall on its edge.")
	lines.append("GRAY ONLY, and gray means height: white where the surface stands highest, black its deepest hollows (gaps between boards, cuts, the spaces between threads), middle gray the general surface. A flat print or dye on a smooth surface has no height and is not drawn. No color, no light, no shadow or shading from any side, no highlights - height alone.")
	lines.append("FORMAT: the same size and shape as the attached image (LANDSCAPE 3:2, 1536x1024). No border, no text, no watermark.")
	return "\n".join(lines)


static func backdrop_image(look: Dictionary, target: String) -> String:
	var light: Dictionary = look.get("light", {}) if look.get("light") is Dictionary else {}
	var lines := PackedStringArray([_paint_head(target), ""])
	lines.append("THE PICTURE: a photograph of the room or the world %s sits in, taken from %s chair: %s. Lit by %s." % [
		"a tarot reader" if not kind_named(look) else "the host of a show of cards", "the reader's" if not kind_named(look) else "the host's",
		String(look.get("setting", "a quiet room")), String(light.get("kind", "low lamplight"))])
	lines.append("THE CAMERA IS LEVEL, at a seated person's eye height - about 110 cm above the floor - looking straight ahead through a wide %d mm lens: the eye's height (the horizon) runs straight across the exact middle of the picture, and every upright line stays upright, none leaning in." % int(CardTable.BACKDROP_LENS))
	lines.append("ONLY THE LOWER THIRD WILL BE SEEN, just past the far edge of a table and out of focus. So the lower half carries the place: the floor or the ground and what stands or lies on it - rugs, the feet of furniture, low shelves, baskets, a hearth, a doorway's sill, the ground or water running away outdoors - one place, its broad shapes and its light. Do NOT show a table, cards, hands or people: the table stands in front of this picture separately.")
	lines.append("Its colors belong to this palette: %s." % ", ".join(PackedStringArray(look.get("palette", []))))
	lines.append("FORMAT: LANDSCAPE 3:2 (1536x1024). No text, no watermark, no signature.")
	return "\n".join(lines)
