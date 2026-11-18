extends SceneTree

## The Environment ([Surroundings], [LightShafts], [EnvironmentCard], [EnvironmentSection], [EnvironmentLibrary], [Roll];
## next/environment.md): what is round a scene, a list of elements chosen on its card, with no renderer.
##
##   godot --headless --path . --script res://tests/table/environment_check.gd
##
## - Roll: a field set is kept, one unset drawn inside its `roll` and the same for the same number (the control: other numbers draw it
##   otherwise), one with no roll its default; what is set is made safe (held to bounds, an unknown choice or key dropped).
## - The block made safe: a kind it does not know dropped, a kind a scene has once kept once, at most MOST, fields held to their
##   bounds, a lit or heard thing's share kept by its name; a light set aside is the scene's own (the control: in use, its preset).
## - Every preset a row a desk can read; every kind's fields rows a person can tune, each roll inside its bounds and its options.
## - What drifts: each air element an effect over a region every host names, as many as its Amount (the control: twice the amount,
##   twice the motes), never going away on a visit, each element's number its own placing; one set aside adds none.
## - What is heard: each sound element a part of the Soundscape's sound, its properties reaching it (its Kind, `sort`, the sound's
##   `kind`); none, silence. An element's own keys are no property (the control: told it is crickets, an element is nothing). Test
##   plays a sound element alone and follows what is changed on it, stopped when pressed again (the control: a light has none).
## - Shafts: columns, never cones (the control: a cone is told apart), parallel to the light's way unless spread (the control: spread,
##   ways of their own within it, a beam's shafts parallel), turned and tipped as Direction and Steepness say, up to thirty beams, as wide as Width says
##   (the control: wider asked, wider drawn), Variety 0 all alike, above it some much fatter, below some much skinnier, each
##   running from its reach up to past where it lands, its mesh wide enough for its
##   blur; its edge blurring the further below its gap (the control: at the gap, past its edge is dark); its patch drawn, no light;
##   narrower shafts inside their beam, about doubling the light where they cross; landing apart inside the boxes,
##   shared out round the viewer; at most MOST; the dust and the shimmer by show time.
## - The card: a row an element and a row for each lit and heard thing the panel's Props sections name; Use from the Dex adds one (a
##   light takes the light's place), Roll draws another keeping what is set, a property set and unset, Used, its ×; the live document
##   and the note touched; its part of the document and its bed (the control: a panel whose bed is another card's keeps it); Keep puts
##   it in a library moved aside, where it is used, renamed and removed (to the gate's own trash).
## - The Dex lists its shelves under their categories, in order.

const ROOT := "user://environment_check"
## The panel, the card and its list, by path: each names autoloads, which resolve only once the tree is up.
const PANEL := "res://src/reading/reading_panel.gd"
const CARD := "res://src/table/environment_card.gd"
const SECTION := "res://src/table/environment_section.gd"

var _fails := 0


## The live document's holder, as the reading's subtitles are.
class Words extends Node:
	var document := {}


## A Props section with a lamp on it, and a receiver that hisses.
class Lit extends PropSection:
	func lit() -> Array:
		return [{"key": "lamp", "name": "The lamp"}]

	func heard() -> Array:
		return [{"key": "receiver", "name": "Receiver"}]


## A shelf of another kind, for the Dex's list.
class Voices extends ShelfSection:
	func title() -> String:
		return "Voices"

	func shelves() -> Array:
		return [{"key": "kept", "label": "Kept voices"}]


func _init() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		print("FAIL: " + what)


func _run() -> void:
	await process_frame
	Library.root = ROOT
	var trashed: Array = []
	Library.discard = func(path: String) -> int:
		trashed.append(path)
		return DirAccess.remove_absolute(path)
	_rmrf(ProjectSettings.globalize_path(ROOT))
	_roll()
	_block()
	_presets()
	_fields()
	_air()
	_sound()
	_shafts()
	await _card(trashed)
	await _dex()
	_rmrf(ProjectSettings.globalize_path(ROOT))
	Library.root = Library.ROOT
	Library.discard = Callable()
	print("environment_check: %s (%d failure%s)" % ["ALL OK" if _fails == 0 else "FAILED", _fails, "" if _fails == 1 else "s"])
	quit(1 if _fails > 0 else 0)


