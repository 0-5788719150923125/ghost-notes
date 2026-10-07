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
##     page and turned over to show its printed back; the waterfall's cards lie overlapping. A box mixing
##     printings gives each printing its own back.
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
	_box_show()
	_printings()
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
		out.append({"key": "c%d" % i, "name": "Card %d" % (i + 1), "numeral": "", "reversed": false, "jumper": false,
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
func _load(seed: int, positions: Array, plan: Dictionary, series: Array = []) -> void:
	var cards := _cards(positions)
	for i in mini(series.size(), cards.size()):
		if not String(series[i]).is_empty():
			(cards[i] as Dictionary)["series"] = series[i]
	plan["spread"] = {"positions": positions}
	var passages: Array = []
	for m in CardProducer.choreography(plan, cards):
		passages.append({"kind": m["kind"], "card": m.get("card", 0), "last": m.get("last", m.get("card", 0)),
			"text": "Some words said about it, at an easy pace, for a while." if not String(m.get("say", "")).is_empty() else ""})
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
	_load(23, [{}, {"comes": "swept"}, {"comes": "swept"}],
		{"look": {"candles": 0}, "staging": {"source": "box", "text": "back"}})
	_ok(medium._cards_from == "box" and not medium._box.is_empty(), "the cards come from a box, and it stands")
	if medium._box.is_empty():
		return
	var filed := 0
	for f in medium._file:
		filed += ((f as MultiMeshInstance3D).multimesh as MultiMesh).instance_count
	_ok(filed > 40, "the box is filled with cards on edge (%d)" % filed)
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
