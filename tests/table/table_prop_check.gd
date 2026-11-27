extends SceneTree

## The table itself as a prop ([TableProp], [Tables], [TableRefine]): what holds it up, a top's material written out in it, and
## every property a person sets written back into what the set dresser wrote.
##
##   godot --headless --path . --script tests/table/table_prop_check.gd
##
## - A base: a top that names none stands on legs (a rectangle or an oval) or a pedestal (round, many-sided); one named is kept, and
##   one the vocabulary does not have is the default (control). Built, a base on legs is four legs and an apron's four sides down to
##   the floor [constant Tables.HIGH] below, casting no shadow; a base of none builds nothing (control); and the built `bounds` are the
##   top and cloths alone, the same with a base as without.
## - A top's material written out in it is its own look, its color kept; a name the table has no material of is a dark wood
##   (control).
## - Every property of the top and of a cloth, set and made safe again, reads back as it was set ([method TableProp.top_values],
##   [method TableProp.cloth_values]); a round top's width is both its sizes; a color set darkens its second color with it; a cloth
##   set on a table that wrote no cloths is set on the default cloth. A value of null leaves the table as it was (control).
## - What a person is offered fits the top: a round top has no depth or corners, the painting no color, a cloth of the painting no
##   colors; a rectangle of wood has every row (control).
## - Built alone, the table stands on the floor at y 0, its top [constant Tables.HIGH] over it.
## - An agent's refining lands as a hand's version of the table: its top and cloths replaced, every thing on the table kept, the
##   table before it a version back, kept from Generate; an answer that is no table, or changes nothing, writes nothing (controls).
##   Its prompt renders whole.

const ROOT := "user://table_prop_check"

var _fails: Array = []


func _initialize() -> void:
	_bases()
	_materials()
	_properties()
	_rows()
	_made()
	_refine()
	print("")
	if _fails.is_empty():
		print("table_prop_check: ALL OK")
		quit(0)
		return
	for f in _fails:
		print("table_prop_check: FAIL - ", f)
	print("table_prop_check: %d FAILED" % _fails.size())
	quit(1)


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails.append(what)


func _safe(top: Variant, layers: Variant = null, mats := {}) -> Dictionary:
	return Tables.sanitize(top, layers, mats, ["#3a2a20", "#c9a227", "#e8dcc0"])


func _bases() -> void:
	_ok(String(_safe({"shape": "rect", "size": [190, 85]})["top"]["base"]) == "legs", "a rectangle that names no base stands on legs")
	_ok(String(_safe({"shape": "round", "size": [140]})["top"]["base"]) == "pedestal", "a round top that names none stands on a pedestal")
	_ok(String(_safe({"shape": "rect", "base": "trestle"})["top"]["base"]) == "trestle", "a base named is kept")
	_ok(String(_safe({"shape": "rect", "base": {"kind": "pedestal"}})["top"]["base"]) == "pedestal", "a base written as {kind} is kept")
	_ok(String(_safe({"shape": "rect", "base": "a stack of crates"})["top"]["base"]) == "legs", "control: a base it has no word for is the default")
	var legs := _safe({"shape": "rect", "size": [190, 85], "base": "legs"})
	var none := _safe({"shape": "rect", "size": [190, 85], "base": "none"})
	var built := Tables.build(legs, 7)
	var bare := Tables.build(none, 7)
	var base: Node3D = (built["node"] as Node3D).get_node_or_null("Base")
	_ok(base != null and base.get_child_count() == 8, "a base on legs is four legs and an apron's four sides (%d)" % (base.get_child_count() if base != null else -1))
	if base != null:
		var lowest := INF
		var shadows := false
		for c in base.get_children():
			var mi := c as MeshInstance3D
			var box := mi.get_aabb()
			lowest = minf(lowest, mi.position.y + box.position.y)
			shadows = shadows or mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_ok(absf(lowest + Tables.HIGH) < 0.002, "the legs reach the floor (%.3f)" % lowest)
		_ok(not shadows, "the base casts no shadow")
	_ok((bare["node"] as Node3D).get_node_or_null("Base") == null, "control: a base of none builds nothing")
	_ok((built["bounds"] as AABB).is_equal_approx(bare["bounds"]), "the built bounds are the top and its cloths alone")
	for b in [built, bare]:
		(b["node"] as Node).free()
	var round_built := Tables.build(_safe({"shape": "round", "size": [140]}), 3)
	var ped: Node3D = (round_built["node"] as Node3D).get_node_or_null("Base")
	_ok(ped != null and ped.get_child_count() == 2, "a pedestal is a column on a foot")
	(round_built["node"] as Node).free()
	var tr := Tables.build(_safe({"shape": "rect", "size": [200, 90], "base": "trestle"}), 3)
	var tb: Node3D = (tr["node"] as Node3D).get_node_or_null("Base")
	_ok(tb != null and tb.get_child_count() == 7, "a trestle base is two posts, their bars and a stretcher")
	(tr["node"] as Node).free()


