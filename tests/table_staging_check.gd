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
##     page and turned over to show its printed back; the waterfall's cards lie overlapping. The file
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
	_placement_drift()
	_box_show()
	_shoebox_show()
	_laid_over_box()
	_loose_box()
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
	_ok(filed + medium._cards.size() == deck.size(), "the box shows its twelve planned cards, including the drawn ones (%d)" % (filed + medium._cards.size()))
	var inner: AABB = medium._box["inner"]
	_posed(0.5)
	var waiting: Transform3D = (medium._cards[0] as MeshInstance3D).transform
	_ok((medium._cards[0] as MeshInstance3D).visible and inner.grow(0.01).has_point(waiting.origin)
		and absf(waiting.basis.z.normalized().y) > 0.9, "card 1 waits standing in the file, in the box")
	_ok(not (medium._deck[0] as MeshInstance3D).visible, "no deck lies on the table")
	var draw := _at(0, "arrive", "draw")
	var s := float((medium._times()["events"] as Array)[0][0]["s"])
	var off := float((medium._times()["events"] as Array)[0][0]["off"])
	_posed(draw + (off + TableMedium.FLIP_END - 0.05) * s)
	var rising: Transform3D = (medium._cards[0] as MeshInstance3D).transform
	_ok(rising.origin.y - TablePositions.CARD.y * 0.5 > (medium._box["world"] as AABB).end.y, "pulled straight up, it clears the rim")
	_posed(draw + 3.6)
	var held: Transform3D = (medium._cards[0] as MeshInstance3D).transform
	_ok(absf(_across(held) - 0.5) < 0.05 and not medium._page.visible, "held up alone in the middle, no page beside it (%.2f across)" % _across(held))
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
	_ok((medium._box["inner"] as AABB).grow(0.01).has_point(returned) and
		returned.y > (medium._box["at_k"][2] as Transform3D).origin.y,
		"a returned card lands on top of the contents inside the box")
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
	_ok(poses.size() == CardTable.SHOEBOX_FILL and spread > 0.09 and turn > 0.1,
		"loose cards occupy varied spots and angles, with the whole inventory present (%d cards, %.1f mm, %.2f rad)" %
		[poses.size(), spread * 1000.0, turn])
	var source: Array = medium._box["at_k"]
	var return_at: Vector3 = medium._box["return_at"]
	var top_down := true
	var separate := true
	for k in source.size():
		var at: Transform3D = source[k]
		if k > 0:
			top_down = top_down and at.origin.y < (source[k - 1] as Transform3D).origin.y
		separate = separate and return_at.x - at.origin.x > CardTable.card_size(medium._look).length() + 0.007
	_ok(top_down and separate and return_at.y > (source[0] as Transform3D).origin.y + 0.0007,
		"loose cards are drawn from the exposed top in order and returned to a clear higher spot")


func _box_poses() -> Array:
	var out: Array = (medium._box["at_k"] as Array).duplicate()
	for f in medium._file:
		var mm: MultiMesh = (f as MultiMeshInstance3D).multimesh
		for i in mm.instance_count:
			out.append(mm.get_instance_transform(i))
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
	_ok(filed["First"] == 6 and filed["Second"] == 3,
		"the nine undrawn cards keep the planned printing mix, six first and three second (%s)" % str(filed))


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
