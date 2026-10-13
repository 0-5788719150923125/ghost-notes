extends Node

## HOW THE CARDS COME AND ARE SHOWN, beyond the tarot's draw (2026-10-07, the user: a collector "might
## have a box... and just draw cards at random from it"; cards in a box "stand vertical... like files in a
## filing cabinet"; a card "tapped... turned sideways"; "a waterfall... presenting several at once,
## overlapping"; cards "stacked vertically, like land in MTG"; a baseball card "held in the center of the
## screen, alone"; a box mixing printings whose "front and backs would be different"):
##
##   - THE MARKS: `fan 3-5` names a run and writes back the same; a box's first card waits for no push
##     (a deck's does - the control); a waterfall rests longer the more cards it sweeps.
##   - THE LAYOUT ([method TablePositions.staged]) over many seeds: stacks lie a step behind the card
##     under them, a waterfall's cards overlap in a run, a sideways card lies a quarter turn round - all
##     on the cloth, in the frame, clear of the deck or the box. A spread asking none of it is the seeded
##     preset, draw for draw (the control).
##   - THE CHOREOGRAPHY ([method CardProducer.choreography]): the plan's positions become the verbs, in
##     order - the opening by the source, drawn, dealt, swept then each shown, `then`'s taps after.
##   - THE TABLE, posed from show time. A deck show: a stacked card lies on the card before it, a dealt
##     card is never held up, a tap turns a lying card a quarter turn, a drawn card is held up LEFT of
##     the middle with its page open. A box show: the box stands with the cards filed in it on edge, a
##     card waits standing in the file and rises out past the rim, is held up ALONE in the middle with no
##     page and turned over to show its printed back; the waterfall's cards lie overlapping. EVERY CARD
##     IN THE FILE STANDS BACK TO THE CAMERA (2026-10-12, the user: a card "changed to something else
##     after getting pulled from the box"): a card comes up showing its back and is turned round to be
##     seen, and the cards nobody drew are printed as the deck's own cards the draw left in. A SEARCH
##     ("a card was lifted from the deck FLAT, and THREE times in a row") draws three different cards
##     up out of their places on edge, part of the way, and lets them back down; off a pile it lifts
##     the top card (two-sided: a lying card's place is looked at lying). THE CARD LOOKED AT IS THE
##     BOX'S OWN, lying or standing in its place before the look and after it, on a pile nothing is
##     drawn from or put back on (two-sided: a box with no card of its own is lent one for the look).
##     THE BOX STANDS in its own place in the room kept for it, a different one each episode, an open
##     box toward the spread (two-sided: a box as big as its room stands where it always did). The file
##     holds the planned count, and a mixed box keeps each printing's own back and share of the cards.
##   - THE AIR'S BURSTS COME FROM THE CARD (2026-10-08, the user: a burst of sparkles came "just BEFORE"
##     a card held up on the left was laid, "detached from the card itself"): over a deck show, a show
##     whose spread lays the card still held, a box show and a jumper's, with a pirouette asked for,
##     every particle a burst on a card moment would throw is born at that card as the table draws it
##     at its birth time - its middle and its edges - and the close waits until every card is down.
##     Two-sided: the close as it was planned (at the spread's mark, from where each card would lie)
##     is far from the card the spread is still laying. A jumper comes down as it lies: its flight
##     ends where it lands, turned as it lands (it snapped a third of a turn round as it touched).
##
##   - WHAT LIES ON WHAT (2026-10-11, the user, of a waterfall's two cards shown one after the other: the
##     second "was pulled THROUGH the 1st card... it may have looked even better to slide the 2nd card
##     out to the right"): through a waterfall, each card shown and laid again, no card passes through
##     another or lies in it - a card under another is slid out along the cloth before it rises, and one
##     put back lies on top. Two-sided: a card lifted straight up from under the one on it does pass
##     through it, and the check says so.
##   - THE CARDS IN THE BOX (the same day: the box's cards "did not match the ones we were drawing";
##     "perfect little stacks, equally-spaced apart"): with the text on the back, every card nobody
##     drew has a printed back as the drawn ones do, never the shared artwork (which a front-text box
##     keeps - the control, in the front details). Piles are of different heights, unevenly spaced and
##     not squared, each card on its own plot of the floor; the drawn cards wait on top of piles, and
##     a card put back goes on a pile. Two-sided: the same piles laid with no mess are the squared grid.
##
##   tests/run_boot_probe.sh tests/table_staging_check.gd 300
##
## A BOOT probe (the medium reaches the Director); no GPU - poses are transforms.

const SEEDS := 40

var _fails := 0
var medium: TableMedium
var subs: Subtitles


func _ready() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + what)
	if not cond:
		_fails += 1


func _run() -> void:
	_marks()
	_layouts()
	_box_places()
	_choreography()
	var stage := SubViewport.new()
	stage.size = Vector2i(640, 360)
	stage.own_world_3d = true
	add_child(stage)
	Director.detach()
	medium = Medium.make("table") as TableMedium
	medium.mount(stage)
	Director.attach(stage, medium)
	Director.hold(true)
	subs = preload("res://src/subtitles.gd").new()
	add_child(subs)
	medium.bind_captions(subs)
	_deck_show()
	_deck_reversals()
	_table_edge()
	_placement_drift()
	_box_show()
	_file_search()
	_shoebox_show()
	_search_and_linger()
	_laid_over_box()
	_loose_box()
	_open_loose_box()
	_piles()
	_waterfall_shown()
	_printings()
	_front_details()
	_bursts()
	Director.hold(false)
	Director.detach()
	print("table_staging_check: %s (%d failure%s)" % ["ALL OK" if _fails == 0 else "FAILED", _fails, "" if _fails == 1 else "s"])
	get_tree().quit(1 if _fails > 0 else 0)


func _marks() -> void:
	print("-- the marks")
	var fan := CardReading.parse("<!-- table: shuffle -->\n\nHi.\n\n<!-- table: fan 3-5 -->\n\nThree.\n")
	var a: Dictionary = (fan["actions"] as Array)[1]
	_ok(String(a["kind"]) == "fan" and int(a["card"]) == 3 and int(a["last"]) == 5, "`fan 3-5` is a run of three (%s)" % str(a))
	_ok(CardReading.compose(fan["passages"]).contains("<!-- table: fan 3-5 -->"), "and is written back as one")
	var boxed := CardReading.parse("<!-- table: open -->\n\nHi.\n\n<!-- table: draw 1 -->\n\nOne.\n")
	var decked := CardReading.parse("<!-- table: shuffle -->\n\nHi.\n\n<!-- table: draw 1 -->\n\nOne.\n")
	_ok(String(boxed["source"]) == "box" and is_equal_approx(float((boxed["actions"] as Array)[1]["dur"]), TableActions.DRAW),
		"a box's first card waits for no push (%.2f s)" % float((boxed["actions"] as Array)[1]["dur"]))
	_ok(is_equal_approx(float((decked["actions"] as Array)[1]["dur"]), TableActions.DRAW + TableActions.PUSH),
		"control: a deck's first card waits for the push (%.2f s)" % float((decked["actions"] as Array)[1]["dur"]))
	_ok(TableActions.rest_of("fan", false, false, true, 4) > TableActions.rest_of("fan", false, false, true, 2),
		"a waterfall of four rests longer than one of two")


## WHERE THE BOX STANDS (2026-10-12, the user: "some ability for random placement might be good"; a card
## coming up out of a box at the side of the table rose half outside the picture): a box smaller than
## the room kept for it stands in a different place every episode, always inside that room - which
## the spread keeps off - and an open box in the inner half of it. Two-sided: a box as big as its
## room has nowhere to go, and stands where it always did.
func _box_places() -> void:
	print("-- where the box stands")
	var most := Vector2(CardTable.BOX_MAX.x, CardTable.BOX_MAX.z)
	var size := Vector2(0.096, 0.17)
	var inside := true
	var inner := true
	var xs: Array = []
	var zs: Array = []
	var fixed := true
	for seed in 60:
		var lay := CardTable.layout_of(seed)
		var mid := TablePositions.box_at(lay["deck"])
		var keep := TablePositions.deck_keep(lay["deck"], most)
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([seed, "box place"])
		var at := TablePositions.box_stand(mid, size, most, -signf(mid.x), rng)
		inside = inside and keep.encloses(Rect2(Vector2(at.x, at.z) - size * 0.5, size))
		inner = inner and absf(at.x) < absf(mid.x) - 0.01
		xs.append(absf(mid.x) - absf(at.x))
		zs.append(at.z - mid.z)
		fixed = fixed and TablePositions.box_stand(mid, most, most, -signf(mid.x), rng).is_equal_approx(mid)
	xs.sort()
	zs.sort()
	_ok(inside, "a box stands inside the room the spread keeps off")
	_ok(inner and float(xs[-1]) - float(xs[0]) > 0.008 and float(zs[-1]) - float(zs[0]) > 0.02,
		"an open box stands toward the spread, in a different place each episode (%.0f to %.0f mm in, %.0f mm of depth)" %
		[float(xs[0]) * 1000.0, float(xs[-1]) * 1000.0, (float(zs[-1]) - float(zs[0])) * 1000.0])
	_ok(fixed, "control: a box as big as its room stands where it always did")