func _materials() -> void:
	var own: Dictionary = _safe({"material": {"kind": "stone", "color": "#556677", "polish": 0.8}})["top"]
	_ok(String(own["material"]) == Tables.TOP_OWN and String(own["look"]["kind"]) == "stone" and String(own["look"]["color"]) == "#556677"
		and is_equal_approx(float(own["look"]["polish"]), 0.8), "a material written out in the top is its own look")
	var missing: Dictionary = _safe({"material": "the walnut"})["top"]
	_ok(String(missing["material"]) == String(Tables.DEFAULT_TOP["material"]) and String(missing["look"]["kind"]) == "wood",
		"control: a material the table has none of is a dark wood")


func _properties() -> void:
	var raw := {"shape": "rect", "size": [190.0, 85.0], "edge": "eased", "thickness": 4.0, "material": "painting",
		"boards": {"width": 18.0, "turn": 0.0}}
	var made: Dictionary = _safe(raw)["top"]
	var sets := {"width": 220.0, "depth": 100.0, "corner": 6.0, "edge": "ogee", "thickness": 6.5, "base": "trestle", "made": "stone"}
	var bad: Array = []
	for f in sets:
		var t := TableProp.set_top(raw, made, f, sets[f])
		var back := TableProp.top_values(_safe(t)["top"])
		if str(back[f]) != str(sets[f]) and not (typeof(back[f]) == TYPE_FLOAT and is_equal_approx(float(back[f]), float(sets[f]))):
			bad.append("%s: %s" % [f, back[f]])
	var wood := TableProp.set_top(raw, made, "made", "wood")
	var wood_made: Dictionary = _safe(wood)["top"]
	for f in {"color": "#224466", "polish": 0.9, "wear": 0.6, "boards": 24.0}:
		var v: Variant = {"color": "#224466", "polish": 0.9, "wear": 0.6, "boards": 24.0}[f]
		var back := TableProp.top_values(_safe(TableProp.set_top(wood, wood_made, f, v))["top"])
		if str(back[f]) != str(v) and not (typeof(back[f]) == TYPE_FLOAT and is_equal_approx(float(back[f]), float(v))):
			bad.append("%s: %s" % [f, back[f]])
	_ok(bad.is_empty(), "every property of the top reads back as set (%s)" % ", ".join(PackedStringArray(bad.map(func(b): return str(b)))))
	var colored: Dictionary = _safe(TableProp.set_top(wood, wood_made, "color", "#ffffff"))["top"]
	_ok(String(colored["look"]["color2"]) != String(wood_made["look"]["color2"]) and Color.html(String(colored["look"]["color2"])).v < 0.9,
		"a color set darkens the second color with it")
	var round_raw := {"shape": "round", "size": [140.0]}
	var rt := TableProp.set_top(round_raw, _safe(round_raw)["top"], "width", 160.0)
	_ok(rt["size"] == [160.0, 160.0], "a round top's width is both its sizes")
	_ok(TableProp.set_top(raw, made, "width", null) == raw, "control: a null value leaves the top as it was")
	_ok(TableProp.set_top({}, _safe(null)["top"], "edge", "bevel").get("material") == Tables.DEFAULT_TOP["material"],
		"a top the set dresser never wrote is set on the default top")
	# the cloths
	var cloths := [{"name": "the runner", "outline": "rect", "size": [200, 40], "fabric": "linen", "pattern": {"kind": "stripes", "colors": ["#112233", "#445566", "#778899"], "scale": 4}}]
	var made_l: Array = _safe(raw, cloths)["layers"]
	var lsets := {"fabric": "velvet", "pattern": "checks", "color": "#aa0000", "color2": "#00aa00", "scale": 12.0, "width": 180.0,
		"depth": 50.0, "turn": 45.0, "fringe": 6.0, "sheen": 0.9}
	var lbad: Array = []
	for f in lsets:
		var ls := TableProp.set_cloth(cloths, made_l, 0, f, lsets[f])
		var back := TableProp.cloth_values(_safe(raw, ls)["layers"][0])
		if str(back[f]) != str(lsets[f]) and not (typeof(back[f]) == TYPE_FLOAT and is_equal_approx(float(back[f]), float(lsets[f]))):
			lbad.append("%s: %s" % [f, back[f]])
	_ok(lbad.is_empty(), "every property of a cloth reads back as set (%s)" % ", ".join(PackedStringArray(lbad.map(func(b): return str(b)))))
	var third: Array = TableProp.set_cloth(cloths, made_l, 0, "color", "#aa0000")[0]["pattern"]["colors"]
	_ok(third.size() == 3 and String(third[2]) == "#778899", "a cloth's color set keeps its other colors")
	var dflt := TableProp.set_cloth(null, _safe(raw)["layers"], 0, "fabric", "silk")
	_ok(dflt.size() == 1 and String((dflt[0] as Dictionary)["fabric"]) == "silk", "a cloth set on a table that wrote none is the default cloth")
	_ok(TableProp.set_cloth(cloths, made_l, 0, "fabric", null) == cloths, "control: a null value leaves the cloths as they were")


