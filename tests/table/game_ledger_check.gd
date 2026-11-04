extends SceneTree

## game_ledger_check - WHAT IS SO AT THE TABLE is its events: a sheet's fields named by the agents, a board of squares or of inches, a state rebuilt by replay (next/tabletop.md). The
## control: a move off the map and a change to what is not there are refused in words, and leave nothing behind.
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


## A GAME MEASURED WITH A TAPE: the same calls, inches and no squares.
func _free_measure() -> void:
	var g := GameLedger.new()
	g.map_down("The Ridge", "a ridge", [24, 24], false, "inch")
	g.place("Squad", [2.5, 3.0], "a squad")
	var m := g.move("Squad", [5.5, 7.0])
	_check(is_equal_approx(float((m["event"] as Dictionary)["far"]), 5.0), "a free measure is a straight line")
	_check(String(m["words"]).contains("inch"), "it says the unit the game measures in")
	_check(is_equal_approx(float(((g.figures["Squad"] as Dictionary)["at"] as Array)[0]), 5.5), "a free measure keeps its fraction")


## IT IS ITS EVENTS: the same list played again stands the same, from nothing.
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
	# ...THE SAME EPISODE ROLLS THE SAME, and the next thing to happen rolls otherwise
	var h := GameLedger.new()
	var b := h.roll("Milo", "1d20+3", "a door", 42)
	_check(int((a["event"] as Dictionary)["total"]) == int((b["event"] as Dictionary)["total"]), "the same seed and place roll the same")
	var seen := {}
	for k in 12:
		seen[int((g.roll("Milo", "1d20", "again", 42)["event"] as Dictionary)["total"])] = true
	_check(seen.size() > 1, "a control: one after another, they differ")
	var e := g.end_game("one survivor bought a boat")
	_check(bool(e["ok"]) and g.over and g.describe().contains("boat"), "a game can end, however it likes")
