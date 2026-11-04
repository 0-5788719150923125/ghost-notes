extends RefCounted
class_name DiceNotation

## DiceNotation - WHAT A ROLL IS, as tabletop players write it, and rolling it (next/tabletop.md). A game's agents ask for dice in the
## words every game's players already use, and what comes back was decided here, from the seed, never by them: an agent cannot fake a number
## it did not roll, which is the whole honesty of a show of this kind (the work shown is the work done).
##
## NO GAME IS NAMED HERE. It knows dice, and nothing of what any number means:
##
##     1d20+5           a die and a modifier
##     2d20kh1+5        roll two, keep the highest (`kl` the lowest, `dh`/`dl` drop instead)
##     8d6              a handful, added
##     20d6>=3          a bucket, counting how many come up 3 or better (`<=`, `>`, `<`, `=`)
##     1d100            percentile: two ten-sided dice on the table, one for the tens
##     4dF              fudge dice: six sides, two each of -1, 0 and +1
##     3d6r1            reroll a 1, once each
##     6d6!             a six rolls again, and adds
##     2d6[skull,sword,sword,shield,shield,blank]   printed faces: the faces come back by name, and nothing is added
##
## and any number of those added and taken away: `2d6+1d4-1`.
##
## A DIE ON THE TABLE IS A SOLID ([Dice]): what is rolled here says which solid and which of its faces (`thrown`), one entry a body, so what is
## shown and what was rolled are one list. A rerolled or exploded die is thrown too: a viewer sees every die that counted.
##
## A FUNCTION OF ITS SEED: the same notation and the same seed give the same dice, whoever asks and in what order, so a scene made again rolls
## what it rolled. Gate: tests/table/dice_notation_check.gd.

## The sides a die can have, which are the solids a table has ([constant Dice.SHAPES]), and the ones played on another's body: a percentile is
## two tens, and a two and a three are sixes numbered over.
const SHAPES := [4, 6, 8, 10, 12, 20]
const STAND_INS := {2: 6, 3: 6, 100: 10}
## The most dice one roll may throw: more is no longer dice, and a real table's bucket is about this.
const MOST := 60
## How many more an exploding die may roll, in all.
const EXPLODE_MOST := 20
const FUDGE := ["-1", "-1", "0", "0", "+1", "+1"]


static func _rx() -> RegEx:
	var r := RegEx.new()
	# one term: a sign, then dice or a number (no `^`: it means the start of the text at any offset, and [method parse] holds a match to where it stands)
	r.compile("\\s*([+-])?\\s*(?:(\\d*)d(\\d+|[fF])(\\[[^\\]]*\\])?(?:(k[hl]|d[hl])(\\d+))?(?:r(\\d+))?(!)?(?:(>=|<=|>|<|=)(\\d+))?|(\\d+))\\s*")
	return r


