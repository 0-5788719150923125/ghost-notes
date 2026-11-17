extends SceneTree

## A prop's working parts and what plays them ([Props] faces and lights, [Motions] `follow`, [PropRig]; next/working_props.md), with
## no renderer.
##
##   godot --headless --path . --script res://tests/table/prop_rig_check.gd
##
## - A face is kept by sanitize (size, outline, `lit`, its glass in range, words, a hand it knows) and built where it was written:
##   found by its name, its size, middle and facing as written in the thing's node, its words a Label3D lying on it. The control: a
##   face a make lacks is null, and `has_faces` says so.
## - A hinge that follows a feed turns as the formula says of what it is fed, held to its range; fed nothing, it follows its `rest`
##   (the control: the same formula at v = 0, not where it was last fed).
## - A part that follows the time alone blinks as its formula says, fed nothing.
## - A light is built dark: a host that plays no rig (the studio, a table) never shows it; a rig lights it, and a feed dims and darkens
##   it.
## - A point on a turning part goes round with it.
## - `follow` is a part's `runs` only: as an act's law it is refused. The set dresser is never told a face or `follow`; an agent
##   refining a prop a scene works is (`Props.describe(true)`), and the puppeteer is never told `follow`.
## - Words handed to a face replace its own, fitted to it.
## - A copy of a rig is a thing of its own: posing it, handing it words or coloring it leaves the one it was copied from as it was
##   (the control: the same rig posed again moves).

var _fails := 0


func _init() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		print("  FAIL: " + what)


func _spec() -> Dictionary:
	return {"things": [{"name": "a gauge", "parts": [
		{"shape": "box", "size": [20, 12, 8], "material": "case"},
		{"shape": "face", "name": "screen", "size": [12, 9], "at": [0, 6, 4.1], "outline": "rounded", "round": 1, "lit": 0.4,
			"glass": {"curve": 0.12, "lines": 3.0, "bloom": 0.6}, "text": "GOOD", "hand": "marker", "ink": "#202020", "material": "glass"},
		{"shape": "box", "name": "needle", "size": [0.2, 4, 0.2], "at": [6, 2, 4.2], "material": "case",
			"joint": {"kind": "hinge", "at": [6, 2, 4.2], "axis": [0, 0, 1], "range": [-60, 60]},
			"points": {"tip": [6, 6, 4.2]},
			"runs": {"law": "follow", "feed": "level", "value": "48 - 96 * v"}},
		{"shape": "ball", "name": "led", "size": [0.4, 0.4, 0.4], "at": [-8, 10, 4], "material": "led",
			"runs": {"law": "follow", "state": "shown", "value": "1 - step(0.1, fract(T / 2.4))"}},
		{"shape": "lathe", "name": "bulb", "profile": [[0, 0], [1, 0], [1, 2], [0, 2]], "at": [0, 12, 0], "material": "case",
			"light": {"kind": "spot", "strength": 2.5, "reach": 200, "angle": 60, "color": "#ffd9a8", "shadows": true, "soft": 6},
			"runs": {"law": "follow", "feed": "lit", "state": "light", "rest": 1}},
	]}], "materials": {"case": {"kind": "painted", "color": "#c8bba0"}, "glass": {"kind": "glass", "color": "#101410"},
		"led": {"kind": "painted", "color": "#33ff55"}}}


