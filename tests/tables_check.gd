extends SceneTree

## tables_check - THE TABLE ITSELF ([Tables]): its top and the layers laid on it, as a set dresser
## writes them, made safe and built.
##
##   godot --headless --path . --script tests/tables_check.gd
##
## - THE VOCABULARY IS THE REGISTRIES: every shape, edge, fabric, pattern and relief is in what the
##   set dresser reads, and its prompt carries it.
## - WHATEVER IS WRITTEN IS BUILDABLE: junk comes out as the defaults, numbers in range, names it
##   knows - each change said; no `top` and no `layers` is the old table (190 x 85 boards, the
##   painting as a 120 x 72 cloth), `layers: []` a bare top.
## - THE TOP HOLDS THE CARDS: every preset spread, the deck and the shuffle of a thousand seeded
##   layouts lie inside [constant Tables.HOLDS] (or a top that holds it could still drop a card); a
##   top too small for it is grown until it holds it - two-sided: the same top ungrown does not.
## - THE OUTLINE IS ONE THING: each shape's edge points lie on its distance field's zero, inside is
##   inside; a card off a round top is refused by [method TablePositions.given] and the same card
##   kept with no top (two-sided).
## - A LAYER HANGS OVER THE EDGE: every point of a cloth past the top's edge is below the top and
##   outside its outline; every point on the top lies flat at its layer's height - and a layer
##   wholly on the top hangs nowhere (the control). Layers stack upward, all under where a card rests.
## - THE LIGHT READS WHAT LIES UPPERMOST: a pale runner over a dark cloth is pale under the runner and
##   dark beside it; past the top, the floor.

var _fails: Array = []


func _initialize() -> void:
	_vocabulary()
	_made_safe()
	_holds_cards()
	_outlines()
	_drape()
	_lightness()
	if _fails.is_empty():
		print("tables_check: ALL OK")
		quit(0)
		return
	print("tables_check: %d FAILURE(S)" % _fails.size())
	for f in _fails:
		print("   ", f)
	quit(1)


func _ok(cond: bool, msg: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + msg)
	if not cond:
		_fails.append(msg)


func _vocabulary() -> void:
	print("-- the vocabulary is the registries")
	var d := Tables.describe()
	var missing := PackedStringArray()
	for reg in [Tables.SHAPES, Tables.EDGES, Tables.FABRICS, Tables.PATTERNS, Tables.RELIEFS]:
		for k in reg:
			if not d.contains("- %s:" % k) and not d.contains("  - %s:" % k):
				missing.append(String(k))
	_ok(missing.is_empty(), "every registry word is described (missing: %s)" % ", ".join(missing))
	var p := CardPrompts.set_dresser("Show", "brief", {"look": {"candles": 1}}, 7, CardTable.headroom(7), [], true, 30, [], "",
		["a round top of oak, 120 cm across"])
	var prompt := String(p["prompt"])
	_ok(prompt.contains(Tables.describe()), "the set dresser is told the table's vocabulary")
	_ok(prompt.contains("a round top of oak"), "the set dresser is told the earlier tables")
	_ok(prompt.contains("`overhead`"), "the set dresser is told it can look from above")
	var ex: Variant = JSON.parse_string("{" + CardPrompts.TABLE_EXAMPLE + "}")
	_ok(ex is Dictionary, "the table's example is JSON")
	if ex is Dictionary:
		var notes := PackedStringArray()
		var safe := Tables.sanitize((ex as Dictionary)["top"], (ex as Dictionary)["layers"],
			{"slate": Props.sanitize_material({"kind": "stone", "color": "#2f3336"}, "#808080")}, [], notes)
		_ok(String((safe["top"] as Dictionary)["material"]) == "slate" and (safe["layers"] as Array).size() == 2,
			"the example builds as written (%s)" % "; ".join(notes))