func _roll() -> void:
	var fields := Surroundings.SHAFT_FIELDS
	var v := Roll.values(fields, {"count": 7}, 41)
	_ok(int(v["count"]) == 7, "a field set is kept")
	var w: Array = (fields["width"] as Dictionary)["roll"]
	_ok(float(v["width"]) >= float(w[0]) - 0.005 and float(v["width"]) <= float(w[1]) + 0.005, "one unset is drawn inside its roll (%.2f)" % float(v["width"]))
	_ok(Roll.values(fields, {"count": 7}, 41) == v, "the same number draws the same")
	var other := false
	for s in [42, 43, 44, 45]:
		other = other or Roll.values(fields, {"count": 7}, s)["width"] != v["width"]
	_ok(other, "the control: other numbers draw it otherwise")
	_ok(String(v["color"]).is_empty(), "a field with no roll is its default")
	var clean := Roll.clean(fields, {"count": 40, "inner": 1.6, "color": "#ABC", "width": "wide", "made_up": 3})
	_ok(int(clean["count"]) == 30 and clean["inner"] is int and int(clean["inner"]) == 2 and String(clean["color"]) == "#aabbcc"
		and not clean.has("width") and not clean.has("made_up"), "what is set is made safe: held to bounds, whole where it must be (%s)" % str(clean))
	var shown := Roll.shown(fields, {"count": 7}, 41)
	_ok(is_equal_approx(float((shown["width"] as Dictionary)["default"]), float(v["width"])) and int((shown["count"] as Dictionary)["default"]) == 4,
		"shown, an unset field stands at what is drawn, a set one's default as it was")
	_ok(String(Roll.clean(Surroundings.LIGHT_FIELDS, {"preset": "noon"}).get("preset", "")).is_empty(), "a choice it does not offer is dropped")


func _block() -> void:
	var many: Array = []
	for i in Surroundings.MOST + 4:
		many.append({"kind": "dust", "seed": i})
	var odd := Surroundings.sanitize({"elements": [{"kind": "noon"}, {"kind": "light", "preset": "moonlight", "seed": 5},
		{"kind": "light", "preset": "dusk"}, {"kind": "shafts", "count": 40, "made_up": 1, "off": true}] + many,
		"lights": {"lamp": 7.0, "terminal": 0.5}, "heard": {"receiver": 0.25, "radio": 9}})
	var els: Array = odd["elements"]
	_ok(els.size() == Surroundings.MOST, "at most %d elements (%d)" % [Surroundings.MOST, els.size()])
	_ok(String(els[0]["kind"]) == "light" and String(els[0]["preset"]) == "moonlight" and int(els[0]["seed"]) == 5
		and String(els[1]["kind"]) == "shafts", "a kind it does not know dropped; a kind a scene has once kept once, the first")
	_ok(int(els[1]["count"]) == 30 and not (els[1] as Dictionary).has("made_up") and els[1]["off"] == true, "fields held to their bounds, set aside kept")
	_ok(is_equal_approx(float((odd["lights"] as Dictionary)["lamp"]), Surroundings.LIGHT_SHARE.y)
		and is_equal_approx(Surroundings.share_of(odd, "terminal"), 0.5) and is_equal_approx(Surroundings.share_of(odd, "radar"), 1.0),
		"a lit thing's share kept by its name, held to its range; one it does not name throws as it is made")
	_ok(is_equal_approx(Surroundings.heard_of(odd, "receiver"), 0.25) and is_equal_approx(Surroundings.heard_of(odd, "radio"), Surroundings.HEARD_SHARE.y),
		"a thing heard kept by its name, held to its range")
	_ok(Surroundings.preset_of(odd) == "moonlight" and Surroundings.light_of(odd)["key"] == "moon" and not Surroundings.has_shafts(odd),
		"its light is the light element's preset; shafts set aside are none")
	var aside := Surroundings.sanitize({"elements": [{"kind": "light", "preset": "moonlight", "off": true, "brightness": 2.0}]})
	_ok(Surroundings.preset_of(aside).is_empty() and Surroundings.light_of(aside, "candlelight") == Surroundings.LIGHTS["candlelight"]
		and is_equal_approx(Surroundings.brightness(aside), 1.0), "a light set aside is the scene's own, as bright as it is")
	_ok(Surroundings.preset_of({"elements": [{"kind": "light", "preset": "own"}]}).is_empty() and Surroundings.preset_of(null).is_empty(),
		"the scene's own light chosen is no preset; no block, none")
	_ok(Surroundings.sanitize(null) == Surroundings.KNOBS, "no block is every key's default")
	var bare := Surroundings.element({"kind": "dust"})
	_ok(int(bare["seed"]) == Surroundings.element({"kind": "dust"})["seed"], "an element with no number is given its kind's own")


