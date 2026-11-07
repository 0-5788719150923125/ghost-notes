extends Node

## tonemap_check - the tonemapper on the Look card ([Tonemaps], [member Director.tonemap], [LookCard]).
##
##   tests/run_boot_probe.sh tests/show/tonemap_check.gd 90
##
## FILMIC IS THE PICTURE AS IT WAS: dressed at Filmic's preset with nothing adjusted, a set's environment is exactly
## what every set wrote before (Filmic, its own exposure, white 1, contrast and saturation 1) - so the default changes
## nothing on screen.
##
## A CHOICE REACHES EVERY SET HANDED IN, AND THE SET'S OWN EXPOSURE HOLDS: chosen AgX with a stop up, an environment
## dressed before is AgX at twice its own exposure, and chosen again it is still twice, never four times. The control:
## the same arithmetic on what the environment held (the last dressing) compounds.
##
## THE ADJUSTMENTS ARE KEPT FOR EACH TONEMAPPER: AgX moved, Filmic is neutral; back to AgX, its own are there. One put
## back at its preset is forgotten. Out of range is held to the range. A NOTE STARTS FROM NOTHING: reset_show is
## Filmic, nothing adjusted.
##
## THE CARD: its block names the tonemapper and only what was adjusted, round-trips through MiniYaml, and a block that
## names none leaves Filmic; picking on the card sets the Director and shows that tonemapper's own dials. (A probe's
## Settings never reach the disk; the Director's look is put back at the end.)

var _fails: Array = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var was_key := Director.tonemap
	var was_adjust := Director.tonemap_adjust.duplicate(true)
	Director.set_tonemap_all(Tonemaps.DEFAULT, {})
	_filmic()
	_choose()
	_kept()
	_card()
	Director.set_tonemap_all(was_key, was_adjust)
	if _fails.is_empty():
		print("tonemap_check: ALL OK")
		get_tree().quit(0)
		return
	print("tonemap_check: %d FAILURE(S)" % _fails.size())
	for f in _fails:
		print("   ", f)
	get_tree().quit(1)


func _ok(cond: bool, msg: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + msg)
	if not cond:
		_fails.append(msg)


func _filmic() -> void:
	print("-- Filmic is the picture as it was")
	var env := Environment.new()
	Tonemaps.dress(env, 0.82)
	_ok(env.tonemap_mode == Environment.TONE_MAPPER_FILMIC and is_equal_approx(env.tonemap_exposure, 0.82)
		and is_equal_approx(env.tonemap_white, 1.0) and is_equal_approx(env.adjustment_contrast, 1.0)
		and is_equal_approx(env.adjustment_saturation, 1.0) and env.adjustment_enabled,
		"Filmic's preset, nothing adjusted: Filmic at the set's own exposure, white, contrast and saturation 1")
	for key in Tonemaps.REGISTRY:
		var row: Dictionary = Tonemaps.REGISTRY[key]
		_ok(not String(row.get("label", "")).is_empty() and not String(row.get("blurb", "")).is_empty() and row.has("mode"),
			"'%s' has a label, a blurb and a mode" % key)
	for name in Tonemaps.ADJUSTMENTS:
		var a: Dictionary = Tonemaps.ADJUSTMENTS[name]
		_ok(float(a["min"]) <= float(a["default"]) and float(a["default"]) <= float(a["max"]), "'%s' is neutral inside its range" % name)


func _choose() -> void:
	print("-- a choice reaches every set, and its exposure holds")
	var env := Environment.new()
	Tonemaps.dress(env, 0.82)
	Director.set_tonemap("agx")
	Director.set_tonemap_adjust("exposure", 1.0)
	_ok(env.tonemap_mode == Environment.TONE_MAPPER_AGX, "chosen on the Director, a set dressed before is AgX")
	_ok(is_equal_approx(env.tonemap_exposure, 1.64), "a stop up is twice the set's own exposure (%.3f)" % env.tonemap_exposure)
	var compounded := env.tonemap_exposure * 2.0
	Tonemaps.choose("agx", Director.tonemap_adjustments())
	_ok(is_equal_approx(env.tonemap_exposure, 1.64), "chosen again, still twice - never compounded (%.3f)" % env.tonemap_exposure)
	_ok(not is_equal_approx(compounded, 1.64), "CONTROL: from what the environment held, it would compound (%.3f)" % compounded)
	Director.set_tonemap_adjust("contrast", 1.1)
	_ok(is_equal_approx(env.adjustment_contrast, 1.1), "contrast lands on the environment's adjustment")
	var e2 := Environment.new()
	Tonemaps.dress(e2, 1.0)
	_ok(e2.tonemap_mode == Environment.TONE_MAPPER_AGX and is_equal_approx(e2.tonemap_exposure, 2.0),
		"a set made after the choice is dressed as it is")


