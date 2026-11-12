extends SceneTree

## dice_notation_check - what a roll is: every kind of game's way of asking for dice, read and rolled, from the seed alone
## (next/tabletop.md). No game is named in the code, so four games' rolls stand here as the fixtures: a d20 plus a number with a keep,
## a d20 judged by the agent in degrees, a wargame's bucket of sixes counted, a percentile. Control: dice that come up the wrong way
## fail the fairness measure, and a notation nobody reads is refused in words.
##
##     godot --headless --path . --script tests/table/dice_notation_check.gd

var fails := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		printerr("FAIL: ", what)


func _init() -> void:
	_reads()
	_keeps()
	_buckets()
	_percentile()
	_printed()
	_same_seed()
	_fair()
	_refuses()
	print("dice_notation_check: ", "ok" if fails == 0 else "%d failed" % fails)
	quit(1 if fails > 0 else 0)


func _reads() -> void:
	var r := DiceNotation.roll("1d20+5", 7)
	_check(bool(r["ok"]), "1d20+5 reads")
	var d20 := int(((r["groups"] as Array)[0] as Dictionary)["rolled"][0])
	_check(d20 >= 1 and d20 <= 20, "a d20 is 1 to 20")
	_check(int(r["total"]) == d20 + 5, "a modifier adds")
	_check(int(r["natural"]) == d20, "one die alone is a natural")
	_check((r["thrown"] as Array).size() == 1 and int((r["thrown"] as Array)[0]["shape"]) == 20 and int((r["thrown"] as Array)[0]["face"]) == d20 - 1, "the body thrown is that die and that face")
	var m := DiceNotation.roll("2d6+1d4-1", 7)
	_check(bool(m["ok"]) and (m["thrown"] as Array).size() == 3, "terms add, and three bodies are thrown")
	var sum := 0
	for g in m["groups"]:
		sum += int((g as Dictionary)["sum"])
	_check(int(m["total"]) == sum - 1, "a term is added and a modifier taken away")
	_check(int(DiceNotation.roll("8d6", 3)["natural"]) == 0, "a handful has no natural")
	_check(not String(r["words"]).is_empty(), "a roll says itself")


func _keeps() -> void:
	for seed in 40:
		var r := DiceNotation.roll("2d20kh1+5", seed)
		var g: Dictionary = (r["groups"] as Array)[0]
		var a := int(g["rolled"][0])
		var b := int(g["rolled"][1])
		_check(int(r["total"]) == maxi(a, b) + 5, "keep highest keeps the higher")
		_check((r["thrown"] as Array).size() == 2, "both dice are thrown, and a viewer sees both")
		var l := DiceNotation.roll("2d20kl1", seed)
		var gl: Dictionary = (l["groups"] as Array)[0]
		_check(int(l["total"]) == mini(int(gl["rolled"][0]), int(gl["rolled"][1])), "keep lowest keeps the lower")
		var dl := DiceNotation.roll("4d6dl1", seed)
		var gd: Dictionary = (dl["groups"] as Array)[0]
		var all: Array = (gd["rolled"] as Array).duplicate()
		all.sort()
		_check(int(dl["total"]) == int(all[1]) + int(all[2]) + int(all[3]), "drop lowest drops the lowest")


func _buckets() -> void:
	var r := DiceNotation.roll("20d6>=3", 11)
	_check(bool(r["ok"]) and bool(r["counted"]), "a bucket counts")
	var g: Dictionary = (r["groups"] as Array)[0]
	var hits := 0
	for v in g["rolled"]:
		if int(v) >= 3:
			hits += 1
	_check(int(r["successes"]) == hits, "successes are the dice at the target or better")
	_check(hits > 0 and hits < 20, "a control on the seed: twenty sixes split")
	_check((r["thrown"] as Array).size() == 20, "a bucket is twenty bodies")
	var over := DiceNotation.roll("6d6!", 5)
	_check((over["thrown"] as Array).size() >= 6, "an exploding die throws at least what was asked")
	var rr := DiceNotation.roll("10d6r1", 9)
	_check((rr["thrown"] as Array).size() >= 10, "a reroll throws what was rerolled too")
	for v in ((rr["groups"] as Array)[0] as Dictionary)["rolled"]:
		_check(int(v) >= 1 and int(v) <= 6, "a rerolled die is still a die")