func _presets() -> void:
	var whole := true
	for k in Surroundings.LIGHTS:
		var row: Dictionary = Surroundings.LIGHTS[k]
		for f in ["label", "blurb", "weight", "lamp", "candles", "leads", "ambient", "ambient_energy", "key", "key_color", "key_strength", "fog"]:
			whole = whole and row.has(f)
		whole = whole and Color.html_is_valid(String(row["ambient"])) and Color.html_is_valid(String(row["key_color"]))
	_ok(whole, "every light is a row with a lamp's share, candles, an ambient, a key and a fog color")
	_ok(is_zero_approx(float(Surroundings.LIGHTS["moonlight"]["weight"])) and is_zero_approx(float(Surroundings.LIGHTS["darkness"]["weight"])),
		"moonlight and no light are only ever chosen")
	var moon := Color.html(String(Surroundings.LIGHTS["moonlight"]["key_color"]))
	_ok(moon.s < 0.15 and moon.v > 0.9 and String(Surroundings.LIGHTS["moonlight"]["key"]) == "moon"
		and is_zero_approx(float(Surroundings.LIGHTS["moonlight"]["lamp"])), "moonlight is the moon's, nearly white, every lamp off")
	var preset: Dictionary = Surroundings.LIGHT_FIELDS["preset"]
	_ok(preset["options"] == ["own"] + Surroundings.LIGHTS.keys() and (preset["roll"] as Array).all(func(k: String) -> bool: return Surroundings.LIGHTS.has(k)),
		"a light's choices are the scene's own and every preset, and it rolls among presets")


func _fields() -> void:
	var bad: Array = []
	for kind in Surroundings.KINDS:
		var fields := Surroundings.fields_of(kind)
		if fields.is_empty():
			bad.append("%s has no fields" % kind)
		for k in fields:
			var f: Dictionary = fields[k]
			if String(f.get("label", "")).is_empty() or String(f.get("blurb", "")).is_empty() or not f.has("type") or not f.has("default"):
				bad.append("%s.%s is no whole row" % [kind, k])
			var roll: Variant = f.get("roll")
			match String(f["type"]):
				"int", "float":
					if roll is Array and (float(roll[0]) < float(f["min"]) or float(roll[1]) > float(f["max"]) or float(roll[0]) > float(roll[1])):
						bad.append("%s.%s rolls outside its bounds" % [kind, k])
					if typeof(f["default"]) in [TYPE_INT, TYPE_FLOAT] and (float(f["default"]) < float(f["min"]) or float(f["default"]) > float(f["max"])):
						bad.append("%s.%s defaults outside its bounds" % [kind, k])
				"enum":
					if (f.get("options", []) as Array).is_empty() or not (f["options"] as Array).has(f["default"]) \
							or (roll is Array and not (roll as Array).all(func(o: String) -> bool: return (f["options"] as Array).has(o))):
						bad.append("%s.%s chooses outside its options" % [kind, k])
	_ok(bad.is_empty(), "every kind's fields are rows a person can tune, each roll inside its bounds and its options (%s)" % str(bad))
	_ok(String((Surroundings.fields_of("rain")["on"] as Dictionary)["default"]) == "window"
		and is_equal_approx(float((Surroundings.fields_of("fire")["size"] as Dictionary)["default"]), 0.45),
		"a sound's defaults are its own words")
	_ok(String((Surroundings.fields_of("shafts", "#ff0000")["color"] as Dictionary)["default"]) == "#ff0000",
		"a shaft's color unset is the light's, as shown")


func _air() -> void:
	var fog := Color(0.2, 0.3, 0.4)
	var fx := Surroundings.effects_of(Surroundings.sanitize({"elements": [{"kind": "haze"}, {"kind": "pixies", "amount": 1.0}, {"kind": "smoke"}]}), fog)
	_ok(fx.size() == 2 and String((fx[0] as Dictionary)["kind"]) == "fog" and String((fx[1] as Dictionary)["kind"]) == "motes",
		"each air element an effect Effects keeps, an unknown one none (%d)" % fx.size())
	_ok(fx.all(func(e: Dictionary) -> bool: return String(e["where"]) in ["far", "near", "room"]), "over a region every host names")
	_ok(String((fx[0] as Dictionary)["color"]).trim_prefix("#") == fog.to_html(false), "haze is fog in the light's color")
	var twice := Surroundings.effects_of(Surroundings.sanitize({"elements": [{"kind": "pixies", "amount": 2.0}]}), fog)
	_ok(int((twice[0] as Dictionary)["count"]) == 2 * int((fx[1] as Dictionary)["count"]),
		"the control: at twice the amount, twice the motes (%d, %d)" % [int((twice[0] as Dictionary)["count"]), int((fx[1] as Dictionary)["count"])])
	_ok(Surroundings.effects_of(Surroundings.sanitize({}), fog).is_empty(), "nothing in the air, nothing drifts")
	_ok(Surroundings.effects_of(Surroundings.sanitize({"elements": [{"kind": "dust", "off": true}]}), fog).is_empty(), "set aside, it drifts no more")
	var pair := {"elements": [{"kind": "pixies", "amount": 1.0}, {"kind": "fireflies", "amount": 1.0}]}
	var spread_out := Surroundings.effects_of(Surroundings.sanitize(pair), fog, 2.0)
	var plain := Surroundings.effects_of(Surroundings.sanitize(pair), fog)
	_ok(int(spread_out[0]["count"]) == 2 * int(plain[0]["count"]) and int(spread_out[1]["count"]) == int(plain[1]["count"]),
		"a host with more air round the work has as many more motes there (%d of %d), and no more past it (the control: fireflies, far, %d)"
		% [int(spread_out[0]["count"]), int(plain[0]["count"]), int(spread_out[1]["count"])])
	var every: Array = []
	for k in Surroundings.KINDS:
		if String((Surroundings.KINDS[k] as Dictionary)["group"]) == "air":
			every.append({"kind": k})
	var all := Surroundings.effects_of(Surroundings.sanitize({"elements": every}), fog)
	_ok(all.size() == every.size(), "every air kind at once is kept (%d of %d)" % [all.size(), every.size()])
	var stays := all.all(func(e: Dictionary) -> bool: return String(e["kind"]) != "motes" or is_zero_approx(float(e.get("away", -1.0))))
	var visits := float((Effects.sanitize([{"kind": "motes", "look": "dust", "where": "near"}], [], ["near"], [])[0] as Dictionary)["away"])
	_ok(stays and visits > 0.0, "a mote never goes away on a visit, whose exit a moving camera can see (the control: a table's motes do, %.2f of their round)" % visits)
	var a := Surroundings.effects_of(Surroundings.sanitize({"elements": [{"kind": "dust", "seed": 1}]}), fog)
	var b := Surroundings.effects_of(Surroundings.sanitize({"elements": [{"kind": "dust", "seed": 2}]}), fog)
	_ok(String(a[0]["name"]) != String(b[0]["name"]), "each element's number places its own motes")


