extends SceneTree

## The gate of WHAT IS IN THINGS ([ShapeField], [Vessel], [Particles], [TablePhysics]; next/table_physics.md), with no
## renderer. The user, 2026-10-28, of the first alchemy episode: "The liquids are not liquids"; the snow "should be
## particles ... With physics and collision"; the shell's crystals "do not move and tumble, and they do not fall into
## the cauldron"; and "I would have expected the grinding to destroy those things".
##
##   godot --headless --path . --script res://tests/table/physics_check.gd
##
## - A SOLID'S FIELD IS ITS SHAPE: a cup's lathe is less inside its wall, more in its hollow and beyond it, and as far
##   from its wall as a point is; its way out points out. The control: a solid lathe (a pestle) has no hollow.
## - A VESSEL'S INSIDE KEEPS ITS VOLUME: a straight cup's inside is the cylinder its profile draws; its level upright is
##   where that share of it stands; tipped, the volume under its level - counted afresh, cell by cell - is the share
##   asked; it pours over its rim only once its liquid reaches it. The controls: upright and a little tipped, nothing
##   flows; a solid lathe has no inside.
## - A POUR IS THE TIP'S: a flask of ink carried over a bowl and tipped across the view pours by itself - the flask
##   empties, the bowl's water rises by what fell into it, a stream falls between them while it flows, and the act's
##   check says how much went where. The control: the flask tipped a little pours nothing, and the check says how far it
##   would have to go.
## - GRAINS ARE REAL: a jar of snow stood still keeps every grain where it lies; tipped over a bowl it spills them out of
##   its mouth and most land in the bowl. The control: carried upright over the bowl, none leaves the jar.
## - LOOSE THINGS TUMBLE: a dish's heap of stones (loose without being told) tipped over a cauldron falls out of it and
##   lands in the cauldron's brew. The control: the dish carried level, its stones stay in it.
## - A PESTLE GRINDS: a crystal lying loose in a mortar, the pestle pressed into the bowl going round over it, breaks
##   into pieces. The control: the pestle held still above it, the crystal stays whole.
## - THE SAME BAKE TWICE: the jar tipped on two tables built alike leaves every grain in the same place - and A FRAME IS ITS
##   OWN MOMENT: baked on to the end, the frame of a moment before the tip still has every grain in the jar (a frame had held
##   the solver's own arrays, and every frame was the latest).
## - A PINCH FALLS WHERE IT IS LET FALL: grains sprinkled from over a bowl land in it, drawn as they fall. The control:
##   before the act, none has fallen.
## - THE BAKE'S OWN THREAD BAKES WHAT THE CALLER'S DOES: the jar tipped with the bake on a thread of its own, the picture
##   asking as the app's does, comes to every grain where the bake on the caller's thread puts it.
## - A TABLE LET GO IS GONE: a table freed frees its work and the work's physics, every frame baked with them (each had held
##   the other, and every table a preview stood was kept). The control: a work and a physics made to hold each other
##   outlive their last holder.
## - A BAKE GOES ON TO THE NEXT TABLE (the puppeteer's `act` had baked from the start every call, 2026-10-28): the snow
##   tipped into the bowl, then the bowl nudged - a table built alike with the nudge written otherwise, handed the first
##   one's bake, takes it up at the checkpoint before the nudge and comes to every grain where a bake of its own plan from
##   the start puts it; with the tip written otherwise, it is taken up before the jar turns - in the middle of its carry -
##   and comes to the same. The controls: the nudge changes the grains (it was baked), the jar stood elsewhere takes
##   nothing, and a bake halted bakes no further.

var _fails := 0


func _init() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		print("  FAIL: " + what)


func _run() -> void:
	await process_frame
	for check in [_field, _vessel, _pour, _grains, _tumble, _grind, _same_twice, _sprinkle, _threaded, _let_go, _carried]:
		var t0 := Time.get_ticks_msec()
		var done: Variant = (check as Callable).call()
		print("  %s: %.1f s" % [(check as Callable).get_method(), float(Time.get_ticks_msec() - t0) / 1000.0])
		_ok(done == true, "%s stopped part way (a script error - see above)" % (check as Callable).get_method())
	print("physics_check: %s (%d failure%s)" % ["ALL OK" if _fails == 0 else "FAILED", _fails, "" if _fails == 1 else "s"])
	quit(1 if _fails > 0 else 0)


