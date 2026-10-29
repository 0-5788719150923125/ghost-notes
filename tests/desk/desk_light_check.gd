extends SceneTree

## Is a desk lit as the card table is ([DeskLook]'s moods and light, [DeskLight]; 2026-10-27, the user: "some nice
## ambient lighting, maybe some open-flame light sources, which cast nice shadows ... leverage the Table primitives";
## and "weird stripey rings of light across the desk and paper")?
##
## - EVERY MOOD COMES UP across 400 desks, each what it says: lamplight's lamp on, no sun but the moon; candlelight's
##   lamp off and a candle burning on the desk, no sun; daylight's sun through a window, the lamp off; dusk's sun low,
##   the lamp part on. The same seed is the same light, another seed another.
## - EVERY CANDLE IS SET DOWN, and most in their bands: on 60 candlelit desks each candle the mood asks for is placed
##   (one had found no room beside the pad and was dropped; a candle with no room in its band goes past it), most beside
##   the pad's left or past the pen's stretch on its right ([constant DeskLook.CANDLE_BAND], [constant
##   DeskLook.CANDLE_RIGHT]). ON BOTH SIDES (2026-10-29, the user: "I
##   don't think I've seen a candle placed on the right side even one time ... The scenes look best when lighting comes
##   from both directions"): about half on the right, and every desk of two or more lit from both - the control, the
##   left's band alone, holds under two thirds of them.
## - A CANDLE BURNS: a candlelight desk, dressed and lit off the stage, has a flame on every wick and one light a
##   candle, its shadow filtered and never sized ([ShadowFilter]); THE KEY is the candle that lights the page most,
##   and burns brighter than the fills.
## - NO PAGE BURNS OUT: every candle lights the page, where it falls hardest, no hotter than [constant DeskLight.PAGE_HEAT] -
##   the control, a key at full strength beside the pad, past it.
## - TEA LIGHTS NEVER STAND IN EACH OTHER (2026-10-29, the user: "the tea lights are clipping through each other"): over
##   200 saucers every two tins are apart and every tin on its saucer's floor - the control, two as they had stood,
##   1.6 cm either side of the middle, met.
## - A FLAME FACES THE CAMERA: looked down on, its quad faces the lens - the control, the table's upright quad,
##   faces it at under a quarter.
## - THE STAGE IS THE CARD TABLE'S: a mounted desk sets [constant TableMedium.STAGE] on its stage (the big shadow
##   atlas and debanding, without which the lamp's shadow map drew a moire over the page) and gives it back as it
##   leaves - the control, the stage's own atlas, is not the table's.
##
##   godot --headless --path . --script tests/desk/desk_light_check.gd

var _fails: Array = []


var _ran := false


## Run on the first frame, the tree up: mounted any sooner, a desk is not in the tree and never leaves it.
func _process(_delta: float) -> bool:
	if _ran:
		return false
	_ran = true
	_moods()
	_candles()
	_tea_lights()
	_stage()
	if _fails.is_empty():
		print("desk_light_check: ALL OK")
		quit(0)
	else:
		print("desk_light_check: %d FAILURE(S)" % _fails.size())
		for f in _fails:
			print("   ", f)
		quit(1)
	return false


func _check(ok: bool, msg: String) -> void:
	print(("   ok   " if ok else "   FAIL ") + msg)
	if not ok:
		_fails.append(msg)