func _sound() -> void:
	_ok(Surroundings.sound_of(Surroundings.sanitize({})).is_empty(), "nothing heard, silence")
	var both := Surroundings.sound_of(Surroundings.sanitize({"elements": [{"kind": "rain", "strength": 0.9, "on": "roof"}, {"kind": "fire"}, {"kind": "sea"}]}))
	_ok(both.get("rain") is Dictionary and both.get("fire") is Dictionary and both.get("water") is Dictionary,
		"each sound element a part of the Soundscape's sound, kept by its sanitize (%s)" % str(both.keys()))
	_ok(is_equal_approx(float((both["rain"] as Dictionary)["strength"]), 0.9) and String((both["rain"] as Dictionary)["on"]) == "roof",
		"its properties reach its part")
	_ok(Soundscape.new(both, {}, 7, 22050, 0.0) != null, "a Soundscape is made of it")


## Shaft [param s]'s radius, as its shader is told.
func _rad(s: MeshInstance3D) -> float:
	return float(s.get_instance_shader_parameter("radius"))


## Whether shaft [param s]'s mesh is a column: as wide where it comes through as where it lands.
func _column(s: MeshInstance3D) -> bool:
	var m := s.mesh as CylinderMesh
	return m != null and is_equal_approx(m.top_radius, m.bottom_radius)


