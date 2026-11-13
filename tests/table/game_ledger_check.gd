extends SceneTree

## game_ledger_check - what is so at the table is its events: a sheet's fields named by the agents, a board of squares or of inches, a
## state rebuilt by replay (next/tabletop.md), and what a roll needed judged by the ledger from the dice, never by whoever asked. Controls: a
## move off the map, a change to what is not there and a need that cannot be read are refused in words and leave nothing behind; a verdict
## comes out both ways.
##
##     godot --headless --path . --script tests/table/game_ledger_check.gd

var fails := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		printerr("FAIL: ", what)


func _init() -> void:
	_sheets()
	_board()
	_free_measure()
	_replay()
	_rolls()
	_needs()
	print("game_ledger_check: ", "ok" if fails == 0 else "%d failed" % fails)
	quit(1 if fails > 0 else 0)


func _sheets() -> void:
	var g := GameLedger.from({"Milo": {"hit points": 12, "pack": ["rope"]}})
	var r := g.change("Milo", "hit points", {"by": -7}, "a goat")
	_check(bool(r["ok"]) and int((g.sheets["Milo"] as Dictionary)["hit points"]) == 5, "a number goes down by what is asked")
	_check(String(r["words"]).contains("12") and String(r["words"]).contains("5"), "the answer says what it was and what it is")
	_check(bool(g.change("Milo", "pack", {"add": "boat"})["ok"]) and ((g.sheets["Milo"] as Dictionary)["pack"] as Array).has("boat"), "a list takes what is added")
	_check(not bool(g.change("Milo", "pack", {"remove": "horse"})["ok"]), "a list refuses what it does not hold")
	_check(not bool(g.change("Milo", "pack", {"by": 1})["ok"]), "a list is no number")
	_check(bool(g.change("Bea", "sanity", {"to": 40})["ok"]), "a field and a person nobody wrote down yet: the agents name them")
	_check(not bool(g.change("", "x", {"by": 1})["ok"]), "a change names who")
	_check(not bool(g.change("Milo", "x", {})["ok"]), "a change says how")
	_check(g.describe().contains("hit points: 5"), "a sheet reads as a number, not 5.0")


func _board() -> void:
	var g := GameLedger.new()
	_check(not bool(g.place("Goat", [1, 1], "a goat")["ok"]), "no figure stands with no map")
	_check(bool(g.map_down("The Inn", "an inn", [20, 14])["ok"]), "a map goes down")
	_check(bool(g.place("Goat", [2, 2], "a goat")["ok"]), "a figure stands")
	_check(not bool(g.place("Goat", [3, 3], "a goat")["ok"]), "one figure of a name")
	var n := g.events.size()
	_check(not bool(g.move("Goat", [99, 0])["ok"]), "off the map is refused")
	_check(not bool(g.place("Ox", [-1, 0], "an ox")["ok"]), "off the map, on the other side, is refused")
	_check(g.events.size() == n, "the refused left nothing behind")
	_check(not bool(g.move("Horse", [1, 1])["ok"]), "a figure that is not there is refused")
	var m := g.move("Goat", [5, 3])
	_check(bool(m["ok"]) and is_equal_approx(float((m["event"] as Dictionary)["far"]), 3.0), "a diagonal is one square, as squares are counted")
	_check(bool(g.place("Ox", [5, 3], "an ox")["ok"]) and String(g.place("Hen", [5, 3], "a hen")["words"]).contains("same spot"), "two on one spot is allowed, and said")
	_check(bool(g.figure_state("fall", "Goat")["ok"]) and bool((g.figures["Goat"] as Dictionary)["down"]), "a figure falls")
	_check(not bool(g.figure_state("fall", "Goat")["ok"]), "what is down cannot fall")
	_check(bool(g.figure_state("rise", "Goat")["ok"]), "a figure rises")
	_check(bool(g.figure_state("remove", "Goat")["ok"]) and not g.figures.has("Goat"), "a figure comes off")
	var off := g.map_down("The Boat", "a small boat", [8, 8])
	_check(g.figures.is_empty() and String(off["words"]).contains("Ox"), "a new map takes what stood on the last, and says what")
	_check(int(((g.maps.back() as Dictionary)["size"] as Array)[0]) == 8, "the last map is the one down")


## A game measured with a tape: the same calls, inches and no squares.
func _free_measure() -> void:
	var g := GameLedger.new()
	g.map_down("The Ridge", "a ridge", [24, 24], false, "inch")
	g.place("Squad", [2.5, 3.0], "a squad")
	var m := g.move("Squad", [5.5, 7.0])
	_check(is_equal_approx(float((m["event"] as Dictionary)["far"]), 5.0), "a free measure is a straight line")
	_check(String(m["words"]).contains("inch"), "it says the unit the game measures in")
	_check(is_equal_approx(float(((g.figures["Squad"] as Dictionary)["at"] as Array)[0]), 5.5), "a free measure keeps its fraction")