func _cards(positions: Array) -> Array:
	var out: Array = []
	for i in positions.size():
		out.append({"key": "c%d" % i, "name": "Card %d" % (i + 1), "numeral": "", "reversed": false,
			"jumper": bool((positions[i] as Dictionary).get("jumper", false)),
			"position": positions[i], "booklet": {"keywords": ["Shortstop", "Bats left"], "upright": "A kid with a glove."}, "art": ""})
	return out


func _layouts() -> void:
	print("-- the layouts")
	var kinds := {
		"stack": [{}, {"on": true}, {"on": true}, {}],
		"waterfall": [{}, {"comes": "swept"}, {"comes": "swept"}, {"comes": "swept"}, {}],
		"sideways": [{"lies": "sideways"}, {}, {"lies": "sideways"}],
	}
	for name in kinds:
		var bad := 0
		var shaped := 0
		for s in range(1, SEEDS + 1):
			var rng := RandomNumberGenerator.new()
			rng.seed = hash([s, "staging-check"])
			var cards := _cards(kinds[name])
			for box in [Vector2.ZERO, Vector2(CardTable.BOX_MAX.x, CardTable.BOX_MAX.z)]:
				var slots := TablePositions.staged(cards, rng, CardTable.layout_of(s), box)
				if slots.size() != cards.size() or not TablePositions.troubles(slots, s, {}, box).is_empty():
					bad += 1
					continue
				match name:
					"stack":
						var a: Vector3 = slots[0]["pos"]
						var b: Vector3 = slots[1]["pos"]
						if absf((a.z - b.z) - TablePositions.STACK_STEP) < 0.006 and b.y > a.y and TablePositions.overlaps(slots[0], slots[1]):
							shaped += 1
					"waterfall":
						if TablePositions.overlaps(slots[1], slots[2]) and TablePositions.overlaps(slots[2], slots[3]) \
								and not TablePositions.overlaps(slots[0], slots[1]):
							shaped += 1
					"sideways":
						if absf(wrapf(float(slots[0]["yaw"]) - TablePositions.SIDEWAYS, -PI, PI)) < 0.1 \
								and absf(wrapf(float(slots[1]["yaw"]), -PI, PI)) < 0.1:
							shaped += 1
		_ok(bad == 0, "every %s lies on the cloth, in the frame, clear of the deck and of the box (%d did not)" % [name, bad])
		_ok(shaped == SEEDS * 2, "and lies as a %s (%d of %d)" % [name, shaped, SEEDS * 2])
	# THE CONTROL: a spread asking for none of it is the preset, draw for draw
	var same := true
	for s in range(1, SEEDS + 1):
		var r1 := RandomNumberGenerator.new()
		r1.seed = s
		var r2 := RandomNumberGenerator.new()
		r2.seed = s
		var a := TablePositions.staged(_cards([{}, {}, {}, {}, {}]), r1, CardTable.layout_of(s))
		var b := TablePositions.seeded(5, r2, CardTable.layout_of(s))
		for i in 5:
			same = same and (a[i]["pos"] as Vector3).is_equal_approx(b[i]["pos"]) and is_equal_approx(float(a[i]["yaw"]), float(b[i]["yaw"]))
	_ok(same, "control: a plain spread is the seeded preset itself")


func _choreography() -> void:
	print("-- the choreography")
	var plan := {"spread": {"positions": [{"name": "a"}, {"name": "b", "comes": "dealt"}, {"name": "c", "comes": "swept"},
		{"name": "d", "comes": "swept"}, {"name": "e", "then": ["tap 2"]}]}}
	var cards := _cards([{}, {}, {}, {}, {}])
	var got := PackedStringArray()
	for m in CardProducer.choreography(plan, cards):
		got.append("%s %d-%d" % [m["kind"], int(m.get("card", 0)), int(m.get("last", m.get("card", 0)))])
	var want := PackedStringArray(["shuffle 0-0", "draw 1-1", "deal 2-2", "fan 3-4", "show 3-3", "show 4-4", "draw 5-5", "tap 2-2", "spread 0-0"])
	_ok(got == want, "the positions become the verbs in order (%s)" % ", ".join(got))
	plan["staging"] = {"source": "box"}
	_ok(String((CardProducer.choreography(plan, cards)[0] as Dictionary)["kind"]) == "open", "a box's reading opens the box")
	plan["spread"] = {"positions": [{"comment": "none", "linger": true, "destination": "box"},
		{"comes": "searched", "destination": "stack"}]}
	var search := CardProducer.choreography(plan, _cards([{}, {}]))
	_ok(search.map(func(m: Dictionary) -> String: return String(m["kind"])) ==
		["open", "draw", "linger", "rummage", "draw", "spread"],
		"a wordless hold precedes the search and its eventual reveal")


func _search_and_linger() -> void:
	print("-- a wordless hold and a search")
	var pos := [{"comment": "none", "linger": true, "destination": "box"},
		{"comes": "searched", "destination": "stack"}, {"destination": "stack", "on": true}]
	_load(48, pos, {"look": {"candles": 0, "card_size": "trading"},
		"staging": {"source": "box", "text": "front", "box_style": "shoebox", "contents": "loose"}})
	var tm := medium._times()
	var holds := medium._sched.filter(func(e: Dictionary) -> bool: return String(e["a"]["kind"]) == "linger")
	_ok(holds.size() == 1, "the silent hold is scheduled once")
	if holds.is_empty():
		return
	var hold: Dictionary = holds[0]
	var during := float(hold["t0"]) + TableActions.LINGER * float(hold["s"]) * 0.8
	_posed(during)
	_ok((medium._cards[0] as MeshInstance3D).visible and
		bool(medium._card_pose(0, during, (tm["events"] as Array)[0], {})["up"]),
		"the ignored card remains revealed through the long hold")
	var searches: Array = tm["rummages"]
	_ok(searches.size() == 1, "one search follows the held card")
	if searches.is_empty():
		return
	var e: Dictionary = searches[0]
	var start := float(e["t0"]) + float(e["off"]) * float(e["s"])
	var span := TableActions.RUMMAGE * float(e["s"])
	# THE CARD LOOKED AT LIES ON ITS PILE BEFORE THE LOOK (2026-10-12: a card that was not on the pile a
	# moment before appeared on it as the look began): one of the box's own, on a pile of its own
	var seats: Array = medium._box.get("search", [])
	_posed(start - 0.5)
	var rests := not medium._searched.is_empty() and medium._searched.size() == seats.size() and medium._looking == null
	var own := true
	for i in medium._searched.size():
		var kept := medium._searched[i] as MeshInstance3D
		var seat: Transform3D = seats[i]
		rests = rests and kept.visible and kept.transform.origin.distance_to(seat.origin) < 0.0005 and kept.transform.basis.y.y > 0.9
		for f in medium._file:
			var mm: MultiMesh = (f as MultiMeshInstance3D).multimesh
			for j in mm.instance_count:
				var d := mm.get_instance_transform(j).origin - seat.origin
				# nothing in its place and nothing on it
				if Vector2(d.x, d.z).length() < NEAR and d.y > -0.0001:
					own = false
		for k in (medium._box["at_k"] as Array).size():
			var d := ((medium._box["at_k"] as Array)[k] as Transform3D).origin - seat.origin
			own = own and Vector2(d.x, d.z).length() > NEAR
		var back: Vector3 = medium._box["return_at"]
		own = own and Vector2(back.x - seat.origin.x, back.z - seat.origin.z).length() > NEAR
	_ok(rests, "the cards a search looks at lie in the box before it, on top of piles (%d)" % medium._searched.size())
	_ok(own, "each on a pile nothing is drawn from or put back on, the top of it")
	for i in 3:
		_posed(start + span * (float(i) + 0.001) / 3.0)
		var card := medium._looking
		var from := card.transform if card != null else Transform3D.IDENTITY
		var at_rest := false
		for seat in seats:
			at_rest = at_rest or from.origin.distance_to((seat as Transform3D).origin) < 0.0005
		_posed(start + span * (float(i) + 0.5) / 3.0)
		_ok(card != null and medium._looking == card and card.visible and at_rest and from.basis.y.y > 0.9
			and (medium._box["inner"] as AABB).grow(0.002).has_point(from.origin)
			and card.position.y - from.origin.y > 0.03 and card.transform.basis.y.z > 0.5 and _in_picture(card.transform),
			"searched card %d is lifted off its pile, from where it lay, and turned up in the picture (%.0f mm)" % [i + 1, (card.position.y - from.origin.y) * 1000.0])
	# control: the same card a hand's breadth higher is out of the picture, and the check says so
	_posed(start + span * 0.5 / 3.0)
	_ok(medium._looking != null and not _in_picture(medium._looking.transform.translated(Vector3(0.0, 0.2, 0.0))),
		"control: lifted far higher, its far edge is over the top of the picture")
	_posed(start + span + 0.02)
	_ok(medium._looking == null and _at(1, "arrive", "draw") >= start + span - 0.01,
		"the search ends before the selected card is drawn (%.2f / %.2f)" % [_at(1, "arrive", "draw"), start + span])
	# control: a box with no pile to spare is given a card for the length of the look only
	var kept_cards: Array = medium._searched
	medium._searched = []
	_posed(start + span * 0.5 / 3.0)
	var lent := medium._looking == medium._rummage_card and medium._rummage_card.visible
	_posed(start - 0.5)
	_ok(lent and not medium._rummage_card.visible, "control: with no card of its own, the look's card is there only for the look")
	medium._searched = kept_cards