func _shafts() -> void:
	var over := AABB(Vector3(-1.0, 0.4, -1.0), Vector3(2.0, 0.0, 1.0))
	var toward := Vector3(0.3, 1.0, -0.2).normalized()
	var reach := 3.0
	var v := {"seed": 11, "count": 4, "inner": 0, "width": 0.3, "strength": 0.7, "variety": 0.5, "flicker": 0.0, "color": ""}
	var r := LightShafts.build([v], Color.WHITE, toward, [over], reach)
	_ok(r.get_child_count() == 4, "as many beams as asked, with none inside them")
	var columns := true
	var parallel := true
	var inside := true
	var runs := true
	var wide := true
	var lands: Array = []
	var radii: Array = []
	for c in r.get_children():
		var shaft := c as MeshInstance3D
		var m := shaft.mesh as CylinderMesh
		columns = columns and _column(shaft)
		parallel = parallel and shaft.transform.basis.y.normalized().dot(toward) > 0.9999
		var top := shaft.position + shaft.transform.basis.y.normalized() * m.height * 0.5
		var land := top - toward * reach
		var bottom := shaft.position - shaft.transform.basis.y.normalized() * m.height * 0.5
		var foot := reach * (1.0 + LightShafts.SINK)
		runs = runs and is_equal_approx(m.height, foot) and (land - bottom).dot(toward) > 0.0 \
			and m.top_radius >= _rad(shaft) + 0.5 * (_rad(shaft) * LightShafts.SOFT + LightShafts.PENUMBRA * foot)
		inside = inside and land.x >= over.position.x - 0.01 and land.x <= over.end.x + 0.01 and absf(land.y - over.end.y) < 0.01
		var base := LightShafts.beam_radius(float(v["width"]), 0.0, 0.0, reach)
		wide = wide and _rad(shaft) >= base - 1e-5 and _rad(shaft) <= base * pow(LightShafts.VARIETY_MOST, float(v["variety"])) + 1e-5
		for o in lands:
			inside = inside and (o as Vector3).distance_to(land) > 0.1
		lands.append(land)
		radii.append(_rad(shaft))
	_ok(columns, "each shaft a column, as wide where it comes through as where it lands")
	var cone := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.bottom_radius = 0.2
	cone.mesh = cm
	_ok(not _column(cone), "the control: a cone is told apart")
	cone.free()
	_ok(parallel, "every shaft parallel to the light's way")
	_ok(runs, "each runs from its reach up to past where it lands, its mesh wide enough for its blur there")
	_ok(inside, "each lands inside the box, no two together")
	_ok(wide, "each as wide as its Width asks, a positive Variety only ever fatter (%s)" % str(radii))
	# Variety: 0 all alike, above 0 some much fatter, below 0 some much skinnier
	var widths := func(variety: float) -> Array:
		var vv := v.duplicate()
		vv.merge({"count": 20, "variety": variety}, true)
		var built := LightShafts.build([vv], Color.WHITE, toward, [over], reach)
		var out: Array = []
		for c in built.get_children():
			out.append(_rad(c as MeshInstance3D))
		built.free()
		return out
	var even: Array = widths.call(0.0)
	var fat: Array = widths.call(1.0)
	var thin: Array = widths.call(-1.0)
	var base_r := LightShafts.beam_radius(float(v["width"]), 0.0, 0.0, reach)
	_ok(even.all(func(w: float) -> bool: return is_equal_approx(w, base_r)), "at Variety 0 every beam is the Width's")
	_ok(fat.all(func(w: float) -> bool: return w >= base_r - 1e-5) and float(fat.max()) > 3.0 * base_r,
		"above 0 the beams stray fatter, some several times the Width (%.3f of %.3f m)" % [float(fat.max()), base_r])
	_ok(thin.all(func(w: float) -> bool: return w <= base_r + 1e-5) and float(thin.min()) < base_r / 3.0,
		"below 0 they stray skinnier, some a fraction of it (%.4f of %.3f m) - the control: the two ways apart" % [float(thin.min()), base_r])
	_ok(not r.get_children().any(func(n: Node) -> bool: return n is Light3D), "no light to light its patch: the shaft draws it")
	var rad := 0.02
	_ok(is_equal_approx(LightShafts.lit(rad, 0.0, 0.0), 1.0 / sqrt(1.0 + 0.5 * LightShafts.SOFT))
		and is_zero_approx(LightShafts.lit(rad, rad * 1.2, 0.0)) and LightShafts.lit(rad, rad * 1.2, 3.0) > 0.05
		and LightShafts.lit(rad, 0.0, 3.0) < LightShafts.lit(rad, 0.0, 0.0),
		"its edge blurs the further below the gap, a little dimmer for it - the control: at the gap, past its edge is dark")
	var wider := v.duplicate()
	wider["width"] = 0.9
	var r2 := LightShafts.build([wider], Color.WHITE, toward, [over], reach)
	var mean := func(root: Node3D) -> float:
		var sum := 0.0
		for c in root.get_children():
			sum += _rad(c as MeshInstance3D)
		return sum / float(root.get_child_count())
	_ok(float(mean.call(r2)) > 2.0 * float(mean.call(r)), "the control: wider asked, wider drawn (%.3f, %.3f m)" % [float(mean.call(r2)), float(mean.call(r))])
	r2.free()
	# their way: turned and steepened from the scene's own, each beam strayed by the Spread, a beam's shafts parallel
	var flat := Vector2(toward.x, toward.z)
	var turned := LightShafts.way_of(toward, 90.0, 0.0)
	var lower := LightShafts.way_of(toward, 0.0, -20.0)
	_ok(LightShafts.way_of(toward, 0.0, 0.0).is_equal_approx(toward) and absf(Vector2(turned.x, turned.z).angle_to(flat) - PI * 0.5) < 0.01
		and is_equal_approx(turned.y, toward.y) and lower.y < toward.y
		and rad_to_deg(asin(LightShafts.way_of(toward, 0.0, -90.0).y)) >= LightShafts.LOWEST - 0.01,
		"Direction turns their way round the vertical, Steepness tips it, never below the lowest a shaft falls from")
	var fan := v.duplicate()
	fan.merge({"count": 12, "inner": 1, "spread": 10.0}, true)
	var spread_r := LightShafts.build([fan], Color.WHITE, toward, [over], reach)
	var ways := {}
	var within := true
	var beam_parallel := true
	for i in spread_r.get_child_count():
		var y := (spread_r.get_child(i) as MeshInstance3D).transform.basis.y.normalized()
		within = within and rad_to_deg(y.angle_to(toward)) <= 10.01
		ways[str(y.snapped(Vector3.ONE * 0.001))] = true
		if i % 2 == 1:
			beam_parallel = beam_parallel and y.dot((spread_r.get_child(i - 1) as MeshInstance3D).transform.basis.y.normalized()) > 0.9999
	spread_r.free()
	_ok(ways.size() > 6 and within and beam_parallel, "spread, beams come from ways of their own within it, a beam's shafts parallel (%d ways) - the control: none spread, one way" % ways.size())
	var thirty := v.duplicate()
	thirty["count"] = 30
	var many := LightShafts.build([thirty], Color.WHITE, toward, [over], reach)
	_ok(many.get_child_count() == 30 and int((Surroundings.SHAFT_FIELDS["count"] as Dictionary)["max"]) == 30, "up to thirty beams")
	many.free()
	# narrower shafts inside their beam
	var nested := LightShafts.build([{"seed": 3, "count": 2, "inner": 2, "width": 0.6, "strength": 0.5, "variety": 0.4, "flicker": 0.0, "color": ""}],
		Color.WHITE, Vector3.UP, [over], reach)
	_ok(nested.get_child_count() == 6, "two beams with two inside each: six shafts (%d)" % nested.get_child_count())
	var held := true
	var doubled := true
	for b in 2:
		var beam := nested.get_child(b * 3) as MeshInstance3D
		var br := _rad(beam)
		var bg := float(beam.get_instance_shader_parameter("glow"))
		for j in [1, 2]:
			var sh := nested.get_child(b * 3 + j) as MeshInstance3D
			var sr := _rad(sh)
			var off := Vector2(sh.position.x - beam.position.x, sh.position.z - beam.position.z).length()
			held = held and sr < br and off + sr <= br + 1e-4
			var both := bg + float(sh.get_instance_shader_parameter("glow"))
			doubled = doubled and both > 1.6 * bg and both < 2.6 * bg
	_ok(held, "each inner shaft narrower than its beam and inside it")
	_ok(doubled, "where one crosses its beam the light is about twice the beam's")
	nested.free()
	# round the viewer: shared out among boxes by their size, each box its share
	var left := AABB(Vector3(-3.0, 0.0, -1.0), Vector3(1.0, 0.0, 2.0))
	var right := AABB(Vector3(2.0, 0.0, -1.0), Vector3(1.0, 0.0, 2.0))
	var behind := AABB(Vector3(-1.0, 0.0, -3.0), Vector3(2.0, 0.0, 1.0))
	var three := v.duplicate()
	three["count"] = 3
	var round_r := LightShafts.build([three], Color.WHITE, Vector3.UP, [left, behind, right], reach)
	var sides := []
	for c in round_r.get_children():
		var x := (c as MeshInstance3D).position.x
		sides.append("left" if x < -1.5 else ("right" if x > 1.5 else "behind"))
	round_r.free()
	_ok(sides.has("left") and sides.has("right") and sides.has("behind"), "three beams round the viewer fall left, behind and right, one each (%s)" % str(sides))
	var crowd := LightShafts.build([{"seed": 1, "count": 30, "inner": 3, "width": 0.3, "strength": 0.5, "variety": 0.5, "flicker": 0.0, "color": ""}],
		Color.WHITE, Vector3.UP, [over], reach)
	_ok(crowd.get_child_count() == LightShafts.MOST, "at most %d shafts (%d)" % [LightShafts.MOST, crowd.get_child_count()])
	crowd.free()
	# show time
	LightShafts.tick(r, 5.0)
	var mats: Array = r.get_meta("shafts")
	_ok(is_equal_approx(float((mats[0] as ShaderMaterial).get_shader_parameter("t")), 5.0), "the dust in them and their shimmer go by show time")
	r.free()
	var flick := v.duplicate()
	flick["flicker"] = 0.8
	var f := LightShafts.build([flick], Color.WHITE, toward, [over], reach)
	_ok(is_equal_approx(float(((f.get_meta("shafts") as Array)[0] as ShaderMaterial).get_shader_parameter("flicker")), 0.8), "a flickering element's shafts shimmer")
	f.free()
	# through the block
	var block := Surroundings.sanitize({"elements": [{"kind": "shafts", "count": 2, "inner": 0}, {"kind": "shafts", "count": 1, "inner": 0, "off": true}]})
	var built := Surroundings.rays(block, Color.WHITE, toward, [over], reach)
	_ok(built != null and built.get_child_count() == 2 and Surroundings.rays(Surroundings.sanitize({}), Color.WHITE, toward, [over], reach) == null,
		"the block's shafts in use are built, none without them")
	if built != null:
		built.free()


