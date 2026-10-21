extends RefCounted
class_name TablePlan

## TablePlan - what an episode decides when it is loaded: everything the table reads to show it,
## and nothing that changes while it plays. A part of [TableMedium].
##
## The episode as the panel handed it over and its reading parsed, the look, the seed, how the
## cards come and are shown, where the camera, the lamp, the deck, its shuffle and every card's place
## are, and the small repeatable differences a hand makes.
##
## A FUNCTION OF THE EPISODE ([method make]): the document the panel hands the medium, the set
## dresser's table as its file said when the episode loaded, and the show's intro hold - and nothing
## else. Every draw comes from the episode's seed in one fixed order, so the same episode is the same
## plan, and the order of the statements in [method make] is part of the show (a salt keeps its
## `tarot-` name: renaming one re-rolls every episode already made). The medium builds its nodes from
## the plan and never decides anything of its own ([method TableMedium._build_episode]);
## tests/table/table_plan_check.gd holds both.
##
## WHY IT IS ITS OWN OBJECT: the table is a pure function of (this, show time). What poses the
## cards, shuffles the deck and lights the room reads it and never writes it; what changes as the
## show plays (the deck's place now, the box, a search, the built meshes, the things as they stood)
## stays with the medium. A part that only poses can be handed a plan instead of the whole medium
## (next/structure.md, step 7), and work that is a pure function of a plan and a time can be done
## early, late or on another thread and still land where it belongs.

var pay: Dictionary = {}           # the episode, as the panel handed it over (CardEpisode.document)
var parse: Dictionary = {}
var seed_value := 0
var hold := 0.0                    # the show's intro hold, the past of a mid-way start is replayed after
var start_si := -1                 # a reading started mid-way: the spoken word it starts at (-1: the top)
var look: Dictionary = {}
var foil := 0.6                    # how much foil the deck was printed with
var staging: Dictionary = CardTable.STAGING.duplicate()   # how the cards come and are shown (CardTable.staging_of)
var cards_from := "deck"                 # where they come from: the reading's opening verb's, else the staging's
var alone := false                   # a drawn card with text on either face is held up alone
var table: Dictionary = {}         # the set dresser's table made safe, as its file said when the episode loaded
var pitch := 45.0                  # the camera: how far it looks down (degrees)...
var cam_base := Transform3D.IDENTITY
var fov := 40.0                    # ...and its lens
var lamp_at := Vector3.ZERO        # the lamp, aimed at the middle of the table
var lamp_color := Color.WHITE
var lamp_base := 1.6                 # the lamp's light before a candle takes the key from it
var background := Color.BLACK      # the room's dark, past the backdrop
var fill := Color.WHITE            # the fill light's color
var mid := Vector3.ZERO            # where it is shuffled, in the middle of the table
var deck_base := Vector3.ZERO      # where the deck is drawn from, to one side
var deck_far := Vector3.ZERO       # where it is slid aside to, when the spread crowds it ([method put_aside])
var aside_card := -1               # ...the card it is slid aside for (-1: it stays)
var slots: Array = []              # per card: Transform3D where it lies in the spread
var jump_land := Vector3.ZERO
var deck_n := 0                    # how many cards the deck holds: a mesh each ([method deck_count])
var slot_jit: Array = []           # per deck slot: Vector3(x, z, yaw)
var lay_jit: Array = []            # per shown card: a small, repeatable placement difference
var ambient := {}                  # the room's own ambient, for a table with no light of its own
var wash_held := false             # the shuffle holds its wash back for a jumper ([method hold_wash])
var wash_from := 0.0               # ...when (into the shuffle) it begins - before the first run ends, at once
var wash_until := 0.0              # ...and when it would end, past the jumper reckoned


