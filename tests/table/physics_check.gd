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
## - A SUNK VESSEL IS THE LIQUID IT IS IN (841899's ladle, stirring its brew, poured sixty parcels a second out of its lip
##   under the brew, drawn falling through the cauldron's floor): a ladle stirred round a pot of water fills and pours
##   nothing while its rim is under the surface. The control: lifted out and tipped, it pours.
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
##   with it on a second, every one; a lump let fall on a pan 1.5 mm thick lies on it. The control: the jar went 25 cm. And
##   AT REST THEY GIVE THEIR SPHERES BACK (841899 replayed: every body had stayed one, and the solver was full by the show's
##   middle): between the carries the lumps hold no particle; the control, carried, they do.
## - A LIQUID'S SURFACE IS MOVED BY WHAT CROSSES IT (the-quiet-crucible 841899, the ladle going round in its cauldron: "I am
##   not seeing any water physics, surface tension, or any of that ... better liquid physics, which would react to
##   ANYTHING we put into them"): a spoon stirring a pot of water ripples it, millimeters high, the ripples running out
##   across most of it, and turns it, its middle dipping; let be, it goes still. The control: the spoon going round just
##   over the water leaves it at rest.
## - A BALANCE WEIGHS (841899: the beam tipped by the puppeteer while the lump on its pan "never settles into the bowl ...
##   just floats above the scale" - "the weight never transfers to the scale"): a balance's beam on its hinge, its pans
##   hung from its ends, stands level empty; a lump carried onto one pan tips it down to its stop, the lump riding the pan
##   down, the pan still level; the lump taken off, it swings back level. The control: no act turns it - the beam empty
##   at the start is level, and so its pans.
## - WHAT THE HAND HOLDS MEETS WHAT IT IS MOVED INTO, AND LET GO IT FALLS TO REST (841899: a pestle put back "clipping
##   through the side of the mortar, completely"; the user: "physics everywhere"): a rod a path drives 5 cm into a block
##   stops at the block's face; a rod lifted and let go 6 cm over the table falls and lies on the table, asleep. The
##   controls: the work's own poses are 5 cm in the block and 6 cm in the air.
## - A MOVE UNDER WAY GOES ON THROUGH A NEW PLAN (841899 played live: a plan made again as a sentence's words came began the
##   ladle's move to the pot again from where the ladle was by then - over the pot, upside-down and past it): a rod lifted,
##   carried and turned, a new plan handed over half way that moves only a later act, ends where its move says. The control:
##   begun again from where it was then, it ends centimeters off.
## - WHAT A BODY IS NOT LOOKED AT AGAINST IS STILL THERE (841899: clear of the table by 18.5 cm and of nothing else looked at,
##   the ladle let go in its pot fell through its floor): a rod carried high over a cup on a stand, stood upright, lowered
##   into it and let go lies on the cup's floor, in nothing. The control: let go there with no cup, it falls to the table.
## - HELD UP BETWEEN ITS MOVES (841899: the ladle stood down into its pot was let go a quarter second after its move, the
##   words before the stir longer than the puppeteer's rehearsal): a rod lifted 6 cm and taken up again 3 s later is held
##   where its move left it until then. The control: set down on the table, it is let go between its moves.
## - A WHOLE THING MEETS WHAT IT IS MOVED INTO (841899's mortar went through the cauldron's rim): a crate a path drives 5 cm
##   into a block stops at its face, and the act's report says the block held it back. The control: the work's own crate is
##   in the block.
## - A THIN WALL AT REST IS NEVER CROSSED (841899: stirring pressed crushed resin through the cauldron's 3 mm copper floor, and
##   the ladle let go in its pot sank through it): a brass ladle stirred over powder on a 3 mm floor presses none through it,
##   and let go in the pot lies on the floor. The control: stirred, the powder moves.
## - WHAT LIVE DIFFERS FROM AN EXPORT BY (841899 played live): what was baked past a new plan's change is dropped (the control:
##   a plan changing nothing keeps it); a part is held for a later act not yet placed (the control: with none, let go); a live
##   show waits for a bake behind it until the bake is 3 s ahead (the control: a bake on the caller's thread never waits); a
##   new plan is baked again from its first change - a rod going round whose act ends later keeps its bake (the control: a
##   path, whose places stretch with its act, is baked again from its start).
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
			_heap_sleeps, _splash, _dip, _sunk, _let_fall, _cut, _held_meets, _waves, _rolls_off, _rides_in, _weighs, _tool_meets, _tool_falls,
			_moved_on, _let_go_in, _held_between, _thing_meets, _held_up_from_below, _carried_with, _put_back_in, _thin_walls, _plan_drops_stale, _held_till_placed, _waits_for_bake, _replan_from_change]:
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
	var xf: Transform3D = ph._solid_at(sd, t)
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
		# ...over the bowl's rim and straight down into it, as a hand dips a cup: carried in an arc, its side went through the rim
		{"name": "dip-cup", "beat": 1, "length": 6, "tracks": [
			{"thing": "cup", "law": "carry", "to": [-2, 9, -10], "lift": 4, "between": [0.0, 0.3]},
			{"thing": "cup", "law": "carry", "to": [-2, dip, -10], "lift": 0, "between": [0.3, 0.5]},
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
	# ...ITS INSIDE DRAWN IN IT: made as it first filled, away from where the cup was built (841899's ladle, first filled in its
	# pot: its inside had been built and drawn that whole way off, a ghost of its bowl going round with every stir)
	var L: Dictionary = m._work.physics.liquids[cup]
	var sd: Dictionary = m._work.physics.solids[int(L["solid"])]
	var off := INF
	var built_off := 0.0
	if not (L["nodes"] as Array).is_empty() and not (sd["meshes"] as Array).is_empty():
		var inside: MeshInstance3D = (L["nodes"] as Array)[0]
		var own: MeshInstance3D = (sd["meshes"] as Array)[0]
		off = (m._work._world_of(inside) * inside.get_aabb().get_center()).distance_to(m._work._world_of(own) * own.get_aabb().get_center())
		built_off = ((sd["rest"] as Transform3D).affine_inverse() * m._work._world_of(inside)).origin.distance_to(
			m._work.physics._mesh_in_vessel(inside, sd).origin)
	_ok(built_off > 0.03, "the control: measured against the cup as built, its inside is only %.1f cm off" % (built_off * 100.0))
	_ok(off < 0.015, "the cup's inside, made as it first filled, is drawn %.1f cm from the cup" % (off * 100.0))
	# ...while the hand still holds it tipped: the act over, it is let go over the bowl, and falls in and fills again
	m._work.tick(27.5)
	_ok(_volume(m, cup, 27.5) < held * 0.5, "tipped 110 degrees, the cup kept %.1f of its %.1f ml" % [_volume(m, cup, 27.5) * 1e6, held * 1e6])
	m._root3.free()
	var c := _filings_bench(0.0, 1.0, 4.5, 110.0)
	c._work.tick(24.5)
	_ok(_volume(c, _liquid(c, "cup"), 24.5) < 1e-9, "the control: dipped short of the surface, the cup holds %.2f ml" % (_volume(c, _liquid(c, "cup"), 24.5) * 1e6))
	c._root3.free()
	return true


const LADLE_SPEC := {"things": [
	{"name": "pot", "parts": [
		{"shape": "lathe", "profile": [[0, 0], [10, 0], [11, 9], [11.4, 9.2], [10.6, 9], [9.6, 0.6], [0, 0.6]], "material": "clay",
			"points": {"floor": [0, 0.6, 0]}},
		{"name": "water", "shape": "lathe", "profile": [[0, 0.6], [9.6, 0.6], [10.2, 6], [0, 6]], "material": "water"},
		{"name": "ladle", "joint": {"kind": "free"}, "at": [15, 0, 0], "points": {"bowl": [15, 0.3, 0], "grip": [17.3, 17, 0]}, "parts": [
			{"shape": "lathe", "profile": [[0, 0], [2, 0], [2.4, 2.2], [2.2, 2.2], [1.8, 0.2], [0, 0.2]], "material": "clay"},
			{"shape": "lathe", "profile": [[0, 0], [0.3, 0], [0.3, 16], [0, 16]], "material": "clay", "at": [2.3, 1.2, 0]}]}]}],
	"materials": {"clay": {"kind": "ceramic", "color": "#8a6a4a"}, "water": {"kind": "liquid", "color": "#6a8aa0"}}}


## A SUNK VESSEL IS THE LIQUID IT IS IN: a ladle stood in a pot of water and stirred round it (2 s to 10 s) fills, and pours
## nothing out while its rim is under the surface - 841899's ladle, stirring its brew, had poured sixty parcels a second out
## of its lip under the brew, each drawn falling through the cauldron's floor toward the brazier under it. The control: lifted
## out (11 s) and tipped (from 12 s), it pours.
func _sunk() -> bool:
	var m := _medium()
	_stand(m, LADLE_SPEC, "pot", _at(Vector3(0, 0, -8)))
	m._work.build({"acts": [{"name": "stir", "beat": 1, "length": 8, "tracks": [{"thing": "pot", "part": "ladle", "law": "aim",
		"tip": {"point": "bowl", "around": "pot.floor", "radius": 4.0, "period": 2.0, "lift": 0.5},
		"grip": {"point": "grip", "around": "pot.floor", "radius": 1.0, "period": 2.0, "lift": 17.0}}]},
		{"name": "lift-tip", "beat": 1, "length": 4, "tracks": [{"thing": "pot", "part": "ladle", "law": "path", "jitter": 0.0, "keys": [
			{"at": 0.0}, {"at": 0.25, "by": [0, 16, 0]}, {"at": 0.5, "by": [12, 16, 0]}, {"at": 0.8, "by": [12, 16, 0], "turn": [0, 0, 120]},
			{"at": 1.0, "by": [12, 16, 0], "turn": [0, 0, 120]}]}]}]}, 1)
	m._work.runs = [{"i": 0, "t0": 2.0, "t1": 10.0}, {"i": 1, "t0": 10.0, "t1": 14.0}]
	m._work._timelines()
	var ph: TablePhysics = m._work.physics
	var ladle := -1
	for wi in m._work.works.size():
		if m._work._part_label(wi) == "ladle":
			ladle = wi
	var inside := -1
	for li in ph.liquids.size():
		if int((ph.solids[int((ph.liquids[li] as Dictionary)["solid"])] as Dictionary)["wi"]) == ladle:
			inside = li
	_ok(inside >= 0, "the ladle has no inside a liquid may fill")
	if inside < 0:
		m._root3.free()
		return true
	m._work.tick(15.0)
	var held := 0.0
	for k in 10:
		held = maxf(held, _volume(m, inside, 9.0 + 0.1 * float(k)))
	var sunk := 0
	var poured := 0
	for pd in ph.parcels:
		if int((pd as Dictionary)["from"]) != inside:
			continue
		var t0 := float((pd as Dictionary)["t0"])
		sunk += 1 if t0 < 10.0 else 0
		poured += 1 if t0 >= 12.0 else 0
	_ok(held > float((ph.liquids[inside] as Dictionary)["full_v"]) * 0.5, "stood in the water, the ladle holds only %.1f ml" % (held * 1e6))
	_ok(sunk == 0, "stirred under the water, the ladle poured %d parcels out of its lip" % sunk)
	_ok(poured > 0, "the control: lifted out and tipped 120 degrees, the ladle poured no parcel")
	m._root3.free()
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
	# down through it and onto the board, up, along four centimeters, down again, up - and laid flat on the cloth in front of
	# the board: let go in the air, a knife falls, and blade first through what it cut
	m._work.build({"acts": [{"name": "chop", "beat": 1, "length": 6, "tracks": [{"thing": "knife", "law": "path", "keys": [
		{"at": 0.0}, {"at": 0.2, "by": [0, -down, 0]}, {"at": 0.35, "by": [0, 0, 0]}, {"at": 0.5, "by": [4, 0, 0]},
		{"at": 0.7, "by": [4, -down, 0]}, {"at": 0.85, "by": [4, 0, 0]}]},
		{"thing": "knife", "law": "carry", "between": [0.88, 1.0], "to": [2, 0, 18], "turn": [0, 0, 90], "lift": 2, "down": true}]}]}, 1)
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
	m._work.tick(3.0)
	var carried := Particles.MOST - ph.sim.room()
	m._work.tick(7.8)
	var resting := Particles.MOST - ph.sim.room()
	_ok(carried > 0 and resting == 0, "the jar's lumps hold %d particles at rest between the carries (%d carried, the control)" % [resting, carried])
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


const BALANCE_SPEC := {"things": [
	{"name": "balance", "parts": [
		{"shape": "box", "size": [19, 1.6, 7], "material": "oak"},
		{"shape": "lathe", "at": [0, 1.6, 0], "smooth": true, "material": "brass",
			"profile": [[0, 0], [1.6, 0, 0], [1.6, 0.4, 0], [0.7, 1], [0.5, 2], [0.45, 11], [0.7, 11.6], [0.5, 12.2], [0.35, 12.6], [0, 12.9]]},
		{"name": "beam", "joint": {"kind": "hinge", "at": [0, 13, 0], "axis": [0, 0, 1], "range": [-10, 10]}, "parts": [
			{"shape": "box", "at": [0, 12.55, 0], "size": [15, 0.45, 0.5], "material": "brass"},
			{"shape": "box", "at": [0, 10, 0.45], "size": [0.25, 3, 0.2], "material": "brass"},
			{"name": "left pan", "at": [-7, 0, 0], "parts": [
				{"shape": "lathe", "at": [0, 3.8, 0], "smooth": true, "material": "brass",
					"profile": [[0, 0], [1.4, 0], [3, 0.7], [3.2, 0.9, 0], [2.95, 0.9, 0], [2.75, 0.65], [1.3, 0.15], [0, 0.15]]},
				{"shape": "tube", "path": [[0, 13, 0], [2.9, 4.7, 0]], "radius": 0.08, "copies": {"ring": {"count": 3, "radius": 0}}, "material": "brass"}]},
			{"name": "right pan", "at": [7, 0, 0], "parts": [
				{"shape": "lathe", "at": [0, 3.8, 0], "smooth": true, "material": "brass",
					"profile": [[0, 0], [1.4, 0], [3, 0.7], [3.2, 0.9, 0], [2.95, 0.9, 0], [2.75, 0.65], [1.3, 0.15], [0, 0.15]]},
				{"shape": "tube", "path": [[0, 13, 0], [2.9, 4.7, 0]], "radius": 0.08, "copies": {"ring": {"count": 3, "radius": 0}}, "material": "brass"}]}]}]},
	{"name": "stand", "parts": [
		{"shape": "box", "size": [4, 2, 4], "material": "oak"},
		{"name": "weight", "shape": "ball", "size": [1.6, 1.4, 1.5], "at": [0, 2, 0], "material": "stone", "loose": true}]}],
	"materials": {"oak": {"kind": "wood", "color": "#6b4a2b"}, "brass": {"kind": "metal", "color": "#b8924c"},
		"stone": {"kind": "stone", "color": "#8a8478"}}}


## The beam's angle as baked (degrees), the weight's lowest point (meters) and the right pan's up, at [param t].
func _balance_at(m: TableMedium, t: float) -> Dictionary:
	var w := m._work
	var ph: TablePhysics = w.physics
	m._work.tick(t)
	var beam := -1
	var weight := -1
	var pan := -1
	for wi in w.works.size():
		match w._part_label(wi):
			"beam":
				beam = wi
			"weight":
				weight = wi
			"right pan":
				pan = wi
	# ...its lowest point where it is - a body, or lying again where it came to rest ([method TablePhysics._rest_loose])
	var low := INF
	var L: Dictionary = ph.loose[int(ph._loose_of[weight])]
	var pose: Variant = ph.pose_of(weight, t)
	if pose != null:
		var moved := (pose as Transform3D) * (L["built"] as Transform3D).affine_inverse()
		for p in (L["spheres"] as PackedVector3Array):
			low = minf(low, (moved * p).y - float(L["rad"]))
	var up := Vector3.ZERO
	for sd in ph.solids:
		if int((sd as Dictionary)["wi"]) == pan:
			up = ((sd as Dictionary)["xf"] as Transform3D).basis.y.normalized()
	var a: Variant = ph.swing_of(beam, t)
	return {"angle": float(a) if a != null else NAN, "low": low, "up": up}


func _weighs() -> bool:
	var m := _medium()
	_stand(m, BALANCE_SPEC, "balance", _at(Vector3(0, 0, -10)))
	_stand(m, BALANCE_SPEC, "stand", _at(Vector3(0, 0, 4)))
	m._work.build({"acts": [
		{"name": "on", "beat": 1, "length": 2, "tracks": [{"thing": "stand", "part": "weight", "law": "carry", "to": [7, 5.0, -10], "lift": 6}]},
		{"name": "off", "beat": 1, "length": 2, "tracks": [{"thing": "stand", "part": "weight", "law": "carry", "to": [0, 3.0, 4], "lift": 6}]},
		{"name": "nudge", "beat": 1, "length": 1, "tracks": [{"thing": "balance", "part": "beam", "law": "path", "keys": [{"at": 0.0, "value": 0.0}, {"at": 1.0, "value": 8.0}]}]}]}, 1)
	m._work.runs = [{"i": 2, "t0": 0.5, "t1": 1.5}, {"i": 0, "t0": 2.0, "t1": 4.0}, {"i": 1, "t0": 10.0, "t1": 12.0}]
	m._work._timelines()
	var empty := _balance_at(m, 1.9)
	_ok(absf(float(empty["angle"])) < 0.2 and (empty["up"] as Vector3).angle_to(Vector3.UP) < 0.01,
		"the control: the empty balance, an act turning its beam, stands at %.2f degrees, its pan's up %s" % [float(empty["angle"]), empty["up"]])
	var on := _balance_at(m, 8.0)
	_ok(float(on["angle"]) < -5.0, "a lump laid on the right pan tips the beam to %.2f degrees, not down toward it" % float(on["angle"]))
	_ok(float(on["low"]) < 0.0395 - 0.005 and float(on["low"]) > 0.0395 - 0.02,
		"the lump on the tipped pan lies %.1f mm up - not ridden down with the pan from its floor at 39.5 mm" % (float(on["low"]) * 1000.0))
	_ok((on["up"] as Vector3).angle_to(Vector3.UP) < 0.01, "the pan hung from the tipped beam is not level: its up %s" % on["up"])
	var off := _balance_at(m, 22.0)
	_ok(absf(float(off["angle"])) < 0.5, "the lump taken off, the beam stands at %.2f degrees - not swung back level" % float(off["angle"]))
	m._root3.free()
	return true


const TOOL_SPEC := {"things": [
	{"name": "tools", "parts": [
		{"shape": "box", "size": [4, 1, 4], "material": "oak"},
		{"name": "rod", "joint": {"kind": "free"}, "parts": [{"shape": "box", "size": [10, 1.2, 1.2], "at": [0, 1, 0], "material": "brass"}]}]},
	{"name": "block", "parts": [{"shape": "box", "size": [6, 6, 6], "material": "oak"}]}],
	"materials": {"oak": {"kind": "wood", "color": "#6b4a2b"}, "brass": {"kind": "metal", "color": "#b8924c"}}}


## A bench of the rod on its stand and a block beside it, the rod moved by [param keys] (a path) from 2 s for [param length].
func _tool_bench(keys: Array, length: float) -> TableMedium:
	var m := _medium()
	_stand(m, TOOL_SPEC, "tools", _at(Vector3(-15, 0, -8)))
	_stand(m, TOOL_SPEC, "block", _at(Vector3(0, 0, -8)))
	m._work.build({"acts": [{"name": "move", "beat": 1, "length": length, "tracks": [{"thing": "tools", "part": "rod", "law": "path", "jitter": 0.0, "keys": keys}]}]}, 1)
	m._work.runs = [{"i": 0, "t0": 2.0, "t1": 2.0 + length}]
	m._work._timelines()
	return m


## The rod's work, its solid, and how deep into the block its surface goes (meters, less than 0 in it), posed [param x].
func _rod_in_block(m: TableMedium, x: Transform3D) -> float:
	var ph: TablePhysics = m._work.physics
	var rod := -1
	for wi in m._work.works.size():
		if m._work._part_label(wi) == "rod":
			rod = wi
	var rs: Dictionary = {}
	var bs: Dictionary = {}
	for sd in ph.solids:
		if int((sd as Dictionary)["wi"]) == rod:
			rs = sd
		elif m._work.things[int((sd as Dictionary)["thing"])]["name"] == "block":
			bs = sd
	var deep := INF
	var local: Transform3D = (rs["rest"] as Transform3D)
	var n0: Transform3D = m._work._rest["w%d:pose" % rod]
	for q in (rs["field"] as ShapeField).surface_points():
		var p := x * n0.affine_inverse() * local * q
		deep = minf(deep, (bs["field"] as ShapeField).sample((bs["inv"] as Transform3D) * p).x)
	return deep


func _rod(m: TableMedium) -> int:
	for wi in m._work.works.size():
		if m._work._part_label(wi) == "rod":
			return wi
	return -1


func _tool_meets() -> bool:
	var m := _tool_bench([{"at": 0.0}, {"at": 0.2, "by": [0, 2, 0]}, {"at": 1.0, "by": [17, 2, 0]}], 3.0)
	var t := 2.0 + 3.0 * 0.97
	m._work.tick(t)
	var rod := _rod(m)
	var held: Variant = m._work.physics.pose_of(rod, t)
	var kin := m._work._work_world(rod, t)
	var deep := _rod_in_block(m, held) if held != null else -INF
	var kdeep := _rod_in_block(m, kin)
	_ok(kdeep < -0.015, "the control: the path drives the rod only %.1f mm into the block" % (-kdeep * 1000.0))
	_ok(held != null and deep > -0.001, "the rod driven into the block goes %.1f mm into it - it does not stop at its face" % (-deep * 1000.0))
	m._root3.free()
	return true


func _tool_falls() -> bool:
	var m := _tool_bench([{"at": 0.0}, {"at": 0.3, "by": [0, 6, 0]}, {"at": 1.0, "by": [0, 6, 9]}], 2.0)
	var rod := _rod(m)
	m._work.tick(7.0)
	var ph: TablePhysics = m._work.physics
	var pose: Variant = ph.pose_of(rod, 7.0)
	var low := INF
	var klow := INF
	for sd in ph.solids:
		if int((sd as Dictionary)["wi"]) != rod:
			continue
		var local: Transform3D = (sd as Dictionary)["rest"]
		var n0: Transform3D = m._work._rest["w%d:pose" % rod]
		for q in ((sd as Dictionary)["field"] as ShapeField).surface_points():
			if pose != null:
				low = minf(low, ((pose as Transform3D) * n0.affine_inverse() * local * q).y)
			klow = minf(klow, (m._work._work_world(rod, 7.0) * n0.affine_inverse() * local * q).y)
	var b: Dictionary = ph.rigid.bodies[int(ph._rigid_of[rod])] if ph._rigid_of.has(rod) else {}
	_ok(klow > 0.05, "the control: the work's own rod is %.1f cm up, not left in the air" % (klow * 100.0))
	_ok(pose != null and low > -0.0005 and low < 0.0015 and bool(b.get("asleep", false)),
		"the rod let go 6 cm over the table lies %.1f mm over it, %s" % [low * 1000.0, "asleep" if bool(b.get("asleep", false)) else "awake"])
	m._root3.free()
	return true


const CUP_SPEC := {"things": [
	{"name": "cup on a stand", "parts": [
		{"shape": "box", "size": [8, 6, 8], "material": "oak"},
		{"shape": "lathe", "profile": [[0, 0], [3, 0], [3, 8], [2.6, 8], [2.6, 1], [0, 1]], "at": [0, 6, 0], "material": "brass"}]}],
	"materials": {"oak": {"kind": "wood", "color": "#6b4a2b"}, "brass": {"kind": "metal", "color": "#b8924c"}}}


## A bench of the rod on its stand and a cup on a stand of its own [param cup_x] cm along, the rod moved by paths
## [param moves] (`[keys, t0, t1]` each).
func _rod_bench(moves: Array, cup_x: float) -> TableMedium:
	var m := _medium()
	_stand(m, TOOL_SPEC, "tools", _at(Vector3(-15, 0, -8)))
	_stand(m, CUP_SPEC, "cup on a stand", _at(Vector3(cup_x, 0, -8)))
	var acts: Array = []
	var runs: Array = []
	for k in moves.size():
		var mv: Array = moves[k]
		acts.append({"name": "move %d" % k, "beat": 1, "length": float(mv[2]) - float(mv[1]),
			"tracks": [{"thing": "tools", "part": "rod", "law": "path", "jitter": 0.0, "keys": mv[0]}]})
		runs.append({"i": k, "t0": float(mv[1]), "t1": float(mv[2])})
	m._work.build({"acts": acts}, 1)
	m._work.runs = runs
	m._work._timelines()
	return m


## The rod's surface posed [param x] (its node's pose, the table's space).
func _rod_points(m: TableMedium, x: Transform3D) -> PackedVector3Array:
	var rod := _rod(m)
	var n0: Transform3D = m._work._rest["w%d:pose" % rod]
	var out := PackedVector3Array()
	for sd in m._work.physics.solids:
		if int((sd as Dictionary)["wi"]) != rod:
			continue
		var local: Transform3D = (sd as Dictionary)["rest"]
		for q in ((sd as Dictionary)["field"] as ShapeField).surface_points():
			out.append(x * n0.affine_inverse() * local * q)
	return out


## A MOVE UNDER WAY GOES ON THROUGH A NEW PLAN: the rod lifted, carried 10 cm and turned a quarter turn (2 s to 6 s), a new
## plan handed over at 4 s that moves only a later act (10 s to 11 s), ends within millimeters of where its move says - a live
## reading hands one over with each sentence's words, and each had begun every held move again from where the bake had it by
## then (841899: the ladle's way to the pot taken twice, its turn too). The control: the move begun again then, as each new
## plan had done, ends centimeters off.
func _moved_on() -> bool:
	var keys := [{"at": 0.0}, {"at": 0.3, "by": [0, 6, 0]}, {"at": 1.0, "by": [-10, 6, 0], "turn": [0, 90, 0]}]
	var later := [{"at": 0.0}, {"at": 1.0, "by": [0, 0, 5]}]
	var off: Array = []
	for begun_again in [false, true]:
		var m := _rod_bench([[keys, 2.0, 6.0], [later, 10.0, 12.0]], 45.0)
		var ph: TablePhysics = m._work.physics
		ph.bake_until(4.0)
		m._work.runs = [{"i": 0, "t0": 2.0, "t1": 6.0}, {"i": 1, "t0": 11.0, "t1": 13.0}]
		m._work._timelines()
		ph.bake_until(4.0)
		if begun_again:
			ph._held = {}
		m._work.tick(5.95)
		var rod := _rod(m)
		var baked: Variant = ph.pose_of(rod, 5.95)
		off.append((baked as Transform3D).origin.distance_to(m._work._work_world(rod, 5.95).origin) if baked != null else INF)
		m._root3.free()
	_ok(float(off[1]) > 0.02, "the control: begun again half way, the rod still ends %.1f mm from where its move says" % (float(off[1]) * 1000.0))
	_ok(float(off[0]) < 0.004, "a new plan handed over half way through the rod's move leaves it %.1f mm from where its move says" % (float(off[0]) * 1000.0))
	return true


## WHAT A BODY IS NOT LOOKED AT AGAINST IS STILL THERE: the rod lifted 24 cm, carried over a cup on a stand and stood upright
## (clear of the table by 20 cm and of nothing else near it), lowered into the cup and let go 2 cm over its floor, lies on the
## floor - its lowest point at the floor's 7 cm, none of it in the cup or its stand past the 2 mm a let-go body may stand in
## what holds it (841899: the ladle let go standing in its
## pot fell through the pot's floor and the brazier to the table). The control: let go there with the cup elsewhere, it falls
## to the table.
func _let_go_in() -> bool:
	var keys := [{"at": 0.0}, {"at": 0.3, "by": [0, 24, 0]}, {"at": 0.6, "by": [25, 24, 0], "turn": [0, 0, 90]},
		{"at": 1.0, "by": [25, 12, 0], "turn": [0, 0, 90]}]
	var low: Array = []
	var deep := INF
	for cup_x in [10.0, 45.0]:
		var m := _rod_bench([[keys, 2.0, 6.0]], cup_x)
		m._work.tick(8.0)
		var ph: TablePhysics = m._work.physics
		var pose: Variant = ph.pose_of(_rod(m), 8.0)
		var lowest := INF
		if pose != null:
			for p in _rod_points(m, pose):
				lowest = minf(lowest, p.y)
				if cup_x == 10.0:
					for sd in ph.solids:
						if String((m._work.things[int((sd as Dictionary)["thing"])] as Dictionary)["name"]) == "cup on a stand":
							deep = minf(deep, ((sd as Dictionary)["field"] as ShapeField).sample(((sd as Dictionary)["inv"] as Transform3D) * p).x)
		low.append(lowest)
		m._root3.free()
	_ok(float(low[1]) < 0.002, "the control: let go with no cup under it, the rod's lowest point is %.1f cm up, not on the table" % (float(low[1]) * 100.0))
	_ok(float(low[0]) > 0.066 and float(low[0]) < 0.08 and deep > -0.002,
		"the rod let go in the cup lies %.1f cm up (its floor is at 7) and %.1f mm into the cup or its stand" % [float(low[0]) * 100.0, -deep * 1000.0])
	return true


## HELD UP BETWEEN ITS MOVES: the rod lifted 6 cm and carried 9 (2 s to 4 s), taken up again at 7 s, is held where its move left
## it at 5.5 s, swaying as a hand holds it (841899: the ladle stood down into its pot was let go a quarter second after its
## move and fell into it - the words before the stir longer than the puppeteer's rehearsal, where the work, the act's check and
## the rehearsal all had the hand holding it). The control: set down on the table instead, it is let go between its moves.
func _held_between() -> bool:
	var up := [{"at": 0.0}, {"at": 0.3, "by": [0, 6, 0]}, {"at": 1.0, "by": [0, 6, 9]}]
	var down := [{"at": 0.0}, {"at": 0.3, "by": [0, 4, 0]}, {"at": 0.8, "by": [0, 4, 9]}, {"at": 1.0, "by": [0, -1, 9]}]
	var again := [{"at": 0.0}, {"at": 1.0, "by": [0, 0, -9]}]
	var res: Array = []
	for keys in [up, down]:
		var m := _rod_bench([[keys, 2.0, 4.0], [again, 7.0, 9.0]], 45.0)
		var rod := _rod(m)
		m._work.tick(5.5)
		var ph: TablePhysics = m._work.physics
		var pose: Variant = ph.pose_of(rod, 5.5)
		var b: Dictionary = ph.rigid.bodies[int(ph._rigid_of[rod])]
		res.append([b["held"] != null, (pose as Transform3D).origin.distance_to(m._work._work_world(rod, 3.99).origin) if pose != null else INF])
		m._root3.free()
	_ok(not bool(res[1][0]), "the control: set down on the table, the rod is still held between its moves")
	_ok(bool(res[0][0]) and float(res[0][1]) < 0.008, "the rod lifted 6 cm and taken up again 3 s later is %s between its moves, %.1f mm from where its move left it" % [
		"held" if bool(res[0][0]) else "let go", float(res[0][1]) * 1000.0])
	return true


## A jar with its stopper in its neck (the neck's bore 1.85 cm, the stopper's plug 1.8).
const STOPPERED_SPEC := {"things": [
	{"name": "jar", "parts": [
		{"name": "jar", "joint": {"kind": "free"}, "shape": "lathe", "material": "glass",
			"profile": [[0, 0], [2.1, 0], [2.2, 0.3], [2.2, 13.2], [2.35, 13.4], [2.35, 13.8], [1.85, 13.8], [1.85, 0.4], [0, 0.4]]},
		{"name": "stopper", "joint": {"kind": "free"}, "shape": "lathe", "material": "cork", "at": [0, 12.8, 0],
			"profile": [[0, 0], [1.8, 0], [1.85, 1.0], [2.35, 1.05], [2.35, 1.8], [0, 1.9]]}]}],
	"materials": {"glass": {"kind": "glass", "color": "#a0c0c0"}, "cork": {"kind": "wood", "color": "#a07850"}}}


## WHAT ONE ACT MOVES TOGETHER, ONE HAND CARRIES (841899: the frankincense jar and its cork fetched by one path, each swayed
## its own way, the cork wandered through the jar's neck - two held bodies passed through each other - and let go it fell in,
## and let go seated it still fell through, its cap's lip finer than the solver's points, [method TablePhysics._seat]):
## a jar and its stopper carried 30 cm by the same path keep the stopper where it sits in the jar within half a millimeter all
## the way, and set down, the stopper is still in the neck. The control: the stopper given a hand of its own wanders from it.
func _carried_with() -> bool:
	var keys := [{"at": 0.0}, {"at": 0.25, "by": [0, 8, 0]}, {"at": 0.75, "by": [30, 8, 0]}, {"at": 1.0, "by": [30, 0, 0]}]
	var res: Array = []
	for own_hand in [false, true]:
		var m := _medium()
		_stand(m, STOPPERED_SPEC, "jar", _at(Vector3(-15, 0, -8)))
		m._work.build({"acts": [{"name": "fetch", "beat": 1, "length": 4.0, "tracks": [
			{"thing": "jar", "part": "jar", "law": "path", "keys": keys}, {"thing": "jar", "part": "stopper", "law": "path", "keys": keys}]}]}, 1)
		if own_hand:
			((m._work.acts[0] as Dictionary)["tracks"] as Array)[1].erase("_with")
			((m._work.acts[0] as Dictionary)["tracks"] as Array)[1]["_hand"] = 12345
		m._work.runs = [{"i": 0, "t0": 2.0, "t1": 6.0}]
		m._work._timelines()
		var jar := -1
		var stopper := -1
		for wi in m._work.works.size():
			match String((m._work.works[wi] as Dictionary)["name"]):
				"jar": jar = wi
				"stopper": stopper = wi
		var sat := m._work._work_world(jar, 1.0).affine_inverse() * m._work._work_world(stopper, 1.0)
		var wander := 0.0
		for k in 40:
			var t := 2.0 + 4.0 * float(k) / 39.0
			var rel := m._work._work_world(jar, t).affine_inverse() * m._work._work_world(stopper, t)
			wander = maxf(wander, rel.origin.distance_to(sat.origin))
		var in_neck := INF
		if not own_hand:
			m._work.tick(8.0)
			var ph: TablePhysics = m._work.physics
			var jp: Variant = ph.pose_of(jar, 8.0)
			var sp: Variant = ph.pose_of(stopper, 8.0)
			if jp != null and sp != null:
				in_neck = ((jp as Transform3D).affine_inverse() * (sp as Transform3D)).origin.distance_to(sat.origin)
		res.append([wander, in_neck])
		m._root3.free()
	_ok(float(res[1][0]) > 0.001, "the control: given a hand of its own, the stopper wanders only %.2f mm from where it sits in the jar" % (float(res[1][0]) * 1000.0))
	_ok(float(res[0][0]) < 0.0005, "carried by the same path as its jar, the stopper wanders %.2f mm from where it sits in it" % (float(res[0][0]) * 1000.0))
	_ok(float(res[0][1]) < 0.004, "carried with its jar and set down, the stopper is %.1f mm from where it sat in the jar's neck" % (float(res[0][1]) * 1000.0))
	return true


## PUT BACK IN ITS SEAT, IT SITS THERE (841899: the brimstone's cork, put back by a hand a few millimeters off, went into its jar
## sideways and stuck; the frankincense cork, held back by the neck's rim, fell in tipped): a stopper drawn out of its jar and held
## aside, then carried home, is let go seated in the neck as it was built, within a millimeter and upright. The control: the jar
## slid 2.5 cm first, the stopper's home is off its seat, and it is not drawn in.
func _put_back_in() -> bool:
	var res: Array = []
	for slid in [false, true]:
		var m := _medium()
		_stand(m, STOPPERED_SPEC, "jar", _at(Vector3(-15, 0, -8)))
		var acts: Array = [
			{"name": "out", "beat": 1, "length": 2.0, "tracks": [{"thing": "jar", "part": "stopper", "law": "path",
				"keys": [{"at": 0.0}, {"at": 0.4, "by": [0, 5, 0]}, {"at": 1.0, "by": [8, 5, 0]}]}]},
			{"name": "home", "beat": 1, "length": 3.0, "tracks": [{"thing": "jar", "part": "stopper", "law": "carry", "lift": 3.0}]}]
		var runs: Array = [{"i": 0, "t0": 2.0, "t1": 4.0}, {"i": 1, "t0": 6.0, "t1": 9.0}]
		if slid:
			acts.append({"name": "slide", "beat": 1, "length": 1.0, "tracks": [{"thing": "jar", "part": "jar", "law": "path", "jitter": 0.0,
				"keys": [{"at": 0.0}, {"at": 1.0, "by": [2.5, 0, 0]}]}]})
			runs.append({"i": 2, "t0": 4.5, "t1": 5.5})
		m._work.build({"acts": acts}, 1)
		m._work.runs = runs
		m._work._timelines()
		var jar := -1
		var stopper := -1
		for wi in m._work.works.size():
			match String((m._work.works[wi] as Dictionary)["name"]):
				"jar": jar = wi
				"stopper": stopper = wi
		m._work.tick(11.0)
		var ph: TablePhysics = m._work.physics
		var sat := ph._rest_of(jar).affine_inverse() * ph._rest_of(stopper)
		# (the jar, moved by no act in the first, is no body: where the work has it)
		var jp: Variant = ph.pose_of(jar, 11.0) if ph._rigid_of.has(jar) else m._work._work_world(jar, 11.0)
		var sp: Variant = ph.pose_of(stopper, 11.0)
		if jp == null or sp == null:
			res.append([-1.0, INF])
		else:
			var rel := (jp as Transform3D).affine_inverse() * (sp as Transform3D)
			res.append([rel.origin.distance_to(sat.origin), Quaternion(rel.basis.orthonormalized()).angle_to(Quaternion(sat.basis.orthonormalized()))])
		m._root3.free()
	_ok(float(res[1][0]) > 0.01, "the control: its home 2.5 cm off its jar's neck, the stopper was drawn into the neck (%.1f mm from its seat)" % (float(res[1][0]) * 1000.0))
	_ok(float(res[0][0]) < 0.001 and float(res[0][1]) < 0.05, "put back, the stopper sits %.1f mm and %.1f degrees from its seat in the neck" % [
		float(res[0][0]) * 1000.0, rad_to_deg(float(res[0][1]))])
	return true


const CRATE_SPEC := {"things": [
	{"name": "crate", "parts": [{"shape": "box", "size": [4, 4, 4], "material": "oak"}]},
	{"name": "block", "parts": [{"shape": "box", "size": [6, 6, 6], "material": "oak"}]}],
	"materials": {"oak": {"kind": "wood", "color": "#6b4a2b"}, "brass": {"kind": "metal", "color": "#b8924c"}}}


## A WHOLE THING MEETS WHAT IT IS MOVED INTO (841899's mortar, carried over the cauldron and tipped, went through its rim - a
## whole thing had gone where its act said, and the act's check never saw the rim): a crate a path drives 5 cm into a block
## stops at the block's face, and the act's report says what held it back. The control: the work's own crate is in the block.
func _thing_meets() -> bool:
	var m := _medium()
	_stand(m, CRATE_SPEC, "crate", _at(Vector3(-15, 0, -8)))
	_stand(m, CRATE_SPEC, "block", _at(Vector3(0, 0, -8)))
	m._work.build({"acts": [{"name": "push", "beat": 1, "length": 3.0, "tracks": [{"thing": "crate", "law": "path", "jitter": 0.0,
		"keys": [{"at": 0.0}, {"at": 0.2, "by": [0, 2, 0]}, {"at": 1.0, "by": [17, 2, 0]}]}]}]}, 1)
	m._work.runs = [{"i": 0, "t0": 2.0, "t1": 5.0}]
	m._work._timelines()
	var t := 2.0 + 3.0 * 0.97
	m._work.tick(t)
	var ph: TablePhysics = m._work.physics
	var crate := -1
	for ti in m._work.things.size():
		if String((m._work.things[ti] as Dictionary)["name"]) == "crate":
			crate = ti
	var baked: Variant = ph.thing_pose_of(crate, t)
	var n0: Transform3D = m._work._rest["t%d:pose" % crate]
	var deep := INF
	var kdeep := INF
	for sd in ph.solids:
		if int((sd as Dictionary)["thing"]) != crate:
			continue
		for bs in ph.solids:
			if String((m._work.things[int((bs as Dictionary)["thing"])] as Dictionary)["name"]) != "block":
				continue
			for q in ((sd as Dictionary)["field"] as ShapeField).surface_points():
				var p0 := ((sd as Dictionary)["rest"] as Transform3D) * q
				var kin := m._work._thing_world(crate, t) * n0.affine_inverse() * p0
				kdeep = minf(kdeep, ((bs as Dictionary)["field"] as ShapeField).sample(((bs as Dictionary)["inv"] as Transform3D) * kin).x)
				if baked != null:
					var p := (baked as Transform3D) * n0.affine_inverse() * p0
					deep = minf(deep, ((bs as Dictionary)["field"] as ShapeField).sample(((bs as Dictionary)["inv"] as Transform3D) * p).x)
	var said := "\n".join(ph.report(2.0, 5.0))
	_ok(kdeep < -0.015, "the control: the path drives the work's own crate only %.1f mm into the block" % (-kdeep * 1000.0))
	_ok(baked != null and deep > -0.0015, "the crate driven into the block goes %.1f mm into it - it does not stop at its face" % (-deep * 1000.0))
	_ok(said.contains("HELD BACK by block"), "the act's report does not say the block held the crate back:\n" + said)
	m._root3.free()
	return true


## ONLY WHAT IS UNDER A BODY HOLDS IT UP (841899 played live: the ladle lifted past a cork pushed it from the side, the cork took
## the ladle for what held it up, slept on it and went round with every stir): a crate in the air pressed 3 mm into a block's side
## does not take the block for its holder, the thing it sleeps on and rides. The control: set 3 mm into the block's top, it does.
func _held_up_from_below() -> bool:
	var m := _medium()
	_stand(m, CRATE_SPEC, "crate", _at(Vector3(-15, 0, -8)))
	_stand(m, CRATE_SPEC, "block", _at(Vector3(0, 0, -8)))
	m._work.build({"acts": [{"name": "lift", "beat": 1, "length": 1.0, "tracks": [{"thing": "crate", "law": "path", "jitter": 0.0,
		"keys": [{"at": 0.0}, {"at": 1.0, "by": [0, 2, 0]}]}]}]}, 1)
	m._work.runs = [{"i": 0, "t0": 2.0, "t1": 3.0}]
	m._work._timelines()
	m._work.tick(0.5)
	var ph: TablePhysics = m._work.physics
	var crate := -1
	var block := -1
	for ti in m._work.things.size():
		match String((m._work.things[ti] as Dictionary)["name"]):
			"crate": crate = ti
			"block": block = ti
	var b: Dictionary = ph.rigid.bodies[int(ph._rigid_of[-1 - crate])]
	var touched: Array = []
	# beside the block, 1.5 cm off the table (its side at -3 cm, the crate's half 2); over it, its top at 6
	for way in [[Vector3(-5.5, 1.5, 0), Vector3(-4.7, 1.5, 0)], [Vector3(0, 6.5, 0), Vector3(0, 5.7, 0)]]:
		var from := Transform3D(Basis.IDENTITY, Vector3(15, 0, 0) * 0.01 + (way[0] as Vector3) * 0.01)
		var want := Transform3D(Basis.IDENTITY, Vector3(15, 0, 0) * 0.01 + (way[1] as Vector3) * 0.01)
		RigidParts._set_motion(b, from)
		b["touch"] = -1
		ph.rigid._go(b, from, want, ph.rigid._near(b, want), false, 1.0 / 60.0)
		var si := int(b["touch"])
		touched.append(si >= 0 and int((ph.solids[si] as Dictionary)["thing"]) == block)
	_ok(bool(touched[1]), "the control: set into the block's top, the crate does not take the block for what holds it up")
	_ok(not bool(touched[0]), "pressed into the block's side, the crate takes the block for what holds it up - it would sleep on it and ride it")
	m._root3.free()
	return true


## A pot with a floor 3 mm thick on a stand 4 cm tall, powder on its floor, and a brass ladle on the stand beside it.
const THIN_POT_SPEC := {"things": [
	{"name": "pot", "parts": [
		{"shape": "box", "size": [36, 4, 24], "material": "oak"},
		{"shape": "lathe", "profile": [[0, 0], [10, 0], [11, 9], [11.4, 9.2], [10.6, 9], [9.6, 0.3], [0, 0.3]], "material": "clay",
			"at": [0, 4, 0], "points": {"floor": [0, 4.3, 0]}},
		{"name": "powder", "shape": "grains", "at": [0, 5, 0], "fill": 0.12, "grain": 0.15, "material": "powder"},
		{"name": "ladle", "joint": {"kind": "free"}, "at": [15, 4, 0], "points": {"bowl": [15, 4.3, 0], "grip": [17.3, 21, 0]}, "parts": [
			{"shape": "lathe", "profile": [[0, 0], [2, 0], [2.4, 2.2], [2.2, 2.2], [1.8, 0.2], [0, 0.2]], "material": "brass"},
			{"shape": "lathe", "profile": [[0, 0], [0.3, 0], [0.3, 16], [0, 16]], "material": "brass", "at": [2.3, 1.2, 0]}]}]}],
	"materials": {"oak": {"kind": "wood", "color": "#6b4a2b"}, "clay": {"kind": "ceramic", "color": "#8a6a4a"},
		"brass": {"kind": "metal", "color": "#b8924c"}, "powder": {"kind": "powder", "color": "#e8e0c8"}}}


## A THIN WALL AT REST IS NEVER CROSSED: a brass ladle stirred round a pot whose floor is 3 mm thick, its bowl half a
## centimeter over the floor through the powder on it (2 s to 10 s), presses none of the powder through the floor; and let go
## in the pot, it lies on the floor, leaning on the rim, and never sinks through it (841899: stirring pressed crushed
## frankincense through the cauldron's copper floor into the brazier, and the ladle let go in its pot stood 2 mm in the floor
## and sank through it, 2 cm in half a second - past a thin wall's middle, its own way out is through its far side). The
## control: stirred, the powder moves.
func _thin_walls() -> bool:
	var m := _medium()
	_stand(m, THIN_POT_SPEC, "pot", _at(Vector3(0, 0, -8)))
	m._work.build({"acts": [{"name": "stir", "beat": 1, "length": 8, "tracks": [{"thing": "pot", "part": "ladle", "law": "aim",
		"tip": {"point": "bowl", "around": "pot.floor", "radius": 4.0, "period": 2.0, "lift": 0.5},
		"grip": {"point": "grip", "around": "pot.floor", "radius": 1.0, "period": 2.0, "lift": 17.0}}]}]}, 1)
	m._work.runs = [{"i": 0, "t0": 2.0, "t1": 10.0}]
	m._work._timelines()
	var ph: TablePhysics = m._work.physics
	m._work.tick(1.0)
	var x0: PackedVector3Array = (ph.frame_at(1.0) as Dictionary)["x"]
	m._work.tick(13.0)
	var f1: Dictionary = ph.frame_at(13.0)
	var x1: PackedVector3Array = f1["x"]
	var alive: PackedByteArray = f1["alive"]
	var axis := _at(Vector3(0, 0, -8))
	var under := 0
	var moved := 0
	for i in (ph.grains[0] as Dictionary)["ids"]:
		if alive[i] != 1:
			continue
		if Vector2(x1[i].x - axis.x, x1[i].z - axis.z).length() < 0.1 and x1[i].y < 0.04:
			under += 1
		if x0[i].distance_to(x1[i]) > 0.003:
			moved += 1
	var ladle := -1
	for wi in m._work.works.size():
		if m._work._part_label(wi) == "ladle":
			ladle = wi
	var low := INF
	var pose: Variant = ph.pose_of(ladle, 13.0)
	var n0: Transform3D = m._work._rest["w%d:pose" % ladle]
	for sd in ph.solids:
		if int((sd as Dictionary)["wi"]) != ladle or pose == null:
			continue
		for q in ((sd as Dictionary)["field"] as ShapeField).surface_points():
			var p := (pose as Transform3D) * n0.affine_inverse() * ((sd as Dictionary)["rest"] as Transform3D) * q
			if Vector2(p.x - axis.x, p.z - axis.z).length() < 0.095:
				low = minf(low, p.y)
	_ok(moved > 0, "the control: the ladle stirred round the pot moved none of its powder")
	_ok(under == 0, "the ladle stirred over a 3 mm floor pressed %d grains of powder through it" % under)
	# (its surface between the points it meets things by may dip into the floor's 3 mm - never through it, under 4.0)
	_ok(low > 0.0405, "the ladle let go in the pot is %.2f cm up inside it - through its floor, 4.0 to 4.3" % (low * 100.0))
	m._root3.free()
	return true




## WHAT WAS BAKED PAST A NEW PLAN'S CHANGE IS GONE: the rod's two moves baked to 12 s, a plan that moves its second (8 s to
## 9 s) leaves nothing baked from 8 s on - kept, the live viewer drew the last plan's frames there and called itself caught
## up (841899 played live: the brew in the brazier, the feather under the cauldron, none of it in a bake of one plan). The
## control: a plan that changes nothing keeps all 12 s.
func _plan_drops_stale() -> bool:
	var up := [{"at": 0.0}, {"at": 0.3, "by": [0, 6, 0]}, {"at": 1.0, "by": [0, 6, 9]}]
	var again := [{"at": 0.0}, {"at": 1.0, "by": [0, 0, -9]}]
	var to := {}
	for moved in [false, true]:
		var m := _rod_bench([[up, 2.0, 4.0], [again, 8.0, 10.0]], 45.0)
		var ph: TablePhysics = m._work.physics
		ph.bake_until(12.0)
		m._work.runs = [{"i": 0, "t0": 2.0, "t1": 4.0}, {"i": 1, "t0": 9.0 if moved else 8.0, "t1": 11.0 if moved else 10.0}]
		m._work._timelines()
		ph._take_plan()
		to[moved] = ph.baked_to()
		m._root3.free()
	_ok(float(to[false]) >= 12.0, "the control: a plan changing nothing left the bake at %.2f s of 12" % float(to[false]))
	_ok(float(to[true]) < 8.0, "a plan moving the act at 8 s left frames baked to %.2f s - the last plan's" % float(to[true]))
	return true


## HELD FOR AN ACT NOT YET PLACED: the rod lifted 6 cm (2 s to 4 s), its next act written but not yet placed - a live reading
## places one only once its word is heard - is held where its move left it at 6 s, as an export with every act placed holds it
## (841899 played live: the ladle let go in its pot before the stir's words came). The control: with no later act, it is let go.
func _held_till_placed() -> bool:
	var up := [{"at": 0.0}, {"at": 0.3, "by": [0, 6, 0]}, {"at": 1.0, "by": [0, 6, 9]}]
	var again := [{"at": 0.0}, {"at": 1.0, "by": [0, 0, -9]}]
	var held := {}
	for later in [false, true]:
		var m := _rod_bench([[up, 2.0, 4.0], [again, 9.0, 11.0]] if later else [[up, 2.0, 4.0]], 45.0)
		m._work.runs = [{"i": 0, "t0": 2.0, "t1": 4.0}]
		m._work._timelines()
		m._work.tick(6.0)
		var ph: TablePhysics = m._work.physics
		var rod := _rod(m)
		held[later] = (ph.rigid.bodies[int(ph._rigid_of[rod])] as Dictionary)["held"] != null
		m._root3.free()
	_ok(not bool(held[false]), "the control: with no later act, the rod is still held in the air at 6 s")
	_ok(bool(held[true]), "with a later act not yet placed, the rod lifted 6 cm is let go at 6 s")
	return true



## A LIVE SHOW WAITS FOR THE BAKE ([method TablePhysics.behind]): with the bake on a thread of its own (as in the app), a show
## less than [constant TablePhysics.WAIT_UNDER] behind it waits, goes on waiting while the bake is 1 s ahead, and is let go once it
## is [constant TablePhysics.WAIT_AHEAD] ahead - drawn behind its bake, 841899's live viewer showed what an export never would. The
## control: a bake on the caller's thread (a render, a preview, a gate) never waits.
func _waits_for_bake() -> bool:
	var m := _rod_bench([[[{"at": 0.0}, {"at": 1.0, "by": [0, 6, 0]}], 2.0, 4.0]], 45.0)
	var ph: TablePhysics = m._work.physics
	ph.bake_until(1.0)
	var on_caller := ph.behind(5.0)
	ph._sync = false
	var at := ph.baked_to()
	var caught := ph.behind(at + 0.02)
	ph.bake_until(at + 1.02)
	var still := ph.behind(at + 0.02)
	ph.bake_until(at + 3.2)
	var gone := ph.behind(at + 0.02)
	var ahead := ph.behind(ph.baked_to() - 1.0)
	ph._sync = true
	m._root3.free()
	_ok(not on_caller, "the control: a bake on the caller's thread made the show wait")
	_ok(caught, "a live show past its bake did not wait")
	_ok(still, "the bake 1 s ahead, the show stopped waiting - it would stall a frame at a time")
	_ok(not gone and not ahead, "the bake 3 s ahead, the show still waits (%s) - or waits with the bake ahead (%s)" % [str(gone), str(ahead)])
	return true


## A NEW PLAN IS BAKED AGAIN FROM ITS FIRST CHANGE, never from where a moved act began (841899 live: a stir runs as long as its
## words leave it, and each sentence gave it a new end - baked again from its start every time, the live show waited 37 s at a
## time): a rod going round by its period (2 s to 10 s) whose act ends at 12 s instead keeps all it had baked, to 9 s. The
## control: a path, whose places go by its act's length, ending later is baked again from its start.
func _replan_from_change() -> bool:
	var to := {}
	for law in ["circle", "path"]:
		var m := _medium()
		_stand(m, TOOL_SPEC, "tools", _at(Vector3(-15, 0, -8)))
		var track: Dictionary = {"thing": "tools", "part": "rod", "law": "circle", "around": [-15, 8, -8], "radius": 2.0, "period": 2.0}
		if law == "path":
			track = {"thing": "tools", "part": "rod", "law": "path", "jitter": 0.0, "keys": [{"at": 0.0}, {"at": 1.0, "by": [0, 8, 6]}]}
		m._work.build({"acts": [{"name": "go", "beat": 1, "length": 8, "tracks": [track]}]}, 1)
		m._work.runs = [{"i": 0, "t0": 2.0, "t1": 10.0}]
		m._work._timelines()
		var ph: TablePhysics = m._work.physics
		ph.bake_until(9.0)
		m._work.runs = [{"i": 0, "t0": 2.0, "t1": 12.0}]
		m._work._timelines()
		ph._take_plan()
		to[law] = ph.baked_to()
		m._root3.free()
	_ok(float(to["path"]) < 2.1, "the control: a path ending later kept its bake to %.2f s - baked from its start, it should be gone" % float(to["path"]))
	_ok(float(to["circle"]) >= 9.0, "a rod going round whose act ends later was baked again from %.2f s, not from where it differs (10 s)" % float(to["circle"]))
	return true