## Load [param positions] as an episode with [param staging], timed as a voice would read it.
func _load(seed: int, positions: Array, plan: Dictionary, series: Array = [],
		say := "Some words said about it, at an easy pace, for a while.") -> void:
	var cards := _cards(positions)
	for i in mini(series.size(), cards.size()):
		if not String(series[i]).is_empty():
			(cards[i] as Dictionary)["series"] = series[i]
	plan["spread"] = {"positions": positions}
	var passages: Array = []
	for m in CardProducer.choreography(plan, cards):
		passages.append({"kind": m["kind"], "card": m.get("card", 0), "last": m.get("last", m.get("card", 0)),
			"text": say if not String(m.get("say", "")).is_empty() else ""})
	var script := CardReading.compose(passages)
	var doc := {"show": "staging-check", "seed": seed, "dir": "", "plan": plan, "cards": cards}
	subs.words = load("res://tests/table_look_probe.gd").timeline(CardReading.parse(script), 0.36, Director.intro_hold)
	subs.document = {"source": script, "title": "Staging Check", "table": doc}
	medium._ensure_doc()
	medium._follow.extend(subs.words)
	medium._sched = medium._follow.place(medium._parse["actions"], maxf(Director.intro_hold, 0.6), TableMedium.LEAD, TableMedium.TAIL)


## When card [param k]'s event of kind [param kind] (`how` too, when given) begins.
func _at(k: int, kind: String, how := "") -> float:
	for e in (medium._times()["events"] as Array)[k]:
		if String((e as Dictionary)["k"]) == kind and (how.is_empty() or String((e as Dictionary).get("how", "")) == how):
			return float((e as Dictionary)["t0"])
	return INF


func _posed(t: float) -> void:
	medium._now = t
	medium._pose(t)


## Where [param xf] lands in the picture (0..1 across).
func _across(xf: Transform3D) -> float:
	var p: Variant = CardTable.project(medium._cam_base, medium._cam.fov, xf.origin)
	return (p as Vector2).x if p != null else -1.0


func _deck_show() -> void:
	print("-- a deck show")
	_load(11, [{}, {"on": true}, {"comes": "dealt", "lies": "sideways"}, {"then": ["tap 1"]}],
		{"look": {"candles": 0}, "staging": {"source": "deck", "text": "booklet"}})
	var end := float(medium._times()["spread"])
	_ok(end < INF, "the reading is placed through to its close")
	_posed(end + 5.0)
	var c0: Transform3D = (medium._cards[0] as MeshInstance3D).transform
	var c1: Transform3D = (medium._cards[1] as MeshInstance3D).transform
	_ok(c1.origin.z < c0.origin.z - 0.015 and c1.origin.y > c0.origin.y, "a stacked card lies behind and over the card before it")
	# the tap: card 1 a quarter turn round from where it was laid
	var laid := medium._slot_xf(0)
	_ok(absf(absf(c0.basis.x.normalized().dot(laid.basis.x.normalized()))) < 0.1, "card 1 was tapped: a quarter turn from where it lay")
	var tap := _at(0, "turn", "tap")
	_posed(tap - 0.05)
	_ok(absf((medium._cards[0] as MeshInstance3D).transform.basis.x.normalized().dot(laid.basis.x.normalized())) > 0.95,
		"control: before the tap it lay as it was laid")
	# the dealt card is never held up: by the middle of its passage it lies in its place
	var deal := _at(2, "arrive", "deal")
	_posed(deal + 5.0)
	_ok((medium._cards[2] as MeshInstance3D).transform.origin.distance_to(medium._slot_xf(2).origin) < 0.002 and not medium._page.visible,
		"a dealt card lies in its place while it is read, no page open")
	# a drawn card is held up left of the middle, its page open
	var draw := _at(3, "arrive", "draw")
	_posed(draw + 5.0)
	var held: Transform3D = (medium._cards[3] as MeshInstance3D).transform
	_ok(_across(held) < 0.42 and medium._page.visible, "a drawn card is held up left of the middle, its page open (%.2f across)" % _across(held))


func _deck_reversals() -> void:
	print("-- reversals on the deck")
	_load(12, [{}, {}, {}], {"look": {"candles": 0}, "staging": {"source": "deck", "text": "booklet"}})
	var cards: Array = medium._pay["cards"]
	(cards[1] as Dictionary)["reversed"] = true
	var draws: Array = medium._times()["draw"]
	var first := float((draws[0] as Array)[0])
	var second := float((draws[1] as Array)[0])
	var top := medium._deck[TableMedium.DECK_N - 1] as MeshInstance3D
	_posed(first - 0.01)
	_ok(top.transform.basis.x.dot(medium._rest_xf(TableMedium.DECK_N - 1).basis.x) > 0.99,
		"the first upright card's back is upright before its draw")
	_posed(first + 0.01)
	_ok(top.transform.basis.x.dot(medium._rest_xf(TableMedium.DECK_N - 1).basis.x) < -0.99,
		"the next reversed card is already reversed under the first card")
	_posed(second - 0.01)
	_ok(top.transform.basis.x.dot(medium._deck_top_xf(1).basis.x) > 0.99,
		"the reversed back stays reversed while waiting on the deck")
	var waiting := top.transform.basis.x
	_posed(second + 0.01)
	_ok((medium._cards[1] as MeshInstance3D).transform.basis.x.dot(waiting) > 0.99,
		"the reversed draw starts with the back's waiting orientation")
	_ok(top.transform.basis.x.dot(medium._rest_xf(TableMedium.DECK_N - 1).basis.x) > 0.99,
		"the following upright card is ready under the reversed card")


func _table_edge() -> void:
	print("-- a thing at the edge of a wide table")
	_load(585418, [{}, {}, {}], {"look": {"candles": 0}, "staging": {"source": "deck", "text": "booklet"}})
	medium._top = Tables.DEFAULT_TOP.duplicate()
	medium._top["size"] = [190.0, 116.0]
	medium._top_o = Tables.top_outline(medium._top)
	var spec := Props.sanitize({"things": [{"name": "edge box", "place": "left", "parts": [
		{"shape": "box", "size": [30, 4, 8]}]}]}, [])
	var thing: Dictionary = (spec["things"] as Array)[0]
	var built := Props.build(thing, spec["materials"], 12)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	# The middle is occupied; on this top there is still clear room outside the old cloth.
	var spot := medium._stand(thing, built, "#edge", {}, [Rect2(-0.31, -1.0, 0.62, 2.0)], rng)
	var bb: Rect2 = (medium._things[-1] as Dictionary)["bb"] if not spot.is_empty() else Rect2()
	var frame: Rect2 = (medium._things[-1] as Dictionary)["rect"] if not spot.is_empty() else Rect2()
	_ok(not spot.is_empty() and maxf(absf(bb.position.x), absf(bb.end.x)) > TableMedium.CLOTH.x * 0.5
		and (frame.position.x < 0.0 or frame.end.x > 1.0),
		"a prop can stand on the table's side margin while partly outside the picture")
	medium._things.clear()
	var flame_spec := Props.sanitize({"things": [{"name": "edge candle", "place": "left", "parts": [
		{"shape": "lathe", "profile": [[0, 0], [15, 0], [15, 4], [0, 4]], "wick": true}]}]}, [])
	var candle: Dictionary = (flame_spec["things"] as Array)[0]
	var candle_built := Props.build(candle, flame_spec["materials"], 13)
	var candle_spot := medium._stand(candle, candle_built, "#flame", {}, [Rect2(-0.31, -1.0, 0.62, 2.0)], rng)
	var candle_frame: Rect2 = (medium._things[-1] as Dictionary)["rect"] if not candle_spot.is_empty() else Rect2()
	_ok(not candle_spot.is_empty() and (candle_frame.position.x < 0.0 or candle_frame.end.x > 1.0),
		"a lit prop may use the side margin when its flame remains in view")