## THE PLAN OF AN EPISODE: [param document] as the panel hands it to the medium (`table`, `source`,
## `start_words`, `start_index`), [param table_json] the set dresser's `table.json` as read (null when
## there is none yet: the look's candles) and [param intro_hold] the show's. Decided in one fixed
## order - change the order and every episode already made plays another show.
static func make(document: Dictionary, table_json: Variant, intro_hold: float) -> TablePlan:
	var p := TablePlan.new()
	p.pay = document.get("table", {}) if document.get("table") is Dictionary else {}
	p.hold = intro_hold
	var src := String(document.get("source", ""))
	p.parse = CardReading.parse(src) if not src.is_empty() else {}
	var plan: Dictionary = p.pay.get("plan", {}) if p.pay.get("plan") is Dictionary else {}
	p.look = CardTable.sanitize_look(plan.get("look", {}) if plan.get("look") is Dictionary else {})
	p.seed_value = int(p.pay.get("seed", 0))
	p.foil = float(p.look.get("foil", 0.6))
	p.staging = CardTable.staging_of(plan)
	p.cards_from = String(p.parse.get("source", p.staging["source"])) if not p.parse.is_empty() else String(p.staging["source"])
	p.alone = String(p.staging["text"]) != "booklet"
	p.deck_n = deck_count(p.pay)
	# A READING STARTED MID-WAY (a scrub) begins where its first words are: everything before them
	# happened long ago, spaced as a voice would have said it, so the cards drawn by then are
	# already down (or up) on the first frame
	var spoken: PackedStringArray = p.parse.get("spoken", PackedStringArray()) if not p.parse.is_empty() \
		else PackedStringArray()
	var sw: Variant = document.get("start_words", PackedStringArray())
	if sw is PackedStringArray and not (sw as PackedStringArray).is_empty() and not spoken.is_empty():
		p.start_si = TabletScript.find_run(spoken, sw, int(document.get("start_index", -1)))
	p.table = table_of(table_json, p.look, p.seed_value)
	# EVERYTHING SAMPLED FROM THE EPISODE'S SEED, on one stream: the camera, the lamp, the deck's place,
	# the deck's own small differences, then the spread
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([p.seed_value, "tarot-table"])
	var lay := CardTable.sample_layout(rng)
	# THE CAMERA: the reader's eye, a little different every episode
	p.pitch = float(lay["pitch"])
	p.cam_base = lay["camera"]
	p.fov = float(lay["fov"])
	# THE LIGHT: the look's own, from above and to one side
	var light: Dictionary = p.look.get("light", {}) if p.look.get("light") is Dictionary else {}
	var lc := CardTable.color(String(light.get("color", "#ffb36b")))
	p.lamp_color = Color(1, 1, 1).lerp(lc, 0.55)
	p.lamp_at = lay["lamp"]
	p.lamp_base = float(lay["lamp_energy"])
	var pal: Array = p.look.get("palette", CardTable.FALLBACK_PALETTE)
	var dark := CardTable.color(String(pal[0]))
	p.background = dark.darkened(0.6)
	p.ambient = {"color": Color(0.5, 0.5, 0.5).lerp(dark.lightened(0.4), 0.35), "energy": 0.18}
	p.fill = Color(0.75, 0.8, 1.0) if String(light.get("warmth", "warm")) == "warm" else lc
	# THE DECK, squared where the reader keeps it
	p.deck_base = lay["deck"]
	# SHUFFLED IN THE MIDDLE, in front of the reader, and pushed to its side before the first card
	p.mid = lay["mid"]
	for i in p.deck_n + 1:
		p.slot_jit.append(Vector3(rng.randf_range(-0.0007, 0.0007), rng.randf_range(-0.0007, 0.0007),
			deg_to_rad(rng.randf_range(-1.3, 1.3))))
	# THE SPREAD: where the cards were given to lie (a plan's coordinates, a dealer's layout - checked
	# on the cloth, in the frame and clear of the deck), else the seeded preset. The preset is drawn
	# either way, so every draw after it lands where it always has.
	var cards: Array = p.pay.get("cards", [])
	var seeded := TablePositions.staged(cards, rng, CardTable.layout_of(p.seed_value), p.box_keep(), p.box_center())
	var given := TablePositions.given(cards, p.seed_value, p.table["top"], p.box_keep(), p.box_center())
	p.slots = given if not given.is_empty() else seeded
	var placement := RandomNumberGenerator.new()
	placement.seed = hash([p.seed_value, "lay by hand"])
	for i in cards.size():
		p.lay_jit.append(Vector3(placement.randf_range(-0.0015, 0.0015),
			placement.randf_range(-0.0015, 0.0015), deg_to_rad(placement.randf_range(-1.2, 1.2))))
	p.put_aside(p.table["top"])
	# a jumper flies out of the deck in the middle and lands on the far side from where the deck
	# is about to go
	p.jump_land = p.mid + Vector3(-signf(p.deck_base.x) * 0.16, 0.0, 0.035)
	p.hold_wash()
	return p