## [param text] read, nothing rolled: `{ok, terms, error}`. A term is `{sign, count, sides, labels, keep, keep_n, reroll, explode, cmp, target}` or `{sign, flat}`.
static func parse(text: String) -> Dictionary:
	var src := text.strip_edges().to_lower().replace(" ", "")
	if src.is_empty():
		return {"ok": false, "terms": [], "error": "no dice were named"}
	var terms: Array = []
	var at := 0
	var rx := _rx()
	var thrown := 0
	while at < src.length():
		var m := rx.search(src, at)
		if m == null or m.get_start() != at or m.get_end() == at:
			return {"ok": false, "terms": [], "error": "could not read \"%s\" in \"%s\" - write dice as 2d6+3, 2d20kh1, 8d6>=4, 1d100, 4dF" % [src.substr(at), text]}
		var sign := -1 if m.get_string(1) == "-" else 1
		if not terms.is_empty() and m.get_string(1).is_empty():
			return {"ok": false, "terms": [], "error": "two terms with nothing between them in \"%s\"" % text}
		if not m.get_string(11).is_empty():
			terms.append({"sign": sign, "flat": int(m.get_string(11))})
			at = m.get_end()
			continue
		var count := int(m.get_string(2)) if not m.get_string(2).is_empty() else 1
		var raw := m.get_string(3)
		var labels := PackedStringArray()
		var sides := 6 if raw == "f" else int(raw)
		if raw == "f":
			labels = PackedStringArray(FUDGE)
		if not m.get_string(4).is_empty():
			# (read from the text as written: the lower-casing above is for the notation, not a face's name)
			for piece in m.get_string(4).trim_prefix("[").trim_suffix("]").split(",", false):
				labels.append(piece.strip_edges())
			sides = labels.size()
		if count < 1:
			return {"ok": false, "terms": [], "error": "\"%s\" throws no dice" % m.get_string().strip_edges()}
		if not SHAPES.has(sides) and not STAND_INS.has(sides):
			return {"ok": false, "terms": [], "error": "no die has %d sides here: %s, or %s on another die" % [sides, str(SHAPES), str(STAND_INS.keys())]}
		var keep := m.get_string(5)
		var keep_n := int(m.get_string(6)) if not m.get_string(6).is_empty() else 0
		if not keep.is_empty() and keep_n < 0:
			return {"ok": false, "terms": [], "error": "a keep needs a number"}
		thrown += count
		terms.append({"sign": sign, "count": count, "sides": sides, "labels": labels, "keep": keep, "keep_n": keep_n,
			"reroll": int(m.get_string(7)) if not m.get_string(7).is_empty() else 0, "explode": not m.get_string(8).is_empty(),
			"cmp": m.get_string(9), "target": int(m.get_string(10)) if not m.get_string(10).is_empty() else 0})
		at = m.get_end()
	if thrown > MOST:
		return {"ok": false, "terms": [], "error": "%d dice is more than a table throws at once (%d at most)" % [thrown, MOST]}
	return {"ok": true, "terms": terms, "error": ""}


## ROLL [param text] from [param seed]: `{ok, error, notation, groups, flat, total, successes, labels, natural, thrown, words}`:
##
## - `groups`: each dice term, `{count, sides, rolled, kept, sum, successes, labels}`; `rolled` every value in the order thrown, `kept` whether each one counted;
## - `flat`: the modifiers added up;
## - `total`: what it comes to, with `successes` counted instead of added wherever a target was named;
## - `natural`: the die's own face when one die alone was thrown, 0 otherwise;
## - `thrown`: every die that goes on the table, `{shape, face, sides, label}`, `face` its 0-based face on that solid;
## - `words`: all of it as one line an agent reads.
static func roll(text: String, seed: int) -> Dictionary:
	var parsed := parse(text)
	if not bool(parsed["ok"]):
		return {"ok": false, "error": parsed["error"], "notation": text}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed, "dice-roll", text.strip_edges().to_lower()])
	var groups: Array = []
	var flat := 0
	var total := 0
	var successes := 0
	var counted := false
	var thrown: Array = []
	var named := PackedStringArray()
	for term in parsed["terms"]:
		var t: Dictionary = term
		if t.has("flat"):
			flat += int(t["sign"]) * int(t["flat"])
			continue
		var g := _roll_group(t, rng, thrown)
		groups.append(g)
		total += int(t["sign"]) * int(g["sum"])
		if not String(t["cmp"]).is_empty():
			counted = true
			successes += int(g["successes"])
		named.append_array(g["labels"])
	total += flat
	var natural := 0
	if thrown.size() == 1 or (groups.size() == 1 and int((groups[0] as Dictionary)["sides"]) == 100 and int((groups[0] as Dictionary)["count"]) == 1):
		natural = int(((groups[0] as Dictionary)["rolled"] as Array)[0]) if not groups.is_empty() else 0
	var out := {"ok": true, "error": "", "notation": text.strip_edges(), "groups": groups, "flat": flat, "total": total,
		"successes": successes, "counted": counted, "labels": named, "natural": natural, "thrown": thrown}
	out["words"] = words_of(out)
	return out