## A medium with no stage, as far as [TableWork] reads one: its root, its still air, its plan.
static func _medium() -> TableMedium:
	var m := TableMedium.new()
	m._root3 = Node3D.new()
	m._props = Node3D.new()
	m._root3.add_child(m._props)
	m._wind = {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	m._plan.cam_base = CardTable.sample_layout(rng)["camera"]
	return m


## [param spec] built and stood on [param m] at [param at] (meters, the table's space): `{node, built, thing}`.
static func _stand(m: TableMedium, spec: Dictionary, name: String, at: Vector3, seed := 5) -> Dictionary:
	var safe := Props.sanitize(spec, [])
	var thing: Dictionary = {}
	for t in safe["things"]:
		if String((t as Dictionary)["name"]) == name:
			thing = t
	m._work.materials = safe["materials"]
	var b := Props.build(thing, safe["materials"], seed)
	var node: Node3D = b["node"]
	node.transform = Transform3D(Basis.IDENTITY, at)
	m._props.add_child(node)
	m._work.take(thing, b, node)
	return {"node": node, "built": b, "thing": thing}


## A place [param cm] centimeters from the middle of the reading, in the table's space.
static func _at(cm: Vector3) -> Vector3:
	return Vector3(Tables.ORIGIN.x + cm.x * 0.01, cm.y * 0.01, Tables.ORIGIN.y + cm.z * 0.01)


const CUP := {"shape": "lathe", "profile": [[0, 0], [3, 0], [3, 8], [2.6, 8], [2.6, 0.4], [0, 0.4]], "material": "clay"}
const PESTLE := {"shape": "lathe", "profile": [[0, 0], [1, 0], [0.8, 8], [0, 8.5]], "material": "clay"}


static func _part(p: Dictionary) -> Dictionary:
	return Props._sanitize_part(p, {"clay": Props.sanitize_material({"kind": "ceramic"}, "#888888")}, [])


func _field() -> bool:
	var f := ShapeField.of(_part(CUP), AABB(Vector3(-0.03, 0.0, -0.03), Vector3(0.06, 0.08, 0.06)))
	_ok(f.hollow(), "a cup's lathe has no hollow")
	var wall := f.sample(Vector3(0.028, 0.04, 0.0))
	_ok(absf(wall.x + 0.002) < 0.0006, "inside a cup's wall, 2 mm from either face, the field says %.2f mm" % (wall.x * 1000.0))
	var near := f.sample(Vector3(0.031, 0.04, 0.0))
	_ok(absf(near.x - 0.001) < 0.0005 and Vector3(near.y, near.z, near.w).dot(Vector3.RIGHT) > 0.9,
		"a millimeter out from the cup's wall the field says %.2f mm, out along %s" % [near.x * 1000.0, str(Vector3(near.y, near.z, near.w))])
	var floor_d := f.sample(Vector3(0.01, 0.006, 0.0))
	_ok(absf(floor_d.x - 0.002) < 0.0006 and floor_d.z > 0.9, "2 mm over the cup's inner floor the field says %.2f mm" % (floor_d.x * 1000.0))
	_ok(f.sample(Vector3(0.0, 0.04, 0.0)).x > 0.004 and f.sample(Vector3(0.06, 0.04, 0.0)).x > 0.004, "the cup's hollow and the air past it are not outside it")
	var p := ShapeField.of(_part(PESTLE), AABB(Vector3(-0.01, 0.0, -0.01), Vector3(0.02, 0.085, 0.02)))
	_ok(not p.hollow() and p.sample(Vector3(0.0, 0.04, 0.0)).x < 0.0, "the control: a pestle is hollow, or not solid through")
	return true


func _vessel() -> bool:
	var f := ShapeField.of(_part(CUP), AABB(Vector3(-0.03, 0.0, -0.03), Vector3(0.06, 0.08, 0.06)))
	var v := Vessel.of(f)
	_ok(v != null, "a cup has no inside")
	if v == null:
		return true
	var want := PI * 0.026 * 0.026 * 0.076
	_ok(absf(v.volume - want) / want < 0.06, "a cup's inside holds %.1f ml, not the %.1f its profile draws" % [v.volume * 1e6, want * 1e6])
	var half := v.level(Vector3.UP, 0.5)
	_ok(absf(half - (0.004 + 0.038)) < 0.002, "half full and upright its level is %.1f cm high, not 4.2" % (half * 100.0))
	# TIPPED, its level keeps the volume: the cylinder under the plane counted afresh, cell by cell
	for deg in [30.0, 55.0, 80.0]:
		var th := deg_to_rad(deg)
		var up := Vector3(sin(th), cos(th), 0.0)
		var s := v.level(up, 0.35)
		var under := 0
		var all := 0
		var c := 0.0012
		for i in 44:
			for j in 64:
				for k in 44:
					var q := Vector3(-0.026 + (float(i) + 0.5) * c, 0.004 + (float(j) + 0.5) * c * 1.19, -0.026 + (float(k) + 0.5) * c)
					if q.x * q.x + q.z * q.z > 0.026 * 0.026 or q.y > 0.08:
						continue
					all += 1
					if q.dot(up) <= s:
						under += 1
		var share := float(under) / float(maxi(all, 1))
		_ok(absf(share - 0.35) < 0.025, "tipped %.0f degrees, the level leaves %.0f%% of the inside under it, not 35%%" % [deg, share * 100.0])
	var full := v.overflow(Vector3.UP, v.level(Vector3.UP, 0.5))
	var bit := v.overflow(Vector3(sin(0.35), cos(0.35), 0.0), v.level(Vector3(sin(0.35), cos(0.35), 0.0), 0.5))
	_ok(float(full["q"]) == 0.0 and float(bit["q"]) == 0.0, "the control: half full and upright, or tipped 20 degrees, the cup pours")
	var over := Vector3(sin(deg_to_rad(80.0)), cos(deg_to_rad(80.0)), 0.0)
	var poured := v.overflow(over, v.level(over, 0.5))
	_ok(float(poured["q"]) > 1e-6, "half full and tipped 80 degrees, nothing flows over the cup's rim")
	# the table's up leaning to +x in the cup's own space: the cup leans the other way, and pours over that side
	var lip: Vector3 = v.rim[int(poured["at"])]
	_ok(lip.x < -0.02, "it flows over the rim's highest point, not its lowest: %s" % str(lip))
	_ok(Vessel.of(ShapeField.of(_part(PESTLE), AABB(Vector3(-0.01, 0.0, -0.01), Vector3(0.02, 0.085, 0.02)))) == null,
		"the control: a pestle has an inside")
	return true


const POUR_SPEC := {"things": [
	{"name": "flask", "parts": [
		{"name": "neck", "shape": "lathe", "profile": [[0, 0], [2.5, 0], [2.5, 6], [1, 7.5], [1, 9], [0.8, 9], [0.8, 7.5], [2.3, 6], [2.3, 0.4], [0, 0.4]],
			"material": "glass", "points": {"mouth": [0, 9, 0]}},
		{"name": "ink", "shape": "lathe", "profile": [[0, 0.4], [2.3, 0.4], [2.3, 4], [0, 4]], "material": "ink"}]},
	{"name": "bowl", "parts": [
		{"shape": "lathe", "profile": [[0, 0], [6, 0], [8, 5], [8.4, 5.2], [7.6, 5], [5.6, 0.6], [0, 0.6]], "material": "clay"},
		{"name": "water", "shape": "lathe", "profile": [[0, 0.6], [5.6, 0.6], [7, 3.5], [0, 3.5]], "material": "water"}]}],
	"materials": {"glass": {"kind": "ceramic", "color": "#9ab0c0"}, "ink": {"kind": "liquid", "color": "#2a3a8a"},
		"clay": {"kind": "ceramic", "color": "#8a6a4a"}, "water": {"kind": "liquid", "color": "#6a8aa0"}}}


## The flask carried over the bowl, tipped [param deg] degrees across the view, held, and set back.
func _pour_bench(deg: float) -> TableMedium:
	var m := _medium()
	_stand(m, POUR_SPEC, "flask", _at(Vector3(25, 0, -10)))
	_stand(m, POUR_SPEC, "bowl", _at(Vector3(-5, 0, -10)))
	m._work.build({"acts": [{"name": "pour-it", "beat": 1, "length": 8, "tracks": [
		{"thing": "flask", "law": "carry", "to": [-14, 10.5, -10], "lift": 4, "between": [0.0, 0.3]},
		{"thing": "flask", "law": "path", "keys": [{"at": 0.32}, {"at": 0.45, "turn": [0, 0, -deg]}, {"at": 0.72, "turn": [0, 0, -deg]}, {"at": 0.8}]},
		{"thing": "flask", "law": "carry", "lift": 4, "between": [0.82, 1.0]}]}]}, 1)
	m._work.runs = [{"i": 0, "t0": 10.0, "t1": 18.0}]
	m._work._timelines()
	return m


func _liquid(m: TableMedium, thing: String) -> int:
	var ph: TablePhysics = m._work.physics
	for li in ph.liquids.size():
		if String((m._work.things[int((ph.liquids[li] as Dictionary)["thing"])] as Dictionary)["name"]) == thing:
			return li
	return -1


func _volume(m: TableMedium, li: int, t: float) -> float:
	var f: Variant = m._work.physics.frame_at(t)
	return float(((f as Dictionary)["liq"] as PackedFloat32Array)[li * 16]) if f != null else -1.0


func _pour() -> bool:
	var m := _pour_bench(105.0)
	var ph: TablePhysics = m._work.physics
	var ink := _liquid(m, "flask")
	var water := _liquid(m, "bowl")
	_ok(ink >= 0 and water >= 0 and bool((ph.liquids[ink] as Dictionary)["made"]), "the flask's ink or the bowl's water is not a liquid in its vessel: %s" % "; ".join(m._work.notes))
	if ink < 0 or water < 0:
		m._root3.free()
		return true
	m._work.tick(9.0)
	var ink0 := _volume(m, ink, 9.0)
	var water0 := _volume(m, water, 9.0)
	_ok(ink0 > 2e-5, "the flask holds %.1f ml of ink as it was drawn" % (ink0 * 1e6))
	# mid-pour a stream falls between them
	var seen := false
	for k in 30:
		m._work.tick(10.0 + 3.6 + float(k) * 0.05)
		for s in ph._streams:
			seen = seen or (s as MeshInstance3D).visible
	_ok(seen, "no stream falls while the flask is tipped over the bowl")
	m._work.tick(20.0)
	var ink1 := _volume(m, ink, 20.0)
	var water1 := _volume(m, water, 20.0)
	_ok(ink1 < ink0 * 0.6, "tipped 105 degrees, the flask kept %.0f%% of its ink" % (ink1 / maxf(ink0, 1e-12) * 100.0))
	_ok(water1 - water0 > (ink0 - ink1) * 0.7, "the bowl's water rose %.1f ml for the %.1f ml that left the flask" % [(water1 - water0) * 1e6, (ink0 - ink1) * 1e6])
	var said: String = m._work.check("pour-it")["text"]
	_ok(said.contains("poured out over its rim") and said.contains("into bowl"), "the check does not say where the ink went:\n%s" % said)
	m._root3.free()
	# the control: tipped a little, nothing pours, and the check says how far it must go
	var c := _pour_bench(20.0)
	var cink := _liquid(c, "flask")
	c._work.tick(9.0)
	var c0 := _volume(c, cink, 9.0)
	c._work.tick(20.0)
	_ok(absf(_volume(c, cink, 20.0) - c0) < 1e-8, "the control: tipped 20 degrees, the flask poured %.2f ml" % ((c0 - _volume(c, cink, 20.0)) * 1e6))
	var csaid: String = c._work.check("pour-it")["text"]
	_ok(not csaid.contains("poured out"), "the control: the check says a flask tipped 20 degrees poured:\n%s" % csaid)
	c._root3.free()
	var d := _pour_bench(45.0)
	d._work.tick(20.0)
	var dsaid: String = d._work.check("pour-it")["text"]
	_ok(dsaid.contains("NOTHING POURED") and dsaid.contains("past"), "a flask tipped 45 degrees that poured nothing is not told how far it must go:\n%s" % dsaid)
	d._root3.free()
	return true


const SNOW_SPEC := {"things": [
	{"name": "jar", "parts": [
		{"shape": "lathe", "profile": [[0, 0], [2.6, 0], [2.6, 6], [2.0, 6.6], [1.8, 6.6], [1.8, 6.1], [2.4, 5.6], [2.4, 0.4], [0, 0.4]], "material": "glass"},
		{"name": "snow", "shape": "grains", "at": [0, 1, 0], "fill": 0.5, "grain": 0.3, "material": "snow"}]},
	{"name": "bowl", "parts": [
		{"shape": "lathe", "profile": [[0, 0], [6, 0], [8, 5], [8.4, 5.2], [7.6, 5], [5.6, 0.6], [0, 0.6]], "material": "clay"}]}],
	"materials": {"glass": {"kind": "ceramic", "color": "#9ab0c0"}, "snow": {"kind": "powder", "color": "#f2f4f8"},
		"clay": {"kind": "ceramic", "color": "#8a6a4a"}}}


func _snow_bench(deg: float) -> TableMedium:
	var m := _medium()
	_stand(m, SNOW_SPEC, "jar", _at(Vector3(25, 0, -10)))
	_stand(m, SNOW_SPEC, "bowl", _at(Vector3(-5, 0, -10)))
	m._work.build({"acts": [{"name": "tip-snow", "beat": 1, "length": 8, "tracks": [
		{"thing": "jar", "law": "carry", "to": [-13, 9, -10], "lift": 4, "between": [0.0, 0.3]},
		{"thing": "jar", "law": "path", "keys": [{"at": 0.32}, {"at": 0.5, "turn": [0, 0, -deg]}, {"at": 0.75, "turn": [0, 0, -deg]}, {"at": 0.85}]},
		{"thing": "jar", "law": "carry", "lift": 4, "between": [0.86, 1.0]}]}]}, 1)
	m._work.runs = [{"i": 0, "t0": 4.0, "t1": 12.0}]
	m._work._timelines()
	return m


## How many of grains part [param gi]'s grains lie in [param thing]'s inside at [param t] (the table's space).
func _grains_in(m: TableMedium, gi: int, thing: String, t: float) -> int:
	var ph: TablePhysics = m._work.physics
	var f: Dictionary = ph.frame_at(t)
	var x: PackedVector3Array = f["x"]
	var alive: PackedByteArray = f["alive"]
	var li := _liquid(m, thing)
	if li < 0:
		return -1
	var sd: Dictionary = ph.solids[int((ph.liquids[li] as Dictionary)["solid"])]
	var xf: Transform3D = ph._pose_owner(sd, t) * (sd["local"] as Transform3D)
	var n := 0
	for i in (ph.grains[gi] as Dictionary)["ids"]:
		if alive[i] == 1 and ((ph.liquids[li] as Dictionary)["vessel"] as Vessel).contains(xf.affine_inverse() * x[i]):
			n += 1
	return n


func _grains() -> bool:
	var m := _snow_bench(130.0)
	var ph: TablePhysics = m._work.physics
	_ok(ph.grains.size() == 1 and ((ph.grains[0] as Dictionary)["ids"] as PackedInt32Array).size() > 40,
		"the jar's snow is not laid as grains: %d grains parts, %s" % [ph.grains.size(), str(((ph.grains[0] as Dictionary)["ids"] as PackedInt32Array).size()) if not ph.grains.is_empty() else "-"])
	if ph.grains.is_empty():
		m._root3.free()
		return true
	var n := ((ph.grains[0] as Dictionary)["ids"] as PackedInt32Array).size()
	m._work.tick(3.0)
	var still := _grains_in(m, 0, "jar", 3.0)
	_ok(still == n, "stood still, the jar's snow has %d of its %d grains in it" % [still, n])
	m._work.tick(14.0)
	var in_bowl := _grains_in(m, 0, "bowl", 14.0)
	var left := _grains_in(m, 0, "jar", 14.0)
	_ok(left < n / 2, "tipped 130 degrees, the jar kept %d of its %d grains" % [left, n])
	_ok(in_bowl > (n - left) / 2, "of the %d grains spilled, only %d landed in the bowl" % [n - left, in_bowl])
	m._root3.free()
	var c := _snow_bench(0.0)
	c._work.tick(14.0)
	var kept := _grains_in(c, 0, "jar", 14.0)
	_ok(kept >= n - 1, "the control: carried upright, the jar lost %d of its grains" % (n - kept))
	c._root3.free()
	return true


const DISH_SPEC := {"things": [
	{"name": "dish", "parts": [
		{"shape": "lathe", "profile": [[0, 0], [2.2, 0], [4.3, 0.9], [5.4, 1.9], [5.25, 2.05, 0], [4.0, 1.1], [1.8, 0.4], [0, 0.3]], "material": "shell"},
		{"name": "stones", "shape": "ball", "size": [1.2, 1.0, 1.2], "lumpy": 0.4, "material": "stone", "at": [0, 0.4, 0],
			"copies": {"heap": {"count": 3, "radius": 1.2}}}]},
	{"name": "cauldron", "parts": [
		{"shape": "lathe", "profile": [[0, 0], [7, 0], [9, 4], [9.4, 7], [8.8, 7], [8.4, 4], [6.6, 0.6], [0, 0.6]], "material": "iron"},
		{"name": "brew", "shape": "lathe", "profile": [[0, 0.6], [6.6, 0.6], [8.4, 4], [8.6, 5], [0, 5]], "material": "brew"}]}],
	"materials": {"shell": {"kind": "bone", "color": "#3a7a6a"}, "stone": {"kind": "stone", "color": "#b08a4a"},
		"iron": {"kind": "metal", "color": "#3a3a3a"}, "brew": {"kind": "liquid", "color": "#4a3a8a"}}}


func _dish_bench(deg: float) -> TableMedium:
	var m := _medium()
	_stand(m, DISH_SPEC, "dish", _at(Vector3(28, 0, -10)))
	_stand(m, DISH_SPEC, "cauldron", _at(Vector3(-5, 0, -10)))
	m._work.build({"acts": [{"name": "tip-dish", "beat": 1, "length": 8, "tracks": [
		{"thing": "dish", "law": "carry", "to": [-9, 11, -10], "lift": 4, "between": [0.0, 0.3]},
		{"thing": "dish", "law": "path", "keys": [{"at": 0.32}, {"at": 0.5, "turn": [0, 0, deg]}, {"at": 0.75, "turn": [0, 0, deg]}, {"at": 0.85}]},
		{"thing": "dish", "law": "carry", "lift": 4, "between": [0.86, 1.0]}]}]}, 1)
	m._work.runs = [{"i": 0, "t0": 4.0, "t1": 12.0}]
	m._work._timelines()
	return m


## How many of the loose things lie in [param thing]'s inside at [param t].
func _loose_in(m: TableMedium, thing: String, t: float) -> int:
	var ph: TablePhysics = m._work.physics
	var li := _liquid(m, thing)
	var sd: Dictionary = ph.solids[int((ph.liquids[li] as Dictionary)["solid"])]
	var xf: Transform3D = ph._pose_owner(sd, t) * (sd["local"] as Transform3D)
	var n := 0
	for l in ph.loose:
		var pose: Variant = ph.pose_of(int((l as Dictionary)["wi"]), t)
		if pose == null:
			continue
		var c := (pose as Transform3D) * ((m._work.works[int((l as Dictionary)["wi"])] as Dictionary)["w"]["box"] as AABB).get_center()
		if ((ph.liquids[li] as Dictionary)["vessel"] as Vessel).contains(xf.affine_inverse() * c):
			n += 1
	return n


func _tumble() -> bool:
	var m := _dish_bench(-110.0)
	var ph: TablePhysics = m._work.physics
	_ok(ph.loose.size() == 3, "the dish's heap of 3 stones is not 3 loose things: %d" % ph.loose.size())
	if ph.loose.size() != 3:
		m._root3.free()
		return true
	m._work.tick(3.0)
	_ok(_loose_in(m, "dish", 3.0) == 3, "stood still, the dish holds %d of its 3 stones" % _loose_in(m, "dish", 3.0))
	m._work.tick(14.0)
	var fell := _loose_in(m, "cauldron", 14.0)
	_ok(fell >= 2, "tipped over the cauldron, %d of the dish's 3 stones fell into it (%d still in the dish)" % [fell, _loose_in(m, "dish", 14.0)])
	var said: String = m._work.check("tip-dish")["text"]
	_ok(said.contains("in cauldron") or said.contains("cauldron's brew"), "the check does not say the stones went into the cauldron:\n%s" % said)
	m._root3.free()
	var c := _dish_bench(0.0)
	c._work.tick(14.0)
	_ok(_loose_in(c, "dish", 14.0) == 3, "the control: carried level, the dish holds %d of its 3 stones" % _loose_in(c, "dish", 14.0))
	c._root3.free()
	return true


const MORTAR_SPEC := {"things": [
	{"name": "mortar", "parts": [
		{"name": "bowl", "shape": "lathe", "profile": [[0, 0], [5.8, 0], [6.0, 0.6], [5.6, 1.3], [6.1, 4.0], [6.4, 5.9], [6.5, 6.4, 0], [5.3, 6.4, 0], [4.6, 4.5], [3.0, 2.3], [0, 1.85]],
			"material": "marble", "points": {"floor": [0, 1.9, 0]}, "smooth": true},
		{"name": "crystal", "shape": "point", "radius": 0.5, "length": 1.6, "tip": 0.6, "material": "quartz", "at": [0, 2.0, 0], "turn": [0, 0, 90], "loose": true},
		{"name": "pestle", "shape": "lathe", "profile": [[0, 0], [1.3, 0.15], [1.6, 1.1], [1.35, 2.5], [0.8, 4.2], [0.75, 8.6], [1.0, 10.0], [0.75, 10.7], [0, 10.9]],
			"material": "wood", "smooth": true, "at": [9, 0, 0], "joint": {"kind": "free"}, "points": {"tip": [9, 0.2, 0], "grip": [9, 10, 0]}}]}],
	"materials": {"marble": {"kind": "stone", "color": "#d8d4cc"}, "quartz": {"kind": "crystal", "color": "#e8e0f0", "clarity": 0.3},
		"wood": {"kind": "wood", "color": "#5a3a22"}}}


func _mortar_bench(grind: bool) -> TableMedium:
	var m := _medium()
	_stand(m, MORTAR_SPEC, "mortar", _at(Vector3(0, 0, -8)))
	var tracks: Array = []
	if grind:
		tracks.append({"thing": "mortar", "part": "pestle", "law": "aim",
			"tip": {"point": "tip", "around": "mortar.floor", "radius": 1.0, "period": 1.6, "lift": 0.4, "press": "mortar"},
			"grip": {"point": "grip", "around": "mortar.floor", "radius": 2.6, "period": 1.6, "lift": 9.5}})
	else:
		tracks.append({"thing": "mortar", "part": "pestle", "law": "carry", "to": "mortar.floor", "by": [0, 9, 0], "turn": [0, 0, 0], "lift": 2})
	m._work.build({"acts": [{"name": "grind", "beat": 1, "length": 14, "tracks": tracks}]}, 1)
	m._work.runs = [{"i": 0, "t0": 2.0, "t1": 16.0}]
	m._work._timelines()
	return m


func _grind() -> bool:
	var m := _mortar_bench(true)
	var ph: TablePhysics = m._work.physics
	_ok(ph.loose.size() == 1, "the mortar's crystal is not one loose thing: %d" % ph.loose.size())
	if ph.loose.size() != 1:
		m._root3.free()
		return true
	var wi := int((ph.loose[0] as Dictionary)["wi"])
	m._work.tick(1.5)
	_ok(ph.whole(wi, 1.5), "the crystal is broken before the pestle comes")
	m._work.tick(16.0)
	var f: Dictionary = ph.frame_at(16.0)
	var pieces := 0
	for i in (f["owner"] as PackedInt32Array).size():
		if (f["owner"] as PackedInt32Array)[i] == 1000 and (f["alive"] as PackedByteArray)[i] == 1:
			pieces += 1
	_ok(not ph.whole(wi, 16.0) and pieces >= 4, "ground for 14 seconds, the crystal is %s (%d pieces)" % ["whole" if ph.whole(wi, 16.0) else "broken", pieces])
	m._root3.free()
	var c := _mortar_bench(false)
	var cwi := int((c._work.physics.loose[0] as Dictionary)["wi"])
	c._work.tick(16.0)
	_ok(c._work.physics.whole(cwi, 16.0), "the control: the pestle held above it, the crystal broke")
	c._root3.free()
	return true


func _same_twice() -> bool:
	var a := _snow_bench(130.0)
	var b := _snow_bench(130.0)
	a._work.tick(10.0)
	b._work.tick(10.0)
	var fa: Dictionary = a._work.physics.frame_at(10.0)
	var fb: Dictionary = b._work.physics.frame_at(10.0)
	var xa: PackedVector3Array = fa["x"]
	var xb: PackedVector3Array = fb["x"]
	var worst := 0.0
	for i in mini(xa.size(), xb.size()):
		worst = maxf(worst, xa[i].distance_to(xb[i]))
	_ok(xa.size() == xb.size() and worst == 0.0, "the same tip on two tables built alike: %d and %d grains, %.3f mm apart at most" % [xa.size(), xb.size(), worst * 1000.0])
	var before := _grains_in(a, 0, "jar", 3.0)
	_ok(before == xa.size(), "baked on past the tip, the frame of a moment before it has %d of %d grains in the jar" % [before, xa.size()])
	a._root3.free()
	b._root3.free()
	return true


func _sprinkle() -> bool:
	var m := _medium()
	_stand(m, SNOW_SPEC, "bowl", _at(Vector3(-5, 0, -10)))
	m._work.build({"acts": [{"name": "a-pinch", "beat": 1, "length": 4, "tracks": [
		{"law": "sprinkle", "at": [-5, 14, -10], "material": "snow", "grain": 0.3, "amount": 24, "spread": 2, "between": [0.1, 0.5]}]}]}, 1)
	m._work.runs = [{"i": 0, "t0": 4.0, "t1": 8.0}]
	m._work._timelines()
	var ph: TablePhysics = m._work.physics
	_ok(ph.grains.size() == 1, "a sprinkle is not a grains part of its own: %d" % ph.grains.size())
	if ph.grains.is_empty():
		m._root3.free()
		return true
	m._work.tick(3.5)
	_ok(((ph.grains[0] as Dictionary)["ids"] as PackedInt32Array).is_empty(), "the control: grains have fallen before the sprinkle")
	m._work.tick(5.0)
	var mm: MultiMesh = ((ph.grains[0] as Dictionary)["mm"] as MultiMeshInstance3D).multimesh
	_ok(mm.visible_instance_count > 0, "sprinkled grains falling are not drawn")
	m._work.tick(10.0)
	var n := ((ph.grains[0] as Dictionary)["ids"] as PackedInt32Array).size()
	var inside := _grains_in(m, 0, "bowl", 10.0)
	_ok(n == 24 and inside >= 20, "of %d grains sprinkled over the bowl, %d lie in it" % [n, inside])
	m._root3.free()
	return true


func _threaded() -> bool:
	var a := _snow_bench(130.0)
	a._work.tick(12.0)
	var b := _snow_bench(130.0)
	var ph: TablePhysics = b._work.physics
	# the bake on a thread of its own, as the app runs it (a gate's medium is not in the tree, so it would bake on ours)
	ph._sync = false
	ph._sem = Semaphore.new()
	ph._thread = Thread.new()
	ph._thread.start(ph._run)
	var t := 0.0
	var waited := 0
	while t <= 12.0 and waited < 120000:
		b._work.tick(t)
		t += 0.25
		OS.delay_msec(2)
		waited += 2
	b._work.tick(12.0)
	while ph._k <= int(12.0 * float(TablePhysics.FPS)) + 1 and waited < 120000:
		OS.delay_msec(10)
		waited += 10
	var fa: Dictionary = a._work.physics.frame_at(12.0)
	var fb: Dictionary = ph.frame_at(12.0)
	var xa: PackedVector3Array = fa["x"]
	var xb: PackedVector3Array = fb["x"]
	var worst := 0.0
	for i in mini(xa.size(), xb.size()):
		worst = maxf(worst, xa[i].distance_to(xb[i]))
	_ok(xa.size() == xb.size() and worst == 0.0, "baked on its own thread, the tipped jar's grains are %.3f mm from where the caller's thread puts them (%d and %d)" % [worst * 1000.0, xa.size(), xb.size()])
	ph.clear()
	_ok(ph._thread == null and ph._sync, "cleared, the bake's thread is not stopped")
	a._root3.free()
	b._root3.free()
	return true


func _let_go() -> bool:
	var m := _snow_bench(130.0)
	m._work.tick(12.0)
	var work_was: WeakRef = weakref(m._work)
	var phys_was: WeakRef = weakref(m._work.physics)
	m._root3.free()
	m.free()
	_ok(work_was.get_ref() == null and phys_was.get_ref() == null, "a table freed keeps its work (%s) or its physics (%s)" % [work_was.get_ref() != null, phys_was.get_ref() != null])
	# the control: a work and a physics holding each other
	var w := TableWork.new()
	var ph := TablePhysics.new()
	w.physics = ph
	ph.set_meta("held", w)
	var w_was: WeakRef = weakref(w)
	w = null
	ph = null
	var kept: TableWork = w_was.get_ref()
	_ok(kept != null, "the control: a work and a physics holding each other are freed")
	if kept != null:
		kept.physics.remove_meta("held")
		kept.physics = null
	return true


## The snow tipped [param deg] into the bowl (4 s to 12 s), then the bowl nudged [param nudge] cm (14 s to 16 s) - the jar
## stood [param jar_x] cm across.
func _nudge_bench(deg: float, nudge: float, jar_x := 25.0) -> TableMedium:
	var m := _medium()
	_stand(m, SNOW_SPEC, "jar", _at(Vector3(jar_x, 0, -10)))
	_stand(m, SNOW_SPEC, "bowl", _at(Vector3(-5, 0, -10)))
	m._work.build({"acts": [{"name": "tip-snow", "beat": 1, "length": 8, "tracks": [
		{"thing": "jar", "law": "carry", "to": [-13, 9, -10], "lift": 4, "between": [0.0, 0.3]},
		{"thing": "jar", "law": "path", "keys": [{"at": 0.32}, {"at": 0.5, "turn": [0, 0, -deg]}, {"at": 0.75, "turn": [0, 0, -deg]}, {"at": 0.85}]},
		{"thing": "jar", "law": "carry", "lift": 4, "between": [0.86, 1.0]}]},
		{"name": "nudge", "beat": 1, "length": 2, "tracks": [{"thing": "bowl", "law": "carry", "to": [-5 + nudge, 0, -10], "lift": 1}]}]}, 1)
	m._work.runs = [{"i": 0, "t0": 4.0, "t1": 12.0}, {"i": 1, "t0": 14.0, "t1": 16.0}]
	m._work._timelines()
	return m


## The farthest any grain is apart in two frames (meters), or INF when they hold different numbers of grains.
static func _apart(fa: Dictionary, fb: Dictionary) -> float:
	var xa: PackedVector3Array = fa["x"]
	var xb: PackedVector3Array = fb["x"]
	if xa.size() != xb.size():
		return INF
	var worst := 0.0
	for i in xa.size():
		worst = maxf(worst, xa[i].distance_to(xb[i]))
	return worst


func _carried() -> bool:
	var a := _nudge_bench(130.0, 3.0)
	a._work.tick(18.0)
	var made: Dictionary = a._work.physics.carry()
	# the nudge written otherwise: taken up at the checkpoint before it
	var b := _nudge_bench(130.0, 6.0)
	var ph: TablePhysics = b._work.physics
	ph.adopt(made)
	ph._take_plan()
	var at := float(ph._k) / float(TablePhysics.FPS)
	_ok(at >= 12.0 and at <= 14.0 - TablePhysics.CARRY_MARGIN, "the nudge changed at 14 s, the carried bake was taken up at %.2f s" % at)
	b._work.tick(18.0)
	var c := _nudge_bench(130.0, 6.0)
	c._work.tick(18.0)
	var off := _apart(ph.frame_at(18.0), c._work.physics.frame_at(18.0))
	_ok(off == 0.0, "carried on, the nudged bowl's grains are %.3f mm from where a bake from the start puts them" % (off * 1000.0))
	var moved := _apart(ph.frame_at(18.0), a._work.physics.frame_at(18.0))
	_ok(moved > 0.0, "the control: the bowl nudged 6 cm leaves every grain where 3 cm does - the change was never baked")
	var same := _apart(ph.frame_at(11.0), a._work.physics.frame_at(11.0))
	_ok(same == 0.0, "before the nudge, the carried frames are not the first table's (%.3f mm)" % (same * 1000.0))
	# the tip written otherwise: taken up before the jar turns, in the middle of its carry - and the same all the same
	var d := _nudge_bench(100.0, 3.0)
	d._work.physics.adopt(a._work.physics.carry())
	d._work.physics._take_plan()
	var turn := 4.0 + 0.32 * 8.0
	var d_at := float(d._work.physics._k) / float(TablePhysics.FPS)
	_ok(d_at >= 5.0 and d_at <= turn - TablePhysics.CARRY_MARGIN, "the tip changed at %.2f s, the carried bake was taken up at %.2f s" % [turn, d_at])
	d._work.tick(14.0)
	var f := _nudge_bench(100.0, 3.0)
	f._work.tick(14.0)
	var mid := _apart(d._work.physics.frame_at(14.0), f._work.physics.frame_at(14.0))
	_ok(mid == 0.0, "taken up in the middle of the jar's carry, its grains are %.3f mm from where a bake from the start puts them" % (mid * 1000.0))
	# the control: the jar stood elsewhere - another table - takes nothing
	var e := _nudge_bench(130.0, 3.0, 27.0)
	e._work.physics.adopt(a._work.physics.carry())
	e._work.physics._take_plan()
	_ok(e._work.physics._k == 0, "the control: the jar stood elsewhere, the carried bake was taken up at frame %d" % e._work.physics._k)
	# halted, a bake goes no further
	e._work.physics.halt()
	e._work.physics.bake_until(5.0)
	_ok(e._work.physics._k == 0, "a bake halted went on to frame %d" % e._work.physics._k)
	for m in [a, b, c, d, e, f]:
		(m as TableMedium)._root3.free()
	return true