func _box_show() -> void:
	print("-- a box show")
	var deck: Array = []
	for i in 12:
		deck.append({"key": "c%d" % i, "name": "Card %d" % i})
	_load(23, [{}, {"comes": "swept"}, {"comes": "swept"}],
		{"look": {"candles": 0}, "staging": {"source": "box", "text": "back"}, "deck": deck})
	_ok(medium._cards_from == "box" and not medium._box.is_empty(), "the cards come from a box, and it stands")
	if medium._box.is_empty():
		return
	var filed := 0
	for f in medium._file:
		filed += ((f as MultiMeshInstance3D).multimesh as MultiMesh).instance_count
	# AN OPEN BOX IS FILED OUT, as a shoebox is (feedback 0020: "barely any cards in the box"): the planned
	# cards at least, standing through at least OPEN_FILE_SHARE of its depth
	var depth: float = (medium._box["inner"] as AABB).size.z
	# (the places a search looks are cards of the file too, each out of the fill)
	var kept := filed + medium._cards.size() + (medium._box.get("search", []) as Array).size()
	_ok(kept >= deck.size() and float(kept) * TableMedium.FILE_PITCH >= depth * TableMedium.OPEN_FILE_SHARE - TableMedium.FILE_PITCH,
		"the box shows its twelve planned cards and is filed out to half its depth (%d cards, %.0f mm of %.0f)" % [kept, float(kept) * TableMedium.FILE_PITCH * 1000.0, depth * 1000.0])
	# THE TEXT IS ON THE BACK: the cards nobody drew are printed as the drawn ones are
	var blanks: Array = ((medium._backs[""] as Dictionary).get("blank", []) as Array).map(func(b: Dictionary) -> Material: return b["mat"])
	var printed := not blanks.is_empty()
	for f in medium._file:
		var shown := ((f as MultiMeshInstance3D).multimesh as MultiMesh).mesh.surface_get_material(1)
		printed = printed and blanks.has(shown) and shown != (medium._backs[""] as Dictionary)["mat"]
	# ...and they are the deck's own cards, the ones the draw left in the box - never a drawn one
	var left := {}
	for b in (medium._backs[""] as Dictionary).get("blank", []):
		var canvas: CardFaces.Face = (b as Dictionary)["canvas"]
		printed = printed and canvas.printed and canvas.back and not canvas.anonymous
		left[String(canvas.card.get("key", ""))] = String(canvas.card.get("name", ""))
	_ok(left.size() == TableMedium.WRITTEN and not left.has("c0") and not left.has("c1") and not left.has("c2")
		and left.values().all(func(n: String) -> bool: return n.begins_with("Card ")),
		"they are printed as the deck's own cards the draw left in (%s)" % ", ".join(left.values()))
	_ok(printed and (medium._cards[0] as MeshInstance3D).get_surface_override_material(1) == (medium._printed[0] as Dictionary)["mat"],
		"with the text on the back, the cards nobody drew have printed backs like the drawn ones, not the shared artwork")
	_ok(not medium._searched.is_empty() and medium._searched.all(func(c: MeshInstance3D) -> bool: return blanks.has(c.get_surface_override_material(1))),
		"the cards a search looks at have printed backs too")
	var inner: AABB = medium._box["inner"]
	_posed(0.5)
	var waiting: Transform3D = (medium._cards[0] as MeshInstance3D).transform
	_ok((medium._cards[0] as MeshInstance3D).visible and inner.grow(0.01).has_point(waiting.origin)
		and absf(waiting.basis.z.normalized().y) > 0.9, "card 1 waits standing in the file, in the box")
	_ok(_faces_camera(waiting) < -0.5, "its back to the camera, as every card in the file stands (%.2f)" % _faces_camera(waiting))
	_ok(not (medium._deck[0] as MeshInstance3D).visible, "no deck lies on the table")
	var draw := _at(0, "arrive", "draw")
	var s := float((medium._times()["events"] as Array)[0][0]["s"])
	var off := float((medium._times()["events"] as Array)[0][0]["off"])
	_posed(draw + (off + TableMedium.FLIP_END - 0.05) * s)
	var rising: Transform3D = (medium._cards[0] as MeshInstance3D).transform
	_ok(rising.origin.y - TablePositions.CARD.y * 0.5 > (medium._box["world"] as AABB).end.y, "pulled straight up, it clears the rim")
	_ok(_faces_camera(rising) < -0.5, "it comes up showing its back, as it stood")
	_posed(draw + 3.6)
	var held: Transform3D = (medium._cards[0] as MeshInstance3D).transform
	_posed(draw + (off + TableMedium.RISE_END + 0.2) * s)
	var shown := _faces_camera((medium._cards[0] as MeshInstance3D).transform)
	_ok(shown > 0.5, "and is turned round to be seen as it comes up to be shown (%.2f)" % shown)
	var up_at := draw + (off + TableMedium.RISE_END) * s
	var looks: Array = medium._looks(0, up_at, INF)
	_ok(not looks.is_empty(), "it is turned over to show its back")
	if not looks.is_empty():
		var l: Dictionary = looks[0]
		var mid := float(l["at"]) + float(l["look"]["turn"]) + float(l["look"]["hold"]) * 0.5
		_ok(absf(absf(medium._turn_of(0, mid, up_at, INF)) - PI) < 0.01, "and held showing it, long enough to read (%.1f s)" % float(l["look"]["hold"]))
	var fan := _at(1, "arrive", "fan")
	_posed(fan + 6.0)
	var a := {"pos": medium._slot_xf(1).origin, "yaw": medium._slots[1]["yaw"]}
	var b := {"pos": medium._slot_xf(2).origin, "yaw": medium._slots[2]["yaw"]}
	_ok(TablePositions.overlaps(a, b), "the waterfall's cards lie overlapping")


## Whether the top of [param xf]'s card (its far edge, lying) is under the picture's top edge.
func _in_picture(xf: Transform3D) -> bool:
	var size := CardTable.card_size(medium._look)
	for x in [-0.5, 0.5]:
		var p: Variant = CardTable.project(medium._cam_base, medium._cam.fov, xf * Vector3(size.x * x, 0.0, -size.y * 0.5))
		if p == null or (p as Vector2).y < 0.0:
			return false
	return true


## How squarely [param xf]'s card shows the camera its FACE (1) or its back (-1).
func _faces_camera(xf: Transform3D) -> float:
	return -xf.basis.y.normalized().dot((medium._cam_base.origin - xf.origin).normalized())


## A SEARCH OF A FILE (the user, 2026-10-12: "a card was lifted from the deck FLAT, and THREE times in a
## row"): each look draws one of the file's own cards up out of its place on edge, back to the camera,
## and lets it back down - three different cards from three different places.
func _file_search() -> void:
	print("-- a search of cards on edge")
	var deck: Array = []
	for i in 30:
		deck.append({"key": "c%d" % i, "name": "Card %d" % i, "group": "Group", "meaning": "What happened that night."})
	_load(31, [{}, {"comes": "searched"}],
		{"look": {"candles": 0, "card_size": "trading"}, "staging": {"source": "box", "text": "back"}, "deck": deck})
	var searches: Array = medium._times()["rummages"]
	var seats: Array = medium._box.get("search", [])
	_ok(searches.size() == 1 and seats.size() >= 3 and bool(medium._box.get("upright", false)),
		"a search of a box of cards on edge has places to look (%d)" % seats.size())
	if searches.is_empty() or seats.size() < 3:
		return
	var e: Dictionary = searches[0]
	var start := float(e["t0"]) + float(e["off"]) * float(e["s"])
	var span := TableActions.RUMMAGE * float(e["s"])
	var inner: AABB = medium._box["inner"]
	var v := CardTable.card_size(medium._look).y
	var seen := {}
	var places := {}
	var good := true
	var worst := ""
	for i in 3:
		# as it appears: in its own place in the file, among the cards
		_posed(start + span * (float(i) + 0.001) / 3.0)
		var card := medium._looking
		if card == null:
			good = false
			worst = "look %d looks at nothing" % (i + 1)
			continue
		var down := card.transform
		var at_seat := false
		for seat in seats:
			at_seat = at_seat or down.origin.distance_to((seat as Transform3D).origin) < 0.001
		if not (card.visible and at_seat and inner.grow(0.002).has_point(Vector3(down.origin.x, inner.get_center().y, down.origin.z))):
			good = false
			worst = "look %d does not start in a place in the file" % (i + 1)
		places[down.origin] = true
		# at its highest: still on edge, back to the camera, most of the way out
		_posed(start + span * (float(i) + 0.5) / 3.0)
		var up := card.transform
		if not (card.visible and absf(up.basis.y.normalized().y) < 0.5 and _faces_camera(up) < -0.3
				and up.origin.y - down.origin.y > v * TableMedium.SEARCH_RISE * 0.9 and up.origin.y - down.origin.y < v):
			good = false
			worst = "look %d: normal up %.2f, facing %.2f, rise %.0f mm" % [i + 1, up.basis.y.normalized().y, _faces_camera(up), (up.origin.y - down.origin.y) * 1000.0]
		seen[card.get_surface_override_material(1)] = true
	_ok(good, "each look draws a card up out of its place on edge, back to the camera, part of the way%s" % ("" if good else " - " + worst))
	_ok(seen.size() == 3 and places.size() == 3, "three different cards from three different places (%d, %d)" % [seen.size(), places.size()])
	# control: a place where a card LIES is lifted flat - the old look, which a file never gets
	var kept: Array = seats.duplicate()
	var kept_cards: Array = medium._searched
	medium._searched = []
	medium._box["search"] = [Transform3D(Basis.IDENTITY, inner.get_center())]
	_posed(start + span * 0.5 / 3.0)
	_ok(medium._looking != null and absf(medium._looking.transform.basis.y.normalized().y) > 0.5, "control: a lying card's place is looked at lying, not on edge")
	medium._box["search"] = kept
	medium._searched = kept_cards