func _rows() -> void:
	var rnd := TableProp.top_rows(_safe({"shape": "round", "size": [140], "material": "painting"})["top"])
	_ok(not rnd.has("depth") and not rnd.has("corner") and not rnd.has("color") and rnd.has("width"),
		"a round top of the painting has no depth, corners or color")
	var all := TableProp.top_rows(_safe({"shape": "rect", "size": [190, 85], "material": {"kind": "wood", "color": "#5c3821"}})["top"])
	_ok(all.size() == TableProp.FIELDS.size(), "control: a rectangle of wood has every row (%d of %d)" % [all.size(), TableProp.FIELDS.size()])
	_ok(float(all["width"]["default"]) == 190.0 and String(all["made"]["default"]) == "wood", "each row stands at what the table is now")
	var painted := TableProp.cloth_rows(_safe(null)["layers"][0])
	_ok(not painted.has("color") and not painted.has("color2") and painted.has("fabric"), "a cloth of the painting has no colors")
	var line := TableProp.line_of(_safe({"shape": "rect", "size": [190, 85], "base": "trestle"})["top"])
	_ok(line.contains("190 x 85") and line.contains("trestles"), "the table's line says its size and what holds it up (%s)" % line)


func _made() -> void:
	var spec := _safe({"shape": "rect", "size": [160, 80], "base": "legs"})
	var m := TableProp.made(spec, 5)
	var box: AABB = m["size"]
	_ok(absf(box.position.y) < 0.002 and absf(box.end.y - Tables.HIGH) < 0.01 and absf((m["node"] as Node3D).position.y - Tables.HIGH) < 0.001,
		"built alone, it stands on the floor, its top as high as a table's (%s)" % str(box))
	(m["node"] as Node).free()
	_ok(TableProp.hash_of(spec, 5) != TableProp.hash_of(_safe({"shape": "rect", "size": [161, 80]}), 5), "its picture's name changes with it")


func _refine() -> void:
	var dir := ProjectSettings.globalize_path(ROOT.path_join("show").path_join("7"))
	DirAccess.make_dir_recursive_absolute(dir)
	var ep := TableEpisode.at_dir(dir)
	var table := {"top": {"shape": "rect", "size": [190, 85], "material": "the walnut"}, "layers": [{"name": "the cloth", "fabric": "felt"}],
		"materials": {"the walnut": {"kind": "wood", "color": "#3a2010"}}, "things": [{"name": "a cup", "parts": []}]}
	ep.write_json("table", table)
	ep.note_made("table", "set_dresser")
	var p := TableRefine.prompt(table, {"look": {"palette": ["#112233"]}}, "make it round", true)
	Rules.missing.clear()
	p = TableRefine.prompt(table, {"look": {"palette": ["#112233"]}}, "make it round", true)
	_ok(Rules.missing.is_empty() and not (String(p["prompt"]) + String(p["system"])).contains("{{") and String(p["prompt"]).contains("make it round")
		and String(p["prompt"]).contains("\"the walnut\""), "the refiner's prompt renders whole (%s)" % ", ".join(Rules.missing))
	var got := TableRefine.land(ep, "here it is: {\"top\": {\"shape\": \"round\", \"size\": [150]}, \"layers\": []}")
	var now: Variant = ep.read_json("table")
	_ok(got.is_empty() and now is Dictionary and String((now as Dictionary)["top"]["shape"]) == "round" and ((now as Dictionary)["layers"] as Array).is_empty(),
		"an answer lands: the top and cloths replaced (%s)" % str(got))
	_ok(now is Dictionary and ((now as Dictionary)["things"] as Array).size() == 1 and (now as Dictionary).has("materials"), "every thing on the table is kept")
	_ok(ep.versions("table").size() == 1 and String(ep.record("table").get("by", "")) == "hand" and ep.kept("table"),
		"the table before is a version back, and the new one is a hand's, kept from Generate")
	var before := ep.digest("table")
	_ok(TableRefine.land(ep, "I would rather not.").has("error") and ep.digest("table") == before, "control: an answer that is no table writes nothing")
	_ok(TableRefine.land(ep, JSON.stringify({"top": (now as Dictionary)["top"], "layers": []})).has("error") and ep.digest("table") == before,
		"control: an answer that changes nothing writes nothing")
	_remove(ProjectSettings.globalize_path(ROOT))


func _remove(path: String) -> void:
	for d in DirAccess.get_directories_at(path):
		_remove(path.path_join(d))
	for f in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	DirAccess.remove_absolute(path)