func _moods() -> void:
	print("-- the moods")
	var seen := {}
	var right := true
	var why := ""
	for seed in 400:
		var l := DeskLook.of(seed)
		var mood := String(l["mood"])
		seen[mood] = int(seen.get(mood, 0)) + 1
		var light: Dictionary = l["light"]
		var sun: Dictionary = light.get("sun", {})
		var share := float((l["lamp"] as Dictionary)["share"])
		var lit := 0
		for t in l["things"]:
			lit += int(bool((DeskLook.THINGS[String((t as Dictionary)["kind"])] as Dictionary).get("lit", false)))
		var ok := true
		match mood:
			"lamplight":
				ok = share == 1.0 and (sun.is_empty() or String(sun["look"]) == "moon")
			"candlelight":
				ok = share == 0.0 and lit >= 1 and sun.is_empty()
			"daylight":
				ok = share == 0.0 and String(sun.get("look", "")) == "sun" and not (light["through"] as Array).is_empty()
			"dusk":
				ok = share > 0.0 and share < 1.0 and String(sun.get("look", "")) == "sun" and float(sun["height"]) <= 20.0
		if not ok and right:
			why = "seed %d (%s)" % [seed, mood]
		right = right and ok
	_check(seen.size() == DeskLook.MOODS.size() and right,
		"every mood comes up across 400 desks (%s), each lit as it says%s" % [str(seen), "" if right else ": not " + why])
	_check(str(DeskLook.of(9)["light"]) == str(DeskLook.of(9)["light"]) and str(DeskLook.of(9)["light"]) != str(DeskLook.of(10)["light"]),
		"the same seed is the same light, another seed another")
	# every candle set down, most in the band
	var asked := 0
	var placed := 0
	var banded := 0
	var desks := 0
	var rights := 0
	var pairs := 0
	var both := 0
	var lefts_only := 0
	for seed in 400:
		var l := DeskLook.of(seed)
		if String(l["mood"]) != "candlelight":
			continue
		desks += 1
		for t in l["things"]:
			asked += int(bool((DeskLook.THINGS[String((t as Dictionary)["kind"])] as Dictionary).get("lit", false)))
		var dressed := DeskLook.dress(l, seed, LegalPad.DESK_Y)
		var sides := Vector2i.ZERO
		for t in dressed["lit"]:
			placed += 1
			var at := ((t as Dictionary)["node"] as Node3D).position
			banded += int(DeskLook.CANDLE_BAND.has_point(Vector2(at.x, at.z)) or DeskLook.CANDLE_RIGHT.has_point(Vector2(at.x, at.z)))
			sides += Vector2i(int(at.x < 0.0), int(at.x > 0.0))
			# THE CONTROL: the band beside the left alone, as candles had stood
			lefts_only += int(DeskLook.CANDLE_BAND.has_point(Vector2(at.x, at.z)))
		rights += sides.y
		if (dressed["lit"] as Array).size() >= 2:
			pairs += 1
			both += int(sides.x > 0 and sides.y > 0)
		(dressed["node"] as Node).free()
		if desks >= 60:
			break
	_check(asked > 60 and placed == asked and banded > asked * 0.7,
		"every candle 60 candlelit desks ask for is set down (%d of %d), %d in their bands beside the pad - with a band on each side, %d went past them"
		% [placed, asked, banded, placed - banded])
	# BOTH SIDES (2026-10-29, the user: "I don't think I've seen a candle placed on the right side even one time ... The
	# scenes look best when lighting comes from both directions")
	_check(pairs > 10 and both == pairs and rights > placed / 3 and rights < placed * 2 / 3 and lefts_only < placed * 2 / 3,
		"the candles stand on both sides: %d of %d on the right, and every desk of two or more lit from both (%d of %d) - the control, the left's band alone, held %d"
		% [rights, placed, both, pairs, lefts_only])


## A candlelight desk of two candles or more, the first found.
static func _candlelit() -> int:
	for seed in 1000:
		var l := DeskLook.of(seed)
		if String(l["mood"]) != "candlelight":
			continue
		var n := 0
		for t in l["things"]:
			n += int(String((t as Dictionary)["kind"]) in ["taper", "pillar"])
		if n >= 2:
			return seed
	return -1


func _candles() -> void:
	print("-- the candles")
	var seed := _candlelit()
	var look := DeskLook.of(seed)
	var m := DeskMedium.new()
	m._root3 = Node3D.new()
	m._env = Environment.new()
	m._cam = Camera3D.new()
	m._root3.add_child(m._cam)
	var p := deg_to_rad(float(DeskMedium.LOCAL["pitch"]))
	m._cam.position = Vector3(0.0, sin(p), cos(p)) * float(DeskMedium.LOCAL["dist"])
	m._cam.basis = Basis.looking_at(-m._cam.position, Vector3.UP)
	var dressed := DeskLook.dress(look, seed, LegalPad.DESK_Y)
	m._root3.add_child(dressed["node"])
	var light := DeskLight.new()
	light.medium = m
	light.build(look, dressed["lit"], seed)
	var lit: Array = dressed["lit"]
	var wicks := 0
	for t in lit:
		wicks += ((t as Dictionary)["wicks"] as Array).size()
	var flames := 0
	var filtered := true
	for c in light._candles:
		flames += ((c as Dictionary)["flames"] as Array).size()
		var l: OmniLight3D = (c as Dictionary)["light"]
		filtered = filtered and l.shadow_enabled and l.light_size == 0.0 \
			and is_equal_approx(l.shadow_normal_bias, ShadowFilter.normal_bias(l, Lights.SHADOW_TEXELS))
	_check(seed >= 0 and lit.size() >= 2 and flames == wicks and light.candles() == lit.size() and filtered,
		"desk %d: %d candles, a flame on each of %d wicks and a light each, their shadows filtered, never sized" % [seed, lit.size(), wicks])
	# the key: the candle that lights the page most, brighter than the fills
	var e := light.energies()
	var key := -1
	var best := -1.0
	for i in light._candles.size():
		var f := DeskLight.page_field(((light._candles[i] as Dictionary)["light"] as OmniLight3D).position).x
		if f > best:
			best = f
			key = i
	var brightest := true
	for i in e.size():
		brightest = brightest and (i == key or e[i] <= e[key] + 1e-6)
	_check(key >= 0 and brightest and e[key] > DeskLight.FILL_ENERGY * 0.99,
		"the candle that lights the page most is the key (%.2f), the others fills (%s)" % [e[key], str(e)])
	# no page burns out
	var paper := DeskLight.paper_lum(look)
	var hottest := 0.0
	for i in light._candles.size():
		var at := ((light._candles[i] as Dictionary)["light"] as OmniLight3D).position
		hottest = maxf(hottest, e[i] * paper * DeskLight.page_field(at).y)
	var ctl := DeskLight.KEY_ENERGY * paper * DeskLight.page_field(Vector3(-0.13, 0.15, 0.0)).y
	_check(hottest <= DeskLight.PAGE_HEAT + 1e-3 and ctl > DeskLight.PAGE_HEAT,
		"no candle lights the page past %.2f where it falls hardest (at most %.2f; the control, a key at full strength beside the pad, %.2f)"
		% [DeskLight.PAGE_HEAT, hottest, ctl])
	# a flame faces the camera
	light.tick(3.0)
	var cz := m._cam.basis.z
	var facing := INF
	for c in light._candles:
		for f in (c as Dictionary)["flames"]:
			facing = minf(facing, ((f["mesh"] as MeshInstance3D).transform.basis.z.normalized()).dot(cz))
	var across := (m._cam.basis.x * Vector3(1, 0, 1)).normalized()
	var upright := across.cross(Vector3.UP).dot(cz)
	_check(facing > 0.99 and absf(upright) < 0.25,
		"looked down on, a flame faces the lens (%.3f), where the table's upright quad faces it at %.2f (the control)" % [facing, absf(upright)])
	light.release()
	m._root3.free()
	m.free()