func _shoebox_show() -> void:
	print("-- a lidded shoebox with small cards")
	var deck: Array = []
	for i in 12:
		deck.append({"key": "s%d" % i, "name": "Small card %d" % i})
	var pos := [{"destination": "stack"}, {"destination": "stack", "on": true},
		{"destination": "box"}]
	_load(45, pos, {"look": {"candles": 0, "card_size": "trading"},
		"staging": {"source": "box", "text": "front", "box_style": "shoebox", "contents": "piles",
			"keepsakes": ["coin", "ticket"]},
		"deck": deck})
	_ok(medium._box.has("lid") and medium._file.size() > 0, "the shoebox has a lid and visible contents")
	_ok(medium._box_objects.size() == 2, "two small keepsakes rest among the cards")
	if not medium._box.has("lid"):
		return
	var mesh: ArrayMesh = (medium._cards[0] as MeshInstance3D).mesh
	var extent := mesh.get_aabb().size
	_ok(absf(extent.x - 0.0635) < 0.001 and absf(extent.z - 0.0889) < 0.001,
		"trading cards are 63.5 by 88.9 mm, not the large card slab")
	_ok(CardFaces.face_px(medium._look).y < CardFaces.FACE_PX.y,
		"the printed face matches the trading card's aspect ratio")
	var first: Transform3D = medium._box["at_k"][0]
	_ok(absf(first.basis.z.y) < 0.1, "the cards lie flat in their piles")
	var start := float(medium._times()["opening"])
	_posed(start + 0.1)
	_ok((medium._box_objects[0] as Node3D).position.y < (medium._box["world"] as AABB).end.y and
		(medium._box["lid"] as Node3D).position.x == (medium._box["lid_rest"] as Vector3).x,
		"the keepsakes wait inside the closed box")
	var before: Vector3 = (medium._box["node"] as Node3D).position
	var before_basis: Basis = (medium._box["node"] as Node3D).basis
	var lid_before: Vector3 = (medium._box["lid"] as Node3D).position
	var shade_before := (medium._box["shadow"] as Decal).position
	var file_before := (medium._file[0] as Node3D).position
	_posed(start + 2.9)
	var center: Vector3 = (medium._box["node"] as Node3D).position
	var center_basis: Basis = (medium._box["node"] as Node3D).basis
	var shade_center := (medium._box["shadow"] as Decal).position
	var file_center := (medium._file[0] as Node3D).position
	_posed(start + 4.2)
	var lid_raised: Vector3 = (medium._box["node"] as Node3D).transform * (medium._box["lid"] as Node3D).position
	_posed(start + 6.0)
	_ok((medium._box_objects[0] as Node3D).visible, "the keepsakes appear when the box is open")
	var after: Vector3 = (medium._box["node"] as Node3D).position
	var after_basis: Basis = (medium._box["node"] as Node3D).basis
	var lid_after: Vector3 = (medium._box["lid"] as Node3D).position
	_ok(absf(before.x) > 0.2 and absf(center.x) < 0.03 and center.distance_to(after) < 0.001 and
		absf(before_basis.z.z) > absf(before_basis.z.x) and
		absf(center_basis.z.x) > absf(center_basis.z.z) and center_basis.is_equal_approx(after_basis),
		"the shoebox arrives vertical, turns horizontal, and stays centered after opening")
	_ok(shade_before.distance_to(shade_center) > 0.2 and file_before.distance_to(file_center) > 0.2,
		"the soft shade and the cards travel with the shoebox")
	_ok(lid_raised.y > (medium._box["world"] as AABB).end.y + 0.03,
		"the lid clears the rim before sliding aside")
	_ok(lid_after.distance_to(lid_before) > 0.2 and lid_after.y < lid_before.y,
		"the lid lifts off and settles beside the centered box")
	var lid_world := (medium._box["lid"] as Node3D).global_position
	var box_bounds: AABB = medium._box["world"]
	_ok(absf(lid_world.x - box_bounds.get_center().x) > box_bounds.size.x + 0.01,
		"the lid clears the side of the box")
	var lid_layers := true
	for panel in (medium._box["lid"] as Node3D).get_children():
		lid_layers = lid_layers and ((panel as MeshInstance3D).layers & 1) == 0
	_ok(lid_layers, "the tabletop's contact shade cannot project onto the lid")
	_ok((medium._cards[0] as MeshInstance3D).cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
		"a card pulled near the box wall cannot cast a jagged shadow across it")
	_ok((medium._file[0] as MultiMeshInstance3D).cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
		"the shoebox inventory cannot cast a hard shadow into the lid")
	var keep := TablePositions.deck_keep(medium._deck_base, medium._box_keep(), medium._box_center())
	var clear := true
	for s in medium._slots:
		var slot: Dictionary = s
		if CardTable.footprint(slot["pos"], float(slot["yaw"]), CardTable.card_size(medium._look)).intersects(keep):
			clear = false
	_ok(clear, "laid cards keep clear of the centered shoebox")
	var front := true
	for slot in medium._slots:
		front = front and (slot["pos"] as Vector3).z > (medium._box["world"] as AABB).end.z + 0.02
	_ok(front, "shoebox cards land in front of its near wall")
	_ok((medium._slots[0]["pos"] as Vector3).distance_to(medium._slots[1]["pos"]) < 0.015,
		"shown cards form a small stack")
	var returned := medium._slot_xf(2).origin
	_ok((medium._box["inner"] as AABB).grow(0.01).has_point(returned) and not _buried(returned),
		"a returned card lands on top of a pile inside the box")
	var events: Array = medium._times()["events"]
	var once := true
	for card_events in events:
		var lays := 0
		for event in card_events:
			lays += 1 if String(event["k"]) == "lay" else 0
		once = once and lays == 1
	_ok(once, "each shown card has one return movement")


func _placement_drift() -> void:
	print("-- the deck's resting places")
	_ok(medium._lay_jit.size() == medium._cards.size() and
		(medium._lay_jit[0] as Vector3).distance_to(medium._lay_jit[1]) > 0.0001,
		"cards laid in a row have different small, repeatable hand offsets")
	medium._move_at(45.0)
	var rests: Array = []
	for m in medium._moves:
		var d: Dictionary = m
		if float(d["t0"]) + float(d["dur"]) < 45.0:
			rests.append(medium._shuffle_wander(float(d["t0"]) + float(d["dur"]) + 0.01))
	var changed := 0
	for i in range(1, rests.size()):
		if (rests[i] as Vector3).distance_to(rests[i - 1]) > 0.001:
			changed += 1
	_ok(changed >= 2, "successive shuffles and cuts settle in different places (%d changed)" % changed)
	if not rests.is_empty():
		var at: Vector3 = rests[-1]
		_ok(at.is_equal_approx(medium._shuffle_wander(float((medium._moves[rests.size() - 1] as Dictionary)["t0"]) +
			float((medium._moves[rests.size() - 1] as Dictionary)["dur"]) + 0.01)),
			"a scrub returns to the same resting place")


