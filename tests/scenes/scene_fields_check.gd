extends Node

## scene_fields_check - WHAT A SCENE CAN BE TOLD ([method GhostScene.choice], [method GhostScene.number],
## [method GhostScene.fields_of]; next/structure.md, steps 27 and 28). Every scene with settings - the
## rotation's and any other a storyboard may name - each setting in turn:
##
##   tests/run_boot_probe.sh tests/scenes/scene_fields_check.gd 600
##
##   - ITS ROWS ARE WHOLE: a label, a blurb, and either the type "choice" with options from a table of the
##     scene that has some (for options that are indices, names for every one of them), or the type
##     "num" with a range of two numbers, low to high;
##   - TOLD, TAKEN: told an option the seed would not have drawn (a number: the end of its range farther
##     from the seed's), the scene comes out as that and as another scene than the seed's - a number on
##     at least one of the builds that draw it (a blizzard's veil is drawn only when there is a blizzard,
##     and a ring's width matters only to a ring), searched for over seeds;
##   - TELLING MOVES NOTHING ELSE: told the very option the seed draws (a number: its whole range), the
##     scene is the seed's scene to the last member, inside what it made too - the die was thrown either
##     way, so every later draw is where it was;
##   - A NUMBER IS HELD TO WHAT IT IS TOLD: told the upper half of its range, it lands in it; told past
##     its range, it stops at the end;
##   - THE INSPECTOR'S ROWS ([method SceneRoster.fields_of]): unset first, then each option by its name;
##     a number's row shows its range while unset;
##   - THE CONTROL: a made-up scene that picks from its table and draws its number itself, never asking
##     `choice` or `number`, must fail "told, taken" for both.
##
## That a scene told nothing rolls exactly what it rolled before the settings existed was checked when
## they came in, by dumping every scene and motion on four seeds before and after.

const SEED := 7
## The seeds a number is looked for on, when a build need not draw it: 7 first, then the rest in order.
const SEEDS := 48
## A scene's state is written out this deep into what it made (its lens, its layers, its particles).
const DEPTH := 2

var _fails := 0


func _ready() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + what)
	if not cond:
		_fails += 1