func _made_safe() -> void:
	print("-- whatever is written is buildable")
	var notes := PackedStringArray()
	var junk := Tables.sanitize({"shape": "blob", "size": "big", "thickness": 900, "edge": "wavy", "material": "unobtainium"},
		[{"outline": "star", "fabric": "chainmail", "pattern": {"kind": "paisley", "colors": ["red", "#zzzzzz"]}, "relief": {"kind": "spiky", "depth": 99}},
		"not a layer", {}, {}, {}, {}], {}, ["#112233", "#445566"], notes)
	var top: Dictionary = junk["top"]
	_ok(top["shape"] == "rect" and top["edge"] == "eased" and float(top["thickness"]) == Tables.THICK.y,
		"a junk top is a rect, eased, its thickness held (%s)" % str([top["shape"], top["edge"], top["thickness"]]))
	_ok(String((top["look"] as Dictionary)["kind"]) == "wood", "an unknown material is the dark wood")
	var layers: Array = junk["layers"]
	_ok(layers.size() == Tables.MAX_LAYERS, "at most %d layers (%d)" % [Tables.MAX_LAYERS, layers.size()])
	var l0: Dictionary = layers[0]
	_ok(l0["outline"] == "rect" and l0["fabric"] == "cotton" and (l0["pattern"] as Dictionary)["kind"] == "plain",
		"a junk layer is a plain cotton rect")
	_ok((l0["pattern"] as Dictionary)["colors"] == ["#112233", "#445566"], "junk colors are the palette's")
	_ok((l0["relief"] as Dictionary)["kind"] == "natural", "an unknown relief is the fabric's own")
	_ok(notes.size() >= 4, "every change is said (%d notes: %s)" % [notes.size(), "; ".join(notes)])
	var deep := Tables.sanitize(null, [{"relief": {"kind": "quilted", "depth": 99}}], {}, [])
	_ok(float(((deep["layers"] as Array)[0]["relief"] as Dictionary)["depth"]) == Tables.RELIEF_MOST, "a relief is no deeper than %d mm" % int(Tables.RELIEF_MOST))
	# THE OLD TABLE when the set dresser wrote neither
	var old := CardTable.sanitize_table({"things": []}, {})
	var ot: Dictionary = old["top"]
	_ok(ot["shape"] == "rect" and ot["size"] == [190.0, 85.0], "no top is the old 190 x 85 table (%s)" % str(ot["size"]))
	var ol: Array = old["layers"]
	_ok(ol.size() == 1 and (ol[0] as Dictionary)["size"] == [120.0, 72.0] and ((ol[0] as Dictionary)["pattern"] as Dictionary)["kind"] == "painting"
		and (ol[0] as Dictionary)["at"] == [0.0, 0.0], "no layers is the painting as a 120 x 72 cloth under the reading")
	var o := Tables.layer_outline(ol[0], ot)
	_ok(((o["center"] as Vector2) - TablePositions.CLOTH_MIDDLE).length() < 1e-6 and (o["half"] as Vector2).is_equal_approx(TablePositions.CLOTH * 0.5),
		"...lying exactly where the old cloth lay")
	_ok((CardTable.sanitize_table({"layers": []}, {})["layers"] as Array).is_empty(), "`layers: []` is a bare top")
	var painted := CardTable.sanitize_table({"top": {"material": "painting"}, "layers": []}, {})
	_ok(String((painted["top"] as Dictionary)["material"]) == "painting"
		and String(((painted["top"] as Dictionary)["relief"] as Dictionary)["kind"]) == "painting", "the painting can be the top, its detail its relief")


