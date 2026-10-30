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
##   into pieces, and the act says nothing passes through anything. The controls: the pestle held still above it, the
##   crystal stays whole; going round too wide for the bowl, its head driven into the wall, it is said to pass through it.
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
## - A HEAP AT REST SLEEPS WHOLE (the-quiet-crucible 707668, 2026-10-29: a jar of iron filings set back on the bench
##   trembled awake for the rest of the show, and the bake ran at half the show's pace): the filings tipped a little and
##   stood back are all asleep 1.9 s later. The control: while the jar turns, they are awake.
## - A SPLASH IS ONE THING'S (707668: "the splash was far too intense: it splattered everywhere"): the filings tipped into
##   water ring it and throw no drop; a heavy stone dropped from 15 cm splashes once, no higher than its speed sends the
##   drops. The control: the stone let go 1 cm over the water splashes nothing.
## - A DIP FILLS (707668's ladle came up empty): a cup dipped under the water and drawn up level holds it, the bowl the
##   less by it, and tipped pours it out. The control: dipped short of the surface, it comes up empty.
## - A THING LET GO FALLS, AND WHERE THE BAKE HAS NOT GOT TO, THE WORK PLACES WHAT IT HOLDS (707668's slip "poofed" back
##   to where the bake had last set it down): the stone let go over the water lies in the bowl, and with the bake short of
##   its carry it is the work's to place. The controls: at a moment baked, and past the bake before the work holds it, it
##   is the bake's.
## - A BLADE CUTS (the user, 2026-10-29: "cut it into pieces (Fruit Ninja style, which is to say - with real cutting
##   dynamics)"): a knife brought down twice through a carrot on a board cuts it into three pieces, each drawn as the
##   carrot's mesh kept behind its cuts and faced over them, lying apart, the middle one as long as between the strokes;
##   the act says so. The controls: the knife stopped short cuts nothing, and nor does it cut a stone.
## - WHAT THE HAND HOLDS MEETS WHAT IT IS CARRIED INTO (the-quiet-crucible 119515: a dragon's scale "clips, because it is
##   larger than the vial ... have proper collision handle how it falls, where it settles"): a scale wider than a vial's
##   mouth, lowered into it, stays out of it. The control: a bead that fits goes in and lies on the vial's floor.
## - WHAT FALLS ON A SLOPE GOES DOWN IT, AND NOTHING FLINGS IT (841899: a resin tear "lands ON TOP of the pestle, and just
##   sits there"; wedged between the pestle and its mortar's wall, a tear had been slid 8 cm up and out in a frame): a tear
##   dropped on a bronze pestle lying across its mortar, at five places along it, comes to rest on the mortar's floor every
##   time. The control: a flat chip dropped on a wooden board tilted 12 degrees stays where it fell on it.
## - WHAT IS IN A THING GOES WITH IT, AND RESTS ON WHAT IS UNDER IT (841899: crushed frankincense "left behind" as its
##   mortar was lifted, sulfur that "clips through" its jar as the jar was moved and "remains on the table", and a lump of
##   sulfur that "just floats above" a balance's thin pan): a jar's lumps, asleep on one another after a first carry, go
##   with it on a second, every one; a lump let fall on a pan 1.5 mm thick lies on it. The control: the jar went 25 cm.
## - A LIQUID'S SURFACE IS MOVED BY WHAT CROSSES IT (the-quiet-crucible 841899, the ladle going round in its cauldron: "I am
##   not seeing any water physics, surface tension, or any of that ... better liquid physics, which would react to
##   ANYTHING we put into them"): a spoon stirring a pot of water ripples it, millimeters high, the ripples running out
##   across most of it, and turns it, its middle dipping; let be, it goes still. The control: the spoon going round just
##   over the water leaves it at rest.
## - A LOOSE THING IS A BODY ONCE ANYTHING COMES TO IT (119515: of its table's 125 loose things, 114 had been left rigid -
##   the solver held no more - and its dragon's blood "didn't crush ... they don't rest on the bottom of the mortar"): set,
##   a dish's heap of forty beads nothing touches costs no particle, before the work comes to it and after. The control:
##   what the work carries is a body.

var _fails := 0


func _init() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		print("  FAIL: " + what)


func _run() -> void:
	await process_frame
	for check in [_field, _vessel, _pour, _grains, _tumble, _grind, _same_twice, _sprinkle, _threaded, _let_go, _carried,
			_heap_sleeps, _splash, _dip, _let_fall, _cut, _held_meets, _waves, _rolls_off, _rides_in]:
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
		# one nothing has come to yet lies as it was built, where the work has it
		if pose == null:
			pose = m._work._work_world(int((l as Dictionary)["wi"]), t)
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


