extends SceneTree

## table_positions_check - where cards lie, as data (next/notes.md step 9, "Positions are data" and
## "Agents choose"), on a fixture episode of its own.
##
##   godot --headless --path . --script tests/table_positions_check.gd
##
## THE PRESETS ARE THE OLD SPREADS: over a thousand seeded spreads, each identical to the old
## algorithm's (kept below, verbatim, as the oracle) unless that one had a card partly outside the
## camera's frame - and every spread, after, lies on the cloth, in the frame and clear of the deck.
## Two-sided: the oracle itself must have cut some card off, or the fallback is tested by nothing.
##
## GIVEN POSITIONS ARE USED ONLY WHOLE AND SOUND: a plan's coordinates for every card are used; one
## card off the cloth, or one card without coordinates, and the table lays its preset instead.
##
## A DEALER LAYS THE CARDS THROUGH ITS TOOLS: told what the table objects to as it places (off the
## cloth, out of the frame, over the deck), refused at submit until every card is placed and nothing
## is objected to, then its layout written into the episode, laid over the plan's positions by the
## episode's document, and taken by the table - every position on the cloth, in the frame and clear.
## And NO CHEATING: nothing a dealer is told names a card.

const DIR := "user://table_positions_check"
const CARD := Vector2(0.07, 0.12)
const DECK_CLEAR := 0.012

var _fails: Array = []


func _initialize() -> void:
	_presets()
	_given()
	_dealer()
	_clean()
	if _fails.is_empty():
		print("table_positions_check: ALL OK")
		quit(0)
		return
	print("table_positions_check: %d FAILURE(S)" % _fails.size())
	for f in _fails:
		print("   ", f)
	quit(1)


func _ok(cond: bool, msg: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + msg)
	if not cond:
		_fails.append(msg)


func _presets() -> void:
	print("-- the presets are the old spreads")
	var same := 0
	var relaid := 0
	var relaid_sound := 0
	var troubled := 0
	var drift := 0
	for seed in range(1, 101):
		for n in range(1, 11):
			var lay := TarotTable.layout_of(seed)
			var r1 := RandomNumberGenerator.new()
			r1.seed = hash([seed, "positions-check"])
			var r2 := RandomNumberGenerator.new()
			r2.seed = r1.seed
			var new := TablePositions.seeded(n, r1, lay)
			var old := _old(n, r2, lay["deck"])
			if r1.state != r2.state:
				drift += 1
			var eq := true
			for i in n:
				if not (new[i]["pos"] as Vector3).is_equal_approx(old[i]["pos"]) or not is_equal_approx(float(new[i]["yaw"]), float(old[i]["yaw"])):
					eq = false
			if eq:
				same += 1
			else:
				relaid += 1
				if TablePositions.troubles(old, seed).is_empty():
					relaid_sound += 1
			if not TablePositions.troubles(new, seed).is_empty():
				troubled += 1
	_ok(drift == 0, "the presets draw exactly what the old spread drew (%d drifted)" % drift)
	_ok(relaid_sound == 0, "a spread is re-laid only when the old one had a card cut off (%d re-laid, %d of them sound)" % [relaid, relaid_sound])
	_ok(relaid > 0, "the control: the old algorithm did cut some card off (%d of %d), so the fallback is exercised" % [relaid, same + relaid])
	_ok(troubled == 0, "every spread lies on the cloth, in the frame and clear of the deck (%d not)" % troubled)


func _given() -> void:
	print("-- given positions")
	var seed := 7
	var cards := [{"position": {"name": "Past", "x": -0.1, "z": -0.1, "yaw": 2.0}},
		{"position": {"name": "Present", "x": 0.0, "z": -0.1, "yaw": 0.0}},
		{"position": {"name": "Future", "x": 0.1, "z": -0.1, "yaw": -2.0}}]
	var got := TablePositions.given(cards, seed)
	_ok(got.size() == 3 and is_equal_approx((got[0]["pos"] as Vector3).x, -0.1), "a plan's coordinates for every card are used")
	var off := cards.duplicate(true)
	off[2]["position"]["x"] = 0.9
	_ok(TablePositions.given(off, seed).is_empty(), "one card off the cloth, and the table lays its preset")
	var bare := cards.duplicate(true)
	(bare[1]["position"] as Dictionary).erase("x")
	_ok(TablePositions.given(bare, seed).is_empty(), "one card without coordinates, and the table lays its preset")