func _loose_box() -> void:
	print("-- loose cards inside a box")
	var deck: Array = []
	for i in 12:
		deck.append({"key": "l%d" % i, "name": "Loose card %d" % i})
	_load(46, [{}, {}, {}], {"look": {"candles": 0, "card_size": "trading"},
		"staging": {"source": "box", "box_style": "shoebox", "contents": "loose"}, "deck": deck})
	var poses: Array = (_box_poses())
	var xs: Array = []
	var angles: Array = []
	for xf in poses:
		var t: Transform3D = xf
		xs.append(t.origin.x)
		angles.append(atan2(t.basis.x.z, t.basis.x.x))
	xs.sort()
	angles.sort()
	var spread := float(xs[-1]) - float(xs[0])
	var turn := float(angles[-1]) - float(angles[0])
	_ok(poses.size() > 200 and poses.size() <= CardTable.SHOEBOX_FILL and spread > 0.09 and turn > 0.1,
		"loose cards occupy varied spots and angles, the box well filled (%d cards, %.1f mm, %.2f rad)" %
		[poses.size(), spread * 1000.0, turn])
	var source: Array = medium._box["at_k"]
	var return_at: Vector3 = medium._box["return_at"]
	var on_top := true
	var in_order := true
	var apart := true
	for k in source.size():
		var at: Transform3D = source[k]
		on_top = on_top and not _buried(at.origin, source)
		apart = apart and Vector2(at.origin.x - return_at.x, at.origin.z - return_at.z).length() > NEAR
		for j in k:
			var before: Transform3D = source[j]
			if Vector2(at.origin.x - before.origin.x, at.origin.z - before.origin.z).length() < NEAR:
				in_order = in_order and before.origin.y > at.origin.y
	_ok(on_top and in_order, "the drawn cards wait on top of piles, the first to be drawn uppermost")
	_ok(apart and not _buried(return_at), "a card put back goes on top of a pile none is drawn from")


## THE CONTROL for the open box's fill: only a box of cards on edge is filed out - the same box with its
## cards loose keeps exactly the planned collection.
func _open_loose_box() -> void:
	print("-- loose cards in an open box")
	var deck: Array = []
	for i in 12:
		deck.append({"key": "o%d" % i, "name": "Open card %d" % i})
	_load(47, [{}, {}, {}], {"look": {"candles": 0},
		"staging": {"source": "box", "box_style": "open", "contents": "loose"}, "deck": deck})
	var filed := 0
	for f in medium._file:
		filed += ((f as MultiMeshInstance3D).multimesh as MultiMesh).instance_count
	# (a card a search looks at is one of the twelve, kept in its place)
	var kept := filed + medium._cards.size() + medium._searched.size()
	_ok(not medium._box.is_empty() and kept == deck.size(),
		"control: an open box of loose cards keeps its twelve planned cards (%d)" % kept)


## Cards nearer than this (xz, meters) lie in one pile.
const NEAR := 0.03


## Whether a card in the box lies over [param at], in its pile ([param but] aside: the drawn cards' own
## places).
func _buried(at: Vector3, but: Array = []) -> bool:
	for xf in _box_poses():
		var o: Vector3 = (xf as Transform3D).origin
		if but.has(xf) or o.is_equal_approx(at):
			continue
		if Vector2(o.x - at.x, o.z - at.z).length() < NEAR and o.y > at.y:
			return true
	return false


func _box_poses() -> Array:
	var out: Array = (medium._box["at_k"] as Array).duplicate()
	for f in medium._file:
		var mm: MultiMesh = (f as MultiMeshInstance3D).multimesh
		for i in mm.instance_count:
			out.append(mm.get_instance_transform(i))
	# the cards a search looks at are cards of the box too, each in its place
	if not medium._searched.is_empty():
		out.append_array(medium._box.get("search", []))
	return out


## A CARD LAID BEHIND THE BOX (feedback 0010: "the seventh card... clips through the card box on the
## right... A real human would probably have started a new row by this point"): the spread keeps off the
## box's whole column - a long row becomes two rather than reaching behind the box - and a card that is
## given a place behind it is carried over its rim, never through it. Two-sided: the same cards laid with
## no box do reach into the column (the oracle), and the old flat arc over the box does clip it.
func _laid_over_box() -> void:
	print("-- laid over the box")
	var size := Vector2(CardTable.BOX_MAX.x, CardTable.BOX_MAX.z)
	var behind := 0
	var oracle := 0
	var rows_of_two := 0
	for s in range(1, SEEDS + 1):
		var lay := CardTable.layout_of(s)
		var col := TablePositions.deck_keep(lay["deck"], size)
		for n in [6, 7, 8]:
			var rng := RandomNumberGenerator.new()
			rng.seed = hash([s, n, "behind-box"])
			var boxed := TablePositions.staged(_cards(_plain(n)), rng, lay, size)
			var zs := {}
			for sl in boxed:
				var foot := CardTable.footprint(sl["pos"], float(sl["yaw"]), TablePositions.CARD)
				zs[snappedf(foot.get_center().y, 0.05)] = true
				if foot.position.x < col.end.x - 0.001 and foot.end.x > col.position.x + 0.001 and foot.position.y < col.end.y:
					behind += 1
			if zs.size() >= 2:
				rows_of_two += 1
			rng.seed = hash([s, n, "behind-box"])
			for sl in TablePositions.seeded(n, rng, lay):
				var foot := CardTable.footprint(sl["pos"], float(sl["yaw"]), TablePositions.CARD)
				if foot.position.x < col.end.x - 0.001 and foot.end.x > col.position.x + 0.001 and foot.position.y < col.end.y:
					oracle += 1
	_ok(behind == 0, "no card lies in the box's column, in front of it or behind (%d did)" % behind)
	_ok(rows_of_two > 0, "a long row that would reach it is two rows (%d of %d spreads)" % [rows_of_two, SEEDS * 3])
	_ok(oracle > 0, "control: with no box the same spreads do lie in its column (%d cards)" % oracle)
	# NOT OFF THE CLOTH (feedback 0020: ten cards beside a box, stepped back past the cloth's far edge and
	# the first of them in the far corner, with the front of the table bare): a row that cannot step aside
	# past the box's column is two rows, every card on the cloth
	var off_cloth := 0
	var cloth := Rect2(TablePositions.CLOTH_MIDDLE - TablePositions.CLOTH * 0.5, TablePositions.CLOTH).grow(-TablePositions.HEM)
	for s in range(1, SEEDS + 1):
		var lay := CardTable.layout_of(s)
		for n in [9, 10, 11, 12]:
			var rng := RandomNumberGenerator.new()
			rng.seed = hash([s, n, "behind-box"])
			for sl in TablePositions.staged(_cards(_plain(n)), rng, lay, size):
				if not cloth.encloses(CardTable.footprint(sl["pos"], float(sl["yaw"]), TablePositions.CARD)):
					off_cloth += 1
	_ok(off_cloth == 0, "every card of a long spread beside the box lies on the cloth (%d did not)" % off_cloth)
	var stepped_back := [{"pos": Vector3(0.0, 0.0, -0.44), "yaw": 0.0}]
	_ok(not TablePositions._on_cloth(stepped_back) and TablePositions._on_cloth([{"pos": Vector3(0.0, 0.0, -0.165), "yaw": 0.0}]),
		"control: a row stepped back to z -0.44 is off the cloth, one at -0.165 is not")
	# THE FLIGHT: from held up in front of the lens to a place right behind the box
	if medium._box.is_empty():
		_ok(false, "a box stands to lay over")
		return
	var world: AABB = medium._box["world"]
	var from := medium._present_xf(0, 0.0)
	var to := Transform3D(Basis(), Vector3(world.get_center().x, TableMedium.CARD_T * 0.5, world.position.z - 0.08))
	var lifted := func(f: float) -> float: return medium._lay_lift(from, to, f)
	var flat := func(f: float) -> float: return sin(PI * f) * TableMedium.LAY_ARC
	var clipped := _clips_box(from, to, lifted, world)
	var control := _clips_box(from, to, flat, world)
	var high := 0.0
	for s in 65:
		high = maxf(high, from.interpolate_with(to, float(s) / 64.0).origin.y + float(lifted.call(float(s) / 64.0)))
	_ok(clipped == 0, "laid behind the box it is carried over the rim (%d steps through it)" % clipped)
	_ok(control > 0, "control: the usual %.2f m arc clips the box (%d steps)" % [TableMedium.LAY_ARC, control])
	_ok(high < from.origin.y + 0.05, "and it is never lifted past where it was held up (%.2f m, held at %.2f)" % [high, from.origin.y])
	_ok(is_zero_approx(float(lifted.call(1.0))) and is_zero_approx(float(lifted.call(0.0))), "set down it is lifted nowhere")
	var free := Transform3D(Basis(), Vector3(-0.2, TableMedium.CARD_T * 0.5, 0.0))
	_ok(is_equal_approx(medium._lay_lift(from, free, 0.5), TableMedium.LAY_ARC), "a card laid clear of the box keeps the usual arc")


## How many of 64 steps of a laying from [param from] to [param to], lifted as [param lift] says, have
## the card's corners under the rim of the box [param world] while over it ([param lift]: f -> meters).
func _clips_box(from: Transform3D, to: Transform3D, lift: Callable, world: AABB) -> int:
	var rim := Rect2(world.position.x, world.position.z, world.size.x, world.size.z).grow(-TableMedium.BOX_GRAZE)
	var n := 0
	for s in 65:
		var f := float(s) / 64.0
		var xf := from.interpolate_with(to, f)
		xf.origin.y += float(lift.call(f))
		var lo := Vector3(INF, INF, INF)
		var hi := Vector3(-INF, -INF, -INF)
		for cx in [-0.5, 0.5]:
			for cz in [-0.5, 0.5]:
				var p := xf * Vector3(cx * TablePositions.CARD.x, 0.0, cz * TablePositions.CARD.y)
				lo = lo.min(p)
				hi = hi.max(p)
		if Rect2(lo.x, lo.z, hi.x - lo.x, hi.z - lo.z).intersects(rim) and lo.y < world.end.y:
			n += 1
	return n