func _run() -> void:
	var safe := Props.sanitize(_spec(), [])
	var thing: Dictionary = (safe["things"] as Array)[0]
	var parts: Array = thing["parts"]
	_ok(parts.size() == 5, "every part kept (%d)" % parts.size())
	var face: Dictionary = parts[1]
	_ok(String(face["shape"]) == "face" and face["size"] == Vector2(12, 9) and String(face["outline"]) == "rounded"
		and is_equal_approx(float(face["lit"]), 0.4) and String(face["text"]) == "GOOD" and String(face["hand"]) == "marker",
		"a face is kept as written: %s" % str(face))
	_ok(is_equal_approx(float((face["glass"] as Dictionary)["lines"]), 1.0) and is_equal_approx(float((face["glass"] as Dictionary)["curve"]), 0.12),
		"its glass is held to its ranges: %s" % str(face["glass"]))
	var bad := Props.sanitize({"things": [{"name": "x", "parts": [{"shape": "face", "size": [5, 5], "hand": "gothic", "outline": "star"}]}]}, [])
	var bf: Dictionary = (((bad["things"] as Array)[0] as Dictionary)["parts"] as Array)[0]
	_ok(String(bf["hand"]) == "print" and String(bf["outline"]) == "rect", "a hand or outline it does not know is its own")
	_ok((parts[4] as Dictionary).get("light") is Dictionary and String(((parts[4] as Dictionary)["light"] as Dictionary)["kind"]) == "spot",
		"a light is kept on its part")

	var b := Props.build(thing, safe["materials"], 7)
	_ok((b["faces"] as Array).size() == 1 and (b["lights"] as Array).size() == 1, "built: one face and one light")
	var studio_dark := true
	for l in b["lights"]:
		studio_dark = studio_dark and not ((l as Dictionary)["node"] as Light3D).visible
	_ok(studio_dark, "a light is built dark: a host with no rig never shows it")

	var rig := PropRig.new(b)
	_ok(rig.face("screen") != null and rig.face("scope") == null, "a face is found by its name; one the make lacks is null")
	_ok(rig.has_faces(["screen"]) and not rig.has_faces(["screen", "scope"]), "has_faces says what the make has")
	var fs := rig.face_size("screen")
	_ok(fs.distance_to(Vector2(0.12, 0.09) * float(b["sized"])) < 1e-4, "its size as built: %s" % str(fs))
	var fx := rig.face_xf("screen")
	var mid := (b["node"] as Node3D).transform.affine_inverse() * ((b["node"] as Node3D).transform * fx.origin)
	var box: AABB = b["size"]
	_ok(absf(mid.x - box.get_center().x) < 1e-3 and fx.basis.z.normalized().dot(Vector3.BACK) > 0.999,
		"its middle and facing as written: %s, %s" % [str(fx.origin), str(fx.basis.z)])
	var words: Label3D = ((b["faces"] as Array)[0] as Dictionary).get("words")
	_ok(words != null and words.text == "GOOD" and words.pixel_size > 0.0, "its words are a Label3D on it")
	var size_was := words.pixel_size if words != null else 0.0
	rig.say("screen", "A LONGER LINE OF WORDS")
	_ok(words != null and words.text == "A LONGER LINE OF WORDS" and words.pixel_size < size_was, "words handed replace its own, fitted smaller")

	_ok(rig.light("bulb") != null and rig.light("bulb").visible, "a rig lights its lights")
	rig.pose(0.0, {"level": 1.0, "lit": 0.5})
	_ok(is_equal_approx(rig.value("needle", "angle"), -48.0), "fed 1, the needle at -48 (%f)" % rig.value("needle", "angle"))
	var turned := rig.part("needle").transform.basis.get_euler().z
	_ok(is_equal_approx(turned, deg_to_rad(-48.0)), "its node turned about its axis (%f)" % rad_to_deg(turned))
	_ok(is_equal_approx(rig.light("bulb").light_energy, 1.25) and rig.light("bulb").visible, "fed half, the light at half its strength")
	var tip_turned: Vector3 = rig.point("tip")
	rig.pose(0.0, {"level": 0.25, "lit": 0.0})
	_ok(is_equal_approx(rig.value("needle", "angle"), 24.0), "fed 0.25, at 24")
	_ok(not rig.light("bulb").visible, "fed 0, the light is dark")
	var tip_back: Vector3 = rig.point("tip")
	_ok(tip_turned.distance_to(tip_back) > 0.01, "a point on the needle goes round with it (%s, %s)" % [str(tip_turned), str(tip_back)])
	rig.pose(0.0, {})
	_ok(is_equal_approx(rig.value("needle", "angle"), 48.0), "fed nothing, its rest (v = 0: 48), not where it was last fed")
	_ok(rig.light("bulb").visible, "fed nothing, the light at its rest (lit)")
	# a scene's own tuning of its lights (the Environment card's): kept through every pose after
	var full := rig.light("bulb").light_energy
	rig.set_light_scale(0.5)
	var halved := rig.light("bulb").light_energy
	rig.pose(0.0, {"lit": 1.0})
	_ok(is_equal_approx(halved, full * 0.5) and is_equal_approx(rig.light("bulb").light_energy, full * 0.5),
		"a light scaled by half throws half, posed again too (%.2f, then %.2f, of %.2f)" % [halved, rig.light("bulb").light_energy, full])
	rig.set_light_scale(0.0)
	_ok(not rig.light("bulb").visible, "scaled to 0, the light is dark though it is fed")
	rig.set_light_scale(1.0)
	_ok(is_equal_approx(rig.light("bulb").light_energy, full) and rig.light("bulb").visible, "the control: scaled to 1, as it was made")
	rig.pose(0.0, {})
	rig.pose(0.1, {})
	var on := rig.part("led").visible
	rig.pose(1.0, {})
	_ok(on and not rig.part("led").visible, "the LED blinks by the time alone")

	# a copy is its own: its parts, its words, its materials
	rig.pose(0.0, {"level": 0.0})
	var twin := rig.copy()
	twin.pose(0.0, {"level": 1.0})
	twin.say("screen", "ANOTHER")
	var twin_mat := twin.face("screen").material_override as ShaderMaterial
	twin_mat.set_shader_parameter("color", Color.RED)
	var own_mat := rig.face("screen").material_override as ShaderMaterial
	_ok(is_equal_approx(twin.value("needle", "angle"), -48.0) and is_equal_approx(rig.value("needle", "angle"), 48.0)
		and not is_equal_approx(rig.part("needle").transform.basis.get_euler().z, twin.part("needle").transform.basis.get_euler().z),
		"a copy posed moves its own needle, never the one it was copied from")
	_ok(((rig.built["faces"] as Array)[0]["words"] as Label3D).text == "A LONGER LINE OF WORDS" and twin_mat != own_mat
		and own_mat.get_shader_parameter("color") != Color.RED and twin.light("bulb") != rig.light("bulb"),
		"its words, materials and lights are its own")
	rig.pose(0.0, {"level": 1.0})
	_ok(is_equal_approx(rig.value("needle", "angle"), -48.0), "the control: the rig itself posed again moves")
	twin.node.free()

	var notes := PackedStringArray()
	_ok(Motions.sanitize_law({"law": "follow", "feed": "x"}, notes, false).is_empty() and not notes.is_empty(), "follow as an act's law is refused")
	_ok(not Motions.sanitize_law({"law": "follow", "feed": "x", "value": "2 * v"}, notes, true).is_empty(), "...and kept as a part's runs")
	var plain := Props.describe()
	var working := Props.describe(true)
	_ok(plain.find("FACE THAT SHOWS") < 0 and plain.find("\"follow\"") < 0, "the set dresser is never told a face or follow")
	_ok(working.find("FACE THAT SHOWS") >= 0 and working.find("\"follow\"") >= 0 and working.find("PARTS A SCENE PLAYS") >= 0,
		"an agent refining a prop a scene works is told them")
	_ok(Motions.describe_laws().find("Follow") < 0 and Motions.describe_laws().find("follow") < 0, "the puppeteer is never told follow")
	(b["node"] as Node).free()
	print("prop_rig_check: %s (%d failure%s)" % ["ALL OK" if _fails == 0 else "FAILED", _fails, "" if _fails == 1 else "s"])
	quit(1 if _fails > 0 else 0)
