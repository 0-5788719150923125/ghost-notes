extends SceneTree

## block_code_check - a block of settings as a code and back ([code]src/data/block_code.gd[/code]). No renderer.
##
##   godot --headless --path . --script res://tests/data/block_code_check.gd
##
## - Every kind a block holds comes back as it went, its type too: whole numbers small, large and negative, decimals
##   (a whole one stays a decimal), switches, null, text in any script, lists and maps nested, long ones, keys that are
##   numbers written plainly and one with a leading zero.
## - The same block is the same code whatever order its keys were set in.
## - A word in the list costs a byte: the same block coded with its words is shorter (control: with none) and reads the
##   same; a code with a word the reader's list lacks is refused.
## - Read as a person types it: either case, dashes and spaces, o for 0, i and l for 1.
## - Refused, never misread: no code, another version, a letter no code has, the last letter cut, and nearly every
##   letter changed (the control: the code itself reads); a block nested past DEEPEST.

var _fails := 0


func _ok(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)


func _initialize() -> void:
	print("block_code_check")
	_round_trip()
	_order()
	_words()
	_typed()
	_refused()
	print("block_code_check: %s" % ("FAILED (%d)" % _fails if _fails > 0 else "ok"))
	quit(1 if _fails > 0 else 0)


func _round_trip() -> void:
	var long_map := {}
	for i in 20:
		long_map["k%d" % i] = i * 1000
	var v := {"small": 7, "edge": 63, "past": 64, "neg": -1, "big": 9007199254740993, "most": 9223372036854775807,
		"least": -9223372036854775807, "f": 0.8, "negf": -3.5, "whole": 2.0, "tiny": 0.000001, "half": -0.5,
		"huge": 1e15, "yes": true, "no": false, "none": null, "text": "héllo ✓ 歌", "empty": "",
		"list": [1, "x", [2, 3.25], {}, []], "long": range(40), "long_map": long_map,
		"place": {"3": 4, "10": "ten", "-2": 1, "01": "a leading zero stays text"}}
	var code := BlockCode.encode(v, [])
	var back := BlockCode.decode(code, [])
	_ok(String(back["why"]).is_empty(), "a block of every kind reads back (%d letters)" % code.length())
	_ok(_same(back["value"], v), "...as it went, each value's type too")
	_ok(code.substr(0, 1) == BlockCode.VERSION and not code.contains("i") and not code.contains("l")
		and not code.contains("o") and not code.contains("u"), "its first letter is the version, and no i, l, o or u")


func _order() -> void:
	var a := {"seed": 5, "parts": {"drums": {"level": -3.0}, "bass": {}}, "likeness": 0.8}
	var b := {"likeness": 0.8, "parts": {"bass": {}, "drums": {"level": -3.0}}, "seed": 5}
	_ok(BlockCode.encode(a, []) == BlockCode.encode(b, []), "the same block in another order is the same code")
	var c := b.duplicate(true)
	c["seed"] = 6
	_ok(BlockCode.encode(a, []) != BlockCode.encode(c, []), "...and one value changed is another (the control)")


func _words() -> void:
	var words := ["seed", "parts", "drums", "bass", "level", "four_floor", "pattern"]
	var v := {"seed": 5, "parts": {"drums": {"pattern": "four_floor", "level": -3.0}, "bass": {}}}
	var with := BlockCode.encode(v, words)
	var without := BlockCode.encode(v, [])
	_ok(with.length() < without.length() * 0.6, "words cost a byte: %d letters with them, %d without" % [with.length(), without.length()])
	_ok(_same(BlockCode.decode(with, words)["value"], v), "...and read back the same")
	var many: Array = []
	for i in 300:
		many.append("w%d" % i)
	var far := {"w5": "w200", "w299": ["w127", "w128"]}
	_ok(_same(BlockCode.decode(BlockCode.encode(far, many), many)["value"], far), "a word past the first 127 reads back")
	var shorter := words.slice(0, 3)
	_ok(not String(BlockCode.decode(with, shorter)["why"]).is_empty(),
		"a code with a word the reader lacks is refused: %s" % BlockCode.decode(with, shorter)["why"])


func _typed() -> void:
	var v := {"seed": 101, "tune": 0.25, "name": "x"}
	var code := BlockCode.encode(v, [])
	var typed := code.to_upper().replace("0", "O").replace("1", "l")
	var spaced := ""
	for i in typed.length():
		spaced += typed[i] + ("-" if i % 4 == 3 else "")
	_ok(_same(BlockCode.decode(spaced + " ", [])["value"], v), "read as typed: %s" % spaced)
	_ok(_same(BlockCode.decode(code.replace("1", "i"), [])["value"], v), "...i for 1")


func _refused() -> void:
	var v := {"seed": 4242, "parts": {"drums": {"level": -3.0}}, "likeness": 0.65, "name": "a song"}
	var code := BlockCode.encode(v, [])
	_ok(_same(BlockCode.decode(code, [])["value"], v), "the control: the code reads")
	for bad in ["", "   ", "9" + code.substr(1), code.substr(0, code.length() - 1), code + "u", code.substr(0, 5)]:
		_ok(not String(BlockCode.decode(bad, [])["why"]).is_empty(), "refused: '%s' (%s)" % [bad, BlockCode.decode(bad, [])["why"]])
	var misread := 0
	var tried := 0
	for i in range(1, code.length()):
		for ch in BlockCode.ALPHABET:
			if ch == code[i]:
				continue
			tried += 1
			var r := BlockCode.decode(code.substr(0, i) + ch + code.substr(i + 1), [])
			if String(r["why"]).is_empty() and not _same(r["value"], v):
				misread += 1
	_ok(misread * 100 <= tried, "a letter changed is refused, never misread: %d of %d read as another block" % [misread, tried])
	var deep: Variant = 1
	for i in BlockCode.DEEPEST + 4:
		deep = [deep]
	_ok(not String(BlockCode.decode(BlockCode.encode(deep, []), [])["why"]).is_empty(), "a block nested past DEEPEST is refused")


## Equal and of the same type, all the way down.
func _same(a: Variant, b: Variant) -> bool:
	if typeof(a) != typeof(b):
		if a is Array and b is Array:
			pass
		else:
			return false
	if a is Dictionary:
		if (a as Dictionary).size() != (b as Dictionary).size():
			return false
		for k in a:
			if not (b as Dictionary).has(k) or not _same(a[k], b[k]):
				return false
		return true
	if a is Array:
		if (a as Array).size() != (b as Array).size():
			return false
		for i in (a as Array).size():
			if not _same(a[i], b[i]):
				return false
		return true
	return a == b