func _plain(n: int) -> Array:
	var out: Array = []
	for i in n:
		out.append({})
	return out


func _printings() -> void:
	print("-- printings")
	var plan := {"look": {"candles": 0, "series": [{"name": "1959 Set", "card_back": "red"}, {"name": "1987 Set", "card_back": "blue"}]},
		"staging": {"source": "deck", "text": "booklet"}}
	_load(31, [{}, {}, {}], plan, ["1959 Set", "1987 Set", ""])
	var backs := []
	for k in 3:
		backs.append((medium._cards[k] as MeshInstance3D).get_surface_override_material(1))
	_ok(backs[0] != backs[1] and backs[0] != backs[2] and backs[1] != backs[2], "each printing has its own back, the deck's own a third")
	_ok(medium._backs.size() == 3, "three backs are printed (%d)" % medium._backs.size())


func _front_details() -> void:
	print("-- front details")
	var deck: Array = []
	for i in 12:
		deck.append({"key": "d%d" % i, "name": "Card %d" % i, "series": "First" if i < 8 else "Second"})
	var plan := {"look": {"candles": 0, "series": [{"name": "First", "card_back": "red star"},
		{"name": "Second", "card_back": "blue moon"}]}, "staging": {"source": "box", "text": "front"}, "deck": deck}
	_load(32, [{}, {}, {}], plan, ["First", "First", "Second"])
	var first := (medium._cards[0] as MeshInstance3D).get_surface_override_material(1)
	var same := (medium._cards[1] as MeshInstance3D).get_surface_override_material(1)
	var other := (medium._cards[2] as MeshInstance3D).get_surface_override_material(1)
	_ok(first == same and first != other, "front text keeps a shared back for each printing")
	_ok(medium._printed.is_empty() and medium._alone, "the cards are shown alone with no card-specific backs")
	_ok((medium._face_canvas[0] as CardFaces.Face).details and
		CardFaces.front_window({}, true).size.y < CardFaces.window().size.y,
		"the face reserves room below the picture for printed details")
	var filed := {"First": 0, "Second": 0}
	for inst in medium._file:
		var mm: MultiMesh = (inst as MultiMeshInstance3D).multimesh
		for name in filed:
			if mm.mesh.surface_get_material(0) == (medium._backs[name] as Dictionary)["mat"]:
				filed[name] += mm.instance_count
	var undrawn_n: int = int(filed["First"]) + int(filed["Second"])
	_ok(filed["First"] >= 6 and filed["Second"] >= 3 and absf(float(filed["First"]) / float(maxi(undrawn_n, 1)) - 8.0 / 12.0) < 0.05,
		"the undrawn cards, the nine planned and the stock filed out with them, keep the planned printing mix, two first to one second (%s)" % str(filed))


## How far the emitter [param e] is from card [param card] as drawn (meters): its middle, or its edges
## (a card's half length round from where they are drawn) when further.
func _off_card(e: Transform3D, card: MeshInstance3D) -> float:
	var d := card.transform.origin.distance_to(e.origin)
	for ax in [0, 2]:
		d = maxf(d, (card.transform.basis[ax].normalized() - e.basis[ax].normalized()).length() * TablePositions.CARD.y * 0.5)
	return d if card.visible else INF


## The worst [method _off_card] over every particle a burst on [param moments] throws, posed at its birth:
## `[meters, what]`.
func _worst_off(moments: Array, fx: Dictionary) -> Array:
	var worst := [0.0, "nothing"]
	for m in moments:
		var mo: Dictionary = m
		for p in Effects.births(fx, [mo], 7):
			var born := float((p as Dictionary)["born"])
			_posed(born)
			var off := _off_card(Effects._along(mo["path"], born), medium._cards[int(mo["card"])])
			if off > float(worst[0]):
				worst = [off, "card %d at %.2f s (its moment at %.2f)" % [int(mo["card"]) + 1, born, float(mo["t"])]]
	return worst


func _bursts() -> void:
	print("-- the air's bursts")
	var fx: Dictionary = Effects.sanitize([{"kind": "burst", "look": "stars", "on": "reveal", "count": 40}], ["#ffe9b0"],
		CardTable.AIR.keys(), CardTable.MOMENTS.keys())[0]
	var long := "Some words said about it, at an easy pace, for a while, and then some more of them, slowly, " \
		+ "about the card and what it holds, and what it might mean tonight."
	var deck := {"look": {"candles": 0}, "staging": {"source": "deck", "text": "booklet"}}
	var episodes := [
		["a deck show", 11, [{}, {"on": true}, {"comes": "dealt", "lies": "sideways"}, {"then": ["tap 1"]}], deck, long],
		["a spread that lays the card still held", 12, [{}, {}, {}], deck, long],
		["a box show", 23, [{}, {"comes": "swept"}, {"comes": "swept"}], {"look": {"candles": 0}, "staging": {"source": "box", "text": "back"}}, long],
		["a jumper's show", 14, [{"jumper": true}, {}], deck, long],
	]
	for epi in episodes:
		var plan: Dictionary = (epi[3] as Dictionary).duplicate(true)
		_load(int(epi[1]), epi[2], plan, [], String(epi[4]))
		medium._spin_wanted = true
		medium._spin_key = ""
		# planned as a frame plans it: the table posed first (its shuffle's and jumper's rooms), then the air
		_posed(1.0)
		var moments := medium._air_moments()
		var seen := PackedStringArray()
		var worst := [0.0, "nothing"]
		for name in moments:
			var on: Array = (moments[name] as Array).filter(func(m: Dictionary) -> bool: return int(m.get("card", -1)) >= 0)
			if on.is_empty():
				continue
			seen.append("%d %s" % [on.size(), name])
			var w := _worst_off(on, fx)
			if float(w[0]) > float(worst[0]):
				worst = [w[0], "%s, %s" % [name, w[1]]]
		_ok(float(worst[0]) < 0.002, "%s: every burst is born at its card as drawn (%s; worst %.2f mm, %s)"
			% [epi[0], ", ".join(seen), float(worst[0]) * 1000.0, worst[1]])
		# THE CLOSE WAITS for every card to be down: from its first birth, each lies where it stays
		var close: Array = moments["close"]
		var still := 0.0
		if not close.is_empty():
			var tc := float((close[0] as Dictionary)["t"])
			_posed(tc + 6.0)
			var after: Array = medium._cards.map(func(c: MeshInstance3D) -> Vector3: return c.transform.origin)
			_posed(tc)
			for k in medium._cards.size():
				still = maxf(still, (medium._cards[k] as MeshInstance3D).transform.origin.distance_to(after[k]))
		_ok(not close.is_empty() and still < 0.0005, "%s: the close waits until every card is down (%.1f mm still to go)" % [epi[0], still * 1000.0])
		if String(epi[0]) == "a jumper's show":
			var ev: Dictionary = ((medium._times()["events"] as Array)[0] as Array)[0]
			var touch := float(ev["t0"]) + (float(ev["off"]) + TableMedium.JUMP_FLY.y) * float(ev["s"])
			_posed(touch - 0.002)
			var flying: Transform3D = (medium._cards[0] as MeshInstance3D).transform
			_posed(touch + 0.002)
			var snap := _off_card(flying, medium._cards[0])
			_ok(String(ev["how"]) == "jumper" and snap < 0.002, "a jumper comes down as it lies: %.1f mm between its flight's end and its landing" % (snap * 1000.0))
			# THE CONTROL: the tumble alone, as it was flown, ends off the landing
			var top := medium._jump_ride(0, TableMedium.JUMP_FLY.x)
			var tumbled := Basis(Vector3.UP, 0.6 + 1.3 * PI) * top.basis * Basis(Vector3(0, 0, 1), 3.0 * PI)
			var old := _off_card(Transform3D(tumbled, flying.origin), medium._cards[0])
			_ok(old > 0.03, "control: the tumble alone ends %.0f mm off its landing" % (old * 1000.0))
		if String(epi[0]) == "a spread that lays the card still held":
			# THE CONTROL: the close as it was planned - at the spread's mark, from where each card would lie
			var tm := medium._times()
			var ts := float(tm["spread"])
			var wj0 := medium._wash_jump(maxf(float(tm["shuffle"]), minf(0.0, medium._now)))
			var old: Array = []
			for k in medium._cards.size():
				old.append({"t": ts, "dur": 0.8, "from": "card", "card": k,
					"path": [[ts, medium._card_pose(k, ts + TableMedium.LAY_END * 2.0, (tm["events"] as Array)[k], wj0)["xf"]]]})
			var w := _worst_off(old, fx)
			_ok(float(w[0]) > 0.02, "control: the close planned at the spread's mark from where the cards would lie is %.0f mm off (%s)"
				% [float(w[0]) * 1000.0, w[1]])
	medium._spin_wanted = false
	medium._spin_key = ""