static func _roll_group(t: Dictionary, rng: RandomNumberGenerator, thrown: Array) -> Dictionary:
	var sides := int(t["sides"])
	var count := int(t["count"])
	var labels: PackedStringArray = t["labels"]
	var rolled: Array = []
	var extra := 0
	var i := 0
	while i < count + extra:
		var v := rng.randi_range(1, sides)
		_throw(thrown, sides, v, labels)
		# ...A REROLL, once each: the first is thrown too, and does not count
		if int(t["reroll"]) > 0 and v <= int(t["reroll"]) and labels.is_empty():
			v = rng.randi_range(1, sides)
			_throw(thrown, sides, v, labels)
		rolled.append(v)
		if bool(t["explode"]) and v == sides and extra < EXPLODE_MOST and thrown.size() < MOST:
			extra += 1
		i += 1
	var kept: Array = []
	kept.resize(rolled.size())
	kept.fill(true)
	var keep := String(t["keep"])
	if not keep.is_empty():
		var order: Array = range(rolled.size())
		order.sort_custom(func(a: int, b: int) -> bool: return int(rolled[a]) > int(rolled[b]) if int(rolled[a]) != int(rolled[b]) else a < b)
		var n := int(t["keep_n"])
		for k in order.size():
			var pos := int(order[k])
			match keep:
				"kh":
					kept[pos] = k < n
				"kl":
					kept[pos] = k >= order.size() - n
				"dh":
					kept[pos] = k >= n
				"dl":
					kept[pos] = k < order.size() - n
	var sum := 0
	var hits := 0
	var names := PackedStringArray()
	for k in rolled.size():
		if not bool(kept[k]):
			continue
		var v := int(rolled[k])
		if not labels.is_empty():
			names.append(labels[v - 1])
			if labels[v - 1].is_valid_int():
				sum += int(labels[v - 1])
			continue
		sum += v
		if _hits(v, String(t["cmp"]), int(t["target"])):
			hits += 1
	return {"count": count, "sides": sides, "rolled": rolled, "kept": kept, "sum": sum, "successes": hits, "labels": names,
		"cmp": String(t["cmp"]), "target": int(t["target"]), "sign": int(t["sign"])}


static func _hits(v: int, cmp: String, target: int) -> bool:
	match cmp:
		">=":
			return v >= target
		"<=":
			return v <= target
		">":
			return v > target
		"<":
			return v < target
		"=":
			return v == target
	return false


## ONE VALUE, AS BODIES ON THE TABLE: a percentile is two tens, its tens die showing 00 to 90 and its units 0 to 9, 00 and 0 being 100.
static func _throw(thrown: Array, sides: int, v: int, labels: PackedStringArray) -> void:
	if sides == 100:
		var units := v % 10
		var tens := (v / 10) % 10
		thrown.append({"shape": 10, "face": tens, "sides": 100, "label": "%d0" % tens if tens > 0 else "00"})
		thrown.append({"shape": 10, "face": units, "sides": 10, "label": str(units)})
		return
	var shape := int(STAND_INS.get(sides, sides))
	# (a ten is printed 0 to 9, its ten shown as 0)
	var face := v % 10 if sides == 10 else v - 1
	# ...A TWO OR A THREE ON A SIX is numbered over: a face of that number, by the die's own value and how many faces carry it
	if shape != sides:
		var over := shape / sides
		face = (v - 1) * over
	var label := labels[v - 1] if not labels.is_empty() else str(v)
	var body := {"shape": shape, "face": face, "sides": sides, "label": label}
	if not labels.is_empty():
		body["labels"] = labels
	thrown.append(body)


## THE ROLL AS ONE LINE, as it is told to an agent: what came up and what it comes to. A die rolled and not counted is said as such.
static func words_of(r: Dictionary) -> String:
	var parts := PackedStringArray()
	for g in r["groups"]:
		var d: Dictionary = g
		var shown := PackedStringArray()
		for k in (d["rolled"] as Array).size():
			var v := str((d["rolled"] as Array)[k])
			shown.append(v if bool((d["kept"] as Array)[k]) else "(%s)" % v)
		var piece := "%dd%d: %s" % [int(d["count"]), int(d["sides"]), ", ".join(shown)]
		if not (d["labels"] as PackedStringArray).is_empty():
			piece = "%dd%d: %s" % [int(d["count"]), int(d["sides"]), ", ".join(d["labels"])]
		elif not String(d["cmp"]).is_empty():
			piece += " - %d at %s%d" % [int(d["successes"]), String(d["cmp"]), int(d["target"])]
		parts.append(piece)
	var line := "; ".join(parts)
	if int(r["flat"]) != 0:
		line += " %s %d" % ["+" if int(r["flat"]) > 0 else "-", absi(int(r["flat"]))]
	if bool(r["counted"]):
		return "%s = %d successes" % [line, int(r["successes"])]
	if not (r["labels"] as PackedStringArray).is_empty() and int(r["total"]) == 0:
		return line
	return "%s = %d" % [line, int(r["total"])]