func _mortar_bench(grind: bool, round := 1.0, seated := false) -> TableMedium:
	var m := _medium()
	var spec: Dictionary = MORTAR_SPEC.duplicate(true)
	if seated:
		# the pestle standing in the bowl, its tip on the floor
		var pestle: Dictionary = (((spec["things"] as Array)[0] as Dictionary)["parts"] as Array)[2]
		pestle["at"] = [0, 2.0, 0]
		pestle["points"] = {"tip": [0, 2.2, 0], "grip": [0, 12, 0]}
	_stand(m, spec, "mortar", _at(Vector3(0, 0, -8)))
	var tracks: Array = []
	if grind:
		tracks.append({"thing": "mortar", "part": "pestle", "law": "aim",
			"tip": {"point": "tip", "around": "mortar.floor", "radius": round, "period": 1.6, "lift": 0.4, "press": "mortar"},
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
	# A TOOL PRESSED ONTO WHAT IT WORKS IN MEETS IT (119515's puppeteer, told its pestle passed through the mortar, lifted it
	# clear of what it ground): the act says nothing passes through - and, the control, its head driven into the bowl's wall by
	# a round too wide for it, it does
	var seated := _mortar_bench(true, 1.0, true)
	var said: Dictionary = seated._work.check("grind")
	_ok(int(said["through"]) == 0, "a pestle pressed onto its mortar's floor is said to pass through it:\n%s" % String(said["text"]))
	seated._root3.free()
	var deep := _mortar_bench(true, 3.6, true)
	_ok(int(deep._work.check("grind")["through"]) > 0, "the control: a pestle ground round wider than its mortar's floor, its head in the wall, is not said to pass through it")
	deep._root3.free()
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


# --- the-quiet-crucible 707668, 2026-10-29 ------------------------------------------------------------------------

## A jar of iron filings (dense, coarse as packed), a bowl of water, and a dish with one heavy stone in it.
const FILINGS_SPEC := {"things": [
	{"name": "jar", "parts": [
		{"shape": "lathe", "profile": [[0, 0], [2.2, 0], [2.2, 4.4], [1.7, 5.0], [1.5, 5.0], [1.5, 4.6], [2.0, 4.1], [2.0, 0.4], [0, 0.4]], "material": "glass"},
		{"name": "filings", "shape": "grains", "at": [0, 0.5, 0], "fill": 0.5, "grain": 0.15, "material": "iron"}]},
	{"name": "bowl", "parts": [
		{"shape": "lathe", "profile": [[0, 0], [6, 0], [8, 5], [8.4, 5.2], [7.6, 5], [5.6, 0.6], [0, 0.6]], "material": "clay"},
		{"name": "water", "shape": "lathe", "profile": [[0, 0.6], [5.6, 0.6], [7, 3.5], [0, 3.5]], "material": "water"}]},
	{"name": "dish", "parts": [
		{"shape": "lathe", "profile": [[0, 0], [2.2, 0], [4.3, 0.9], [5.4, 1.9], [5.25, 2.05, 0], [4.0, 1.1], [1.8, 0.4], [0, 0.3]], "material": "clay"},
		{"name": "stone", "shape": "ball", "size": [3.0, 2.6, 3.0], "lumpy": 0.3, "material": "stone", "at": [0, 0.4, 0], "loose": true}]},
	{"name": "cup", "parts": [
		{"shape": "lathe", "profile": [[0, 0], [1.5, 0], [1.5, 2.0], [1.3, 2.0], [1.3, 0.2], [0, 0.2]], "material": "clay"}]}],
	"materials": {"glass": {"kind": "glass", "color": "#9ab0c0"}, "iron": {"kind": "metal", "color": "#3a3a3a"},
		"clay": {"kind": "ceramic", "color": "#8a6a4a"}, "water": {"kind": "liquid", "color": "#6a8aa0"},
		"stone": {"kind": "stone", "color": "#8a8a80"}}}


## The bench: the jar of filings tipped [param deg] into the bowl's water (4 s to 12 s) and set back; the stone carried
## [param drop] cm over the water and let go (14 s to 17 s); the cup dipped into the bowl, its foot [param dip] cm over the
## table (the water stands at 3.5, the cup's rim 2 over its foot), held and drawn up level (18 s to 24 s), then tipped
## [param pour] degrees (25 s to 28 s).
func _filings_bench(deg: float, drop: float, dip: float, pour := 0.0) -> TableMedium:
	var m := _medium()
	_stand(m, FILINGS_SPEC, "jar", _at(Vector3(25, 0, -10)))
	_stand(m, FILINGS_SPEC, "bowl", _at(Vector3(-5, 0, -10)))
	_stand(m, FILINGS_SPEC, "dish", _at(Vector3(-30, 0, -10)))
	_stand(m, FILINGS_SPEC, "cup", _at(Vector3(15, 0, 10)))
	m._work.build({"acts": [{"name": "tip-filings", "beat": 1, "length": 8, "tracks": [
		{"thing": "jar", "law": "carry", "to": [-11, 10, -10], "lift": 4, "between": [0.0, 0.3]},
		{"thing": "jar", "law": "path", "keys": [{"at": 0.32}, {"at": 0.5, "turn": [0, 0, -deg]}, {"at": 0.75, "turn": [0, 0, -deg]}, {"at": 0.85}]},
		{"thing": "jar", "law": "carry", "lift": 4, "between": [0.86, 1.0]}]},
		{"name": "drop-stone", "beat": 1, "length": 3, "tracks": [
			{"thing": "dish", "part": "stone", "law": "carry", "to": [-5, 3.5 + drop, -10], "lift": 4, "between": [0.0, 0.6]}]},
		{"name": "dip-cup", "beat": 1, "length": 6, "tracks": [
			{"thing": "cup", "law": "carry", "to": [-2, dip, -10], "lift": 6, "between": [0.0, 0.5]},
			{"thing": "cup", "law": "carry", "to": [-2, 12, -10], "lift": 0, "between": [0.7, 1.0]}]},
		{"name": "pour-cup", "beat": 1, "length": 3, "tracks": [
			{"thing": "cup", "law": "path", "keys": [{"at": 0.0}, {"at": 0.4, "turn": [0, 0, pour]}, {"at": 1.0, "turn": [0, 0, pour]}]}]}]}, 1)
	m._work.runs = [{"i": 0, "t0": 4.0, "t1": 12.0}, {"i": 1, "t0": 14.0, "t1": 17.0}, {"i": 2, "t0": 18.0, "t1": 24.0},
		{"i": 3, "t0": 25.0, "t1": 28.0}]
	m._work._timelines()
	return m


func _awake(ph: TablePhysics) -> int:
	var n := 0
	for i in ph.sim.n:
		if ph.sim.alive[i] == 1 and ph.sim.asleep[i] == 0:
			n += 1
	return n


## A HEAP AT REST SLEEPS WHOLE: the jar of filings tipped a little (they slide, none leaves it) and stood back - they come
## to rest and every one sleeps, where a few trembling ones had kept the rest awake for the whole show. The control: while
## the jar is still moving, they are awake.
func _heap_sleeps() -> bool:
	var m := _filings_bench(40.0, 15.0, 6.0)
	var ph: TablePhysics = m._work.physics
	m._work.tick(7.0)
	var moving := _awake(ph)
	_ok(moving > 20, "the control: tipped 40 degrees, only %d of the jar's filings are awake" % moving)
	m._work.tick(13.9)
	var left := _awake(ph)
	_ok(left == 0, "set back 1.9 s ago, %d of the jar's filings are still awake" % left)
	m._root3.free()
	return true


## A SPLASH IS ONE THING'S: the filings tipped into the water ring it and throw no drop; the heavy stone dropped into it
## from 15 cm throws a few, no higher than its own speed sends them. The control: the stone dropped from 1 cm throws none.
func _splash() -> bool:
	var m := _filings_bench(130.0, 15.0, 6.0)
	var ph: TablePhysics = m._work.physics
	m._work.tick(20.0)
	var water := _liquid(m, "bowl")
	var rings := 0
	var from_grains := 0
	var from_stone: Array = []
	for r in ph.ripples:
		if int((r as Dictionary)["liquid"]) == water and float((r as Dictionary)["t"]) < 13.0:
			rings += 1
	for sp in ph.splashes:
		var t := float((sp as Dictionary)["t"])
		if t < 13.0:
			from_grains += 1
		elif t >= 14.0:
			from_stone.append(sp)
	_ok(rings > 3, "the filings tipped into the water rang it %d times" % rings)
	_ok(from_grains == 0, "the filings tipped into the water splashed it %d times" % from_grains)
	_ok(from_stone.size() >= 1 and from_stone.size() <= 2, "the stone dropped into the water from 15 cm splashed it %d times" % from_stone.size())
	if not from_stone.is_empty():
		var sp: Dictionary = from_stone[0]
		var high := -INF
		for k in 40:
			for d in ph._drops_at(float(sp["t"]) + float(k) / 60.0):
				high = maxf(high, ((d as Array)[0] as Vector3).y - (sp["at"] as Vector3).y)
		var most := pow(sqrt(2.0 * TablePhysics.GRAVITY * 0.15) * TablePhysics.SPLASH_UP, 2.0) / (2.0 * TablePhysics.GRAVITY)
		_ok(int(sp["count"]) <= TablePhysics.DROPS_EACH and high > 0.0 and high <= most * 1.2,
			"the stone's splash threw %d drops %.1f mm high (no higher than %.1f mm)" % [int(sp["count"]), high * 1000.0, most * 1000.0])
	m._root3.free()
	var c := _filings_bench(130.0, 1.0, 6.0)
	c._work.tick(20.0)
	var late := 0
	for sp in c._work.physics.splashes:
		late += 1 if float((sp as Dictionary)["t"]) >= 14.0 else 0
	_ok(late == 0, "the control: the stone let go 1 cm over the water splashed it %d times" % late)
	c._root3.free()
	return true


## A DIP FILLS: the cup dipped under the water's surface and drawn up level holds water, and the bowl the less by it; tipped,
## it pours it out. The control: dipped short of the surface, it comes up empty.
func _dip() -> bool:
	var m := _filings_bench(0.0, 1.0, 0.7, 110.0)
	var cup := _liquid(m, "cup")
	var water := _liquid(m, "bowl")
	_ok(cup >= 0 and water >= 0, "the cup has no inside a liquid may fill, or the bowl no water")
	if cup < 0 or water < 0:
		m._root3.free()
		return true
	m._work.tick(17.5)
	var bowl0 := _volume(m, water, 17.5)
	m._work.tick(24.5)
	var held := _volume(m, cup, 24.5)
	var full := float((m._work.physics.liquids[cup] as Dictionary)["full_v"])
	_ok(held > full * 0.6, "dipped and drawn up, the cup holds %.1f of its %.1f ml" % [held * 1e6, full * 1e6])
	_ok(absf((bowl0 - _volume(m, water, 24.5)) - held) < full * 0.2, "the bowl gave %.1f ml for the cup's %.1f" % [(bowl0 - _volume(m, water, 24.5)) * 1e6, held * 1e6])
	m._work.tick(29.0)
	_ok(_volume(m, cup, 29.0) < held * 0.5, "tipped 110 degrees, the cup kept %.1f of its %.1f ml" % [_volume(m, cup, 29.0) * 1e6, held * 1e6])
	m._root3.free()
	var c := _filings_bench(0.0, 1.0, 4.5, 110.0)
	c._work.tick(24.5)
	_ok(_volume(c, _liquid(c, "cup"), 24.5) < 1e-9, "the control: dipped short of the surface, the cup holds %.2f ml" % (_volume(c, _liquid(c, "cup"), 24.5) * 1e6))
	c._root3.free()
	return true


## A THING LET GO FALLS, AND IS SEEN WHERE THE WORK HOLDS IT WHILE THE BAKE HAS NOT GOT THERE: the stone carried over the
## water and let go lies in the bowl after; and with the bake only as far as the carry's start, the stone, held after it,
## is the work's to place (707668's slip "poofed" back to where the bake had last set it down). The controls: the stone at
## a moment the bake has reached, and past it before the work holds it, is the bake's.
func _let_fall() -> bool:
	var m := _filings_bench(0.0, 8.0, 6.0)
	m._work.tick(17.5)
	_ok(_loose_in(m, "bowl", 17.5) == 1, "the stone carried over the water and let go is not in the bowl")
	m._root3.free()
	var b := _filings_bench(0.0, 8.0, 6.0)
	b._work.tick(13.0)
	var ti := -1
	for i in b._work.things.size():
		if String((b._work.things[i] as Dictionary)["name"]) == "dish":
			ti = i
	var wi := int((b._work._part_of(ti, "stone") as Dictionary)["wi"])
	_ok(b._work._outran(wi, 15.5), "the bake at 13 s, the stone carried from 14 s is drawn where the bake last had it at 15.5 s")
	_ok(not b._work._outran(wi, 12.0), "the control: at 12 s, which the bake has reached, the stone is not the bake's")
	_ok(not b._work._outran(wi, 13.5), "the control: at 13.5 s, past the bake but before the work holds it, the stone is not the bake's")
	b._root3.free()
	return true


## A board, something on it to cut - a carrot along it, or a stone - and a knife standing over it, its blade square across.
func _cut_bench(what: String, down: float) -> TableMedium:
	var spec := {"things": [
		# what is cut lies on the board as a part of it: a thing of its own is stood with its lowest point on the cloth
		{"name": "board", "parts": [{"shape": "box", "size": [24, 1.5, 12], "material": "wood"},
			{"name": "carrot", "shape": "lathe", "profile": [[0, 0], [1.3, 0], [1.2, 8], [0.5, 12], [0, 12.2]], "smooth": true,
				"material": "carrot" if what == "carrot" else "stone", "turn": [0, 0, -90], "at": [-6, 1.5 + 1.3, 0], "loose": true}]},
		{"name": "knife", "parts": [
			{"shape": "box", "size": [0.15, 4, 11], "material": "steel", "at": [0, 0, 0], "edge": true},
			{"shape": "box", "size": [1.2, 1.6, 7], "material": "wood", "at": [0, 3.2, 8]}]}],
		"materials": {"wood": {"kind": "wood", "color": "#8a6a4a"}, "carrot": {"kind": "plant", "color": "#e0742a", "density": 1.0},
			"stone": {"kind": "stone", "color": "#8a8a80"}, "steel": {"kind": "metal", "color": "#c8ccd0"}}}
	var m := _medium()
	_stand(m, spec, "board", _at(Vector3(0, 0, 0)))
	_stand(m, spec, "knife", _at(Vector3(-2, 1.5 + 2.6 + 1.0, 0)))
	# down through it and onto the board, up, along four centimeters, down again, up
	m._work.build({"acts": [{"name": "chop", "beat": 1, "length": 6, "tracks": [{"thing": "knife", "law": "path", "keys": [
		{"at": 0.0}, {"at": 0.2, "by": [0, -down, 0]}, {"at": 0.35, "by": [0, 0, 0]}, {"at": 0.5, "by": [4, 0, 0]},
		{"at": 0.7, "by": [4, -down, 0]}, {"at": 0.85, "by": [4, 0, 0]}]}]}]}, 1)
	m._work.runs = [{"i": 0, "t0": 2.0, "t1": 8.0}]
	m._work._timelines()
	return m


func _pieces_of(ph: TablePhysics, t: float) -> Array:
	var out: Array = []
	for c in (ph.frame_at(t) as Dictionary).get("cut", []):
		if int((c as Array)[0]) != -1:
			out.append(c)
	return out


## A BLADE CUTS (the user, 2026-10-29: "cut it into pieces (Fruit Ninja style, which is to say - with real cutting
## dynamics)"): a knife brought down twice through a carrot on a board cuts it into three pieces, each piece's mesh on
## its own side of its cuts with a face over them, lying apart along the board, the middle one as long as between the
## strokes - and the act says so. The controls: the knife stopped short of the carrot cuts nothing, and nor does it a stone.
func _cut() -> bool:
	var m := _cut_bench("carrot", 5.0)
	var ph: TablePhysics = m._work.physics
	m._work.tick(10.0)
	var cut := _pieces_of(ph, 10.0)
	_ok(cut.size() == 3, "a carrot cut twice is in %d pieces" % cut.size())
	if cut.size() == 3:
		var spans: Array = []
		for c in cut:
			var node := ph._piece_node(int(c[1]), c[2])
			var mesh := (node.get_child(0) as MeshInstance3D).mesh
			var worst := 0.0
			for q in mesh.get_faces():
				for pl in c[2]:
					worst = maxf(worst, (pl as Plane).distance_to(q))
			_ok(worst < 1e-4 and mesh.get_surface_count() >= 2, "a piece's mesh reaches %.2f mm past its cut, in %d surfaces" % [worst * 1000.0, mesh.get_surface_count()])
			var box: AABB = (c[3] as Transform3D) * mesh.get_aabb()
			spans.append(Vector2(box.position.x, box.end.x))
			node.free()
		spans.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
		var apart := (spans[0] as Vector2).y <= (spans[1] as Vector2).x + 0.001 and (spans[1] as Vector2).y <= (spans[2] as Vector2).x + 0.001
		var middle := (spans[1] as Vector2).y - (spans[1] as Vector2).x
		_ok(apart and middle > 0.035 and middle < 0.045, "the three pieces lie at %s cm along the board, the middle one %.1f cm long" % [
			str(spans.map(func(v: Vector2) -> String: return "%.1f..%.1f" % [(v.x - Tables.ORIGIN.x) * 100.0, (v.y - Tables.ORIGIN.x) * 100.0])), middle * 100.0])
		var said: String = m._work.check("chop")["text"]
		_ok(said.contains("CUT into 3 pieces"), "the act does not say the carrot was cut:\n%s" % said)
	m._root3.free()
	var c := _cut_bench("carrot", 1.0)
	c._work.tick(10.0)
	_ok(_pieces_of(c._work.physics, 10.0).is_empty(), "the control: the knife stopped short of the carrot cut it into %d pieces" % _pieces_of(c._work.physics, 10.0).size())
	c._root3.free()
	var s := _cut_bench("stone", 5.0)
	s._work.tick(10.0)
	_ok(_pieces_of(s._work.physics, 10.0).is_empty(), "the control: a stone was cut into %d pieces" % _pieces_of(s._work.physics, 10.0).size())
	s._root3.free()
	return true


# --- the-quiet-crucible 119515, 2026-10-29 ------------------------------------------------------------------------

## A narrow vial (its mouth 1.3 cm across), a tray with a scale 3.2 cm wide and a bead 0.8 cm across, both loose, and a
## dish of forty loose beads nothing comes near.
const VIAL_SPEC := {"things": [
	{"name": "vial", "parts": [{"shape": "lathe", "profile": [[0, 0], [1.2, 0], [1.2, 6], [0.8, 7], [0.8, 7.8], [0.65, 7.8], [0.65, 7.1],
		[1.05, 6], [1.05, 0.2], [0, 0.2]], "material": "glass"}]},
	{"name": "tray", "parts": [
		{"shape": "lathe", "profile": [[0, 0], [6, 0], [6, 1], [5.6, 1], [5.6, 0.3], [0, 0.3]], "material": "clay"},
		{"name": "scale", "shape": "box", "size": [3.2, 0.3, 3.2], "material": "stone", "at": [-2.5, 0.3, 0], "loose": true},
		{"name": "bead", "shape": "ball", "size": [0.8, 0.8, 0.8], "material": "stone", "at": [2.5, 0.3, 0], "loose": true}]},
	{"name": "dish", "parts": [
		{"shape": "lathe", "profile": [[0, 0], [5, 0], [5, 1.2], [4.6, 1.2], [4.6, 0.3], [0, 0.3]], "material": "clay"},
		{"name": "beads", "shape": "ball", "size": [0.9, 0.9, 0.9], "material": "stone", "at": [0, 0.3, 0], "copies": {"heap": {"count": 40, "radius": 3}}}]}],
	"materials": {"glass": {"kind": "glass", "color": "#9ab0c0"}, "clay": {"kind": "ceramic", "color": "#8a6a4a"},
		"stone": {"kind": "stone", "color": "#8a8a80"}}}


## The vial bench: [param what] (the scale or the bead) lifted over the vial's mouth (2 s to 5 s) and lowered straight
## down into it, to 2 cm over the table (5 s to 7 s), and let go.
func _vial_bench(what: String) -> TableMedium:
	var m := _medium()
	_stand(m, VIAL_SPEC, "vial", _at(Vector3(0, 0, -10)))
	_stand(m, VIAL_SPEC, "tray", _at(Vector3(15, 0, -10)))
	_stand(m, VIAL_SPEC, "dish", _at(Vector3(-35, 0, 5)))
	m._work.build({"acts": [{"name": "in", "beat": 1, "length": 5, "tracks": [
		{"thing": "tray", "part": what, "law": "carry", "to": [0, 12, -10], "lift": 4, "between": [0.0, 0.6]},
		{"thing": "tray", "part": what, "law": "carry", "to": [0, 2, -10], "lift": 0, "between": [0.6, 1.0]}]}]}, 1)
	m._work.runs = [{"i": 0, "t0": 2.0, "t1": 7.0}]
	m._work._timelines()
	return m


## Where loose part [param part] of the tray is at [param t] (the table's space), and whether it is a body.
func _tray_part(m: TableMedium, part: String, t: float) -> Array:
	var ti := -1
	for i in m._work.things.size():
		if String((m._work.things[i] as Dictionary)["name"]) == "tray":
			ti = i
	var wi := int((m._work._part_of(ti, part) as Dictionary)["wi"])
	var pose: Variant = m._work.physics.pose_of(wi, t)
	var box: AABB = ((m._work.works[wi] as Dictionary)["w"] as Dictionary).get("box", AABB())
	var at: Vector3 = ((pose as Transform3D) if pose != null else m._work._work_world(wi, t)) * box.get_center()
	return [at, pose != null]


func _held_meets() -> bool:
	var m := _vial_bench("scale")
	var ph: TablePhysics = m._work.physics
	_ok(ph.sim.n == 0, "set, the table's loose things already hold %d particles - a heap nothing touches should cost none" % ph.sim.n)
	m._work.tick(1.5)
	_ok(not bool(_tray_part(m, "scale", 1.5)[1]), "before the work comes to it, the scale is a body already")
	m._work.tick(9.0)
	var sc: Array = _tray_part(m, "scale", 9.0)
	var mouth := _at(Vector3(0, 0, -10))
	var c: Vector3 = sc[0]
	var inside := Vector2(c.x - mouth.x, c.z - mouth.z).length() < 0.0105 and c.y < 0.065
	_ok(bool(sc[1]) and not inside, "the scale 3.2 cm wide lowered into a vial 1.3 cm across its mouth went in: its middle at %.1f cm up, %.1f cm off the vial's axis" % [
		c.y * 100.0, Vector2(c.x - mouth.x, c.z - mouth.z).length() * 100.0])
	var heaped := 0
	for L in ph.loose:
		if String((L as Dictionary)["name"]).begins_with("beads") and int((L as Dictionary)["body"]) >= 0:
			heaped += 1
	_ok(heaped == 0, "%d of the dish's beads, which nothing came near, were made bodies" % heaped)
	m._root3.free()
	var b := _vial_bench("bead")
	b._work.tick(9.0)
	var bd: Array = _tray_part(b, "bead", 9.0)
	var d: Vector3 = bd[0]
	_ok(bool(bd[1]) and Vector2(d.x - mouth.x, d.z - mouth.z).length() < 0.0105 and d.y < 0.015,
		"the control: the bead 0.8 cm across lowered into the vial lies at %.1f cm up, %.1f cm off its axis - not on its floor" % [
		d.y * 100.0, Vector2(d.x - mouth.x, d.z - mouth.z).length() * 100.0])
	b._root3.free()
	return true


const WAVE_SPEC := {"things": [
	{"name": "pot", "parts": [
		{"shape": "lathe", "profile": [[0, 0], [10, 0], [11, 9], [11.4, 9.2], [10.6, 9], [9.6, 0.6], [0, 0.6]], "material": "clay",
			"points": {"floor": [0, 0.6, 0]}},
		{"name": "water", "shape": "lathe", "profile": [[0, 0.6], [9.6, 0.6], [10.2, 6], [0, 6]], "material": "water"},
		{"name": "spoon", "shape": "lathe", "profile": [[0, 0], [0.7, 0], [0.5, 18], [0, 18.2]], "material": "wood", "at": [15, 0, 0],
			"joint": {"kind": "free"}, "points": {"tip": [15, 0.5, 0], "grip": [15, 17, 0]}}]}],
	"materials": {"clay": {"kind": "ceramic", "color": "#8a6a4a"}, "water": {"kind": "liquid", "color": "#6a8aa0"},
		"wood": {"kind": "wood", "color": "#5a3a22"}}}


## The pot of water stirred by its spoon (2 s to 10 s), its tip [param lift] cm over the pot's floor - the water stands
## 5.4 cm deep - going round 4 cm out from its middle every 2 s.
func _wave_bench(lift: float) -> TableMedium:
	var m := _medium()
	_stand(m, WAVE_SPEC, "pot", _at(Vector3(0, 0, -8)))
	m._work.build({"acts": [{"name": "stir", "beat": 1, "length": 8, "tracks": [{"thing": "pot", "part": "spoon", "law": "aim",
		"tip": {"point": "tip", "around": "pot.floor", "radius": 4.0, "period": 2.0, "lift": lift},
		"grip": {"point": "grip", "around": "pot.floor", "radius": 1.5, "period": 2.0, "lift": lift + 15.0}}]}]}, 1)
	m._work.runs = [{"i": 0, "t0": 2.0, "t1": 10.0}]
	m._work._timelines()
	return m


## The water's ripples in frame [param t]: `[most (meters), share of its cells over 0.1 mm, its dip]` - or nulls at rest.
func _ripples(m: TableMedium, li: int, t: float) -> Array:
	var f: Dictionary = m._work.physics.frame_at(t)
	var dp: PackedVector2Array = f.get("dips", PackedVector2Array())
	var dip := dp[li].x if li < dp.size() else 0.0
	var wb: Variant = (f.get("waves", []) as Array)[li] if li < (f.get("waves", []) as Array).size() else null
	if wb == null:
		return [0.0, 0.0, dip]
	var W: SurfaceWaves = (m._work.physics.liquids[li] as Dictionary)["waves"]
	var most := 0.0
	var over := 0
	var cells := 0
	for c in (wb as PackedByteArray).size():
		if W.mask[c] == 0:
			continue
		cells += 1
		var h := absf(float(int((wb as PackedByteArray)[c]) - 128) * SurfaceWaves.QUANTUM)
		most = maxf(most, h)
		over += 1 if h > 0.0001 else 0
	return [most, float(over) / float(maxi(cells, 1)), dip]


func _waves() -> bool:
	var m := _wave_bench(2.5)
	var water := _liquid(m, "pot")
	_ok(water >= 0, "the pot's water is not a liquid in its vessel")
	if water < 0:
		m._root3.free()
		return true
	var most := 0.0
	var spread := 0.0
	var dip := 0.0
	var t := 4.0
	while t <= 9.5:
		m._work.tick(t)
		var r := _ripples(m, water, t)
		most = maxf(most, float(r[0]))
		spread = maxf(spread, float(r[1]))
		dip = maxf(dip, float(r[2]))
		t += 0.25
	_ok(most > 0.0005 and most < 0.006, "the spoon stirring the water raised ripples %.2f mm high (0.5 to 6)" % (most * 1000.0))
	_ok(spread > 0.4, "the stir's ripples reached %.0f%% of the water's surface (more than 40%%)" % (spread * 100.0))
	_ok(dip > 1.0, "the stirred water turned none: its middle dips %.2f m a square meter" % dip)
	print("  stirred: ripples %.2f mm, over %.0f%% of it, its curve %.2f m a square meter" % [most * 1000.0, spread * 100.0, dip])
	m._work.tick(19.0)
	var still := _ripples(m, water, 19.0)
	_ok(float(still[0]) == 0.0, "9 s after the stir, the water still ripples %.3f mm" % (float(still[0]) * 1000.0))
	m._root3.free()
	var c := _wave_bench(7.5)
	var above := 0.0
	t = 4.0
	while t <= 9.5:
		c._work.tick(t)
		above = maxf(above, float(_ripples(c, _liquid(c, "pot"), t)[0]))
		t += 0.25
	_ok(above == 0.0, "the control: the spoon going round over the water rippled it %.3f mm" % (above * 1000.0))
	c._root3.free()
	return true


const ROLL_SPEC := {"things": [
	{"name": "mortar", "parts": [
		{"name": "bowl", "material": "bronze", "points": {"floor": [0, 1.9, 0], "mouth": [0, 8.4, 0]}, "smooth": true, "shape": "lathe",
			"profile": [[0, 0], [5.2, 0, 0], [5.4, 0.6, 0], [4.8, 1.2], [5, 6.4], [6.3, 7.6], [6.6, 8.4, 0], [5.8, 8.4, 0], [4.6, 7.3], [4, 4], [2.6, 2], [0, 1.8]]},
		{"name": "pestle", "material": "bronze", "smooth": true, "shape": "lathe", "at": [-1.4, 2.6, 0], "turn": [0, 0, -50], "joint": {"kind": "free"},
			"profile": [[0, 0], [1.3, 0], [1.55, 0.8], [1.2, 2.4], [0.7, 3.8], [0.75, 10.8], [1.05, 11.6], [0.8, 12.3], [0, 12.5]]}]},
	{"name": "board", "parts": [{"shape": "box", "size": [14, 1, 7], "material": "oak", "at": [0, 3, 0], "turn": [0, 0, 12]}]},
	{"name": "jar", "parts": [
		{"shape": "lathe", "profile": [[0, 0], [3, 0], [3, 1], [2.6, 1], [2.6, 0.3], [0, 0.3]], "material": "clay"},
		{"name": "tear", "shape": "ball", "size": [1.0, 0.8, 0.9], "lumpy": 0.6, "material": "resin", "at": [0, 0.3, 0], "loose": true},
		{"name": "chip", "shape": "box", "size": [1.8, 0.5, 1.8], "material": "resin", "at": [1.5, 0.3, 0], "loose": true}]}],
	"materials": {"bronze": {"kind": "metal", "color": "#8f6a3a"}, "clay": {"kind": "ceramic", "color": "#8a6a4a"},
		"resin": {"kind": "crystal", "color": "#e6d49a", "clarity": 0.4}, "oak": {"kind": "wood", "color": "#7a5530"}}}


## The tear carried from its jar and let go [param drop] (cm from the middle of the reading) over [param onto], at 3 s:
## where it is at 6 s (the table's space).
func _tear_onto(onto: String, drop: Vector3, what := "tear") -> Vector3:
	var m := _medium()
	_stand(m, ROLL_SPEC, onto, _at(Vector3(0, 0, -8)))
	_stand(m, ROLL_SPEC, "jar", _at(Vector3(18, 0, -8)))
	m._work.build({"acts": [{"name": "drop", "beat": 1, "length": 2, "tracks": [
		{"thing": "jar", "part": what, "law": "carry", "to": [drop.x, drop.y, drop.z], "lift": 4}]}]}, 1)
	m._work.runs = [{"i": 0, "t0": 1.0, "t1": 3.0}]
	m._work._timelines()
	var ph: TablePhysics = m._work.physics
	m._work.tick(6.0)
	var wi := -1
	for L in ph.loose:
		if String((L as Dictionary)["name"]) == what:
			wi = int((L as Dictionary)["wi"])
	var pose: Variant = ph.pose_of(wi, 6.0)
	var at: Vector3 = (pose as Transform3D).origin if pose != null else Vector3.INF
	m._root3.free()
	return at


func _rolls_off() -> bool:
	var axis := _at(Vector3(0, 0, -8))
	var where := PackedStringArray()
	var bad := 0
	for x in [-1.5, 0.0, 1.0, 2.0, 3.0]:
		var at := _tear_onto("mortar", Vector3(x, 12.0, -8.0))
		var off := Vector2(at.x - axis.x, at.z - axis.z).length()
		where.append("%.1f cm over it, %.1f cm out" % [at.y * 100.0, off * 100.0])
		bad += 0 if at.y < 0.035 and off < 0.05 else 1
	_ok(bad == 0, "the tear dropped on the pestle across its mortar does not come to rest on the mortar's floor every time: %s" % ", ".join(where))
	var on := _tear_onto("board", Vector3(0.0, 8.0, -8.0), "chip")
	_ok(on.y > 0.01 and absf(on.x - axis.x) < 0.03, "the control: a flat chip dropped on a wooden board tilted 12 degrees is %.1f cm up, %.1f cm along - not where it fell on it" % [
		on.y * 100.0, (on.x - axis.x) * 100.0])
	return true


const RIDE_SPEC := {"things": [
	{"name": "jars", "parts": [{"name": "jar", "joint": {"kind": "free"}, "parts": [
		{"shape": "lathe", "profile": [[0, 0], [2.2, 0], [2.4, 0.3], [2.4, 4.6], [2, 5.2], [1.8, 5.4], [1.8, 6], [1.55, 6], [1.55, 5.4], [2.05, 4.7], [2.1, 0.4], [0, 0.4]],
			"material": "clay"},
		{"name": "lumps", "shape": "ball", "size": [1.1, 0.9, 1.0], "lumpy": 0.5, "material": "sulfur", "at": [0, 0.4, 0],
			"copies": {"heap": {"count": 6, "radius": 1.4}, "jitter": 0.5}, "loose": true}]}]},
	{"name": "pan", "parts": [
		{"shape": "lathe", "profile": [[0, 0], [1.4, 0], [3, 0.7], [3.2, 0.9], [2.95, 0.9], [2.75, 0.65], [1.3, 0.15], [0, 0.15]], "material": "brass", "at": [0, 3.8, 0]},
		{"shape": "box", "size": [1.6, 3.8, 1.6], "material": "brass"}]}],
	"materials": {"clay": {"kind": "ceramic", "color": "#8a6a4a"}, "sulfur": {"kind": "crystal", "color": "#e8d23a"},
		"brass": {"kind": "metal", "color": "#b8924c"}}}


func _rides_in() -> bool:
	var m := _medium()
	_stand(m, RIDE_SPEC, "jars", _at(Vector3(0, 0, -8)))
	_stand(m, RIDE_SPEC, "pan", _at(Vector3(30, 0, -8)))
	m._work.build({"acts": [
		{"name": "there", "beat": 1, "length": 2, "tracks": [{"thing": "jars", "part": "jar", "law": "path", "keys": [{"at": 0.0}, {"at": 0.3, "by": [0, 6, 0]}, {"at": 0.8, "by": [-25, 6, 0]}, {"at": 1.0, "by": [-25, 0, 0]}]}]},
		{"name": "back", "beat": 1, "length": 2, "tracks": [{"thing": "jars", "part": "jar", "law": "path", "keys": [{"at": 0.0}, {"at": 0.3, "by": [0, 6, 0]}, {"at": 0.8, "by": [25, 6, 0]}, {"at": 1.0, "by": [25, 0, 0]}]}]},
		{"name": "lump", "beat": 1, "length": 2, "tracks": [{"thing": "jars", "part": "lumps 1", "law": "carry", "to": [30, 5.5, -8], "lift": 4}]}]}, 1)
	m._work.runs = [{"i": 0, "t0": 2.0, "t1": 4.0}, {"i": 1, "t0": 8.0, "t1": 10.0}, {"i": 2, "t0": 12.0, "t1": 14.0}]
	m._work._timelines()
	var ph: TablePhysics = m._work.physics
	m._work.tick(11.0)
	var jar: Vector3 = _at(Vector3(0, 0, -8))
	var out := 0
	var far := 0.0
	for L in ph.loose:
		var pose: Variant = ph.pose_of(int((L as Dictionary)["wi"]), 11.0)
		var c: Vector3 = (pose as Transform3D).origin if pose != null else Vector3.INF
		var off := Vector2(c.x - jar.x, c.z - jar.z).length()
		far = maxf(far, off)
		out += 0 if off < 0.025 and c.y < 0.05 else 1
	_ok(ph.loose.size() == 6 and out == 0, "carried 25 cm and back, %d of the jar's %d lumps are not in it (the furthest %.1f cm from its axis)" % [out, ph.loose.size(), far * 100.0])
	m._work.tick(16.0)
	var L1: Dictionary = {}
	for L in ph.loose:
		if String((L as Dictionary)["name"]) == "lumps 1":
			L1 = L
	var low := INF
	if not L1.is_empty() and int(L1["body"]) >= 0:
		for i in (ph.sim.bodies[int(L1["body"])] as Dictionary)["ids"]:
			low = minf(low, ph.sim.x[i].y - ph.sim.r[i])
	_ok(absf(low - 0.0395) < 0.001, "the lump let fall on the pan lies %.1f mm over the pan's floor (at 39.5 mm)" % ((low - 0.0395) * 1000.0))
	m._root3.free()
	return true