## THE TOP HOLDS THE CARDS: everywhere the cards go, over a thousand layouts, lies in HOLDS - and a
## top too small for HOLDS is grown until it holds it.
func _holds_cards() -> void:
	print("-- the top holds the cards")
	var holds := Rect2(Tables.ORIGIN + Tables.HOLDS.position, Tables.HOLDS.size)
	var out := 0
	var worst := 0.0
	for seed in range(1, 301):
		var lay := CardTable.layout_of(seed)
		for n in range(1, 11):
			var rng := RandomNumberGenerator.new()
			rng.seed = seed * 31 + n
			for sl in TablePositions.seeded(n, rng, lay):
				for c in TablePositions.corners(sl):
					if not holds.has_point(c):
						out += 1
						worst = maxf(worst, maxf(holds.position.y - c.y, c.y - holds.end.y))
		var deck: Rect2 = TablePositions.deck_keep(lay["deck"])
		for c in [deck.position, deck.end]:
			if not holds.grow(0.001).has_point(c):
				out += 1
		# THE SHUFFLE AND THE WASH: an ellipse round the middle, a card's half-diagonal past it
		var mid: Vector3 = lay["mid"]
		var reach := Vector2(0.29, 0.15) + Vector2.ONE * Vector2(0.035, 0.06).length()
		for c in [Vector2(mid.x - reach.x, mid.z - 0.01), Vector2(mid.x + reach.x, mid.z - 0.01), Vector2(mid.x, mid.z - 0.01 - reach.y),
				Vector2(mid.x, mid.z - 0.01 + reach.y)]:
			if not holds.has_point(c):
				out += 1
	_ok(out == 0, "every preset card, the deck and the wash lie where every top holds (%d out, worst %.3f m)" % [out, worst])
	for shape in ["round", "oval", "rect", "polygon"]:
		var small := {"shape": shape, "size": [70, 60], "sides": 8}
		var raw := Tables._sanitize_top(small, {}, [], PackedStringArray())
		raw["size"] = [70.0, 60.0] if shape != "round" else [70.0, 70.0]
		var notes := PackedStringArray()
		var safe := Tables._sanitize_top(small, {}, [], notes)
		_ok(not Tables.holds_cards(raw) and Tables.holds_cards(safe) and float(safe.get("grown", 1.0)) > 1.0,
			"a %s top too small for the cards is grown to %s cm and holds them (ungrown it does not)" % [shape, str(safe["size"])])
	var round := Tables._sanitize_top({"shape": "round", "size": [10]}, {}, [], PackedStringArray())
	_ok(absf(float(round["size"][0]) * 0.01 - Tables._least_round()) < 0.06, "a round top comes out about the least that holds the cards (%.2f m against %.2f)" %
		[float(round["size"][0]) * 0.01, Tables._least_round()])


func _outlines() -> void:
	print("-- the outline is one thing")
	var tops := [{"shape": "rect", "size": [190, 85], "corner": 0}, {"shape": "rect", "size": [150, 100], "corner": 12},
		{"shape": "round", "size": [130]}, {"shape": "oval", "size": [180, 120]}, {"shape": "polygon", "size": [140, 140], "sides": 8},
		{"shape": "round", "size": [140], "scallops": 24}]
	for t in tops:
		var top := Tables._sanitize_top(t, {}, [], PackedStringArray())
		var o := Tables.top_outline(top)
		var worst := 0.0
		for q in Tables.edge_points(o):
			worst = maxf(worst, absf(Tables.sdf_local(o, q)))
		var c: Vector2 = o["center"]
		_ok(worst < 0.0005 and Tables.inside(top, c, 0.1) and not Tables.inside(top, c + Vector2(3.0, 0.0)),
			"a %s's edge lies on its outline (%.5f m off at worst), its middle inside, far off outside" % [String(top["shape"]), worst])
	# A CARD OFF A ROUND TOP is refused once the top is known, and kept without it
	var round := Tables._sanitize_top({"shape": "round", "size": [10]}, {}, [], PackedStringArray())
	var seed := 11
	var lay := CardTable.layout_of(seed)
	# a card at the back left, inside the cloth and the frame but past a round top's curve
	var probe := {}
	for x in range(-50, 0, 2):
		for z in range(-34, -10, 2):
			var cards := [{"position": {"x": x / 100.0, "z": z / 100.0, "yaw": 0.0}}]
			if not TablePositions.given(cards, seed).is_empty() and TablePositions.given(cards, seed, round).is_empty():
				probe = cards[0]
	_ok(not probe.is_empty(), "a card off a round top's edge but on the cloth is refused with the top, kept without it (%s)" % str(probe.get("position", {})))
	var _unused := lay