func _run() -> void:
	var scripts: Array = []
	var behaviors := {}
	for row in SceneRoster.SCENES:
		var s: Script = row["script"]
		if not scripts.has(s):
			scripts.append(s)
			behaviors[s] = String(row["behavior"])
	# ...and every scene file a storyboard may name that has settings, in the rotation or not
	for f in DirAccess.get_files_at("res://src/scenes"):
		if f.ends_with(".gd"):
			var s := SceneRoster.script_of(f.get_basename())
			if s != null and not scripts.has(s) and not GhostScene.fields_of(s).is_empty():
				scripts.append(s)
				behaviors[s] = "drift"
	var whole := 0
	var broken: PackedStringArray = []
	var taken := 0
	var not_taken: PackedStringArray = []
	var still := 0
	var moved: PackedStringArray = []
	var settings := 0
	var numbers := 0
	var held := 0
	var loose: PackedStringArray = []
	var first_num: Array = []
	for s in scripts:
		var fields := GhostScene.fields_of(s)
		var name := String(s.resource_path).get_file().get_basename()
		for key in fields:
			settings += 1
			var row: Dictionary = fields[key]
			if String(row.get("type", "")) == "num":
				var n := _number_setting(s, behaviors[s], String(key), row)
				whole += 1 if n["whole"] else 0
				taken += 1 if n["taken"] else 0
				still += 1 if n["still"] else 0
				numbers += 1
				held += 1 if n["held"] else 0
				if not n["whole"]:
					broken.append("%s.%s" % [name, key])
				if not n["taken"]:
					not_taken.append("%s.%s" % [name, key])
				if not n["still"]:
					moved.append("%s.%s" % [name, key])
				if not n["held"]:
					loose.append("%s.%s" % [name, key])
				if first_num.is_empty():
					first_num = [name, String(key), row["range"]]
				continue
			var options := GhostScene.options_of(s, String(key))
			var names := GhostScene.table_of(s, String(row.get("names", "")))
			var ok_row := not String(row.get("label", "")).is_empty() and not String(row.get("blurb", "")).is_empty() \
				and String(row.get("type", "")) == "choice" and not options.is_empty() and row.get("default") == null
			if row.has("names"):
				for o in options:
					ok_row = ok_row and typeof(o) == TYPE_INT and int(o) < names.size()
			if ok_row:
				whole += 1
			else:
				broken.append("%s.%s" % [name, key])
				continue
			var r := _told(s, behaviors[s], String(key), options)
			taken += 1 if r["taken"] else 0
			still += 1 if r["still"] else 0
			if not r["taken"]:
				not_taken.append("%s.%s" % [name, key])
			if not r["still"]:
				moved.append("%s.%s" % [name, key])
	print("every setting of every scene (%d)" % settings)
	_ok(settings > 40 and whole == settings, "its rows are whole (%d of %d; %s)" % [whole, settings, ", ".join(broken)])
	_ok(taken == whole, "told an option the seed would not draw, the scene takes it (%d of %d; not: %s)" % [taken, whole, ", ".join(not_taken)])
	_ok(still == whole, "told the option the seed draws, nothing else moves (%d of %d; moved: %s)" % [still, whole, ", ".join(moved)])
	_ok(numbers > 0 and held == numbers, "a number is held to the half it is told, and stops at its range's end (%d of %d; not: %s)"
		% [held, numbers, ", ".join(loose)])

	print("the inspector's rows")
	var snow := SceneRoster.fields_of("snowfall")
	_ok(snow.has("snow") and (snow["snow"]["options"] as Array) == ["", "powder", "flurry", "blizzard", "hoar"]
		and String(snow["snow"]["type"]) == "enum", "unset first, then each option (%s)" % str(snow.get("snow", {}).get("options", [])))
	var fractal := SceneRoster.fields_of("fractal_zoom")
	_ok(fractal.has("family") and (fractal["family"]["options"] as Array).has("julia"),
		"an option that is an index shows its name (%s)" % str(fractal.get("family", {}).get("options", [])))
	var told_julia := _build(SceneRoster.script_of("fractal_zoom"), "drift", {"family": "julia"})
	_ok(int(told_julia.chosen.get("family", -1)) == 1, "...and is told by it (julia: %s)" % str(told_julia.chosen.get("family")))
	told_julia.free()
	if not first_num.is_empty():
		var num_rows := SceneRoster.fields_of(String(first_num[0]))
		var nrow: Dictionary = num_rows.get(first_num[1], {})
		_ok(String(nrow.get("type", "")) == "num" and nrow.get("default") == first_num[2],
			"a number's row shows its range while unset (%s.%s: %s)" % [first_num[0], first_num[1], str(nrow.get("default"))])

	print("the control")
	var gd := GDScript.new()
	gd.source_code = "extends GhostScene\nconst KINDS := [\"a\", \"b\", \"c\"]\nconst FIELDS := {\"kind\": {\"label\": \"Kind\", " \
		+ "\"type\": \"choice\", \"options\": \"KINDS\", \"default\": null, \"blurb\": \"x\"}, \"size\": {\"label\": " \
		+ "\"Size\", \"type\": \"num\", \"range\": [1.0, 2.0], \"default\": null, \"blurb\": \"x\"}}\nvar kind := \"\"\n" \
		+ "var girth := 0.0\nfunc build_params(rng: RandomNumberGenerator) -> Dictionary:\n\tkind = KINDS[rng.randi() % KINDS.size()]\n" \
		+ "\tchosen[\"kind\"] = kind\n\tgirth = rng.randf_range(1.0, 2.0)\n\tchosen[\"size\"] = girth\n" \
		+ "\treturn {\"kind\": kind}\n"
	gd.reload()
	var c := _told(gd, "drift", "kind", ["a", "b", "c"])
	_ok(not c["taken"], "a scene that picks from its table itself, never asking, is caught")
	var cn := _number_setting(gd, "drift", "size", GhostScene.fields_of(gd)["size"])
	_ok(not cn["taken"], "a scene that draws its number itself, never asking, is caught")

	print("scene_fields_check: %s" % ("ALL OK" if _fails == 0 else "%d FAILED" % _fails))
	get_tree().quit(0 if _fails == 0 else 1)


## Setting [param key] of [param script] told: `taken` - an option the seed does not draw is what the
## scene came out as, and the scene differs; `still` - the option it draws, told, leaves it the same.
func _told(script: Script, behavior: String, key: String, options: Array) -> Dictionary:
	var plain := _build(script, behavior, {})
	var drawn: Variant = plain.chosen.get(key)
	var base := _dump(plain)
	plain.free()
	var other: Variant = null
	for o in options:
		if str(o) != str(drawn):
			other = o
			break
	var same := _build(script, behavior, {key: drawn})
	var still := _dump(same) == base and str(same.chosen.get(key)) == str(drawn)
	same.free()
	var taken := false
	if other != null:
		var told := _build(script, behavior, {key: other})
		taken = str(told.chosen.get(key)) == str(other) and _dump(told) != base
		told.free()
	return {"taken": taken, "still": still}