func _dealer() -> void:
	print("-- a dealer lays the cards")
	TarotEpisode.root = DIR
	_clean()
	var ep := TarotEpisode.open("dealer-check", 11)
	var plan := {"spread": {"positions": [{"name": "Root"}, {"name": "Crown"}, {"name": "Path"}]}}
	ep.write_json("plan", plan)
	ep.write_json("draw", {"cards": [{"key": "tower", "name": "The Tower"}, {"key": "star", "name": "The Star"},
		{"key": "moon", "name": "The Moon"}]})
	var d := DealerTools.new(ep, plan, 3)
	var told := d.instructions() + JSON.stringify(d.list_tools())
	_ok(not told.contains("Tower") and not told.contains("Star") and not told.contains("Moon"),
		"NO CHEATING: nothing a dealer is told names a card")
	_ok(told.contains("Root") and told.contains("Crown"), "it is told the plan's positions by name")
	var lay := TarotTable.layout_of(ep.seed)
	var deck: Vector3 = lay["deck"]
	var r := d.call_tool("place", {"card": 1, "x": 0.9, "z": 0.0})
	_ok(String(r["text"]).contains("off the cloth"), "placed off the cloth, it is told so (%s)" % r["text"])
	r = d.call_tool("place", {"card": 1, "x": deck.x, "z": deck.z})
	_ok(String(r["text"]).contains("over the deck"), "placed on the deck, it is told so (%s)" % r["text"])
	r = d.call_tool("place", {"card": 1, "x": -0.55, "z": -0.34})
	_ok(String(r["text"]).contains("frame"), "placed in the far corner, it is told it is out of the frame (%s)" % r["text"])
	_ok(not String(d.call_tool("submit", {}).get("error", "")).is_empty(), "a layout with troubles is refused")
	var away := -signf(deck.x)
	d.call_tool("place", {"card": 1, "x": away * 0.12, "z": -0.12, "yaw": 3.0})
	_ok(String(d.call_tool("submit", {}).get("error", "")).contains("not every card"), "a layout with cards missing is refused")
	d.call_tool("place", {"card": 2, "x": away * 0.03, "z": -0.12})
	d.call_tool("place", {"card": 3, "x": away * -0.06, "z": -0.12, "yaw": -3.0})
	d.call_tool("flip", {"card": 3, "face": "down"})
	var look := String(d.call_tool("look", {})["text"])
	_ok(look.contains("objects to nothing"), "the look says the table objects to nothing:\n%s" % look)
	r = d.call_tool("submit", {})
	_ok(String(r.get("error", "")).is_empty() and FileAccess.file_exists(ep.dir.path_join(DealerTools.LAYOUT)),
		"the layout is handed in and written into the episode")
	var doc := ep.document()
	var cards: Array = doc["cards"]
	_ok(cards.size() == 3 and (cards[0]["position"] as Dictionary).has("x") and String(cards[0]["position"]["name"]) == "Root",
		"the episode lays the dealer's coordinates over the plan's positions, names kept")
	_ok(String(cards[2]["position"].get("face", "")) == "down", "the flipped card lies face down")
	var slots := TablePositions.given(cards, ep.seed)
	_ok(slots.size() == 3, "the table takes the dealer's layout")
	_ok(TablePositions.troubles(slots, ep.seed).is_empty(), "every position on the cloth, in the frame and clear of the deck")


func _clean() -> void:
	var abs := ProjectSettings.globalize_path(DIR)
	if not DirAccess.dir_exists_absolute(abs):
		return
	for sub in ["dealer-check/11", "dealer-check"]:
		var d := abs.path_join(sub)
		if DirAccess.dir_exists_absolute(d):
			for f in DirAccess.get_files_at(d):
				DirAccess.remove_absolute(d.path_join(f))
			DirAccess.remove_absolute(d)
	DirAccess.remove_absolute(abs)


## THE OLD SPREAD, verbatim (TarotMedium._spread_slots before step 9) - the oracle.
func _old(n: int, rng: RandomNumberGenerator, deck_base: Vector3) -> Array:
	var out: Array = []
	if n <= 0:
		return out
	var gap := CARD.x * rng.randf_range(1.12, 1.3)
	var kinds := ["row", "arc"]
	if n >= 5:
		kinds.append("rows")
	if n == 3 or n == 6:
		kinds.append("pyramid")
	var kind := String(kinds[rng.randi_range(0, kinds.size() - 1)])
	if n * gap > 0.66:
		kind = "rows"
	var pos: Array = []
	match kind:
		"rows":
			var top := int(ceil(n / 2.0))
			for i in n:
				var row := 0 if i < top else 1
				var k: int = i if row == 0 else i - top
				var cnt: int = top if row == 0 else n - top
				pos.append(Vector3((float(k) - float(cnt - 1) * 0.5) * gap, 0.0, -0.165 + float(row) * CARD.y * 1.12))
		"pyramid":
			var rows := [[0], [1, 2]] if n == 3 else [[0], [1, 2], [3, 4, 5]]
			var z0 := -0.21 if n == 6 else -0.15
			for r in rows.size():
				var row: Array = rows[r]
				for k in row.size():
					pos.append(Vector3((float(k) - float(row.size() - 1) * 0.5) * gap, 0.0, z0 + float(r) * CARD.y * 0.92))
		"arc":
			var bend := rng.randf_range(0.18, 0.32)
			for i in n:
				var x := (float(i) - float(n - 1) * 0.5) * gap
				pos.append(Vector3(x, 0.0, -0.08 + bend * x * x * 3.0 - 0.02))
		_:
			for i in n:
				pos.append(Vector3((float(i) - float(n - 1) * 0.5) * gap, 0.0, -0.085))
	for i in n:
		var p: Vector3 = pos[i]
		p += Vector3(rng.randf_range(-0.003, 0.003), (float(i) + 1.0) * 0.0002, rng.randf_range(-0.003, 0.003))
		var yaw := deg_to_rad(rng.randf_range(-2.5, 2.5))
		if kind == "arc":
			yaw += -p.x * 0.6
		out.append({"pos": p, "yaw": yaw})
	var keep := Rect2(deck_base.x - CARD.x * 0.5 - DECK_CLEAR, deck_base.z - CARD.y * 0.5 - DECK_CLEAR,
		CARD.x + DECK_CLEAR * 2.0, CARD.y + DECK_CLEAR * 2.0)
	var off := TarotTable.clear_of(out, CARD, keep)
	for sl in out:
		sl["pos"] = sl["pos"] + Vector3(off.x, 0.0, off.y)
	return out
