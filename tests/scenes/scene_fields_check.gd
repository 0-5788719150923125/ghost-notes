extends Node

## scene_fields_check - WHAT A SCENE CAN BE TOLD ([method GhostScene.choice], [method GhostScene.fields_of];
## next/structure.md, step 27). Every scene with settings - the rotation's and any other a storyboard
## may name - each setting in turn:
##
##   tests/run_boot_probe.sh tests/scenes/scene_fields_check.gd 600
##
##   - ITS ROWS ARE WHOLE: a label, a blurb, the type "choice", options from a table of the scene that
##     has some - and, for options that are indices, names for every one of them;
##   - TOLD, TAKEN: told an option the seed would not have drawn, the scene comes out as that option and
##     as another scene than the seed's;
##   - TELLING MOVES NOTHING ELSE: told the very option the seed draws, the scene is the seed's scene to
##     the last member - the die was thrown either way, so every later draw is where it was;
##   - THE INSPECTOR'S ROWS ([method SceneRoster.fields_of]): unset first, then each option by its name;
##   - THE CONTROL: a made-up scene that picks from its table itself, never asking `choice`, must fail
##     "told, taken".
##
## That a scene told nothing rolls exactly what it rolled before the settings existed was checked when
## they came in, by dumping all 71 scenes and motions on four seeds before and after.

const SEED := 7

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
	for s in scripts:
		var fields := GhostScene.fields_of(s)
		var name := String(s.resource_path).get_file().get_basename()
		for key in fields:
			settings += 1
			var row: Dictionary = fields[key]
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

	print("the control")
	var gd := GDScript.new()
	gd.source_code = "extends GhostScene\nconst KINDS := [\"a\", \"b\", \"c\"]\nconst FIELDS := {\"kind\": {\"label\": \"Kind\", " \
		+ "\"type\": \"choice\", \"options\": \"KINDS\", \"default\": null, \"blurb\": \"x\"}}\nvar kind := \"\"\n" \
		+ "func build_params(rng: RandomNumberGenerator) -> Dictionary:\n\tkind = KINDS[rng.randi() % KINDS.size()]\n" \
		+ "\tchosen[\"kind\"] = kind\n\treturn {\"kind\": kind}\n"
	gd.reload()
	var c := _told(gd, "drift", "kind", ["a", "b", "c"])
	_ok(not c["taken"], "a scene that picks from its table itself, never asking, is caught")

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


func _build(script: Script, behavior: String, set: Dictionary) -> GhostScene:
	var sc: GhostScene = script.new()
	if not set.is_empty():
		sc.spec = {"set": set}
	sc.init_with_seed(SEED, behavior)
	return sc


## A scene's state as text: what it rolled and every plain member, objects by class (their ids change).
func _dump(sc: GhostScene) -> String:
	var out: PackedStringArray = [_text(sc.params)]
	for prop in sc.get_property_list():
		if int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue
		var nm := String(prop["name"])
		if nm in ["spec", "feed", "params", "chosen"]:
			continue
		out.append("%s=%s" % [nm, _text(sc.get(nm))])
	return "\n".join(out)


func _text(v: Variant) -> String:
	match typeof(v):
		TYPE_OBJECT:
			return "<%s>" % (v.get_class() if v != null else "null")
		TYPE_ARRAY:
			var parts: PackedStringArray = []
			for x in v:
				parts.append(_text(x))
			return "[" + ", ".join(parts) + "]"
		TYPE_DICTIONARY:
			var parts: PackedStringArray = []
			for k in v:
				parts.append("%s: %s" % [str(k), _text(v[k])])
			return "{" + ", ".join(parts) + "}"
	return var_to_str(v)