## TEA LIGHTS NEVER STAND IN EACH OTHER (2026-10-29, the user: "the tea lights are clipping through each other. There
## are two of them, and they are clipped into each other").
func _tea_lights() -> void:
	print("-- tea lights")
	var pairs := 0
	var apart := 0
	var ctl_in := 0
	var in_dish := true
	for seed in 200:
		var spec := DeskLook._thing("tealights", DeskLook._rng(seed, "tea"))
		var parts: Array = spec["things"][0]["parts"]
		var tins: Array = parts.filter(func(p: Dictionary) -> bool: return p["material"] == "tin")
		var dish := float((parts[0]["profile"] as Array)[4][0])
		for a in tins.size():
			var pa := Vector2(float(tins[a]["at"][0]), float(tins[a]["at"][2]))
			in_dish = in_dish and pa.length() + DeskLook.TEA_TIN <= dish + 1e-4
			for b in range(a + 1, tins.size()):
				var pb := Vector2(float(tins[b]["at"][0]), float(tins[b]["at"][2]))
				pairs += 1
				apart += int(pa.distance_to(pb) >= 2.0 * DeskLook.TEA_TIN)
				# THE CONTROL: the tins as they had stood, each the dish's own radius less two from its middle
				var sr := 3.6 if tins.size() == 2 else 4.6
				ctl_in += int(2.0 * (sr - 2.0) * sin(PI / float(tins.size())) < 2.0 * DeskLook.TEA_TIN)
	_check(pairs > 300 and apart == pairs and in_dish and ctl_in > 0,
		"no two tea lights stand in each other (%d pairs over 200 saucers, every one apart, every tin on its saucer's floor) - the control, the tins as they had stood, met in %d"
		% [pairs, ctl_in])


func _stage() -> void:
	print("-- the stage")
	var vp := SubViewport.new()
	vp.size = Vector2i(320, 180)
	root.add_child(vp)
	var before := {}
	for key in TableMedium.STAGE:
		before[key] = vp.get(key)
	var m := DeskMedium.new()
	m.feed = ShowFeed.new()
	m.mount(vp)
	var set_ok := true
	for key in TableMedium.STAGE:
		set_ok = set_ok and vp.get(key) == TableMedium.STAGE[key]
	var differs := false
	for key in TableMedium.STAGE:
		differs = differs or before[key] != TableMedium.STAGE[key]
	vp.remove_child(m)
	var back := true
	for key in TableMedium.STAGE:
		back = back and vp.get(key) == before[key]
	_check(set_ok and differs and back,
		"a mounted desk sets the card table's stage (atlas %d, debanding) and gives it back as it leaves (the control: the stage's own, atlas %d, differs)"
		% [int(TableMedium.STAGE["positional_shadow_atlas_size"]), int(before["positional_shadow_atlas_size"])])
	m.free()
	vp.queue_free()