## THE SET DRESSER'S TABLE made safe - or, before it wrote one ([param table_json] null), the look's
## candles.
static func table_of(table_json: Variant, look: Dictionary, seed: int) -> Dictionary:
	if table_json is Dictionary:
		return CardTable.sanitize_table(table_json as Dictionary, look)
	return CardTable.default_table(look, seed)


## HOW MANY CARDS THE DECK HOLDS, as the episode says - the table never picks a number of its own
## (the user, 2026-10-14: "The agents define how many cards a deck will use"): what the draw was
## shuffled from (`deck_n`, [method CardProducer._make_draw]; for an episode drawn before the draw
## counted it, the deck its brief lists, [method EpisodeCard._table_doc]), else the deck the producer
## chose, else a box's drawn and left-in cards - and never fewer than the cards drawn. An episode that
## says none of these (a made-up one) holds [constant TableMedium.DECK_FALLBACK].
static func deck_count(pay: Dictionary) -> int:
	var drawn: int = (pay.get("cards", []) as Array).size() if pay.get("cards") is Array else 0
	var n := int(pay.get("deck_n", 0))
	var plan: Dictionary = pay.get("plan", {}) if pay.get("plan") is Dictionary else {}
	if n <= 0 and plan.get("deck") is Array:
		n = (plan["deck"] as Array).size()
	if n <= 0 and pay.get("left") is Array and not (pay["left"] as Array).is_empty():
		n = drawn + (pay["left"] as Array).size()
	return maxi(n if n > 0 else TableMedium.DECK_FALLBACK, maxi(drawn, 1))


## Each spoken word's time along the reading as a voice would say it - the past a mid-way start
## is replayed in: the intro, then a word every 0.4 s, and each action's own rest.
func estimated_times(n: int) -> PackedFloat32Array:
	var rests := {}
	for a in parse.get("actions", []):
		var k := int((a as Dictionary)["after"])
		rests[k] = float(rests.get(k, 0.0)) + float((a as Dictionary)["dur"]) + TableMedium.LEAD + TableMedium.TAIL
	var out := PackedFloat32Array()
	out.resize(n)
	var t := maxf(hold, 0.0)
	for j in n:
		t += float(rests.get(j, 0.0))
		out[j] = t
		t += 0.4
	return out


## Where the box the cards are kept in may stand, across and deep - kept clear by the spread - or zero
## when they come from a deck.
func box_keep() -> Vector2:
	var most := CardTable.SHOEBOX_MAX if String(staging.get("box_style", "open")) == "shoebox" else CardTable.BOX_MAX
	return Vector2(most.x, most.z) if cards_from == "box" else Vector2.ZERO


func box_center() -> Vector3:
	return TablePositions.SHOEBOX_AT if cards_from == "box" and String(staging.get("box_style", "open")) == "shoebox" else Vector3.ZERO