## How uneven [param piles] ([method TablePositions.box_piles]) are: `{low, high}` the shortest and the
## tallest pile's cards, `gaps` how far the widest space between two piles next to each other in a row is
## from the narrowest (meters), `ragged` the most a pile's cards lie off its first (meters), `kept`
## whether every card lies inside its own plot.
func _pile_measure(piles: Array, size: Vector2) -> Dictionary:
	var low := 1 << 30
	var high := 0
	var ragged := 0.0
	var kept := true
	var rows := {}
	for p in piles:
		var cards: Array = (p as Dictionary)["cards"]
		var plot: Rect2 = (p as Dictionary)["rect"]
		low = mini(low, cards.size())
		high = maxi(high, cards.size())
		if cards.is_empty():
			continue
		var first: Vector3 = (cards[0] as Transform3D).origin
		for xf in cards:
			var t: Transform3D = xf
			ragged = maxf(ragged, Vector2(t.origin.x - first.x, t.origin.z - first.z).length())
			var foot := CardTable.footprint(t.origin, atan2(-t.basis.x.z, t.basis.x.x), size)
			kept = kept and plot.grow(0.0002).encloses(foot)
		var row := snappedf(plot.position.y, 0.0001)
		if not rows.has(row):
			rows[row] = []
		(rows[row] as Array).append(first.x)
	var steps: Array = []
	for row in rows:
		var xs: Array = rows[row]
		xs.sort()
		for i in range(1, xs.size()):
			steps.append(float(xs[i]) - float(xs[i - 1]))
	steps.sort()
	return {"low": low, "high": high, "ragged": ragged, "kept": kept,
		"gaps": float(steps[-1]) - float(steps[0]) if steps.size() > 1 else 0.0}


func _piles() -> void:
	print("-- piles in a box")
	var inner := AABB(Vector3(-0.16, 0.0, -0.105), Vector3(0.32, 0.1, 0.21))
	var size: Vector2 = CardTable.CARD_SIZES["trading"]
	var worst := {"low": 1.0, "gaps": INF, "ragged": INF}
	var kept := true
	var whole := true
	for seed in SEEDS:
		for mess in [TablePositions.PILES_NEAT, 1.0]:
			var rng := RandomNumberGenerator.new()
			rng.seed = seed
			var piles := TablePositions.box_piles(inner, size, 600, 0.00072, float(mess), rng)
			var m := _pile_measure(piles, size)
			var count := 0
			for p in piles:
				count += ((p as Dictionary)["cards"] as Array).size()
			whole = whole and count == 600
			kept = kept and bool(m["kept"])
			worst["low"] = minf(float(worst["low"]), 1.0 - float(m["low"]) / float(m["high"]))
			worst["gaps"] = minf(float(worst["gaps"]), float(m["gaps"]))
			worst["ragged"] = minf(float(worst["ragged"]), float(m["ragged"]))
	_ok(whole and kept, "every card is in a pile, on its own pile's plot of the floor, inside the box")
	_ok(float(worst["low"]) > 0.15, "some piles are taller than others (the shortest at least %.0f%% under the tallest)" % (float(worst["low"]) * 100.0))
	_ok(float(worst["gaps"]) > 0.002 and float(worst["ragged"]) > 0.001,
		"the piles are unevenly spaced and not squared (spaces %.1f mm apart at least, cards %.1f mm off)" %
		[float(worst["gaps"]) * 1000.0, float(worst["ragged"]) * 1000.0])
	var square := RandomNumberGenerator.new()
	square.seed = 5
	var grid := _pile_measure(TablePositions.box_piles(inner, size, 600, 0.00072, 0.0, square), size)
	_ok(int(grid["high"]) - int(grid["low"]) <= 1 and float(grid["gaps"]) < 0.0001 and float(grid["ragged"]) < 0.0001,
		"control: laid with no mess, the piles are the squared grid (%d to %d cards, spaces %.2f mm apart, %.2f mm off)" %
		[int(grid["low"]), int(grid["high"]), float(grid["gaps"]) * 1000.0, float(grid["ragged"]) * 1000.0])


## How many times a card passes through another, or lies in it, between [param from] and [param to]
## (two poses of every card, a frame apart: `[Transform3D or null when unseen]`): a point of one card
## over the other's face changing sides of it, or within it.
func _through(from: Array, to: Array) -> int:
	var n := 0
	var half := TablePositions.CARD * 0.5
	for a in from.size():
		for b in from.size():
			if a == b or from[a] == null or to[a] == null or from[b] == null or to[b] == null:
				continue
			var hit := false
			for gx in [-0.96, 0.0, 0.96]:
				for gz in [-0.96, -0.5, 0.0, 0.5, 0.96]:
					var p := Vector3(float(gx) * half.x, 0.0, float(gz) * half.y)
					var was: Vector3 = (from[b] as Transform3D).affine_inverse() * ((from[a] as Transform3D) * p)
					var now: Vector3 = (to[b] as Transform3D).affine_inverse() * ((to[a] as Transform3D) * p)
					if absf(was.x) > half.x or absf(was.z) > half.y or absf(now.x) > half.x or absf(now.z) > half.y:
						continue
					if signf(was.y) != signf(now.y) or absf(now.y) < TableMedium.CARD_T * 0.9:
						hit = true
			n += 1 if hit else 0
	return n


func _seen() -> Array:
	var out: Array = []
	for c in medium._cards:
		out.append((c as MeshInstance3D).transform if (c as MeshInstance3D).visible else null)
	return out


func _waterfall_shown() -> void:
	print("-- a waterfall, each card shown")
	_load(871516, [{"comes": "swept"}, {"comes": "swept"}, {}],
		{"look": {"candles": 0}, "staging": {"source": "deck", "text": "booklet"}})
	var tm := medium._times()
	var kinds: Array = ((tm["events"] as Array)[0] as Array).map(func(e: Dictionary) -> String: return String(e["k"]))
	_ok(kinds == ["arrive", "show", "lay"] and _at(1, "show") < INF,
		"the waterfall's cards are swept out, then each shown and laid again (%s)" % str(kinds))
	var t := _at(0, "arrive", "fan")
	var end := float(tm["spread"]) + 2.0
	_posed(t)
	var prev := _seen()
	var through := 0
	var first := INF
	while t < end:
		t += 1.0 / 60.0
		_posed(t)
		var now := _seen()
		var hits := _through(prev, now)
		if hits > 0 and first == INF:
			first = t
		through += hits
		prev = now
	_ok(through == 0, "no card passes through another or lies in it (%d times, first at %.2f s)" % [through, first])
	# card 1 lies under card 2 until it is shown: it slides out along the cloth before it rises
	var show := _at(0, "show")
	_posed(show - 0.02)
	var under: Transform3D = (medium._cards[0] as MeshInstance3D).transform
	var over: Transform3D = (medium._cards[1] as MeshInstance3D).transform
	_ok(over.origin.y - under.origin.y > TableMedium.CARD_T * 0.99, "the second card swept out lies on the first, a card's thickness up")
	_posed(show + TableMedium.SHOW_SLIDE * 0.98)
	var slid: Transform3D = (medium._cards[0] as MeshInstance3D).transform
	_ok(absf(slid.origin.y - under.origin.y) < 0.0002 and Vector2(slid.origin.x - under.origin.x, slid.origin.z - under.origin.z).length() > 0.03
		and not TablePositions.overlaps({"pos": slid.origin, "yaw": medium._slots[0]["yaw"]}, {"pos": over.origin, "yaw": medium._slots[1]["yaw"]}),
		"shown, the first is slid out from under the second along the cloth before it rises (%.0f mm)" %
		(Vector2(slid.origin.x - under.origin.x, slid.origin.z - under.origin.z).length() * 1000.0))
	_posed(_at(1, "show") - 0.02)
	_ok((medium._cards[0] as MeshInstance3D).transform.origin.y - (medium._cards[1] as MeshInstance3D).transform.origin.y > TableMedium.CARD_T * 0.99,
		"laid again, the first lies on top of the second")
	# THE CONTROL: lifted straight up from where it lay under the second, it passes through it
	var straight := 0
	var was: Array = [under, over]
	for i in 12:
		var up: Array = [Transform3D(under.basis, under.origin + Vector3(0.0, 0.004 * float(i + 1), 0.0)), over]
		straight += _through(was, up)
		was = up
	_ok(straight > 0, "control: a card lifted straight up from under another passes through it")