## The number [param key] of [param script] ([param row] its FIELDS row), on the builds that draw it (up
## to four, over [constant SEEDS] seeds): `whole` - its row is; `taken` - on one of them, told the end of
## its range farther from the seed's draw, it comes out as that end and the scene differs; `still` - on
## each, told its whole range, the scene is the seed's; `held` - on each, told its upper half it lands in
## it, and told past its top it stops there. A number no build draws is none of these.
func _number_setting(script: Script, behavior: String, key: String, row: Dictionary) -> Dictionary:
	var out := {"whole": false, "taken": false, "still": true, "held": true}
	var r: Variant = row.get("range")
	out["whole"] = not String(row.get("label", "")).is_empty() and not String(row.get("blurb", "")).is_empty() \
		and r is Array and (r as Array).size() == 2 and float(r[0]) < float(r[1]) and row.get("default") == null
	if not out["whole"]:
		return {"whole": false, "taken": false, "still": false, "held": false}
	var lo := float(r[0])
	var hi := float(r[1])
	var drawn_on := 0
	var seeds: Array = [SEED]
	for s in range(1, SEEDS + 1):
		if s != SEED:
			seeds.append(s)
	for s in seeds:
		var plain := _build(script, behavior, {}, s)
		var drawn: Variant = plain.chosen.get(key)
		if drawn == null:
			plain.free()
			continue
		drawn_on += 1
		var base := _dump(plain)
		plain.free()
		var far := hi if float(drawn) - lo < hi - float(drawn) else lo
		var told := _build(script, behavior, {key: far}, s)
		out["taken"] = out["taken"] or (told.chosen.get(key) != null and is_equal_approx(float(told.chosen[key]), far) and _dump(told) != base)
		told.free()
		var same := _build(script, behavior, {key: [r[0], r[1]]}, s)
		out["still"] = out["still"] and _dump(same) == base and str(same.chosen.get(key)) == str(drawn)
		same.free()
		var mid := (lo + hi) * 0.5
		var upper := _build(script, behavior, {key: [mid, hi]}, s)
		var u: Variant = upper.chosen.get(key)
		upper.free()
		var past := _build(script, behavior, {key: hi + (hi - lo)}, s)
		var p: Variant = past.chosen.get(key)
		past.free()
		var least := floorf(mid) if typeof(r[0]) == TYPE_INT else mid - 1e-9
		out["held"] = out["held"] and u != null and float(u) >= least and float(u) <= hi + 1e-9 \
			and p != null and is_equal_approx(float(p), hi)
		if drawn_on >= 4 or (out["taken"] and drawn_on >= 2):
			break
	if drawn_on == 0:
		return {"whole": true, "taken": false, "still": false, "held": false}
	return out


func _build(script: Script, behavior: String, set: Dictionary, seed := SEED) -> GhostScene:
	var sc: GhostScene = script.new()
	if not set.is_empty():
		sc.spec = {"set": set}
	sc.init_with_seed(seed, behavior)
	return sc


## A scene's state as text: what it rolled and every plain member, and [constant DEPTH] deep into the
## objects it made (their script's members; an object without one by its class - their ids change).
func _dump(sc: GhostScene) -> String:
	var out: PackedStringArray = [_text(sc.params, 0)]
	for prop in sc.get_property_list():
		if int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue
		var nm := String(prop["name"])
		if nm in ["spec", "feed", "params", "chosen"]:
			continue
		out.append("%s=%s" % [nm, _text(sc.get(nm), 0)])
	return "\n".join(out)


func _text(v: Variant, depth: int) -> String:
	match typeof(v):
		TYPE_OBJECT:
			if v == null or not is_instance_valid(v):
				return "<null>"
			if depth >= DEPTH or (v as Object).get_script() == null or v is ShowFeed:
				return "<%s>" % v.get_class()
			var parts: PackedStringArray = []
			for prop in (v as Object).get_property_list():
				if int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE != 0:
					parts.append("%s=%s" % [prop["name"], _text((v as Object).get(prop["name"]), depth + 1)])
			return "<%s %s>" % [v.get_class(), " ".join(parts)]
		TYPE_ARRAY:
			var parts: PackedStringArray = []
			for x in v:
				parts.append(_text(x, depth))
			return "[" + ", ".join(parts) + "]"
		TYPE_DICTIONARY:
			var parts: PackedStringArray = []
			for k in v:
				parts.append("%s: %s" % [str(k), _text(v[k], depth)])
			return "{" + ", ".join(parts) + "}"
	return var_to_str(v)
