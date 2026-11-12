extends SceneTree

## table_tune_check - the numbers a person has judged, as rows ([TableTune]; next/editing.md step 11).
##
##   godot --headless --path . --script res://tests/table/table_tune_check.gd
##
## What it holds:
##   - told nothing, every row is the number the code had (a show with no `tune:` plays as it did) - each default against the
##     constant it took over;
##   - a number told is taken; one outside a row's bounds is brought inside them and said; a key with no row is said and left
##     out. The control: a show's tune changes the number the table reads;
##   - as a form shows them ([method TableTune.fields] in a [SchemaForm]): a slider per row within its bounds (the control: a row
##     with no bound draws none); each offered by the laws it paces (the control: acts that only turn things are offered none); the
##     panel's Pacing card shown while a section offers a row, a row moved handed back (the control: nothing offered, no card).

var _fails := 0


class Offer extends TuneSection:
	var offered := {}
	var told := {}

	func rows() -> Dictionary:
		return offered

	func values() -> Dictionary:
		return told

	func set_value(key: String, value: Variant) -> String:
		told[key] = value
		return ""


func _initialize() -> void:
	_ok(TableTune.value({}, "slow_most") == TablePaint.SLOW_MOST and TableTune.value({}, "rest_most") == TablePaint.REST_MOST
		and TableTune.value({}, "move_pace") == TablePaint.MOVE_PACE and TableTune.value({}, "laid_rest") == TableWork.LAID_REST,
		"told nothing, every row is the number the code had")
	var safe := TableTune.sanitize({"slow_most": 3.5, "rest_most": 90, "pace_of_tide": 2, "move_pace": "fast"})
	var v: Dictionary = safe["values"]
	var said := " ".join(safe["notes"])
	_ok(float(v.get("slow_most", 0.0)) == 3.5, "a number told is taken")
	_ok(float(v.get("rest_most", 0.0)) == float(TableTune.ROWS["rest_most"]["most"]) and said.contains("rest_most"), "one outside its bounds is brought inside them, and said")
	_ok(not v.has("pace_of_tide") and said.contains("pace_of_tide") and not v.has("move_pace") and said.contains("move_pace"),
		"a key with no row, and a value that is no number, are said and left out")
	_ok(TableTune.value(v, "slow_most") != TableTune.value({}, "slow_most"), "the control: a show's tune changes the number the table reads")
	# As a form (the Episode card's rows): a slider per row, its bounds the row's, a number told standing where it was told
	var form := SchemaForm.new()
	form.show_fields(TableTune.fields(), {"slow_most": 3.0})
	var sliders := form.find_children("*", "HSlider", true, false)
	var first: HSlider = sliders[0] if not sliders.is_empty() else null
	_ok(sliders.size() == TableTune.ROWS.size() and first != null and first.min_value == 1.0 and first.max_value == 5.0 and first.value == 3.0,
		"as a form, each row a slider within its bounds, a number told where it was told (%d sliders)" % sliders.size())
	var loose := TableTune.fields()
	(loose["rest_most"] as Dictionary).erase("max")
	form.show_fields(loose, {})
	_ok(form.find_children("*", "HSlider", true, false).size() == TableTune.ROWS.size() - 1, "the control: a row with no bound draws no slider")
	form.free()
	# Offered by what the acts use: the brush's numbers to a show that paints, the laid rest to one that sets things down - the control
	# a show whose acts only turn things is offered none
	_ok(TableTune.fields(["paint"]).keys() == ["slow_most", "rest_most", "move_pace"] and TableTune.fields(["carry", "turn"]).keys() == ["laid_rest"],
		"each law brings the numbers that pace it: %s, %s" % [TableTune.fields(["paint"]).keys(), TableTune.fields(["carry", "turn"]).keys()])
	_ok(TableTune.fields(["turn", "clock"]).is_empty(), "the control: acts that only turn things are offered nothing to pace")
	# The pacing card: shown while a section offers a row, a row moved handed to its section - the control: nothing offered, no card
	var offer := Offer.new()
	offer.offered = TableTune.fields(["paint"])
	var card := Card.new("check.pacing", "Pacing", &"producer")
	root.add_child(card)
	var pacing := PacingCard.new(func() -> Array: return [offer])
	card.body.add_child(pacing)
	pacing.refresh()
	_ok(card.visible and pacing.row_count() == 3, "the Pacing card shows what is offered (%d rows)" % pacing.row_count())
	pacing._form.edited.emit("slow_most", 3.0)
	_ok(offer.told.get("slow_most") == 3.0, "a row moved is handed to the section that offers it")
	offer.offered = {}
	pacing.refresh()
	_ok(not card.visible and pacing.row_count() == 0, "the control: nothing offered, no Pacing card")
	card.free()
	if _fails == 0:
		print("table_tune_check: ALL OK")
		quit(0)
		return
	print("table_tune_check: %d FAILED" % _fails)
	quit(1)


func _ok(cond: bool, msg: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + msg)
	if not cond:
		_fails += 1