func _kept() -> void:
	print("-- the adjustments are kept for each")
	Director.set_tonemap("filmic")
	_ok(is_equal_approx(float(Director.tonemap_adjustments()["exposure"]), 0.0), "Filmic, never moved, is neutral")
	Director.set_tonemap("agx")
	_ok(is_equal_approx(float(Director.tonemap_adjustments()["exposure"]), 1.0)
		and is_equal_approx(float(Director.tonemap_adjustments()["contrast"]), 1.1), "back to AgX, its own are there")
	Director.set_tonemap_adjust("saturation", 9.0)
	_ok(is_equal_approx(float(Director.tonemap_adjustments()["saturation"]), 1.5), "out of range is held to it")
	for n in Tonemaps.ADJUSTMENTS:
		Director.set_tonemap_adjust(n, Tonemaps.neutral(n))
	_ok(not Director.tonemap_adjust.has("agx"), "put back at its preset, it is forgotten")
	Director.set_tonemap_adjust("exposure", 0.5)
	Director.reset_show()
	_ok(Director.tonemap == "filmic" and Director.tonemap_adjust.is_empty(), "a note starts from nothing: Filmic, nothing adjusted")
	Director.set_tonemap("bogus")
	_ok(Director.tonemap == "filmic", "an unknown tonemapper is Filmic")


func _card() -> void:
	print("-- the card")
	var card := LookCard.new()
	add_child(card)
	Director.set_tonemap("aces")
	Director.set_tonemap_adjust("exposure", -0.5)
	var block := card.capture()
	_ok(String(block.get("tonemap", "")) == "aces" and (block.get("tonemap_adjust", {}) as Dictionary).keys() == ["aces"],
		"the block names the tonemapper and only what was adjusted (%s)" % str(block.get("tonemap_adjust")))
	var parsed: Dictionary = MiniYaml.parse(MiniYaml.emit({"look": block}))
	var back: Dictionary = (parsed.get("data", {}) as Dictionary).get("look", {})
	Director.reset_show()
	card.apply(back)
	_ok(Director.tonemap == "aces" and is_equal_approx(float(Director.tonemap_adjustments()["exposure"]), -0.5),
		"it round-trips through a note's block")
	_ok(card._tonemap.selected == Tonemaps.REGISTRY.keys().find("aces")
		and is_equal_approx((card._adjust_rows["exposure"]["slider"] as HSlider).value, -0.5),
		"and the card shows it: ACES, its dial at -0.5")
	Director.reset_show()
	card.apply({"filters": {}})
	_ok(Director.tonemap == "filmic", "a block that names no tonemapper leaves Filmic")
	var i := Tonemaps.REGISTRY.keys().find("agx")
	card._tonemap.select(i)
	card._tonemap.item_selected.emit(i)
	_ok(Director.tonemap == "agx", "picking AgX on the card sets the Director")
	(card._adjust_rows["saturation"]["slider"] as HSlider).value = 0.8
	_ok(is_equal_approx(float(Director.tonemap_adjustments()["saturation"]), 0.8), "a dial moved is AgX's adjustment")
	_ok(card._filter_summary.text.begins_with("AgX"), "the summary leads with AgX (%s)" % card._filter_summary.text)
	card._tonemap.select(0)
	card._tonemap.item_selected.emit(0)
	_ok(is_equal_approx((card._adjust_rows["saturation"]["slider"] as HSlider).value, 1.0), "Filmic's dials show its own, neutral")
	_ok(not card._filter_summary.text.begins_with("Filmic") and not card._filter_summary.text.begins_with("AgX"),
		"and at Filmic it names no tonemapper (%s)" % card._filter_summary.text)
	card.queue_free()
