extends SceneTree

## table_actions_check - the table's verbs as one registry (next/notes.md step 9, "Actions are a
## registry"), which changed no behavior: cards_check, table_wash_check and table_place_check run
## unchanged through it. This holds the registry itself.
##
##   godot --headless --path . --script tests/table_actions_check.gd
##
## THE RESTS ARE THE OLD SUMS, every case of them: the voice waits exactly as long as it did - the
## shuffle's lead, a first draw's push, a draw after a shown card's lay, a first jumper, a later one,
## the spread after a shown card and with none.
##
## THE MOMENTS AGREE, both ways: every moment a verb makes is one the air knows
## ([constant CardTable.MOMENTS]), and every moment the air knows is made by some verb.
##
## THE MARKS ARE THE WRITTEN VERBS: each written verb parses as a mark, a verb performed between them
## (the lay, the push) does not, and neither does a verb nobody registered.

var _fails: Array = []


func _initialize() -> void:
	print("-- the rests")
	var cases := [["shuffle", false, TableActions.SHUFFLE_LEAD], ["draw", false, TableActions.PUSH + TableActions.DRAW],
		["draw", true, TableActions.LAY + TableActions.DRAW], ["jumper", false, TableActions.JUMP], ["jumper", true, TableActions.LAY + TableActions.JUMP],
		["spread", true, TableActions.LAY + TableActions.SETTLE], ["spread", false, TableActions.SETTLE]]
	for c in cases:
		var got := TableActions.rest_of(String(c[0]), bool(c[1]))
		_ok(is_equal_approx(got, float(c[2])), "%s %s: %.2f s (was %.2f)" % [c[0],
			"after a shown card" if c[1] else "with nothing shown", got, float(c[2])])
	_ok(CardReading.rest_of("draw", true) == TableActions.rest_of("draw", true), "CardReading's rest is the registry's")
	_ok(TableActions.lead_of("draw", true) == TableActions.PUSH and TableActions.lead_of("jumper", true) == 0.0 and TableActions.lead_of("draw", false) == TableActions.LAY,
		"a card's lead: the push for a first draw, none for a first jumper, the lay after a card")
	print("-- the moments")
	for k in TableActions.REGISTRY:
		for m in TableActions.REGISTRY[k]["moments"]:
			_ok(CardTable.MOMENTS.has(m), "%s makes '%s', which the air knows" % [k, m])
	for m in CardTable.MOMENTS:
		_ok(TableActions.moments().has(m), "the air's '%s' is made by some verb" % m)
	print("-- the marks")
	_ok(TableActions.written() == ["shuffle", "open", "draw", "jumper", "spread", "deal", "fan", "show", "tap", "untap", "flip"],
		"the written verbs are the registry's eleven: tarot's four and a collection's seven (%s)" % str(TableActions.written()))
	for v in TableActions.written():
		var line := "<!-- table: %s 2 -->" % v if TableActions.takes_card(v) else "<!-- table: %s -->" % v
		var p := CardReading.parse(line + "\n\nWords.\n")
		_ok((p["passages"] as Array).any(func(x: Dictionary) -> bool: return String(x["kind"]) == v),
			"'%s' is read as a mark" % line)
	for v in ["lay", "push", "square", "gather"]:
		var p := CardReading.parse("<!-- table: %s -->\n\nWords.\n" % v)
		_ok((p["actions"] as Array).is_empty(), "'%s' is not a mark a reading writes" % v)
	_ok(CardReading.is_reading("<!-- table: spread -->") and not CardReading.is_reading("<!-- table: lay -->"),
		"a reading is known by a written verb's mark")
	var composed := CardReading.compose([{"kind": "shuffle"}, {"kind": "draw", "card": 1, "text": "One."},
		{"kind": "spread"}])
	_ok(composed.contains("<!-- table: shuffle -->") and composed.contains("<!-- table: draw 1 -->")
		and composed.contains("<!-- table: spread -->"), "compose writes a card only for a verb that takes one")
	print("-- a reader writes words, never the table's actions")
	var reply := "Oh, look at this.\n<!-- table: draw 2 -->\n<!-- delivery: quicker -->\nThe second card. <!-- a note to myself -->\n<!-- speaker: Familiar -->\nHa."
	var clean := CardProducer.clean_spoken(reply)
	_ok(not clean.contains("table:") and not clean.contains("a note to myself"), "a table mark and a stray note in a reply are dropped")
	_ok(clean.contains("<!-- delivery: quicker -->") and clean.contains("<!-- speaker: Familiar -->"),
		"the voice's own marks stay")
	_ok((CardReading.parse(CardReading.compose([{"kind": "shuffle", "text": clean}]))["actions"] as Array).size() == 1,
		"composed into a script, the reply deals nothing")
	if _fails.is_empty():
		print("table_actions_check: ALL OK")
		quit(0)
		return
	print("table_actions_check: %d FAILURE(S)" % _fails.size())
	for f in _fails:
		print("   ", f)
	quit(1)


func _ok(cond: bool, msg: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + msg)
	if not cond:
		_fails.append(msg)