## It is its events: the same list played again stands the same, from nothing.
func _replay() -> void:
	var g := GameLedger.from({"Milo": {"hit points": 12}})
	g.map_down("The Inn", "an inn", [20, 14])
	g.place("Milo's figure", [1, 1], "a small man", "Milo")
	g.move("Milo's figure", [4, 4])
	g.change("Milo", "hit points", {"by": -3})
	g.reveal("The Innkeeper", "a large angry goose")
	g.roll("Milo", "1d20", "a door", 7)
	var again := GameLedger.from({"Milo": {"hit points": 12}}, g.events)
	_check(again.describe() == g.describe(), "a replay stands the same")
	_check(again.next_id() == g.next_id(), "a replay carries the ids on")
	var part := GameLedger.from({"Milo": {"hit points": 12}}, g.events.slice(0, 2))
	_check(int(((part.figures["Milo's figure"] as Dictionary)["at"] as Array)[0]) == 1, "part of a list stands as it stood then")


func _rolls() -> void:
	var g := GameLedger.new()
	var a := g.roll("Milo", "1d20+3", "a door", 42)
	_check(bool(a["ok"]) and g.events.size() == 1, "a roll happens")
	_check(int((a["event"] as Dictionary)["id"]) == 1, "ids begin at one")
	_check(not bool(g.roll("Milo", "1d7", "nonsense", 42)["ok"]), "dice no table has are refused")
	_check(g.events.size() == 1, "and did not happen")
	# ...the same episode rolls the same, and the next thing to happen rolls otherwise
	var h := GameLedger.new()
	var b := h.roll("Milo", "1d20+3", "a door", 42)
	_check(int((a["event"] as Dictionary)["total"]) == int((b["event"] as Dictionary)["total"]), "the same seed and place roll the same")
	var seen := {}
	for k in 12:
		seen[int((g.roll("Milo", "1d20", "again", 42)["event"] as Dictionary)["total"])] = true
	_check(seen.size() > 1, "a control: one after another, they differ")
	var e := g.end_game("one survivor bought a boat")
	_check(bool(e["ok"]) and g.over and g.describe().contains("boat"), "a game can end, however it likes")


## What a roll needed is set before it lands, and whether it made it is the dice's: the same answer however it is read back.
func _needs() -> void:
	_check(GameLedger.needs_of("15")["cmp"] == ">=" and int(GameLedger.needs_of("15+")["target"]) == 15, "a bare number is that or more")
	_check(GameLedger.needs_of("<= 40")["cmp"] == "<=", "a game rolled under says so")
	_check(String(GameLedger.needs_of("none")["cmp"]).is_empty() and bool(GameLedger.needs_of("")["ok"]), "a roll may need nothing")
	var g := GameLedger.new()
	# the control: a need nobody can read throws nothing, and takes no id
	_check(not bool(g.roll("Milo", "1d20+3", "a door", 42, false, "fifteen")["ok"]) and not bool(g.roll("Milo", "1d20", "a door", 42, false, ">=15+")["ok"]), "a need that cannot be read is refused")
	_check(g.events.is_empty(), "and nothing was thrown")
	var both := {}
	for k in 40:
		var r := g.roll("Milo", "1d20+3", "a door", 42, false, "14")
		var e: Dictionary = r["event"]
		var made := int(e["total"]) >= 14
		_check(bool(e["made"]) == made and String(e["needs"]) == ">=14", "the verdict is the dice's: %d against 14" % int(e["total"]))
		_check(String(r["words"]).contains("SUCCEEDS" if made else "FAILS") and not String(e["words"]).contains("needed"), "the answer says it, and the table's words do not")
		both[made] = true
	_check(both.size() == 2, "a control: it comes out both ways")
	for k in 20:
		var e: Dictionary = g.roll("Bea", "1d100", "nerve", 42, false, "<=40")["event"]
		_check(bool(e["made"]) == (int(e["total"]) <= 40), "under is under: %d" % int(e["total"]))
	var bucket: Dictionary = g.roll("Bea", "20d6>=3", "volley", 42, false, "12")["event"]
	_check(bool(bucket["made"]) == (int(bucket["successes"]) >= 12), "a bucket's need is its successes")
	_check(not g.roll("Bea", "8d6", "a hit", 42, false, "none")["event"].has("made"), "a roll that needs nothing has no verdict")
	# a die's own extremes, when one die counted: the die kept, read from the same dice the ledger threw
	var seen := {}
	for k in 200:
		for dice in ["1d20+2", "2d20kh1"]:
			var id := g.next_id()
			var e: Dictionary = g.roll("Milo", dice, "x", 42)["event"]
			var d: Dictionary = (DiceNotation.roll(dice, hash([42, "game", id]))["groups"] as Array)[0]
			var face := 0
			for i in (d["rolled"] as Array).size():
				if bool((d["kept"] as Array)[i]):
					face = int((d["rolled"] as Array)[i])
			var want := "highest" if face == 20 else "lowest" if face == 1 else ""
			_check(String(e.get("extreme", "")) == want, "%s: %s is %s" % [dice, String(e["words"]), want if not want.is_empty() else "no extreme"])
			seen[want] = true
	_check(seen.has("highest") and seen.has("lowest") and seen.has(""), "a control: extremes come up, and mostly do not")
	_check(not g.roll("Bea", "8d6", "a hit", 42)["event"].has("extreme"), "many dice counted have no one face")