func _card(trashed: Array) -> void:
	var panel_script: GDScript = load(PANEL)
	var card_script: GDScript = load(CARD)
	var bed_script: GDScript = card_script.get("Bed")
	var panel: Node = panel_script.new()
	var subs := Words.new()
	panel.subtitles = subs
	var card: Control = card_script.call("for_note", {"workspace": panel})
	root.add_child(card)
	await process_frame
	_ok(panel.bed.get_script() == bed_script and (panel.document_parts.get("environment") as Callable).is_valid(),
		"it hands the panel its part of the document and its bed")
	_ok(panel.bed.of().get("make") == null, "nothing heard: the bed makes nothing")
	card.apply({"elements": [{"kind": "light", "preset": "moonlight", "seed": 9}, {"kind": "pixies", "seed": 4}]})
	var got: Dictionary = card.capture()
	_ok((got["elements"] as Array).size() == 2 and Surroundings.preset_of(got) == "moonlight", "applied a block, it keeps it")
	var sec: PropSection = card.get("section")
	_ok(sec.rows().size() == 2 and String(sec.rows()[0]["name"]) == "Moonlight" and sec.rows()[1]["picture"] is Image,
		"a row an element, named as it is and pictured")
	_ok((card.get("list") as PropsCard).row_count() == 2, "the list draws them")
	panel.set("_dirty", false)
	_ok(sec.add("kind:rain").is_empty() and Surroundings.sound_of(card.capture()).has("rain") and bool(panel.get("_dirty")),
		"Use from the Dex adds one and touches the note")
	_ok(subs.document.get("environment") is Dictionary and Surroundings.sound_of(subs.document["environment"]).has("rain"),
		"the live document a playing scene reads has it at once")
	_ok(((panel.document_parts["environment"] as Callable).call() as Dictionary).get("environment") == card.capture(),
		"its part of the document is the block")
	var heard: Dictionary = panel.bed.of()
	_ok(heard.get("make") is Callable and ((heard["make"] as Callable).call(22050, 0.0)) is Soundscape, "something heard: a Soundscape")
	sec.add("preset:daylight")
	var lights := (card.capture()["elements"] as Array).filter(func(e: Dictionary) -> bool: return String(e["kind"]) == "light")
	_ok(lights.size() == 1 and Surroundings.preset_of(card.capture()) == "daylight", "a light added takes the light's place")
	# a sound's Kind is a property of its own: set, the element stays what it is and its sound takes it; an element's own keys are
	# no property (the control: an element told it is crickets is nothing at all)
	sec.add("kind:insects")
	var ins := (card.capture()["elements"] as Array).size() - 1
	var told := sec.set_field("el:%d" % ins, "sort", "cicadas")
	var bug: Dictionary = Surroundings.sound_of(card.capture()).get("insects", {})
	_ok(told.is_empty() and String(card.capture()["elements"][ins]["kind"]) == "insects" and String(bug.get("kind", "")) == "cicadas"
		and sec.rows().size() > ins, "an insect's Kind set: still insects, the cicadas heard (%s %s)" % [told, bug])
	_ok(not sec.set_field("el:%d" % ins, "kind", "crickets").is_empty() and String(card.capture()["elements"][ins]["kind"]) == "insects",
		"an element's own kind is no property: told otherwise, it stays")
	_ok(Surroundings.element({"kind": "crickets"}).is_empty(), "the control: an element told it is crickets is nothing")
	# Test: a sound heard alone, following what is changed on it, stopped when pressed again; the insects' dials reach their sound
	var test_label := func() -> String:
		for v in (sec.rows()[ins]["verbs"] as Array):
			if String((v as Dictionary)["key"]) == "test":
				return String((v as Dictionary)["label"])
		return ""
	_ok(sec.act("el:%d" % ins, "test").is_empty() and card.testing(ins) and card.tester.playing() and test_label.call() == "Test ■",
		"Test on a sound plays it alone (%s)" % test_label.call())
	var heard_was: String = card.tester.key()
	sec.set_field("el:%d" % ins, "amount", 1.0)
	_ok(card.tester.key() != heard_was and float((Surroundings.sound_of(card.capture())["insects"] as Dictionary).get("amount", -1.0)) == 1.0,
		"a property changed while it plays is heard at once, the insects' How many reaching their sound")
	_ok(sec.act("el:%d" % ins, "test").is_empty() and not card.tester.playing() and test_label.call() == "Test", "pressed again, it stops")
	var light_i := -1
	for i in (card.capture()["elements"] as Array).size():
		if String(card.capture()["elements"][i]["kind"]) == "light":
			light_i = i
	_ok(light_i >= 0 and not card.test(light_i).is_empty() and not card.tester.playing()
		and not (sec.rows()[light_i]["verbs"] as Array).any(func(v: Dictionary) -> bool: return String(v["key"]) == "test"),
		"the control: a light has no Test and makes no sound to hear")
	sec.remove("el:%d" % ins)
	# Roll, properties, Used, Remove: on the pixies (row 1)
	_ok(sec.set_field("el:1", "amount", 2.0).is_empty() and is_equal_approx(float(card.capture()["elements"][1]["amount"]), 2.0),
		"a property set is pinned")
	var seed := int(card.capture()["elements"][1]["seed"])
	var drawn: Array = []
	for i in 4:
		sec.act("el:1", "roll")
		drawn.append(Surroundings.values_of(card.capture()["elements"][1])["glow"])
	_ok(int(card.capture()["elements"][1]["seed"]) != seed and is_equal_approx(float(card.capture()["elements"][1]["amount"]), 2.0)
		and drawn.any(func(g: float) -> bool: return not is_equal_approx(g, float(drawn[0]))),
		"Roll draws another: a new number, what is set kept, what is not drawn again (%s)" % str(drawn))
	sec.set_field("el:1", "amount", null)
	_ok(not (card.capture()["elements"][1] as Dictionary).has("amount"), "unset, it is the number's again")
	sec.set_on("el:1", false)
	_ok(Surroundings.effects_of(card.capture(), Color.BLACK).is_empty() and sec.rows()[1]["on"] == false, "Used unticked, it is set aside")
	sec.set_on("el:1", true)
	# the props' lights and sounds
	panel.prop_sections = [Lit.new()]
	var keys: Array = sec.rows().map(func(r: Dictionary) -> String: return String(r["key"]))
	_ok(keys.has("lit:lamp") and keys.has("heard:receiver"), "a row stands for the lamp and the receiver the Props section names (%s)" % str(keys))
	sec.set_field("lit:lamp", "share", 0.4)
	sec.set_field("heard:receiver", "share", 0.0)
	_ok(is_equal_approx(Surroundings.share_of(card.capture(), "lamp"), 0.4) and is_zero_approx(Surroundings.heard_of(card.capture(), "receiver")),
		"the lamp's share and the receiver's loudness each kept alone")
	# kept
	_ok(sec.act("el:1", "keep").is_empty(), "Keep puts it in the library")
	var kept_row: Dictionary = sec.rows()[1]
	var kept_name := String((kept_row["verbs"] as Array)[1]["tip"]).trim_prefix("In your library as ").trim_suffix(".")
	_ok(String((kept_row["verbs"] as Array)[1]["label"]) == "Kept" and EnvironmentLibrary.entries().size() == 1, "and says so")
	var shelf := sec.offers().filter(func(o: Dictionary) -> bool: return String(o["shelf"]) == "kept")
	_ok(shelf.size() == 1 and String(shelf[0]["name"]) == kept_name, "the Dex's Kept shelf has it (%s)" % kept_name)
	_ok(sec.rename("kept:" + kept_name, "Sparkle").is_empty() and not EnvironmentLibrary.read("Sparkle").is_empty(), "renamed in place")
	_ok(sec.rows()[1].has("remove_tip") and sec.rows().filter(func(r: Dictionary) -> bool: return bool(r.get("open", false))).all(
		func(r: Dictionary) -> bool: return not r.has("remove_tip")), "an element's entry has its ×, a prop's share none")
	sec.remove("el:1")
	_ok((card.capture()["elements"] as Array).size() == 2, "Remove takes it away")
	sec.add("kept:Sparkle")
	var back: Dictionary = (card.capture()["elements"] as Array).back()
	_ok(String(back["kind"]) == "pixies" and String(back["name"]) == "Sparkle", "a kept one used is the same element again")
	sec.act("kept:Sparkle", "forget")
	_ok(EnvironmentLibrary.entries().is_empty() and trashed.size() == 1, "removed from the library, to the gate's own trash")
	# a panel whose bed is another's keeps it
	var other: Node = panel_script.new()
	other.bed = bed_script.new(card)
	var kept_bed: Object = other.bed
	var second: Control = card_script.call("for_note", {"workspace": other})
	_ok(other.bed == kept_bed, "the control: a panel whose bed is another card's keeps it")
	second.free()
	other.free()
	card.queue_free()
	await process_frame
	subs.free()
	panel.free()


func _dex() -> void:
	var dex := DexWindow.new()
	root.add_child(dex)
	var env: ShelfSection = (load(SECTION) as GDScript).new()
	dex.open([env, Voices.new()])
	await process_frame
	_ok(dex.category_labels() == ["Environment", "Voices"], "the Dex lists its shelves under their categories, in order (%s)" % str(dex.category_labels()))
	var labels := dex.shelf_labels()
	var lights := 1 + Surroundings.SHAFT_LOOKS.size() + Surroundings.LIGHTS.size()
	_ok(labels.size() == 5 and String(labels[0]) == "Light (%d)" % lights, "each shelf with how many it has (%s)" % str(labels))
	_ok(dex.adds_label().is_empty(), "opened on its own, it adds nothing")
	dex.queue_free()
	await process_frame


func _rmrf(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for d in DirAccess.get_directories_at(path):
		_rmrf(path.path_join(d))
	for f in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	DirAccess.remove_absolute(path)