func _percentile() -> void:
	for seed in 60:
		var r := DiceNotation.roll("1d100", seed)
		var v := int(r["total"])
		_check(v >= 1 and v <= 100, "a percentile is 1 to 100")
		var t: Array = r["thrown"]
		_check(t.size() == 2 and int(t[0]["shape"]) == 10 and int(t[1]["shape"]) == 10, "a percentile is two tens")
		var read := int(t[0]["face"]) * 10 + int(t[1]["face"])
		_check((read if read > 0 else 100) == v, "the tens and the units read back the same number: %d, %d" % [read, v])
		_check(int(r["natural"]) == v, "a percentile alone is a natural")


func _printed() -> void:
	var f := DiceNotation.roll("4dF", 4)
	_check(bool(f["ok"]), "fudge dice read")
	_check(absi(int(f["total"])) <= 4, "fudge dice add their printed numbers")
	for t in f["thrown"]:
		_check(int((t as Dictionary)["shape"]) == 6, "a fudge die is a six")
	var s := DiceNotation.roll("2d6[skull,sword,sword,shield,shield,blank]", 8)
	_check(bool(s["ok"]) and (s["labels"] as PackedStringArray).size() == 2, "printed faces come back by name")
	_check(not String(s["words"]).contains("= 0"), "printed faces say no sum")
	var bad := DiceNotation.parse("1d6[a,b,c,d,e]")
	_check(not bool(bad["ok"]), "five printed faces is no die")
	# ...and a two and a three are sixes numbered over: the face thrown reads back
	for seed in 30:
		var three := DiceNotation.roll("1d3", seed)
		var t: Dictionary = (three["thrown"] as Array)[0]
		_check(int(t["shape"]) == 6 and int(t["face"]) / 2 + 1 == int(three["total"]), "a three reads on a six")


func _same_seed() -> void:
	_check(DiceNotation.roll("8d6+2", 123)["total"] == DiceNotation.roll("8d6+2", 123)["total"], "the same seed is the same roll")
	var differ := false
	for s in 10:
		if int(DiceNotation.roll("8d6", s)["total"]) != int(DiceNotation.roll("8d6", s + 1000)["total"]):
			differ = true
	_check(differ, "another seed is another roll")


## Fair: a chi-squared on a die's faces, against a limit a fair die clears, and a control, the same measure on a loaded die, which it must not clear.
func _fair() -> void:
	for sides: int in [6, 20]:
		var counts: Array = []
		counts.resize(sides)
		counts.fill(0)
		var n: int = 200 * sides
		for s in n:
			counts[int(DiceNotation.roll("1d%d" % sides, s)["total"]) - 1] += 1
		_check(_chi(counts, n) < _limit(sides), "a d%d is fair: %.1f" % [sides, _chi(counts, n)])
	var loaded: Array = []
	loaded.resize(6)
	loaded.fill(200)
	loaded[5] = 400
	loaded[0] = 0
	_check(_chi(loaded, 1200) >= _limit(6), "the control: a loaded die fails the measure")


static func _chi(counts: Array, n: int) -> float:
	var want := float(n) / float(counts.size())
	var out := 0.0
	for c in counts:
		out += pow(float(c) - want, 2.0) / want
	return out


## About the 0.999 point of a chi-squared with k-1 degrees: a fair die stays under it nearly always, and this seed is fixed.
static func _limit(k: int) -> float:
	var df := float(k - 1)
	return df + 3.3 * sqrt(2.0 * df) + 4.0


func _refuses() -> void:
	for bad in ["", "banana", "1d7", "0d6", "1d20++2", "90d6", "1d20 2d6"]:
		var r := DiceNotation.roll(bad, 1)
		_check(not bool(r["ok"]) and not String(r["error"]).is_empty(), "\"%s\" is refused in words" % bad)