func _drape() -> void:
	print("-- a layer hangs over the edge")
	var top := Tables._sanitize_top({"shape": "round", "size": [120], "thickness": 4, "edge": "bullnose"}, {}, [], PackedStringArray())
	var o := Tables.top_outline(top)
	var spec := {"top": top, "layers": [
		Tables._sanitize_layer({"name": "cloth", "outline": "top", "drop": 25, "fabric": "linen"}, 0, [], PackedStringArray()),
		Tables._sanitize_layer({"name": "runner", "outline": "rect", "size": [40, 200], "turn": 90, "fringe": 6}, 1, [], PackedStringArray()),
		Tables._sanitize_layer({"name": "mat", "outline": "round", "size": [50]}, 2, [], PackedStringArray())]}
	var built := Tables.build(spec, 5)
	var node: Node3D = built["node"]
	var heights: Array = []
	for i in 3:
		var mi: MeshInstance3D = node.get_child(i + 1)
		var arrays := (mi.mesh as ArrayMesh).surface_get_arrays(0)
		var pos: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var flat_y := Tables.LAYER_FLOOR + Tables.LAYER_GAP * i
		heights.append(flat_y)
		var hung := 0
		var bad := 0
		var bend := Tables.profile_inset("bullnose", 0.0, 0.04)
		for p in pos:
			var past := Tables.sdf(o, Vector2(p.x, p.z))
			if p.y < flat_y - 1e-6:
				if p.y < flat_y - 0.0005:
					hung += 1
				# going down only where the top's face has ended - rolling over its edge, or past it
				if past < -bend - 0.001:
					bad += 1
		if i < 2:
			_ok(hung > 20 and bad == 0, "%s hangs over the edge (%d points hanging, %d through the top or off its height)" % [["the cloth", "the runner"][i], hung, bad])
		else:
			_ok(hung == 0 and bad == 0, "a mat wholly on the top hangs nowhere (the control: %d hanging)" % hung)
	var deepest := 0.0
	for i in 2:
		var arrays := ((node.get_child(i + 1) as MeshInstance3D).mesh as ArrayMesh).surface_get_arrays(0)
		for p: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
			deepest = minf(deepest, p.y)
	_ok(deepest < -0.2 and deepest >= -Tables.DROP_MOST - 0.01, "the tablecloth falls its drop and no further (%.2f m)" % deepest)
	_ok(heights[0] < heights[1] and heights[1] < heights[2] and float(heights[2]) + Tables.LAYER_GAP * float(Tables.MAX_LAYERS - 3) < Tables.LAYERS_UNDER,
		"layers stack upward, all under where a card rests")
	_ok((built["painted"] as Array).is_empty(), "no surface takes the painting when none asks for it")
	var with_painting := Tables.build(CardTable.sanitize_table({}, {}), 5)
	_ok((with_painting["painted"] as Array).size() == 1, "the old table's cloth takes the painting")
	node.free()
	(with_painting["node"] as Node).free()


func _lightness() -> void:
	print("-- the light reads what lies uppermost")
	var top := Tables._sanitize_top({"shape": "round", "size": [120], "material": "oak"}, {"oak": Props.sanitize_material({"kind": "wood", "color": "#3a2a1a"}, "#808080")}, [], PackedStringArray())
	var layers := [Tables._sanitize_layer({"name": "dark", "outline": "top", "drop": 10, "pattern": {"kind": "plain", "colors": ["#101010"]}}, 0, [], PackedStringArray()),
		Tables._sanitize_layer({"name": "pale runner", "outline": "rect", "size": [200, 30], "turn": 90, "pattern": {"kind": "plain", "colors": ["#f0ece0"]}}, 1, [], PackedStringArray())]
	var rect := Rect2(-0.7, -0.8, 1.4, 1.24)
	var grid := Vector2i(35, 31)
	var lum := Tables.surface_lum({"top": top, "layers": layers}, null, rect, grid, Color.GRAY)
	var at := func(x: float, z: float) -> float:
		var gx := int((x - rect.position.x) / rect.size.x * grid.x)
		var gy := int((z - rect.position.y) / rect.size.y * grid.y)
		return lum[gy * grid.x + gx]
	var under := float(at.call(0.0, -0.1))
	var beside := float(at.call(0.3, -0.1))
	var past := float(at.call(-0.68, -0.78))
	_ok(under > 0.6 and beside < 0.02 and past <= 0.02, "pale under the runner (%.2f), dark beside it (%.3f), the floor past the top (%.2f)" % [under, beside, past])
	var bare := Tables.surface_lum({"top": top, "layers": []}, null, rect, grid, Color.GRAY)
	_ok(absf(bare[int((-0.1 - rect.position.y) / rect.size.y * grid.y) * grid.x + int((0.0 - rect.position.x) / rect.size.x * grid.x)] - beside) > 0.005,
		"a bare top is its wood's lightness, not a cloth's")