## THE DECK PUT ASIDE ([constant TableMedium.DECK_CROWD]): the first card of the spread that would lie
## that near the deck, and the spot further out - in the frame, on [param top], as far from the spread
## as it can be, by the least slide - it is moved to before that card is drawn. None when nothing
## crowds it, the die says it stays, the cards come from a box, or there is nowhere better; the first
## card itself crowding it puts the deck there from the start.
func put_aside(top: Dictionary) -> void:
	aside_card = -1
	deck_far = deck_base
	if cards_from == "box" or slots.is_empty():
		return
	var gap := func(a: Rect2, b: Rect2) -> float:
		return Vector2(maxf(0.0, maxf(a.position.x - b.end.x, b.position.x - a.end.x)),
			maxf(0.0, maxf(a.position.y - b.end.y, b.position.y - a.end.y))).length()
	var feet: Array = []
	for sl in slots:
		feet.append(CardTable.footprint((sl as Dictionary)["pos"], float((sl as Dictionary)["yaw"]), TableMedium.CARD))
	var keep := TablePositions.deck_keep(deck_base)
	var crowd := -1
	for i in feet.size():
		if float(gap.call(keep, feet[i])) < TableMedium.DECK_CROWD:
			crowd = i
			break
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "tarot-deck-aside"])
	if crowd < 0 or rng.randf() >= TableMedium.DECK_ASIDE:
		return
	var lay := CardTable.layout_of(seed_value)
	var side := signf(deck_base.x)
	var best := -INF
	for dx in range(4, 17):
		for dz in range(-3, 3):
			var at := deck_base + Vector3(side * float(dx) * 0.01, 0.0, float(dz) * 0.02)
			var r := TablePositions.deck_keep(at)
			if not TablePositions._frame_trouble(r, lay).is_empty():
				continue
			if not (Tables.inside(top, r.position, Tables.EDGE) and Tables.inside(top, r.end, Tables.EDGE)
					and Tables.inside(top, Vector2(r.position.x, r.end.y), Tables.EDGE) and Tables.inside(top, Vector2(r.end.x, r.position.y), Tables.EDGE)):
				continue
			var near := INF
			for f in feet:
				near = minf(near, float(gap.call(r, f)))
			# room enough wins; past it, the shorter slide
			var score := minf(near, TableMedium.DECK_CROWD + 0.03) - at.distance_to(deck_base) * 0.1
			if near > float(gap.call(keep, feet[crowd])) + 0.02 and score > best:
				best = score
				deck_far = at
	if best == -INF:
		return
	if crowd == 0:
		deck_base = deck_far
	else:
		aside_card = crowd


## A JUMPER'S WASH, held back for it: an episode whose first card is a jumper washes the deck into
## it now and then ([constant TableMedium.JUMPER_WASH], its own die) - its one wash begins
## [constant TableMedium.JUMPER_WASH_LEAD] before the jumper is reckoned to come (the script's words at
## the follower's steady pace, [method estimated_times]) and runs [constant TableMedium.JUMPER_WASH_SLACK]
## past it, so the jumper comes while it mixes whatever the voice's real pace.
func hold_wash() -> void:
	wash_held = false
	var first := {}
	for a in parse.get("actions", []):
		var kind := String((a as Dictionary)["kind"])
		if TableActions.shows(kind):
			first = a
			break
	if first.is_empty() or String(first["kind"]) != "jumper":
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "jumper-wash"])
	var spoken: PackedStringArray = parse.get("spoken", PackedStringArray())
	var k := mini(int(first["after"]), spoken.size())
	if rng.randf() >= TableMedium.JUMPER_WASH or k <= 0:
		return
	# the shuffle starts its lead before the first word; the jumper a beat after the intro's last
	var est := estimated_times(spoken.size())
	var at := est[k - 1] + 0.4 + TableMedium.LEAD - (est[0] - TableActions.SHUFFLE_LEAD - TableMedium.TAIL)
	wash_held = true
	wash_from = at - TableMedium.JUMPER_WASH_LEAD
	wash_until = at + TableMedium.JUMPER_WASH_SLACK
