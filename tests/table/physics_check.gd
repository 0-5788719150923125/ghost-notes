extends SceneTree

## The gate of WHAT IS IN THINGS ([ShapeField], [Vessel], [Particles], [TablePhysics]; next/table_physics.md), with no
## renderer. The user, 2026-10-28, of the first alchemy episode: "The liquids are not liquids"; the snow "should be
## particles ... With physics and collision"; the shell's crystals "do not move and tumble, and they do not fall into
## the cauldron"; and "I would have expected the grinding to destroy those things".
##
##   godot --headless --path . --script res://tests/table/physics_check.gd [-- --only=_jars_apart,_sheet_lies]
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
## - THE HAND PLANS, THE PHYSICS SETTLES (the-quiet-crucible 841899 exported, 2026-10-31; next/table_physics.md "A step back"):
##   A PART IN ITS SEAT GOES WITH IT - a stopper fetched with its jar on keys of its own, half a centimeter off, keeps to its
##   seat within half a millimeter, and set down is still; the jar goes where it was sent (the control: drawn up out of the
##   neck by its own move, it leaves it); A HAND LETS GO OF WHAT STANDS IN A VESSEL - a ladle left tipped in a pot until its
##   next move leans there, in nothing, still (the control: left over the rim, it is held); TOUCHING IS NOT RESTING - a rod
##   with only its end on a block is held (the control: its middle over the block, let go); WHAT STANDS IN A LIQUID IS UNDER
##   ITS SURFACE - a ladle filling in a pot leaves the water no lower, lifted out with its fill it is lower, and under the
##   water its own surface is not drawn (the controls: the water's own volume alone falls; lifted out, the ladle's surface is
##   drawn); WHAT FLOATS STAYS IN, AND IS MET ACROSS ITS FACE - a leaf swept by a paddle into the pot's wall never goes
##   through it (the control: the paddle moved it); A CARRY CLEARS WHAT IS IN ITS WAY - a crate carried over a 9 cm block
##   with a 2 cm lift is never held back (the control: with nothing in the way, no lift is added); A POUR IS A HAND'S - a jug
##   `pour`ed into a cup empties into it, its lip a few centimeters up (the control: tipped by hand about its middle, 10 cm
##   up, it spills); WHAT STRIKES A VESSEL'S INSIDE RUNS DOWN INTO IT - a parcel thrown at a pot's inner wall ends in its water
##   (the control: thrown out over the rim, spilled); A DIP IS A HAND'S - 841899's straight-handled ladle `dip`ped into a deep pot
##   comes up half full or more, nothing outside the pot, never held back (the control: lowered level by hand, its handle meets
##   the rim and it comes up empty).

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
			_moved_on, _let_go_in, _held_between, _thing_meets, _held_up_from_below, _carried_with, _put_back_in, _thin_walls, _plan_drops_stale, _held_till_placed, _unbrought_not_there, _waits_for_bake, _replan_from_change,
			_seat_rides, _leans_in, _held_unless_resting, _level_counts, _floats_in, _clears_way, _pours_into, _runs_down, _dips_full,
			_jars_apart, _tool_entry, _rests_let_go, _sheet_lies, _past_baked, _rests_on_rim, _pours_loose, _world_from_table,
			_kept_across_plans, _warmed_first, _frame_names_bodies, _part_stays_when_thing_goes, _not_dropped_on_a_rim, _sheet_tip_in_pot, _brew_kept, _stands_held_for_a_moment, _sheet_bends_round, _floater_lives, _sheet_stays_whole]:
		# ...or only those named after `--only=` (by hand: `-- --only=_jars_apart,_sheet_lies`)
		var only := ""
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--only="):
				only = a.substr(7)
		if not only.is_empty() and not (only.split(",") as PackedStringArray).has((check as Callable).get_method()):
			continue
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


## A bench of the rod on its stand and a block beside it, the rod moved by [param keys] (a path - or, [param aimed], an aim whose
## two ends both go by them: a law the hand never plans round) from 2 s for [param length].
func _tool_bench(keys: Array, length: float, aimed := false) -> TableMedium:
	var m := _medium()
	_stand(m, TOOL_SPEC, "tools", _at(Vector3(-15, 0, -8)))
	_stand(m, TOOL_SPEC, "block", _at(Vector3(0, 0, -8)))
	var tr := {"thing": "tools", "part": "rod", "law": "path", "jitter": 0.0, "keys": keys}
	if aimed:
		var ends := keys.map(func(k: Dictionary) -> Dictionary: return {"at": k["at"], "by": k.get("by", [0, 0, 0])})
		tr = {"thing": "tools", "part": "rod", "law": "aim", "tip": {"point": "tip", "keys": ends}, "grip": {"point": "grip", "keys": ends}}
	m._work.build({"acts": [{"name": "move", "beat": 1, "length": length, "tracks": [tr]}]}, 1)
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
	var keys := [{"at": 0.0}, {"at": 0.2, "by": [0, 2, 0]}, {"at": 1.0, "by": [17, 2, 0]}]
	var m := _tool_bench(keys, 3.0, true)
	var t := 2.0 + 3.0 * 0.97
	m._work.tick(t)
	var rod := _rod(m)
	var held: Variant = m._work.physics.pose_of(rod, t)
	var kin := m._work._work_world(rod, t)
	var deep := _rod_in_block(m, held) if held != null else -INF
	var kdeep := _rod_in_block(m, kin)
	_ok(kdeep < -0.015, "the control: the aim drives the rod only %.1f mm into the block" % (-kdeep * 1000.0))
	_ok(held != null and deep > -0.001, "the rod driven into the block goes %.1f mm into it - it does not stop at its face" % (-deep * 1000.0))
	m._root3.free()
	# ...AND A PATH THERE IS THE HAND'S: lifted over the block and set beside it where there is room ([method TableWork._path_clearance],
	# [method TableWork._room]) - its own way is in nothing, and nothing holds it back
	var pm := _tool_bench(keys, 3.0)
	var said := ""
	var most := INF
	for k in 13:
		var tk := 2.0 + 3.0 * float(k) / 12.0
		most = minf(most, _rod_in_block(pm, pm._work._work_world(_rod(pm), tk)))
	pm._work.tick(6.0)
	said = "\n".join(pm._work.physics.report(2.0, 5.0))
	_ok(most > -0.002 and not said.contains("HELD BACK"), "a path into the block was not taken over it and beside it: its way %.2f mm into it; %s" % [-most * 1000.0, said])
	pm._root3.free()
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
	# [its first move, when the next begins, when it is looked at]: held across a pause; set down across a gap; and set down on the table
	for c in [[up, 4.5, 4.25], [up, 8.0, 7.5], [down, 7.0, 5.5]]:
		var m := _rod_bench([[c[0], 2.0, 4.0], [again, float(c[1]), float(c[1]) + 2.0]], 45.0)
		var rod := _rod(m)
		m._work.tick(float(c[2]))
		var ph: TablePhysics = m._work.physics
		var pose: Variant = ph.pose_of(rod, float(c[2]))
		var b: Dictionary = ph.rigid.bodies[int(ph._rigid_of[rod])]
		var left := m._work._work_world(rod, 3.99)
		res.append([b["held"] != null, (pose as Transform3D).origin.distance_to(left.origin) if pose != null else INF,
			left.origin.y - (pose as Transform3D).origin.y if pose != null else 0.0])
		m._root3.free()
	_ok(not bool(res[2][0]), "the control: set down on the table, the rod is still held between its moves")
	_ok(bool(res[0][0]) and float(res[0][1]) < 0.008, "the rod lifted 6 cm and taken up again half a second later is %s across the pause, %.1f mm from where its move left it" % [
		"held" if bool(res[0][0]) else "let go", float(res[0][1]) * 1000.0])
	_ok(not bool(res[1][0]) and float(res[1][2]) > 0.04, "the rod lifted 6 cm and taken up again 4 s later is %s in the air between its moves, %.1f cm under where its move left it - a hand nobody sees holding it still is a thing floating" % [
		"held" if bool(res[1][0]) else "not held", float(res[1][2]) * 100.0])
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
## and let go seated it still fell through, its cap's lip finer than the solver's points):
## a jar and its stopper carried 30 cm by the same path keep the stopper where it sits in the jar within half a millimeter all
## the way, and set down, the stopper is still in the neck. The control: without its physical seat, identical paths alone
## do not bind the two objects together.
func _carried_with() -> bool:
	var keys := [{"at": 0.0}, {"at": 0.25, "by": [0, 8, 0]}, {"at": 0.75, "by": [30, 8, 0]}, {"at": 1.0, "by": [30, 0, 0]}]
	var res: Array = []
	for own_hand in [false, true]:
		var m := _medium()
		_stand(m, STOPPERED_SPEC, "jar", _at(Vector3(-15, 0, -8)))
		m._work.build({"acts": [{"name": "fetch", "beat": 1, "length": 4.0, "tracks": [
			{"thing": "jar", "part": "jar", "law": "path", "keys": keys}, {"thing": "jar", "part": "stopper", "law": "path", "keys": keys}]}]}, 1)
		m._work.runs = [{"i": 0, "t0": 2.0, "t1": 6.0}]
		m._work._timelines()
		var jar := -1
		var stopper := -1
		for wi in m._work.works.size():
			match String((m._work.works[wi] as Dictionary)["name"]):
				"jar": jar = wi
				"stopper": stopper = wi
		var ph: TablePhysics = m._work.physics
		if own_hand:
			(ph.rigid.bodies[int(ph._rigid_of[stopper])] as Dictionary)["seat"] = PackedInt32Array()
		var sat := m._work._work_world(jar, 1.0).affine_inverse() * m._work._work_world(stopper, 1.0)
		m._work.tick(8.0)
		var wander := 0.0
		for k in 40:
			var t := 2.0 + 4.0 * float(k) / 39.0
			var rel := _baked(m, jar, t).affine_inverse() * _baked(m, stopper, t)
			wander = maxf(wander, rel.origin.distance_to(sat.origin))
		var in_neck := INF
		if not own_hand:
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
## whole thing had gone where its act said, and the act's check never saw the rim): a crate an aim drives 5 cm into a block
## stops at the block's face, and the act's report says what held it back. The control: the work's own crate is in the block.
func _thing_meets() -> bool:
	var m := _medium()
	_stand(m, CRATE_SPEC, "crate", _at(Vector3(-15, 0, -8)))
	_stand(m, CRATE_SPEC, "block", _at(Vector3(0, 0, -8)))
	# ...AIMED there, both its ends: a law the hand never plans round (a path is lifted over the block, [method _tool_meets])
	var ends := [{"at": 0.0, "by": [0, 0, 0]}, {"at": 0.2, "by": [0, 2, 0]}, {"at": 1.0, "by": [17, 2, 0]}]
	m._work.build({"acts": [{"name": "push", "beat": 1, "length": 3.0, "tracks": [{"thing": "crate", "law": "aim",
		"tip": {"point": "tip", "keys": ends}, "grip": {"point": "grip", "keys": ends}}]}]}, 1)
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
	_ok(kdeep < -0.015, "the control: the aim drives the work's own crate only %.1f mm into the block" % (-kdeep * 1000.0))
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


const POT_RIM_SPEC := {"things": [
	{"name": "pot", "parts": [{"shape": "lathe", "profile": [[0, 0], [10, 0], [12, 10], [12.4, 12], [11.6, 12], [10, 1.5], [0, 1.5]], "material": "iron"}]},
	{"name": "mortar", "parts": [{"shape": "lathe", "profile": [[0, 0], [4, 0], [5, 8], [5.5, 8.3], [4.6, 8], [3.6, 1.2], [0, 1.2]], "material": "stone"}]}],
	"materials": {"iron": {"kind": "metal", "color": "#2c2a28"}, "stone": {"kind": "stone", "color": "#8a8580"}}}


## A HAND NEVER LETS GO WHERE WHAT IT HOLDS WOULD COME DOWN BADLY ([method TablePhysics._lands_ill]; 2026-11-01, feedback 0004-0007: the
## mortar, level over the cauldron after its pour, its next act past the pause, let go: over the rim and onto the table, tipped 112
## degrees, trembling until its way home hauled it up): a mortar brought level over a pot's rim. Its next act 5 s on, it is held there.
## Its next act 20 s on, or none, or one written but not placed, it is put back where it last rested, upright and at rest. The control:
## the same move over the bare table is let go, and lands where it is.
func _not_dropped_on_a_rim() -> bool:
	var over := [{"at": 0.0}, {"at": 0.5, "by": [0, 20, 0]}, {"at": 0.9, "by": [BY_RIM, 20, 0]}, {"at": 1.0, "by": [BY_RIM, 13, 0]}]
	var clear := [{"at": 0.0}, {"at": 0.5, "by": [0, 20, 0]}, {"at": 0.9, "by": [-14, 20, 0]}, {"at": 1.0, "by": [-14, 13, 0]}]
	var home := [{"at": 0.0}, {"at": 1.0, "by": [0, 0, 6]}]
	var cases := [
		{"name": "its next act 5 s on", "keys": over, "next": 10.0, "at": 9.0, "held": true},
		{"name": "its next act 20 s on", "keys": over, "next": 25.0, "at": 11.5, "back": true},
		{"name": "no later act", "keys": over, "next": -1.0, "at": 11.5, "back": true},
		{"name": "a later act not yet placed, 7 s on", "keys": over, "next": 10.0, "unplaced": true, "at": 12.0, "held": true},
		{"name": "a later act not yet placed, 11 s on", "keys": over, "next": 10.0, "unplaced": true, "at": 16.0, "back": true},
		{"name": "the control: over the bare table", "keys": clear, "next": -1.0, "at": 9.0, "landed": true}]
	for c in cases:
		var cd: Dictionary = c
		var m := _medium()
		_stand(m, POT_RIM_SPEC, "pot", _at(Vector3(0, 0, -8)))
		_stand(m, POT_RIM_SPEC, "mortar", _at(Vector3(-30, 0, -8)))
		var acts: Array = [{"name": "over", "beat": 1, "length": 3.0, "tracks": [{"thing": "mortar", "law": "path", "jitter": 0.0, "keys": cd["keys"]}]}]
		var runs: Array = [{"i": 0, "t0": 2.0, "t1": 5.0}]
		if float(cd["next"]) >= 0.0:
			acts.append({"name": "home", "beat": 1, "length": 2.0, "tracks": [{"thing": "mortar", "law": "path", "jitter": 0.0, "keys": home}]})
			if not bool(cd.get("unplaced", false)):
				runs.append({"i": 1, "t0": float(cd["next"]), "t1": float(cd["next"]) + 2.0})
		m._work.build({"acts": acts}, 1)
		m._work.runs = runs
		m._work._timelines()
		var ph: TablePhysics = m._work.physics
		var ti: int = m._work._thing_named("mortar")
		var built: Transform3D = m._work._rest["t%d:pose" % ti]
		var at := float(cd["at"])
		ph.bake_until(at)
		var pose: Transform3D = ph.thing_pose_of(ti, at)
		var tilt := rad_to_deg((pose.basis * Vector3.UP).angle_to(Vector3.UP))
		var left_at: Transform3D = built
		left_at.origin += Vector3(float((cd["keys"] as Array)[3]["by"][0]), float((cd["keys"] as Array)[3]["by"][1]), 0.0) * 0.01
		var b: Dictionary = ph.rigid.bodies[int(ph._rigid_of[-1 - ti])]
		m._root3.free()
		var say := "at (%.1f, %.1f, %.1f) cm, tilted %.0f" % [pose.origin.x * 100.0, pose.origin.y * 100.0, pose.origin.z * 100.0, tilt]
		if bool(cd.get("held", false)):
			_ok(tilt < 8.0 and pose.origin.distance_to(left_at.origin) < 0.02 and b["held"] != null, "%s, the mortar over the rim at %.1f s is still held where its move left it: %s" % [cd["name"], at, say])
		elif bool(cd.get("back", false)):
			_ok(tilt < 4.0 and pose.origin.distance_to(built.origin) < 0.02 and b["held"] == null, "%s, the mortar is put back where it rested by %.1f s, upright, let go: %s" % [cd["name"], at, say])
		else:
			_ok(tilt < 4.0 and absf(pose.origin.y - built.origin.y) < 0.01 and Vector2(pose.origin.x - left_at.origin.x, pose.origin.z - left_at.origin.z).length() < 0.02,
				"%s, it is let go and lands where it is: %s" % [cd["name"], say])
	return true


## How far along the bench the mortar is brought to stand over the pot's near rim (cm; [method _not_dropped_on_a_rim]): from 30 cm away, to
## 12 from the pot's middle.
const BY_RIM := 18.0


## A PART SET ASIDE STAYS WHERE IT IS DRAWN WHEN ITS THING GOES (2026-11-01, feedback 0004-0007: "the pestle disappeared, and then
## reappeared", "moving in-sync, as if they are stuck together", "clipped through the table"): a free part's node hangs from its
## thing's, and a frame poses it again only where it can have changed ([method TableWork._settled]) - which asked of the moves written
## on the thing, while its body also moves outside them. The rod laid aside and its stand lifted, then let go to fall, played frame by
## frame as a live show draws it: the rod is drawn where the bake has it at every frame, through the lift and the fall. The
## control: the stand does fall, outside any move written on it.
func _part_stays_when_thing_goes() -> bool:
	var m := _medium()
	_stand(m, TOOL_SPEC, "tools", _at(Vector3(-15, 0, -8)))
	m._work.build({"acts": [
		{"name": "aside", "beat": 1, "length": 2.0, "tracks": [{"thing": "tools", "part": "rod", "law": "path", "jitter": 0.0,
			"keys": [{"at": 0.0}, {"at": 0.4, "by": [0, 8, 0]}, {"at": 1.0, "by": [-25, 0, 0]}]}]},
		{"name": "lift", "beat": 1, "length": 1.0, "tracks": [{"thing": "tools", "law": "path", "jitter": 0.0,
			"keys": [{"at": 0.0}, {"at": 1.0, "by": [20, 15, 0]}]}]}]}, 1)
	m._work.runs = [{"i": 0, "t0": 1.0, "t1": 3.0}, {"i": 1, "t0": 5.0, "t1": 6.0}]
	m._work._timelines()
	var w := m._work
	var ph: TablePhysics = w.physics
	var rod := _rod(m)
	var node: Node3D = (w.works[rod] as Dictionary)["node"]
	var tools := w._thing_named("tools")
	var worst := 0.0
	var worst_at := 0.0
	var fell := 0.0
	var top := -INF
	var t := 4.0
	while t < 8.0:
		w.tick(t)
		var baked: Variant = ph.pose_of(rod, t)
		var off := w._world_of(node).origin.distance_to((baked as Transform3D).origin) if baked != null else 0.0
		if off > worst:
			worst = off
			worst_at = t
		var thing_y := ((w.things[tools] as Dictionary)["node"] as Node3D).position.y
		top = maxf(top, thing_y)
		if t > 6.2:
			fell = maxf(fell, top - thing_y)
		t += 1.0 / 60.0
	m._root3.free()
	_ok(fell > 0.05, "the control: let go after its lift, the stand fell %.1f cm, outside any move written on it" % (fell * 100.0))
	_ok(worst < 0.001, "the rod laid aside is drawn %.1f cm from where the bake has it, at %.2f s, as its stand goes" % [worst * 100.0, worst_at])
	return true


## WHAT A PLAN FOUND IS KEPT FOR THE NEXT (2026-11-01, played live: every plan a live reading made - one a sentence - worked out
## again, twice and on the app's thread, where every move so far comes to rest; by 841899's second stir 2.8-3.5 s of every sentence,
## the picture frozen while the voice went on): the rod's two moves planned again with nothing changed find no room again, and the
## second ends where it did. The control: the first move written a second later, both are found again.
func _kept_across_plans() -> bool:
	var up := [{"at": 0.0}, {"at": 0.3, "by": [0, 6, 0]}, {"at": 1.0, "by": [0, 6, 9]}]
	var again := [{"at": 0.0}, {"at": 1.0, "by": [0, 0, -9]}]
	var m := _rod_bench([[up, 2.0, 4.0], [again, 8.0, 10.0]], 45.0)
	var w := m._work
	var end_of := func() -> Transform3D:
		for ch in w._chan:
			for e in w._chan[ch]:
				if String((e as Dictionary)["act"]) == "move 1":
					return (e as Dictionary)["end"]
		return Transform3D()
	var end0: Transform3D = end_of.call()
	w.profiling = true
	w.profile = {}
	w._timelines()
	var same := int(w.profile.get("rooms found", 0))
	var end1: Transform3D = end_of.call()
	w.profile = {}
	w.runs = [{"i": 0, "t0": 3.0, "t1": 5.0}, {"i": 1, "t0": 8.0, "t1": 10.0}]
	w._timelines()
	var moved := int(w.profile.get("rooms found", 0))
	m._root3.free()
	_ok(moved >= 2, "the control: the first move written a second later found %d rooms again (2 moves)" % moved)
	_ok(same == 0, "a plan made again with nothing changed found %d rooms again" % same)
	_ok(end1.origin.distance_to(end0.origin) < 1e-6, "...and the second move ends %.3f mm from where it did" % (end1.origin.distance_to(end0.origin) * 1000.0))
	return true


## WHAT A DRIP IS DRAWN WITH IS MADE AS THE TABLE STANDS (2026-11-01: as the ladle first came out of the brew the picture froze 3.4 s,
## the GPU building the shaders of the stream and the drops, made only then): before anything has poured, the drops and a stream's
## node stand, and a copy of each IN THE SAME MATERIAL is drawn at nothing's size for the table's first frames, then let go - what
## the GPU builds for the copies is what the real ones need. The control: nothing drawn yet, the copies are there.
func _warmed_first() -> bool:
	var m := _rod_bench([[[{"at": 0.0}, {"at": 1.0, "by": [0, 6, 0]}], 2.0, 4.0]], 45.0)
	var ph: TablePhysics = m._work.physics
	var made := ph._drops != null and ph._streams.size() >= 1
	var warm := ph._warm.size() == 2
	var same := warm and (ph._warm[0] as MeshInstance3D).material_override == (ph._streams[0] as MeshInstance3D).material_override \
		and (ph._warm[1] as MultiMeshInstance3D).material_override == ph._drops.material_override \
		and (ph._warm[1] as MultiMeshInstance3D).multimesh.mesh == ph._drops.multimesh.mesh
	for k in TablePhysics.WARM_TICKS + 1:
		ph.tick(0.0)
	var gone := ph._warm.is_empty()
	m._root3.free()
	_ok(warm, "the control: before the table's first frame, the copies drawn for the GPU stand (%d of 2)" % (2 if warm else 0))
	_ok(made, "a stream's node and the drops are made with the table, before anything pours")
	_ok(same, "each copy is drawn in its real node's own material and mesh")
	_ok(gone, "the copies are let go after the table's first %d frames" % TablePhysics.WARM_TICKS)
	return true


## A FRAME NAMES ITS OWN BODIES (2026-11-01): the rod woken by its move (2-4 s) and its frame at 5 s kept as a new plan takes the bake
## back to its first checkpoint - which puts every body woken since back to sleep ([method TablePhysics._restore]) - the frame still
## poses the rod where it was baked, never where it was built: the picture's thread reads a frame, never what the bake keeps changing.
## The control: its frame at 1 s, before it woke, poses it where it was built.
func _frame_names_bodies() -> bool:
	var m := _rod_bench([[[{"at": 0.0}, {"at": 0.3, "by": [0, 6, 0]}, {"at": 1.0, "by": [0, 6, 9]}], 2.0, 4.0]], 45.0)
	var ph: TablePhysics = m._work.physics
	var rod := _rod(m)
	ph.bake_until(6.0)
	var rest := ph._rest_of(rod)
	var baked: Transform3D = ph.pose_of(rod, 5.0)
	ph._restore(ph._ck[0])
	var after: Transform3D = ph.pose_of(rod, 5.0)
	var early: Transform3D = ph.pose_of(rod, 1.0)
	m._root3.free()
	_ok(early.origin.distance_to(rest.origin) < 1e-5, "the control: at 1 s, before it woke, the rod is where it was built (%.1f mm off)" % (early.origin.distance_to(rest.origin) * 1000.0))
	_ok(baked.origin.distance_to(rest.origin) > 0.05, "the rod was moved by 5 s (%.1f cm from where it was built)" % (baked.origin.distance_to(rest.origin) * 100.0))
	_ok(after.origin.distance_to(baked.origin) < 1e-5, "after the bake went back, its frame at 5 s still has it where it was baked (%.1f cm off)" % (after.origin.distance_to(baked.origin) * 100.0))
	return true


## LIVE AS EXPORTED, NOTHING HANGS IN THE AIR FOR A LATER ACT (2026-11-01, feedback 0001-0002: the ladle over the cauldron and the
## pestle over its mortar, held for the words before their next acts) - AND NOTHING IS DROPPED FOR ONE NOT YET HEARD (feedback 0004:
## the mortar, its pour ended a second before the word its way home is cued at, let go tipped over the cauldron): the rod lifted 6 cm
## (2 s to 4 s) with no later act is set down where it is; with its next act written but not yet placed - a live reading places one
## only once its word is heard - it is held across a pause, as an export holding it for an act that soon would, and set down after
## one; with its next act 5 s on it is set down at once. Placed later within the pause, nothing before that act is baked again (the
## hold already stood in for it); an act placed 5 s on afterwards leaves the bake as it was (what it held a moment is a moment's
## hover - going back for it had the show wait); and AN ACT MOVED INTO THE PAUSE after the bake let the rod go takes the bake back
## to the move's end, and it is held there, as an export holds it. The control: its next act placed half a second on, it is held
## across the pause.
func _held_till_placed() -> bool:
	var up := [{"at": 0.0}, {"at": 0.3, "by": [0, 6, 0]}, {"at": 1.0, "by": [0, 6, 9]}]
	var again := [{"at": 0.0}, {"at": 1.0, "by": [0, 0, -9]}]
	var held := {}
	var resumed := {}
	for case in ["none", "unplaced", "unplaced, later", "placed", "soon", "placed 5 s on, later", "placed 1.5 s on, later", "moved in, later"]:
		var later: bool = case != "none"
		var start: float = 4.5 if case == "soon" else 9.0
		var m := _rod_bench([[up, 2.0, 4.0], [again, start, start + 2.0]] if later else [[up, 2.0, 4.0]], 45.0)
		var ph: TablePhysics = m._work.physics
		if case.begins_with("unplaced") or case.begins_with("placed") and case.ends_with("later"):
			m._work.runs = [{"i": 0, "t0": 2.0, "t1": 4.0}]
			m._work._timelines()
		var at: float = 4.25 if case == "soon" else (7.5 if case == "unplaced, later" else 6.0)
		if case.ends_with(", later") and not case.begins_with("unplaced"):
			# ...baked on first with the act not yet placed, then its word heard
			ph.bake_until(8.0)
			var t1: float = 9.0 if case.begins_with("placed 5") else 5.5
			m._work.runs = [{"i": 0, "t0": 2.0, "t1": 4.0}, {"i": 1, "t0": t1, "t1": t1 + 2.0}]
			m._work._timelines()
			ph._take_plan()
			# ...how far the bake kept what it had (a bake goes back to its last checkpoint before the change, and keeps its frames up to it)
			resumed[case] = ph.baked_to()
			at = 6.0 if case.begins_with("placed 5") else 5.0
		m._work.tick(at)
		var rod := _rod(m)
		var pose: Variant = ph.pose_of(rod, at)
		held[case] = [(ph.rigid.bodies[int(ph._rigid_of[rod])] as Dictionary)["held"] != null,
			m._work._work_world(rod, 3.99).origin.y - (pose as Transform3D).origin.y if pose != null else 0.0]
		m._root3.free()
	_ok(bool(held["soon"][0]), "the control: its next act half a second on, the rod was let go across the pause")
	for case in ["none", "placed", "unplaced, later"]:
		_ok(not bool(held[case][0]) and float(held[case][1]) > 0.04, "the rod lifted 6 cm (%s) is %s, %.1f cm under where its move left it" % [
			{"none": "no later act, at 6 s", "placed": "its next act 5 s on, at 6 s", "unplaced, later": "a later act not yet placed, at 7.5 s"}[case],
			"held in the air" if bool(held[case][0]) else "let go", float(held[case][1]) * 100.0])
	for case in ["unplaced", "placed 1.5 s on, later", "moved in, later"]:
		_ok(bool(held[case][0]) and absf(float(held[case][1])) < 0.02, "the rod (%s) was %s, %.1f cm from where its move left it" % [
			{"unplaced": "a later act not yet placed, 2 s after its move", "placed 1.5 s on, later": "its next act placed 1.5 s on after the bake, 1 s after its move",
				"moved in, later": "its next act moved from 5 s on to 1.5 s on after the bake, 1 s after its move"}[case],
			"held" if bool(held[case][0]) else "LET GO", float(held[case][1]) * 100.0])
	_ok(float(resumed["placed 1.5 s on, later"]) >= 5.4, "its act placed within the pause, the bake kept what it had only to %.2f s - not to the act at 5.5 s, where the hold already stood" % float(resumed["placed 1.5 s on, later"]))
	_ok(float(resumed["placed 5 s on, later"]) >= 7.9, "its act placed 5 s on after a bake that held it, the bake kept what it had only to %.2f s - not all it had baked, to 8 s" % float(resumed["placed 5 s on, later"]))
	_ok(float(resumed["moved in, later"]) <= 4.0 + 1e-3, "its act moved into the pause after a bake that let it go, the bake kept what it had to %.2f s - past the move's end at 4 s, where it lets go" % float(resumed["moved in, later"]))
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


## Body [param wi]'s pose as the bake has it at [param t], or the work's where it is no body.
func _baked(m: TableMedium, wi: int, t: float) -> Transform3D:
	var p: Variant = m._work.physics.pose_of(wi, t)
	return p if p != null else m._work._work_world(wi, t)


func _work_of_name(m: TableMedium, name: String) -> int:
	for wi in m._work.works.size():
		if String((m._work.works[wi] as Dictionary)["name"]) == name:
			return wi
	return -1


## A PART IN ITS SEAT GOES WITH ITS SEAT (the-quiet-crucible 841899: the sulfur cork's keys ended half a centimeter above its
## jar's, so it had a hand of its own and wandered through the neck; and let go seated, each cork was woken by its jar settling
## and trembled 3 mm about the neck for seconds): a jar fetched 70 cm with its stopper, the stopper's keys a hand of its own and
## half a centimeter off at the end (841899's sulfur-fetch's, each hand bowing its own way), keeps the stopper within half a
## millimeter of its seat all the way and after it is set
## down, still - and the jar goes where it was sent (seated on each other, a jar and its cork had been welded where they stood).
## The control: the stopper's own move drawing it 5 cm up out of the neck takes it out.
func _seat_rides() -> bool:
	var keys := [{"at": 0.0}, {"at": 0.2, "by": [0, 9, 3]}, {"at": 0.55, "by": [-38, 10, 22]}, {"at": 0.85, "by": [-62, 6, 27]}, {"at": 1.0, "by": [-64.8, 0, 27]}]
	var off := [{"at": 0.0}, {"at": 0.2, "by": [0, 9, 3]}, {"at": 0.55, "by": [-38, 10, 22]}, {"at": 0.85, "by": [-62, 6, 27]}, {"at": 1.0, "by": [-64.8, 0.5, 27]}]
	var res: Array = []
	for out in [false, true]:
		var m := _medium()
		# ...each hand seeded as that episode's were: its seed and the act's name
		m._plan.seed_value = 841899
		_stand(m, STOPPERED_SPEC, "jar", _at(Vector3(45, 0, -8)))
		var tracks: Array = [{"thing": "jar", "part": "jar", "law": "path", "keys": keys}, {"thing": "jar", "part": "stopper", "law": "path", "keys": off}]
		if out:
			tracks = [{"thing": "jar", "part": "stopper", "law": "path", "keys": [{"at": 0.0}, {"at": 1.0, "by": [0, 5, 0]}]}]
		m._work.build({"acts": [{"name": "sulfur-fetch", "beat": 1, "length": 4.0, "tracks": tracks}]}, 1)
		m._work.runs = [{"i": 0, "t0": 2.0, "t1": 6.0}]
		m._work._timelines()
		var jar := _work_of_name(m, "jar")
		var stopper := _work_of_name(m, "stopper")
		var ph: TablePhysics = m._work.physics
		m._work.tick(11.0)
		var sat := ph._rest_of(jar).affine_inverse() * ph._rest_of(stopper)
		var most := 0.0
		var after := 0.0
		var last := Transform3D()
		for k in 60:
			var t := 2.0 + 9.0 * float(k) / 59.0
			var rel := _baked(m, jar, t).affine_inverse() * _baked(m, stopper, t)
			most = maxf(most, rel.origin.distance_to(sat.origin))
			if t > 7.0:
				var sp := _baked(m, stopper, t)
				if k > 0 and last != Transform3D():
					after = maxf(after, sp.origin.distance_to(last.origin))
				last = sp
		var went := _baked(m, jar, 11.0).origin.distance_to(ph._rest_of(jar).origin)
		res.append([most, after, went])
		m._root3.free()
	_ok(float(res[1][0]) > 0.03, "the control: drawn 5 cm up out of its neck by its own move, the stopper stayed %.1f mm from its seat" % (float(res[1][0]) * 1000.0))
	_ok(float(res[0][2]) > 0.6, "the jar sent 70 cm went %.1f cm - held where it stood by its own stopper" % (float(res[0][2]) * 100.0))
	_ok(float(res[0][0]) < 0.0005, "fetched with its jar on keys of its own, the stopper went %.2f mm from its seat" % (float(res[0][0]) * 1000.0))
	_ok(float(res[0][1]) < 0.0001, "set down seated, the stopper still moved %.3f mm in a sixth of a second" % (float(res[0][1]) * 1000.0))
	return true


## A HAND LETS GO OF WHAT RESTS OR STANDS IN A VESSEL, AND HOLDS WHAT WOULD FALL (841899: the ladle brought upright into the brew
## was held there 14 s, swaying, "wiggling unstably", where a person leans it on the rim; and held over the pot after its dip it
## was let go because it grazed the rim, and fell in): a ladle brought into a pot of water, tipped 30 degrees, and taken up again
## 6 s later is let go between the moves, leans in the pot - none of it in the pot's wall - and lies still. The control: left
## 3 cm over the pot's rim, it is held.
func _leans_in() -> bool:
	var res: Array = []
	for over in [false, true]:
		var m := _medium()
		_stand(m, LADLE_SPEC, "pot", _at(Vector3(0, 0, -8)))
		var end_y := 13.0 if over else 2.0
		m._work.build({"acts": [{"name": "in", "beat": 1, "length": 3.0, "tracks": [{"thing": "pot", "part": "ladle", "law": "path", "jitter": 0.0, "keys": [
			{"at": 0.0}, {"at": 0.3, "by": [0, 14, 0]}, {"at": 0.7, "by": [-15, 14, 0], "turn": [0, 0, 30]}, {"at": 1.0, "by": [-15, end_y, 0], "turn": [0, 0, 30]}]}]},
			{"name": "again", "beat": 1, "length": 2.0, "tracks": [{"thing": "pot", "part": "ladle", "law": "path", "jitter": 0.0, "keys": [{"at": 0.0}, {"at": 1.0, "by": [0, 8, 0]}]}]}]}, 1)
		# ...over the rim, its next move half a second on - held across the pause, looked at in it; in the pot, 6 s on
		m._work.runs = [{"i": 0, "t0": 2.0, "t1": 5.0}, {"i": 1, "t0": 5.5 if over else 11.0, "t1": 7.5 if over else 13.0}]
		m._work._timelines()
		var ladle := _work_of_name(m, "ladle")
		var ph: TablePhysics = m._work.physics
		m._work.tick(5.25 if over else 10.0)
		var b: Dictionary = ph.rigid.bodies[int(ph._rigid_of[ladle])]
		var still := _baked(m, ladle, 9.0).origin.distance_to(_baked(m, ladle, 10.0).origin) if not over else 0.0
		var deep := INF
		var pose := _baked(m, ladle, 5.25 if over else 10.0)
		for sd in ph.solids:
			if int((sd as Dictionary)["wi"]) == ladle or String((m._work.things[int((sd as Dictionary)["thing"])] as Dictionary)["name"]) != "pot" \
					or (sd as Dictionary).has("body"):
				continue
			for sl in ph.solids:
				if int((sl as Dictionary)["wi"]) != ladle and not (int((sl as Dictionary)["wi"]) >= 0 and m._work._within(int((sl as Dictionary)["wi"]), ladle) == 1):
					continue
				for q in ((sl as Dictionary)["field"] as ShapeField).surface_points():
					var p := pose * ph._rest_of(ladle).affine_inverse() * ((sl as Dictionary)["rest"] as Transform3D) * q
					deep = minf(deep, ((sd as Dictionary)["field"] as ShapeField).sample(((sd as Dictionary)["inv"] as Transform3D) * p).x)
		res.append([b["held"] != null, still, deep, rad_to_deg(pose.basis.y.normalized().angle_to(Vector3.UP))])
		m._root3.free()
	_ok(bool(res[1][0]), "the control: left 3 cm over the pot's rim, its next move half a second on, the ladle was let go across the pause")
	_ok(not bool(res[0][0]), "left standing in the pot until its next move, the ladle is still held there")
	_ok(float(res[0][1]) < 0.0005 and float(res[0][2]) > -0.002, "let go in the pot, the ladle moved %.2f mm in its last second and is %.1f mm into the pot's wall" % [
		float(res[0][1]) * 1000.0, -float(res[0][2]) * 1000.0])
	return true


## ...AND IT IS NOT DROPPED IN FOR A MOMENT (841899, ladle-in-1 and its stir 1.6 s apart: let go 15 cm up, it fell against the wall, lay down, and was hauled upright again):
## a ladle brought into a pot of water, its next move 1.5 s on, stays as it was brought. The control: its next move 8 s on, it is let go and leans.
func _stands_held_for_a_moment() -> bool:
	var res := {}
	for gap in [1.5, 8.0]:
		var m := _medium()
		_stand(m, LADLE_SPEC, "pot", _at(Vector3(0, 0, -8)))
		m._work.build({"acts": [{"name": "in", "beat": 1, "length": 3.0, "tracks": [{"thing": "pot", "part": "ladle", "law": "path", "jitter": 0.0, "keys": [
			{"at": 0.0}, {"at": 0.3, "by": [0, 14, 0]}, {"at": 0.7, "by": [-15, 14, 0], "turn": [0, 0, 30]}, {"at": 1.0, "by": [-15, 4, 0], "turn": [0, 0, 30]}]}]},
			{"name": "again", "beat": 1, "length": 2.0, "tracks": [{"thing": "pot", "part": "ladle", "law": "path", "jitter": 0.0, "keys": [{"at": 0.0}, {"at": 1.0, "by": [0, 8, 0]}]}]}]}, 1)
		m._work.runs = [{"i": 0, "t0": 2.0, "t1": 5.0}, {"i": 1, "t0": 5.0 + float(gap), "t1": 7.0 + float(gap)}]
		m._work._timelines()
		var ladle := _work_of_name(m, "ladle")
		var ph: TablePhysics = m._work.physics
		var look := 5.0 + minf(float(gap) - 0.1, 3.0)
		m._work.tick(look + 1.0)
		var a := _baked(m, ladle, 5.0)
		var b := _baked(m, ladle, look)
		res[gap] = [a.origin.distance_to(b.origin), rad_to_deg(Quaternion(a.basis.orthonormalized()).angle_to(Quaternion(b.basis.orthonormalized())))]
		m._root3.free()
	_ok(float(res[1.5][0]) < 0.006 and float(res[1.5][1]) < 3.0, "its next move 1.5 s on, the ladle standing in the pot moved %.1f cm and turned %.0f degrees" % [float(res[1.5][0]) * 100.0, float(res[1.5][1])])
	_ok(float(res[8.0][0]) > 0.006 or float(res[8.0][1]) > 3.0, "the control: its next move 8 s on, the ladle stayed held as it was brought")
	return true


## TOUCHING IS NOT RESTING (841899: the ladle held over the vial after its pour grazed it, was let go and fell to the table): a rod
## lowered with one end on a block's top and its middle past the block's edge, taken up again half a second later, is held across
## the pause. The control: lowered with its middle over the block, it rests there and is let go.
func _held_unless_resting() -> bool:
	var res: Array = []
	for over_middle in [false, true]:
		var m := _medium()
		_stand(m, TOOL_SPEC, "tools", _at(Vector3(-15, 0, -8)))
		_stand(m, TOOL_SPEC, "block", _at(Vector3(0, 0, -8)))
		# where the block's top is and the rod's underside, as built (each move is from there)
		m._work.build({"acts": []}, 1)
		var top := -INF
		var low := INF
		var rod := _rod(m)
		for sd in m._work.physics.solids:
			if String((m._work.things[int((sd as Dictionary)["thing"])] as Dictionary)["name"]) == "block":
				top = maxf(top, ((sd as Dictionary)["wbox"] as AABB).end.y)
			elif int((sd as Dictionary)["wi"]) == rod:
				low = minf(low, ((sd as Dictionary)["wbox"] as AABB).position.y)
		m._root3.free()
		m = _medium()
		_stand(m, TOOL_SPEC, "tools", _at(Vector3(-15, 0, -8)))
		_stand(m, TOOL_SPEC, "block", _at(Vector3(0, 0, -8)))
		# the rod 10 cm long: its middle 1 cm over the block's middle, or its end 1.5 cm over the block's edge
		# (the rod built from -20 to -10 cm, the block from -3 to 3: its right end 1.5 cm over the block's edge is 8.5 cm along)
		var x := 15.0 if over_middle else 8.5
		var up := (top - low - 0.002) * 100.0 + 0.05
		m._work.build({"acts": [{"name": "set", "beat": 1, "length": 3.0, "tracks": [{"thing": "tools", "part": "rod", "law": "path", "jitter": 0.0, "keys": [
			{"at": 0.0}, {"at": 0.3, "by": [0, up + 6.0, 0]}, {"at": 0.8, "by": [x, up + 6.0, 0]}, {"at": 1.0, "by": [x, up, 0]}]}]},
			{"name": "again", "beat": 1, "length": 2.0, "tracks": [{"thing": "tools", "part": "rod", "law": "path", "jitter": 0.0, "keys": [{"at": 0.0}, {"at": 1.0, "by": [0, 5, 0]}]}]}]}, 1)
		m._work.runs = [{"i": 0, "t0": 2.0, "t1": 5.0}, {"i": 1, "t0": 5.5, "t1": 7.5}]
		m._work._timelines()
		rod = _rod(m)
		var ph: TablePhysics = m._work.physics
		m._work.tick(5.25)
		res.append((ph.rigid.bodies[int(ph._rigid_of[rod])] as Dictionary)["held"] != null)
		m._root3.free()
	_ok(not bool(res[1]), "the control: lowered with its middle over the block, the rod resting there is still held")
	_ok(bool(res[0]), "lowered with only its end on the block, its middle over nothing, the rod was let go - it would fall")
	return true


## WHAT STANDS IN A LIQUID IS UNDER ITS SURFACE (841899, the user: "the ladle is placed into the liquid - and this causes the amount
## of liquid to DECREASE. That is backwards"): a ladle stood in a pot of water fills, and the water stands no lower for it; lifted
## out with what it holds, the water is lower; under the water the ladle's own surface is not drawn, and lifted out it is. The
## control: the water's level reckoned from its own volume alone falls as the ladle fills.
func _level_counts() -> bool:
	var m := _medium()
	_stand(m, LADLE_SPEC, "pot", _at(Vector3(0, 0, -8)))
	m._work.build({"acts": [{"name": "in", "beat": 1, "length": 3.0, "tracks": [{"thing": "pot", "part": "ladle", "law": "path", "jitter": 0.0, "keys": [
		{"at": 0.0}, {"at": 0.3, "by": [0, 14, 0]}, {"at": 0.7, "by": [-15, 14, 0]}, {"at": 1.0, "by": [-15, 1.0, 0]}]}]},
		{"name": "out", "beat": 1, "length": 3.0, "tracks": [{"thing": "pot", "part": "ladle", "law": "path", "jitter": 0.0, "keys": [{"at": 0.0}, {"at": 1.0, "by": [0, 13, 0]}]}]},
		{"name": "later", "beat": 1, "length": 1.0, "tracks": [{"thing": "pot", "part": "ladle", "law": "path", "jitter": 0.0, "keys": [{"at": 0.0}, {"at": 1.0, "by": [3, 0, 0]}]}]}]}, 1)
	# ...lifted out and held over the pot for its next move a pause later (a hand holds nothing in the air longer - left there, it
	# is set down in the pot again: [constant TablePhysics.HOLD_MOST])
	m._work.runs = [{"i": 0, "t0": 2.0, "t1": 5.0}, {"i": 1, "t0": 5.2, "t1": 8.2}, {"i": 2, "t0": 8.9, "t1": 9.9}]
	m._work._timelines()
	var ph: TablePhysics = m._work.physics
	var water := _liquid(m, "pot")
	var ladle := _work_of_name(m, "ladle")
	var inside := -1
	for li in ph.liquids.size():
		if int((ph.solids[int((ph.liquids[li] as Dictionary)["solid"])] as Dictionary)["wi"]) == ladle:
			inside = li
	_ok(water >= 0 and inside >= 0 and inside != water, "the pot has no water, or the ladle no inside")
	if water < 0 or inside < 0 or inside == water:
		m._root3.free()
		return true
	m._work.tick(10.0)
	var at := func(t: float) -> float: return float((ph.frame_at(t) as Dictionary)["liq"][water * 16 + 5])
	var sunk := func(t: float) -> bool:
		var s: PackedByteArray = (ph.frame_at(t) as Dictionary).get("sunk", PackedByteArray())
		return inside < s.size() and s[inside] == 1
	var before: float = at.call(1.0)
	var held := _volume(m, inside, 5.1)
	var dipped: float = at.call(5.1)
	var after: float = at.call(8.6)
	# the control: the water's own level, its volume alone
	var L: Dictionary = ph.liquids[water]
	var sd: Dictionary = ph.solids[int(L["solid"])]
	var vs: Vessel = L["vessel"]
	var up := ((sd["xf"] as Transform3D).basis.inverse() * Vector3.UP).normalized()
	var alone := ((sd["xf"] as Transform3D) * vs.surface_middle(up, vs.level(up, _volume(m, water, 5.1) / float(L["full_v"])))).y
	_ok(held > 1e-6, "stood in the water, the ladle holds %.2f ml" % (held * 1e6))
	_ok(before - alone > 0.0003, "the control: from its own volume alone, the water stood only %.2f mm lower as the ladle filled" % ((before - alone) * 1000.0))
	_ok(dipped >= before - 0.0001, "the ladle stood in it and filled, the water stands %.2f mm lower than before" % ((before - dipped) * 1000.0))
	_ok(after < before - 0.0002 and _volume(m, inside, 8.6) > 1e-6, "lifted out holding %.2f ml, the water stands %.2f mm lower than before it went in" % [
		_volume(m, inside, 8.6) * 1e6, (before - after) * 1000.0])
	_ok(bool(sunk.call(5.1)), "under the water, the ladle's own surface is drawn as well as the water's")
	_ok(not bool(sunk.call(8.6)), "the control: lifted out, the ladle's own surface is not drawn")
	m._root3.free()
	return true


const LEAF_SPEC := {"things": [
	{"name": "pot", "parts": [
		{"shape": "lathe", "profile": [[0, 0], [7, 0], [7.6, 9], [8, 9.2], [7.3, 9], [6.6, 0.6], [0, 0.6]], "material": "clay",
			"points": {"floor": [0, 0.6, 0]}},
		{"name": "water", "shape": "lathe", "profile": [[0, 0.6], [6.6, 0.6], [7.0, 6], [0, 6]], "material": "water"},
		{"name": "leaf", "shape": "sheet", "size": [3, 12], "at": [0, 6.2, 0], "loose": true, "material": "leaf"},
		{"name": "paddle", "shape": "box", "size": [0.8, 7, 8], "material": "wood", "at": [12, 0, 0], "joint": {"kind": "free"}}]}],
	"materials": {"clay": {"kind": "ceramic", "color": "#8a6a4a"}, "water": {"kind": "liquid", "color": "#6a8aa0"},
		"wood": {"kind": "wood", "color": "#5a3a22"}, "leaf": {"kind": "fabric", "color": "#c8401a"}}}


## WHAT FLOATS STAYS IN WHAT IT FLOATS IN, AND IS MET ACROSS ITS FACE (841899: the phoenix feather, afloat and pushed about by the
## stirring ladle, stood on edge against the cauldron's wall and went through it, and lay outside in the coals - a sheet had been a
## line of spheres down its middle, its width met by nothing): a leaf 12 cm by 3 afloat in a pot 13 cm across, swept by a paddle
## into the pot's wall and pressed there, is never out of the pot's inside, and is made of spheres across its width. The control:
## the paddle moved it.
func _floats_in() -> bool:
	var m := _medium()
	_stand(m, LEAF_SPEC, "pot", _at(Vector3(0, 0, -8)))
	m._work.build({"acts": [{"name": "sweep", "beat": 1, "length": 8, "tracks": [{"thing": "pot", "part": "paddle", "law": "path", "jitter": 0.0,
		"keys": [{"at": 0.0}, {"at": 0.25, "by": [0, 10, 0]}, {"at": 0.45, "by": [-16, 10, 0]}, {"at": 0.6, "by": [-16, 2.6, 0]},
			{"at": 0.9, "by": [-6.1, 2.6, 0]}, {"at": 1.0, "by": [-6.1, 2.6, 0]}]}]}]}, 1)
	m._work.runs = [{"i": 0, "t0": 2.0, "t1": 10.0}]
	m._work._timelines()
	var ph: TablePhysics = m._work.physics
	var leaf := _work_of_name(m, "leaf")
	var water := _liquid(m, "pot")
	var vs: Vessel = (ph.liquids[water] as Dictionary)["vessel"]
	var pot: Dictionary = ph.solids[int((ph.liquids[water] as Dictionary)["solid"])]
	var inv: Transform3D = pot["inv"]
	var rim := (pot["wbox"] as AABB).end.y
	m._work.tick(11.0)
	var out := 0
	var moved := 0.0
	var first: Variant = null
	for k in 120:
		var t := 1.0 + 10.0 * float(k) / 119.0
		var f: Dictionary = ph.frame_at(t)
		var li := int(ph._loose_of.get(leaf, -1))
		var bi := li >= 0 and int((ph.loose[li] as Dictionary)["body"]) >= 0
		if not bi:
			continue
		var b := int((ph.loose[li] as Dictionary)["body"])
		var x: PackedVector3Array = f["x"]
		var owner: PackedInt32Array = f["body"]
		for i in x.size():
			# ...THROUGH ITS WALL: out of the clay and out of the inside, under the rim (pressed into the wall, a sphere's middle may
			# reach it; squeezed up, it may go over the rim)
			if i < owner.size() and owner[i] == b and x[i].y < rim and not vs.contains(inv * x[i]) \
					and (pot["field"] as ShapeField).sample(inv * x[i]).x > 0.001:
				out += 1
		var pose: Variant = ph.pose_of(leaf, t)
		if pose != null:
			if first == null:
				first = pose
			moved = maxf(moved, (pose as Transform3D).origin.distance_to((first as Transform3D).origin))
	var across := 0.0
	var L: Dictionary = ph.loose[int(ph._loose_of.get(leaf, -1))]
	var sph: PackedVector3Array = L["spheres"]
	var mid := Vector3.ZERO
	for p in sph:
		mid += p / float(maxi(sph.size(), 1))
	for p in sph:
		across = maxf(across, absf(p.x - mid.x))
	_ok(across > 0.008, "the leaf 3 cm wide is met by spheres only %.1f mm either side of its middle" % (across * 1000.0))
	_ok(moved > 0.01, "the control: the paddle moved the leaf only %.1f mm" % (moved * 1000.0))
	_ok(out == 0, "pressed into the pot's wall, the leaf afloat had a sphere through it, outside the pot, %d times" % out)
	m._root3.free()
	return true


const WAY_SPEC := {"things": [
	{"name": "crate", "parts": [{"shape": "box", "size": [4, 4, 4], "material": "oak"}]},
	{"name": "tall block", "parts": [{"shape": "box", "size": [6, 9, 30], "material": "oak"}]}],
	"materials": {"oak": {"kind": "wood", "color": "#6b4a2b"}}}


## A CARRY CLEARS WHAT STANDS IN ITS WAY (841899: the ladle carried home with a 6 cm lift went into the 8.5 cm recipe tin between it
## and its rest, was held back on it and lay on it to the end of the show): a crate carried 30 cm with a lift of 2 cm over a block
## 9 cm tall goes over it, never held back, and is set down where it was sent. The control: the same carry with the block out of
## its way is lifted only as written.
func _clears_way() -> bool:
	var res: Array = []
	for in_way in [true, false]:
		var m := _medium()
		_stand(m, WAY_SPEC, "crate", _at(Vector3(-15, 0, -8)))
		_stand(m, WAY_SPEC, "tall block", _at(Vector3(0, 0, -8 if in_way else -60)))
		m._work.build({"acts": [{"name": "over", "beat": 1, "length": 4.0, "tracks": [{"thing": "crate", "law": "carry", "to": [15, 0, -8], "lift": 2.0, "down": true}]}]}, 1)
		m._work.runs = [{"i": 0, "t0": 2.0, "t1": 6.0}]
		m._work._timelines()
		var ph: TablePhysics = m._work.physics
		m._work.tick(8.0)
		var ti := -1
		for i in m._work.things.size():
			if String((m._work.things[i] as Dictionary)["name"]) == "crate":
				ti = i
		var back := 0.0
		for k in 50:
			var f: Dictionary = ph.frame_at(2.0 + 4.0 * float(k) / 49.0)
			back = maxf(back, ph.held_off(f, int(ph._rigid_of[-1 - ti])))
		var end: Variant = ph.thing_pose_of(ti, 8.0)
		m._work.value("t%d:pose" % ti, 4.0)
		var e: Dictionary = (m._work._chan["t%d:pose" % ti] as Array)[0]
		res.append([back, (end as Transform3D).origin.distance_to(_at(Vector3(15, 0, -8))) if end != null else INF, float(e.get("_clear", 0.0))])
		m._root3.free()
	_ok(float(res[1][2]) < 0.001, "the control: with nothing in its way, the carry was lifted %.1f cm more than written" % (float(res[1][2]) * 100.0))
	_ok(float(res[0][0]) < 0.01 and float(res[0][1]) < 0.01, "carried over a 9 cm block with a 2 cm lift, the crate was held back %.1f cm and ended %.1f cm from where it was sent" % [
		float(res[0][0]) * 100.0, float(res[0][1]) * 100.0])
	return true


const JUG_SPEC := {"things": [
	{"name": "jug", "parts": [
		{"name": "jug", "joint": {"kind": "free"}, "parts": [
			{"shape": "lathe", "material": "clay", "profile": [[0, 0], [3.2, 0], [3.2, 7], [2.8, 7], [2.8, 0.4], [0, 0.4]]},
			{"name": "milk", "shape": "lathe", "profile": [[0, 0.4], [2.8, 0.4], [2.8, 2.6], [0, 2.6]], "material": "water"}]}]},
	{"name": "cup", "parts": [
		{"shape": "lathe", "profile": [[0, 0], [2.2, 0], [2.4, 8], [2.0, 8], [1.85, 0.4], [0, 0.4]], "material": "clay"}]}],
	"materials": {"clay": {"kind": "ceramic", "color": "#8a6a4a"}, "water": {"kind": "liquid", "color": "#e8e4d8"}}}


## A POUR IS A HAND'S (841899, the user: the ladle "dumps liquid into a vial in a strange way, both missing the vial AND pouring from
## much too high in the air. Not carefully"): a jug poured `into` a cup 4 cm across, 25 cm away, empties into it - most of what
## left the jug in the cup, its lip held a couple of centimeters over the cup's rim while it flows. The control: the same jug
## tipped by hand about its middle, held 10 cm over the cup, spills much of it.
func _pours_into() -> bool:
	var res: Array = []
	for by_hand in [false, true]:
		var m := _medium()
		_stand(m, JUG_SPEC, "jug", _at(Vector3(20, 0, -8)))
		_stand(m, JUG_SPEC, "cup", _at(Vector3(-5, 0, -8)))
		var tracks: Array = [{"thing": "jug", "part": "jug", "law": "pour", "into": "cup"}]
		if by_hand:
			tracks = [{"thing": "jug", "part": "jug", "law": "path", "jitter": 0.0, "keys": [{"at": 0.0}, {"at": 0.3, "by": [-25, 10, 0]},
				{"at": 0.6, "by": [-25, 10, 0], "turn": [0, 0, 120]}, {"at": 0.8, "by": [-25, 10, 0], "turn": [0, 0, 120]}, {"at": 1.0, "by": [-25, 10, 0]}]}]
		m._work.build({"acts": [{"name": "pour-it", "beat": 1, "length": 8.0, "tracks": tracks}]}, 1)
		m._work.runs = [{"i": 0, "t0": 2.0, "t1": 10.0}]
		m._work._timelines()
		var ph: TablePhysics = m._work.physics
		var milk := -1
		var cup := _liquid(m, "cup")
		for li in ph.liquids.size():
			if bool((ph.liquids[li] as Dictionary)["made"]):
				milk = li
		m._work.tick(13.0)
		var gave := _volume(m, milk, 1.0) - _volume(m, milk, 13.0)
		var got := _volume(m, cup, 13.0) - _volume(m, cup, 1.0)
		# the lowest any stream stood while it flowed, against the cup's rim
		var rim := -INF
		for sd in ph.solids:
			if String((m._work.things[int((sd as Dictionary)["thing"])] as Dictionary)["name"]) == "cup":
				rim = maxf(rim, ((sd as Dictionary)["wbox"] as AABB).end.y)
		var high := -INF
		for k in 160:
			for st in ((ph.frame_at(2.0 + 8.0 * float(k) / 159.0) as Dictionary).get("streams", []) as Array):
				for p in ((st as Dictionary)["pts"] as PackedVector3Array):
					high = maxf(high, p.y - rim)
		res.append([gave, got, high])
		m._root3.free()
	_ok(float(res[0][0]) > 5e-6, "poured, the jug gave only %.1f ml" % (float(res[0][0]) * 1e6))
	_ok(float(res[0][1]) > float(res[0][0]) * 0.85, "poured into the cup, %.1f ml of the jug's %.1f reached it" % [float(res[0][1]) * 1e6, float(res[0][0]) * 1e6])
	_ok(float(res[0][2]) < 0.04, "poured, its stream left the lip %.1f cm over the cup's rim" % (float(res[0][2]) * 100.0))
	_ok(float(res[1][1]) < float(res[1][0]) * 0.7, "the control: tipped by hand about its middle 10 cm up, %.1f ml of the jug's %.1f reached the cup" % [
		float(res[1][1]) * 1e6, float(res[1][0]) * 1e6])
	return true


const CORKED_SPEC := {"things": [
	{"name": "jug", "parts": [
		{"name": "jug", "joint": {"kind": "free"}, "parts": [
			{"shape": "lathe", "material": "clay", "profile": [[0, 0], [3.2, 0], [3.2, 7], [2.8, 7], [2.8, 0.4], [0, 0.4]]},
			{"name": "milk", "shape": "lathe", "profile": [[0, 0.4], [2.8, 0.4], [2.8, 2.6], [0, 2.6]], "material": "water"}]}]},
	{"name": "cup", "parts": [
		{"shape": "lathe", "profile": [[0, 0], [2.2, 0], [2.4, 8], [2.0, 8], [1.85, 0.4], [0, 0.4]], "material": "clay"},
		{"name": "cup cork", "at": [0, 6.8, 0], "shape": "lathe", "profile": [[0, 0], [1.9, 0], [2.0, 1.2], [0, 1.2]], "material": "cork", "start": {"shown": 0.0}}]}],
	"materials": {"clay": {"kind": "ceramic", "color": "#8a6a4a"}, "water": {"kind": "liquid", "color": "#e8e4d8"}, "cork": {"kind": "wood", "color": "#b08a5a"}}}


## WHAT NO ACT HAS BROUGHT YET IS NOT THERE, HEARD OF OR NOT (841899, feedback 0013: "When the ladle poured into the vial here, nothing happened"; a
## vial's cork, `shown` 0 until the act after the pour, stood unseen in its neck whenever that act's words had not reached a live plan, and the 27 ml
## stopped on it; a bake of the whole plan had always filled the vial, so no gate saw it): a jug poured into a cup whose cork comes later fills the cup
## alike with that act placed and with it not yet heard - and the words that place it, heard after the bake, change nothing before it. The control:
## the cork brought before the pour stops the stream.
func _unbrought_not_there() -> bool:
	var got := {}
	for case in ["placed", "unheard", "heard after", "brought first"]:
		var m := _medium()
		_stand(m, CORKED_SPEC, "jug", _at(Vector3(20, 0, -8)))
		_stand(m, CORKED_SPEC, "cup", _at(Vector3(-5, 0, -8)))
		m._work.build({"acts": [{"name": "pour-it", "beat": 1, "length": 8.0, "tracks": [{"thing": "jug", "part": "jug", "law": "pour", "into": "cup"}]},
			{"name": "cork-it", "beat": 1, "length": 1.0, "tracks": [{"thing": "cup", "part": "cup cork", "law": "to", "state": "shown", "value": 1.0}]}]}, 1)
		var runs: Array = [{"i": 0, "t0": 2.0, "t1": 10.0}]
		if case == "placed":
			runs.append({"i": 1, "t0": 14.0, "t1": 15.0})
		if case == "brought first":
			runs.append({"i": 1, "t0": 0.2, "t1": 1.2})
		m._work.runs = runs
		m._work._timelines()
		var ph: TablePhysics = m._work.physics
		var cup := _liquid(m, "cup")
		if case == "heard after":
			ph.bake_until(13.0)
			m._work.runs = [{"i": 0, "t0": 2.0, "t1": 10.0}, {"i": 1, "t0": 14.0, "t1": 15.0}]
			m._work._timelines()
			ph._take_plan()
		m._work.tick(13.0)
		got[case] = _volume(m, cup, 13.0)
		m._root3.free()
	_ok(float(got["placed"]) > 5e-6, "with the cork's act placed for after the pour, the cup holds only %.1f ml" % (float(got["placed"]) * 1e6))
	_ok(absf(float(got["unheard"]) - float(got["placed"])) < 5e-7, "the cork's act not yet heard, the cup holds %.1f ml - %.1f with it placed: something not there stopped the pour" % [float(got["unheard"]) * 1e6, float(got["placed"]) * 1e6])
	_ok(absf(float(got["heard after"]) - float(got["placed"])) < 5e-7, "the cork's act heard after the bake, the cup holds %.1f ml - %.1f with it placed all along" % [float(got["heard after"]) * 1e6, float(got["placed"]) * 1e6])
	_ok(float(got["brought first"]) < float(got["placed"]) * 0.3, "the control: the cork brought before the pour, the cup still took %.1f ml of the stream" % (float(got["brought first"]) * 1e6))
	return true


## WHAT STRIKES A VESSEL'S INSIDE RUNS DOWN INTO IT (841899's dip: the ladle drawn up tilted out of its pot spilled over the pot's
## inner wall, and that was counted gone - 8.5 ml "SPILLED" of a pot it never left): a milliliter thrown from the ladle at the
## pot's inner wall from above its water ends in the water, and the water holds a milliliter more. The control: thrown outward over the rim, it is
## spilled.
func _runs_down() -> bool:
	var res: Array = []
	for out in [false, true]:
		var m := _medium()
		_stand(m, LADLE_SPEC, "pot", _at(Vector3(0, 0, -8)))
		m._work.build({"acts": []}, 1)
		var ph: TablePhysics = m._work.physics
		var water := _liquid(m, "pot")
		var ladle := -1
		for li in ph.liquids.size():
			if li != water:
				ladle = li
		# ...the pot's own axis (its thing stands centered with the ladle beside it)
		var c: Vector3 = (ph.solids[int((ph.liquids[water] as Dictionary)["solid"])] as Dictionary)["xf"].origin
		var v0 := float((ph._liq[water] as Dictionary)["v"])
		# a parcel 8 cm out from the pot's middle, 8 cm up (the water stands at 6, the rim at 9.2), going out at 1 m/s
		var from := c + Vector3(0.08 if not out else 0.105, 0.08 if not out else 0.1, 0.0)
		ph.parcels.append({"t0": 0.2, "p": from, "v": Vector3(1.0 if not out else 0.6, 0.0, 0.0), "vol": 1e-6, "from": ladle, "t1": INF,
			"into": -2, "color": Color.WHITE})
		for k in 60:
			ph._parcels_step(float(k + 1) / 60.0 + 0.2, 1.0 / 60.0)
		res.append([int((ph.parcels.back() as Dictionary)["into"]), float((ph._liq[water] as Dictionary)["v"]) - v0, water])
		m._root3.free()
	_ok(int(res[1][0]) == -1, "the control: thrown outward over the rim, the parcel went into liquid %d" % int(res[1][0]))
	_ok(int(res[0][0]) == int(res[0][2]) and absf(float(res[0][1]) - 1e-6) < 1e-8, "thrown at the pot's inner wall, the parcel went into %d (the water is %d), the water %.2f ml more" % [
		int(res[0][0]), int(res[0][2]), float(res[0][1]) * 1e6])
	return true


## 841899's own ladle - a bowl with a straight handle at its rim's height - on its rest, and a deep pot of water.
const DIP_SPEC := {"things": [
	{"name": "ladle rest", "parts": [{"material": "oak", "round": 0.4, "shape": "box", "size": [24.0, 1.2, 7.0]},
		{"joint": {"kind": "free"}, "name": "ladle", "parts": [
			{"at": [-6.0, 1.2, 0.0], "material": "brass", "smooth": true, "shape": "lathe",
				"profile": [[0.0, 0.0], [1.5, 0.0], [2.8, 0.8], [3.2, 2.0], [3.3, 2.8, 0.0], [3.0, 2.8, 0.0], [2.9, 2.0], [2.5, 0.95], [1.3, 0.35], [0.0, 0.35]]},
			{"material": "brass", "path": [[-2.9, 3.85, 0.0], [2.0, 4.0, 0.0], [9.5, 4.05, 0.0], [12.6, 4.2, 0.0], [13.4, 3.3, 0.0]], "radius": 0.35, "shape": "tube"}]}]},
	{"name": "pot", "parts": [
		{"shape": "lathe", "profile": [[0, 0], [8, 0], [9, 13], [9.4, 13.2], [8.6, 13], [7.6, 0.6], [0, 0.6]], "material": "clay"},
		{"name": "water", "shape": "lathe", "profile": [[0, 0.6], [7.6, 0.6], [8.1, 7.5], [0, 7.5]], "material": "water"}]}],
	"materials": {"brass": {"kind": "metal", "color": "#b8924c"}, "oak": {"kind": "wood", "color": "#6b4a2b"},
		"clay": {"kind": "ceramic", "color": "#8a6a4a"}, "water": {"kind": "liquid", "color": "#6a8aa0"}}}


## A DIP IS A HAND'S (841899: its ladle, dipped by an aim's keys, came up full and tipped beside the rim, and 10 ml went over the
## rim - "the spoon spills liquid in a strange way when lifting from the cauldron"): the episode's ladle `dip`ped into a deep pot of
## water comes up holding at least half its bowl, nothing it spilled lands outside the pot, and nothing holds it back on the way.
## The control: lowered level into the pot by hand, its straight handle meets the rim, it is held back, and it comes up empty.
func _dips_full() -> bool:
	var res: Array = []
	for by_hand in [false, true]:
		var m := _medium()
		_stand(m, DIP_SPEC, "ladle rest", _at(Vector3(30, 0, -14)))
		_stand(m, DIP_SPEC, "pot", _at(Vector3(-5, 0, -8)))
		var tracks: Array = [{"thing": "ladle rest", "part": "ladle", "law": "dip", "into": "pot"}]
		if by_hand:
			tracks = [{"thing": "ladle rest", "part": "ladle", "law": "path", "jitter": 0.0, "keys": [{"at": 0.0}, {"at": 0.25, "by": [0, 16, 0]},
				{"at": 0.5, "by": [-29, 16, 6], "turn": [0, 180, 0]}, {"at": 0.75, "by": [-29, 4, 6], "turn": [0, 180, 0]}, {"at": 1.0, "by": [-29, 16, 6], "turn": [0, 180, 0]}]}]
		m._work.build({"acts": [{"name": "dip-it", "beat": 1, "length": 6.0, "tracks": tracks},
			{"name": "later", "beat": 1, "length": 1.0, "tracks": [{"thing": "ladle rest", "part": "ladle", "law": "path", "jitter": 0.0, "keys": [{"at": 0.0}, {"at": 1.0, "by": [0, 2, 0]}]}]}]}, 1)
		# ...its next move a pause on: drawn up, it is held over the pot for it (left there longer, it is set down in the pot again)
		m._work.runs = [{"i": 0, "t0": 2.0, "t1": 8.0}, {"i": 1, "t0": 8.6, "t1": 9.6}]
		m._work._timelines()
		var ph: TablePhysics = m._work.physics
		var ladle := _work_of_name(m, "ladle")
		var bowl := -1
		for li in ph.liquids.size():
			if m._work._within(int((ph.solids[int((ph.liquids[li] as Dictionary)["solid"])] as Dictionary)["wi"]), ladle) == 1:
				bowl = li
		m._work.tick(11.0)
		var back := 0.0
		for k in 120:
			back = maxf(back, ph.held_off(ph.frame_at(2.0 + 6.0 * float(k) / 119.0) as Dictionary, int(ph._rigid_of[ladle])))
		var spilled := 0.0
		for pd in ph.parcels:
			if int((pd as Dictionary)["into"]) == -1:
				spilled += float((pd as Dictionary)["vol"])
		res.append([_volume(m, bowl, 8.4) / float((ph.liquids[bowl] as Dictionary)["full_v"]) if bowl >= 0 else 0.0, spilled, back])
		m._root3.free()
	_ok(float(res[1][2]) > 0.01 and float(res[1][0]) < 0.2, "the control: lowered level by hand, the ladle was held back %.1f cm and came up %.0f%% full" % [
		float(res[1][2]) * 100.0, float(res[1][0]) * 100.0])
	_ok(float(res[0][0]) > 0.5, "dipped, the ladle came up only %.0f%% full" % (float(res[0][0]) * 100.0))
	_ok(float(res[0][1]) < 5e-7, "dipped, %.2f ml landed outside the pot" % (float(res[0][1]) * 1e6))
	_ok(float(res[0][2]) < 0.01, "dipped, the ladle was held back %.1f cm on its way" % (float(res[0][2]) * 100.0))
	return true


const JARS_SPEC := {"things": [
	{"name": "jars", "parts": [
		{"name": "left jar", "joint": {"kind": "free"}, "at": [-4, 0, 0], "parts": [
			{"shape": "lathe", "profile": [[0, 0], [2.4, 0], [2.4, 6], [2.0, 6], [2.0, 0.4], [0, 0.4]], "material": "glass"}]},
		{"name": "middle jar", "joint": {"kind": "free"}, "at": [0, 0, 6], "parts": [
			{"shape": "lathe", "profile": [[0, 0], [2.4, 0], [2.4, 6], [2.0, 6], [2.0, 0.4], [0, 0.4]], "material": "glass"}]},
		{"name": "right jar", "joint": {"kind": "free"}, "at": [4, 0, 0], "parts": [
			{"shape": "lathe", "profile": [[0, 0], [2.4, 0], [2.4, 6], [2.0, 6], [2.0, 0.4], [0, 0.4]], "material": "glass"}]}]},
	{"name": "tray", "parts": [
		{"shape": "box", "size": [16, 1, 8], "material": "oak"},
		{"name": "left jar", "joint": {"kind": "free"}, "at": [-4, 1, 0], "parts": [
			{"shape": "lathe", "profile": [[0, 0], [2.4, 0], [2.4, 6], [2.0, 6], [2.0, 0.4], [0, 0.4]], "material": "glass"}]},
		{"name": "right jar", "joint": {"kind": "free"}, "at": [4, 1, 0], "parts": [
			{"shape": "lathe", "profile": [[0, 0], [2.4, 0], [2.4, 6], [2.0, 6], [2.0, 0.4], [0, 0.4]], "material": "glass"}]}]}],
	"materials": {"glass": {"kind": "glass", "color": "#a0c0b0"}, "oak": {"kind": "wood", "color": "#6b4a2b"}}}


## A THING IS ONE ONLY AS FAR AS SOMETHING HOLDS IT TOGETHER (the-quiet-crucible 841899, 2026-10-31: "All 4 jars of ingredients are
## stuck together, and moved together here"): three jars side by side with nothing under them, carried 25 cm whole, are carried
## one at a time, in the order they were built, keeping the original duration per jar - each to its own place, upright and as far apart as they
## stood, each a body of its own. The control: two jars on a tray carried whole ride it together, both on their way at once.
func _jars_apart() -> bool:
	var res := {}
	for name in ["jars", "tray"]:
		var m := _medium()
		_stand(m, JARS_SPEC, name, _at(Vector3(0, 0, -8)))
		m._work.build({"acts": [{"name": "fetch", "beat": 1, "length": 4.0, "tracks": [{"thing": name, "law": "carry", "by": [25, 0, 0],
			"lift": 6, "down": true}]}]}, 1)
		var length := float((m._work.acts[0] as Dictionary)["length"])
		m._work.runs = [{"i": 0, "t0": 2.0, "t1": 2.0 + length}]
		m._work._timelines()
		var ph: TablePhysics = m._work.physics
		var lj := -1
		var rj := -1
		for wi in m._work.works.size():
			if int((m._work.works[wi] as Dictionary)["thing"]) == 0:
				if String((m._work.works[wi] as Dictionary)["name"]) == "left jar":
					lj = wi
				elif String((m._work.works[wi] as Dictionary)["name"]) == "right jar":
					rj = wi
		var end := 4.0 + length
		m._work.tick(end)
		# ...each jar's middle where the bake has it (both nodes stand at their thing's origin)
		var mid := func(wi: int, t: float) -> Vector3:
			return _baked(m, wi, t) * (((m._work.works[wi] as Dictionary)["w"] as Dictionary).get("middle", Vector3.ZERO) as Vector3)
		var l0: Vector3 = mid.call(lj, 1.0)
		var r0: Vector3 = mid.call(rj, 1.0)
		var mid_t := 3.5
		var middle := _work_of_name(m, "middle jar") if name == "jars" else -1
		res[name] = {"bodies": ph._rigid_of.has(lj) and ph._rigid_of.has(rj) and not ph._rigid_of.has(-1),
			"l_mid": (mid.call(lj, mid_t) as Vector3).distance_to(l0), "r_mid": (mid.call(rj, mid_t) as Vector3).distance_to(r0),
			"middle_mid": (mid.call(middle, mid_t) as Vector3).distance_to(mid.call(middle, 1.0)) if middle >= 0 else 0.0,
			"length": length,
			"l_end": (mid.call(lj, end) as Vector3) - l0, "r_end": (mid.call(rj, end) as Vector3) - r0,
			"apart": (mid.call(lj, end) as Vector3).distance_to(mid.call(rj, end)), "apart0": l0.distance_to(r0),
			"tilt": maxf(rad_to_deg(_baked(m, lj, end).basis.y.normalized().angle_to(Vector3.UP)), rad_to_deg(_baked(m, rj, end).basis.y.normalized().angle_to(Vector3.UP)))}
		# A short passage cannot squeeze the trips back into one group move's duration.
		var action := {"kind": "work", "card": 1, "after": 0, "dur": 0.0}
		m._work.schedule([{"a": action, "t0": 2.0, "s": 1.0}], {"actions": [action], "spoken": PackedStringArray(["fetch"])},
			PackedFloat32Array([2.0]), PackedFloat32Array([4.0]), PackedFloat32Array([2.0]), 0.0)
		var run: Dictionary = m._work.runs[0]
		res[name]["scheduled_length"] = float(run["t1"]) - float(run["t0"])
		res[name]["report"] = m._work.parts_report()
		m._root3.free()
	var j: Dictionary = res["jars"]
	var t: Dictionary = res["tray"]
	_ok(float(t["l_mid"]) > 0.01 and float(t["r_mid"]) > 0.01, "the control: on a tray carried whole, the jars were not both on their way at once (%.1f, %.1f cm)" % [
		float(t["l_mid"]) * 100.0, float(t["r_mid"]) * 100.0])
	_ok(bool(j["bodies"]), "two jars with nothing under them are not each a body of their own")
	_ok(float(j["middle_mid"]) < 0.003, "the second jar moved with the first: %.1f cm" % (float(j["middle_mid"]) * 100.0))
	_ok(is_equal_approx(float(j["length"]), 12.0), "three separate trips did not keep four seconds each")
	_ok(is_equal_approx(float(j["scheduled_length"]), 12.0), "a short reading squeezed the trips into %.1f seconds" % float(j["scheduled_length"]))
	_ok(String(j["report"]).contains("COLLECTION") and not String(t["report"]).contains("COLLECTION"), "the planner cannot distinguish a collection from jars on a carrier")
	_ok(float(j["l_mid"]) > 0.01 and float(j["r_mid"]) < 0.003, "carried whole with nothing to hold them together, the third jar went with the first (%.1f and %.1f cm a third of the way)" % [
		float(j["l_mid"]) * 100.0, float(j["r_mid"]) * 100.0])
	for k in ["l_end", "r_end"]:
		var d: Vector3 = j[k]
		_ok(absf(d.x - 0.25) < 0.015 and absf(d.z) < 0.015 and absf(d.y) < 0.005, "a jar carried in its turn went %s cm, not 25 along" % str(d * 100.0))
	_ok(absf(float(j["apart"]) - float(j["apart0"])) < 0.01 and float(j["tilt"]) < 5.0, "the jars ended %.1f cm apart (as built %.1f), tipped %.0f degrees" % [
		float(j["apart"]) * 100.0, float(j["apart0"]) * 100.0, float(j["tilt"])])
	return true


## A tool already inside a vessel resumes without an entry hop. The control: reaching in from outside still lifts.
## Test the contact point, not the tool's node origin (a handle or an arbitrarily placed group origin can be outside).
func _tool_entry() -> bool:
	var m := _medium()
	_stand(m, LADLE_SPEC, "pot", _at(Vector3(0, 0, -8)))
	m._work.build({"acts": [{"name": "stir", "beat": 1, "length": 4.0, "tracks": [{"thing": "pot", "part": "ladle", "law": "aim",
		"tip": {"point": "bowl", "at": [2, 4, -10]}, "grip": {"point": "grip", "at": [4.3, 20.7, -10]}}]}]}, 1)
	m._work.runs = [{"i": 0, "t0": 2.0, "t1": 6.0}]
	m._work._timelines()
	var wi := _work_of_name(m, "ladle")
	var entry: Dictionary = (m._work._chan["w%d:pose" % wi] as Array)[0]
	var tip := m._work._point_local(wi, "bowl")
	var res: Array = []
	for inside in [true, false]:
		var e := entry.duplicate()
		var from: Transform3D = m._work._rest["w%d:pose" % wi]
		if inside:
			from.origin += Vector3(-0.15, 0.03, 0.0)
		e["from"] = from
		var high := -INF
		for k in 25:
			var tau := TableWork.BLEND_IN * float(k) / 24.0
			var pose: Transform3D = m._work._eval(e, tau, 2.0 + tau)
			high = maxf(high, (pose * tip).y)
		res.append(high)
	_ok(float(res[0]) <= 0.045, "resuming inside the pot lifted the bowl to %.1f cm" % (float(res[0]) * 100.0))
	_ok(float(res[1]) > 0.07, "the control: reaching into the pot from outside never lifted over its rim")
	m._root3.free()
	return true


const REST_SPEC := {"things": [
	{"name": "the ladle on its rest", "parts": [
		{"material": "oak", "round": 0.4, "shape": "box", "size": [24.0, 1.2, 7.0]},
		{"at": [9.5, 1.2, 0.0], "material": "oak", "round": 0.5, "shape": "box", "size": [3.0, 2.5, 6.0]},
		{"joint": {"kind": "free"}, "name": "ladle", "points": {"bowl": [-6.0, 2.2, 0.0], "grip": [11.0, 4.1, 0.0]}, "parts": [
			{"at": [-6.0, 1.2, 0.0], "material": "brass", "shape": "lathe", "smooth": true, "profile": [[0.0, 0.0], [1.5, 0.0], [2.8, 0.8],
				[3.2, 2.0], [3.3, 2.8, 0.0], [3.0, 2.8, 0.0], [2.9, 2.0], [2.5, 0.95], [1.3, 0.35], [0.0, 0.35]]},
			{"material": "brass", "radius": 0.35, "shape": "tube", "path": [[-2.9, 3.85, 0.0], [2.0, 4.0, 0.0], [9.5, 4.05, 0.0], [12.6, 4.2, 0.0],
				[13.4, 3.3, 0.0]]}]}]}],
	"materials": {"oak": {"kind": "wood", "color": "#6b4a2b"}, "brass": {"kind": "metal", "color": "#b8924c"}}}


## A HAND LETS GO OF WHAT, LET GO, COMES TO REST WHERE IT IS (the-quiet-crucible 841899, 2026-10-31: "this ladle will not settle,
## it's moving around on its block" - put back on its rest, it was read as not held up, and held there swaying for two and a half
## minutes): 841899's own ladle, lifted 6 cm off its rest by its two ends and put back as it was built, taken up again 6 s later,
## is let go between its moves and lies still on its rest. The control: put back only to 8 cm over its rest, it is held there.
func _rests_let_go() -> bool:
	var res: Array = []
	for end_y in [0.0, 8.0]:
		var m := _medium()
		_stand(m, REST_SPEC, "the ladle on its rest", _at(Vector3(-10, 0, -8)))
		var keys := [{"at": 0.0, "by": [0.0, 0.0, 0.0]}, {"at": 0.4, "by": [0.0, 6.0, 0.0]}, {"at": 1.0, "by": [0.0, end_y, 0.0]}]
		m._work.build({"acts": [{"name": "back", "beat": 1, "length": 3.0, "tracks": [{"thing": "the ladle on its rest", "part": "ladle", "law": "aim",
				"grip": {"point": "grip", "keys": keys}, "tip": {"point": "bowl", "keys": keys}}]},
			{"name": "again", "beat": 1, "length": 2.0, "tracks": [{"thing": "the ladle on its rest", "part": "ladle", "law": "path", "jitter": 0.0,
				"keys": [{"at": 0.0}, {"at": 1.0, "by": [0, 5, 0]}]}]}]}, 1)
		var over: bool = end_y > 0.0
		m._work.runs = [{"i": 0, "t0": 2.0, "t1": 5.0}, {"i": 1, "t0": 5.5 if over else 11.0, "t1": 7.5 if over else 13.0}]
		m._work._timelines()
		var ladle := _work_of_name(m, "ladle")
		var ph: TablePhysics = m._work.physics
		m._work.tick(5.25 if over else 10.0)
		var b: Dictionary = ph.rigid.bodies[int(ph._rigid_of[ladle])]
		var p9 := _baked(m, ladle, 9.0)
		var p10 := _baked(m, ladle, 10.0)
		res.append([b["held"] != null, p9.origin.distance_to(p10.origin), rad_to_deg(Quaternion(p9.basis.orthonormalized()).angle_to(Quaternion(p10.basis.orthonormalized())))])
		m._root3.free()
	_ok(bool(res[1][0]), "the control: put back 8 cm over its rest, its next move half a second on, the ladle was let go across the pause")
	_ok(not bool(res[0][0]), "put back on its rest as built, the ladle is still held there")
	_ok(float(res[0][1]) < 0.0003 and float(res[0][2]) < 0.3, "on its rest, the ladle moved %.2f mm and turned %.2f degrees in its last second" % [
		float(res[0][1]) * 1000.0, float(res[0][2])])
	return true


const FEATHER_SPEC := {"things": [
	{"name": "gifts", "parts": [
		{"shape": "box", "size": [20, 1, 16], "material": "oak"},
		{"name": "feather", "shape": "sheet", "outline": "feather", "size": [3, 12], "bend": 0.2, "at": [0, 1, 0], "loose": true, "material": "plume"}]}],
	"materials": {"oak": {"kind": "wood", "color": "#6b4a2b"}, "plume": {"kind": "fabric", "color": "#e0501a"}}}


## The lowest of loose work [param wi]'s drawn surface at show time [param t], as the table draws it (meters): its own mesh, posed.
func _drawn_low(m: TableMedium, wi: int, t: float) -> float:
	m._work.tick(t)
	var low := INF
	var node: Node3D = (m._work.works[wi] as Dictionary)["node"]
	var stack: Array = [node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var xf := m._work._world_of(mi)
		for q in mi.mesh.get_faces():
			low = minf(low, (xf * q).y)
	return low


## A SHEET RESTS AT ITS OWN THICKNESS, AND IS HELD UP AS ANYTHING IS (the-quiet-crucible 841899, 2026-10-31: the phoenix feather
## "appears to be floating above the table ... casting too much of a shadow" - its spheres, 3.3 mm, held a feather 0.8 mm thick that
## far up; and, fetched to be held up, it had been dropped on the table as its fetch ended): a feather lifted 6 cm off its board and
## let go comes to rest with its drawn underside within a millimeter of the board; lifted 10 cm and taken up again half a second
## later, it is held up across the pause. The controls: resting on its spheres' own radius it lies more than 2 mm up; with no later move it is let fall.
func _sheet_lies() -> bool:
	var res := {}
	for kind in ["lies", "spheres", "held", "dropped"]:
		var m := _medium()
		_stand(m, FEATHER_SPEC, "gifts", _at(Vector3(0, 0, -8)))
		var up := 10.0 if kind in ["held", "dropped"] else 6.0
		var acts: Array = [{"name": "lift", "beat": 1, "length": 2.0, "tracks": [{"thing": "gifts", "part": "feather", "law": "carry", "by": [0, up, 0], "lift": 0}]}]
		var runs: Array = [{"i": 0, "t0": 2.0, "t1": 4.0}]
		if kind == "held":
			acts.append({"name": "again", "beat": 1, "length": 2.0, "tracks": [{"thing": "gifts", "part": "feather", "law": "carry", "by": [4, 0, 0], "lift": 2}]})
			runs.append({"i": 1, "t0": 4.5, "t1": 6.5})
		m._work.build({"acts": acts}, 1)
		m._work.runs = runs
		m._work._timelines()
		var ph: TablePhysics = m._work.physics
		var fw := _work_of_name(m, "feather")
		if kind == "spheres":
			(ph.loose[int(ph._loose_of[fw])] as Dictionary)["contact"] = 0.0
		var top := 0.01
		res[kind] = _drawn_low(m, fw, 4.25 if kind == "held" else 7.0) - top
		m._root3.free()
	_ok(float(res["spheres"]) > 0.002, "the control: resting on its spheres' radius, the feather lay only %.2f mm over its board" % (float(res["spheres"]) * 1000.0))
	_ok(float(res["lies"]) > -0.0004 and float(res["lies"]) < 0.001, "let fall on its board, the feather's underside lies %.2f mm over it" % (float(res["lies"]) * 1000.0))
	_ok(float(res["dropped"]) < 0.01, "the control: lifted with no later move, the feather was not let fall (%.1f cm up)" % (float(res["dropped"]) * 100.0))
	_ok(float(res["held"]) > 0.07, "lifted 10 cm and taken up again half a second later, the feather fell to %.1f cm across the pause" % (float(res["held"]) * 100.0))
	return true


const SHEET_POT_SPEC := {"things": [
	{"name": "pot", "parts": [{"shape": "lathe", "smooth": true, "material": "iron", "profile": [[0, 0], [3.5, 0], [6.5, 1.5], [8.8, 4.5], [9, 6.5], [8.3, 9.5], [7.8, 10.4],
		[8.4, 10.8, 0], [8.4, 11.2, 0], [7.9, 11.2, 0], [7.5, 10.6], [8, 9.5], [8.6, 6.5], [8.4, 4.5], [6.2, 1.8], [3.3, 0.4], [0, 0.4]]}]},
	{"name": "gifts", "parts": [
		{"name": "feather", "shape": "sheet", "outline": "feather", "size": [3, 12], "bend": 0.2, "at": [0, 0.2, 0], "loose": true, "material": "plume"}]}],
	"materials": {"iron": {"kind": "metal", "color": "#2c2a28"}, "plume": {"kind": "fabric", "color": "#e0501a"}}}


## A SHEET'S WHOLE OUTLINE MEETS THE WORLD ([method Particles.fill_shape], feedback 0010: the feather's tip "clipping through the pot ... a little red
## triangle poking out"): what meets the world is a point at the sheet's own thickness, and past its last point it meets nothing. Its points reach within
## a centimeter of all of it, and let fall into a round pot nothing of it as drawn stands out of the far side of the pot's wall. The control: its grid alone.
func _sheet_tip_in_pot() -> bool:
	var res := {}
	var gap := {}
	for kind in ["outline", "grid"]:
		var m := _medium()
		_stand(m, SHEET_POT_SPEC, "pot", _at(Vector3(0, 0, -8)))
		_stand(m, SHEET_POT_SPEC, "gifts", _at(Vector3(-30, 0, -8)))
		m._work.build({"acts": [{"name": "in", "beat": 1, "length": 2.0, "tracks": [{"thing": "gifts", "part": "feather", "law": "carry", "by": [30, 13, 0], "lift": 6}]}]}, 1)
		m._work.runs = [{"i": 0, "t0": 1.0, "t1": 3.0}]
		m._work._timelines()
		var ph: TablePhysics = m._work.physics
		var fw := _work_of_name(m, "feather")
		var pot := -1
		for li in ph.liquids.size():
			if String((m._work.things[int((ph.solids[int((ph.liquids[li] as Dictionary)["solid"])] as Dictionary)["thing"])] as Dictionary)["name"]) == "pot":
				pot = li
		var L: Dictionary = ph.loose[int(ph._loose_of[fw])]
		var spheres: PackedVector3Array = L["spheres"]
		_ok(spheres.size() <= Particles.SOFT_MOST, "%s: a sheet is made of %d points, at most %d" % [kind, spheres.size(), Particles.SOFT_MOST])
		if kind == "grid":
			spheres = spheres.slice(0, spheres.size() - Particles.SHEET_REACHES)
			L["spheres"] = spheres
		gap[kind] = _farthest_from(m, fw, spheres)
		var worst := 0.0
		for t in [5.0, 6.0, 7.0, 8.0]:
			worst = maxf(worst, _past_wall(m, fw, ph, pot, t))
		res[kind] = worst
		m._root3.free()
	_ok(float(gap["grid"]) > 0.011, "the control: on its grid alone, part of the feather lies %.1f cm from anything that meets the world" % (float(gap["grid"]) * 100.0))
	_ok(float(gap["outline"]) < 0.0105, "with its outline, no part of the feather lies over %.1f cm from a point that meets the world" % (float(gap["outline"]) * 100.0))
	_ok(float(res["grid"]) > 0.003, "the control: on its grid alone the feather stands only %.1f mm out of the far side of the pot's wall" % (float(res["grid"]) * 1000.0))
	_ok(float(res["outline"]) < 0.0005, "let fall in a round pot, the feather stands %.1f mm out of the far side of its wall" % (float(res["outline"]) * 1000.0))
	return true


## The farthest any of work [param wi]'s drawn surface lies from the nearest of [param spheres], all as built (meters).
func _farthest_from(m: TableMedium, wi: int, spheres: PackedVector3Array) -> float:
	var far := 0.0
	var stack: Array = [(m._work.works[wi] as Dictionary)["node"]]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var xf := m._work._world_of(mi)
		for q in mi.mesh.get_faces():
			var p := xf * q
			var near := INF
			for c in spheres:
				near = minf(near, p.distance_to(c))
			far = maxf(far, near)
	return far


## How far out of the far side of liquid [param li]'s vessel's wall loose work [param wi]'s drawn surface stands at show time [param t] (meters): what is seen from outside - under its
## rim, out of its inside and out of the wall too. In the wall itself it is hidden.
func _past_wall(m: TableMedium, wi: int, ph: TablePhysics, li: int, t: float) -> float:
	m._work.tick(t)
	var sd: Dictionary = ph.solids[int((ph.liquids[li] as Dictionary)["solid"])]
	var vs: Vessel = (ph.liquids[li] as Dictionary)["vessel"]
	var field: ShapeField = sd["field"]
	var inv: Transform3D = (sd["xf"] as Transform3D).affine_inverse()
	var worst := 0.0
	var stack: Array = [(m._work.works[wi] as Dictionary)["node"]]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var xf := m._work._world_of(mi)
		for q in mi.mesh.get_faces():
			var p := inv * (xf * q)
			if p.y < vs.top_y and not vs.contains(p):
				worst = maxf(worst, field.sample(p).x)
	return worst


const BREW_SPEC := {"things": [
	{"name": "pot", "parts": [
		{"name": "cauldron", "shape": "lathe", "smooth": true, "material": "iron", "at": [0, 4.5, 0], "points": {"mouth": [0, 12.9, 0]}, "profile": [[0, 0], [3.5, 0], [6.5, 1.5], [8.8, 4.5], [9, 6.5], [8.3, 9.5],
			[7.8, 10.4], [8.4, 10.8, 0], [8.4, 11.2, 0], [7.9, 11.2, 0], [7.5, 10.6], [8, 9.5], [8.6, 6.5], [8.4, 4.5], [6.2, 1.8], [3.3, 0.4], [0, 0.4]]},
		{"name": "brew", "shape": "lathe", "smooth": true, "material": "brew", "at": [0, 4.9, 0], "profile": [[0, 0], [3.3, 0], [6.2, 1.4], [8.4, 4.1], [8.6, 6.1], [8.15, 8, 0], [0, 8]]}]},
	{"name": "the ladle on its rest", "parts": [
		{"material": "oak", "round": 0.4, "shape": "box", "size": [24.0, 1.2, 7.0]},
		{"at": [9.5, 1.2, 0.0], "material": "oak", "round": 0.5, "shape": "box", "size": [3.0, 2.5, 6.0]},
		{"joint": {"kind": "free"}, "name": "ladle", "points": {"bowl": [-6.0, 2.2, 0.0], "grip": [11.0, 4.1, 0.0]}, "parts": [
			{"at": [-6.0, 1.2, 0.0], "material": "iron", "shape": "lathe", "smooth": true, "profile": [[0.0, 0.0], [1.5, 0.0], [2.8, 0.8],
				[3.2, 2.0], [3.3, 2.8, 0.0], [3.0, 2.8, 0.0], [2.9, 2.0], [2.5, 0.95], [1.3, 0.35], [0.0, 0.35]]},
			{"material": "iron", "radius": 0.35, "shape": "tube", "path": [[-2.9, 3.85, 0.0], [2.0, 4.0, 0.0], [9.5, 4.05, 0.0], [12.6, 4.2, 0.0], [13.4, 3.3, 0.0]]}]}]}],
	"materials": {"oak": {"kind": "wood", "color": "#6b4a2b"}, "iron": {"kind": "metal", "color": "#6a4a30"}, "brew": {"kind": "liquid", "color": "#b8964a"}}}


## LIQUID IS NEVER LOST ([method TablePhysics._dips], feedback 0009, 0011: "Every time I've seen the ladle go into the pot, the liquid level decreases ... The
## amount of liquid never recovers"): 841899's own ladle and cauldron, with the show's own act - lowered in, tipped, let go to lean on the wall, drawn out and laid
## back on its rest. A vessel partly under a liquid has that liquid's surface: it stands as high inside as out, and neither sloshes nor pours. Through all of it the
## brew and the ladle together hold what the brew began with, the surface never falls for what goes in, nothing is spilled, and the ladle gone, the brew is back
## where it began.
func _brew_kept() -> bool:
	var m := _medium()
	_stand(m, BREW_SPEC, "the ladle on its rest", _at(Vector3(-25, 0, -8)))
	_stand(m, BREW_SPEC, "pot", _at(Vector3(15, 0, -8)))
	m._work.build({"acts": [{"name": "in", "beat": 1, "length": 3.0, "tracks": [{"thing": "the ladle on its rest", "part": "ladle", "law": "carry", "to": "pot.mouth", "by": [0, 7, 0], "lift": 12, "turn": [0, 0, 75]}]},
		{"name": "back", "beat": 1, "length": 3.0, "tracks": [{"thing": "the ladle on its rest", "part": "ladle", "law": "carry", "lift": 6, "down": true}]}]}, 1)
	m._work.runs = [{"i": 0, "t0": 1.0, "t1": 4.0}, {"i": 1, "t0": 12.0, "t1": 15.0}]
	m._work._timelines()
	var ph: TablePhysics = m._work.physics
	var ladle := _work_of_name(m, "ladle")
	var brew := _liquid(m, "pot")
	var bowl := -1
	for li in ph.liquids.size():
		if m._work._within(int((ph.solids[int((ph.liquids[li] as Dictionary)["solid"])] as Dictionary)["wi"]), ladle) == 1:
			bowl = li
	_ok(brew >= 0 and bowl >= 0, "the pot has no brew, or the ladle no bowl")
	if brew < 0 or bowl < 0:
		m._root3.free()
		return true
	m._work.tick(19.0)
	var start := _volume(m, brew, 0.5)
	var surface0 := float((ph.frame_at(0.5) as Dictionary)["liq"][brew * 16 + 5])
	var lost := 0.0
	var fell := 0.0
	var surface_out := 0.0
	var worst_at := 0.0
	for k in 56:
		var t := 0.5 + float(k) * 1.0 / 3.0
		var flown := 0.0
		for pd in ph.parcels:
			var pp: Dictionary = pd
			if float(pp["t0"]) <= t and (float(pp["t1"]) > t or int(pp["into"]) == -1):
				flown += float(pp["vol"])
		var whole := _volume(m, brew, t) + _volume(m, bowl, t) + flown
		if absf(whole - start) > lost:
			lost = absf(whole - start)
			worst_at = t
		if t < 12.0:
			fell = maxf(fell, surface0 - float((ph.frame_at(t) as Dictionary)["liq"][brew * 16 + 5]))
		elif t > 16.0:
			surface_out = maxf(surface_out, surface0 - float((ph.frame_at(t) as Dictionary)["liq"][brew * 16 + 5]))
	var spilled := 0.0
	for pd in ph.parcels:
		if int((pd as Dictionary)["into"]) == -1:
			spilled += float((pd as Dictionary)["vol"])
	var end := _volume(m, brew, 18.9)
	var bowl_end := _volume(m, bowl, 18.9)
	print("  the brew began at %.1f ml, ended at %.1f; the ladle ended with %.1f; %.1f ml spilled; its surface fell %.1f mm at most with the ladle in, %.1f mm with it out" % [start * 1e6, end * 1e6, bowl_end * 1e6, spilled * 1e6, fell * 1000.0, surface_out * 1000.0])
	_ok(lost < 1e-6, "the brew, the ladle and what is in the air differ by %.1f ml from what the brew began with (at %.1f s)" % [lost * 1e6, worst_at])
	_ok(spilled < 0.01 * start, "%.1f ml of %.1f was spilled from a ladle lifted out of its pot" % [spilled * 1e6, start * 1e6])
	_ok(fell < 0.0005, "as the ladle went in and leaned there, the brew's surface fell %.1f mm" % (fell * 1000.0))
	_ok(surface_out < 0.003, "the ladle out with what it held, the brew's surface fell %.1f mm for the %.1f ml gone" % [surface_out * 1000.0, (start - end) * 1e6])
	# THE LEVEL HAS NO STAIRS: the cauldron's cells are about a centimeter tall, and no percent of it moves the surface more than a percent should
	var vs: Vessel = (ph.liquids[brew] as Dictionary)["vessel"]
	var stair := 0.0
	var bare := 0.0
	var heights := PackedFloat32Array()
	for q in vs.points:
		heights.append(q.y)
	heights.sort()
	for k in range(10, 90):
		stair = maxf(stair, vs.level(Vector3.UP, float(k + 1) * 0.01) - vs.level(Vector3.UP, float(k) * 0.01))
		var at0 := int(float(k) * 0.01 * float(heights.size() - 1))
		var at1 := int(float(k + 1) * 0.01 * float(heights.size() - 1))
		bare = maxf(bare, heights[at1] - heights[at0])
	_ok(bare > 0.005, "the control: the bare grid's level moves %.1f mm in a percent" % (bare * 1000.0))
	_ok(stair < 0.0025, "a percent of the brew moves its surface %.1f mm at most (no stairs)" % (stair * 1000.0))
	m._root3.free()
	# ...AND WHAT TRULY MISSES IS COUNTED, the sum still holding: the control - the pot itself turned over above the bare table
	var c := _medium()
	_stand(c, BREW_SPEC, "pot", _at(Vector3(15, 0, -8)))
	c._work.build({"acts": [{"name": "over", "beat": 1, "length": 3.0, "tracks": [{"thing": "pot", "law": "path", "jitter": 0.0, "keys": [{"at": 0.0}, {"at": 0.4, "by": [0, 20, 0]}, {"at": 1.0, "by": [0, 20, 0], "turn": [0, 0, 110]}]}]}]}, 1)
	c._work.runs = [{"i": 0, "t0": 1.0, "t1": 4.0}]
	c._work._timelines()
	var cp: TablePhysics = c._work.physics
	c._work.tick(5.0)
	var off := 0.0
	var in_air := 0.0
	for pd in cp.parcels:
		var pp: Dictionary = pd
		if float(pp["t0"]) <= 5.0 and (int(pp["into"]) == -1 or float(pp["t1"]) > 5.0):
			if int(pp["into"]) == -1:
				off += float(pp["vol"])
			else:
				in_air += float(pp["vol"])
	var left := _volume(c, _liquid(c, "pot"), 4.99)
	_ok(off > 100e-6, "the control: the pot turned over spilled only %.1f ml" % (off * 1e6))
	_ok(absf(left + off + in_air - _volume(c, _liquid(c, "pot"), 0.5)) < 30e-6, "the pot turned over: %.1f ml left, %.1f spilled, %.1f in the air, of %.1f" % [left * 1e6, off * 1e6, in_air * 1e6, _volume(c, _liquid(c, "pot"), 0.5) * 1e6])
	c._root3.free()
	return true


const FLOAT_SPEC := {"things": [
	{"name": "pot", "parts": [
		{"shape": "lathe", "smooth": true, "material": "iron", "points": {"mouth": [0, 9, 0]}, "profile": [[0, 0], [11, 0], [13, 3], [13.4, 8], [12, 12], [12.6, 12.4, 0], [12.2, 12.6, 0], [11.4, 12], [12.8, 8], [12.4, 3], [10.6, 0.5], [0, 0.5]]},
		{"name": "brew", "shape": "lathe", "smooth": true, "material": "brew", "start": {"boil": 0.2}, "profile": [[0, 0.5], [10.6, 0.5], [12.4, 3], [12.8, 8], [12.5, 9], [0, 9]]}]},
	{"name": "gifts", "parts": [
		{"name": "feather", "shape": "sheet", "outline": "feather", "size": [3, 12], "bend": 0.2, "at": [0, 0.2, 0], "loose": true, "material": "plume"},
		{"name": "stone", "shape": "ball", "size": [3, 2.4, 3], "at": [0, 0, 12], "loose": true, "material": "rock"},
		{"name": "plate", "shape": "sheet", "outline": "feather", "size": [3, 12], "at": [12, 0.2, 0], "loose": true, "material": "tin"}]},
	{"name": "rod", "parts": [{"material": "iron", "shape": "tube", "radius": 0.35, "path": [[0, 0, 0], [0, 20, 0]]}]},
	{"name": "the ladle on its rest", "parts": [
		{"material": "oak", "round": 0.4, "shape": "box", "size": [24.0, 1.2, 7.0]},
		{"at": [9.5, 1.2, 0.0], "material": "oak", "round": 0.5, "shape": "box", "size": [3.0, 2.5, 6.0]},
		{"joint": {"kind": "free"}, "name": "ladle", "points": {"bowl": [-6.0, 2.2, 0.0], "grip": [11.0, 4.1, 0.0]}, "parts": [
			{"at": [-6.0, 1.2, 0.0], "material": "iron", "shape": "lathe", "smooth": true, "profile": [[0.0, 0.0], [1.5, 0.0], [2.8, 0.8], [3.2, 2.0], [3.3, 2.8, 0.0], [3.0, 2.8, 0.0], [2.9, 2.0], [2.5, 0.95], [1.3, 0.35], [0.0, 0.35]]},
			{"material": "iron", "radius": 0.35, "shape": "tube", "path": [[-2.9, 3.85, 0.0], [2.0, 4.0, 0.0], [9.5, 4.05, 0.0], [12.6, 4.2, 0.0], [13.4, 3.3, 0.0]]}]}]}],
	"materials": {"iron": {"kind": "metal", "color": "#6a4a30"}, "brew": {"kind": "liquid", "color": "#b8964a"}, "plume": {"kind": "fabric", "color": "#e0501a"}, "oak": {"kind": "wood", "color": "#6b4a2b"},
		"rock": {"kind": "stone", "color": "#555555"}, "tin": {"kind": "metal", "color": "#999999", "density": 0.4}}}


## How many of [param frames] moments the rod's axis (from its foot, 20 cm up) passes through loose work [param wi]'s drawn surface, as the table draws both.
func _rod_through(m: TableMedium, wi: int, ph: TablePhysics, rod_key: int, moments: Array) -> int:
	var count := 0
	for t in moments:
		m._work.tick(float(t))
		var pose: Variant = ph.pose_of(rod_key, float(t))
		if pose == null:
			continue
		var foot: Vector3 = (pose as Transform3D).origin
		var head: Vector3 = (pose as Transform3D) * Vector3(0, 0.2, 0)
		var stack: Array = [(m._work.works[wi] as Dictionary)["node"]]
		var hit := false
		while not stack.is_empty() and not hit:
			var n: Node = stack.pop_back()
			stack.append_array(n.get_children())
			var mi := n as MeshInstance3D
			if mi == null or mi.mesh == null:
				continue
			var xf := m._work._world_of(mi)
			var faces := mi.mesh.get_faces()
			for k in range(0, faces.size() - 2, 3):
				if Geometry3D.segment_intersects_triangle(foot, head, xf * faces[k], xf * faces[k + 1], xf * faces[k + 2]) != null:
					hit = true
					break
		if hit:
			count += 1
	return count


## A SHEET BENDS ROUND WHAT MEETS IT, GENTLY ([method Particles.make_soft], [SheetBend]; 841899, feedback 0012: "The phoenix feather is clipping through the ladle ... The feather should
## probably be more deformable, so that it's able to wrap and contort around the ladle ... gently enough that it doesn't create a whiplash effect and spring the feather out of the liquid"):
## a feather afloat, a 7 mm rod brought down across its middle and swept through it: the rod hardly ever stands through what is drawn; what is drawn bends, the points about the
## rod off their own shape by millimeters and the mesh with them; nothing is thrown out of the liquid; and left alone again, it lies back. The controls: met only at its points' own
## thickness, as it had been, a rod fits between them; and the rod did move it.
func _sheet_bends_round() -> bool:
	var m := _medium()
	_stand(m, FLOAT_SPEC, "pot", _at(Vector3(0, 0, -8)))
	_stand(m, FLOAT_SPEC, "gifts", _at(Vector3(-40, 0, -8)))
	_stand(m, FLOAT_SPEC, "rod", _at(Vector3(40, 0, -8)))
	m._work.build({"acts": [
		{"name": "in", "beat": 1, "length": 3.0, "tracks": [{"thing": "gifts", "part": "feather", "law": "path", "jitter": 0.0, "keys": [{"at": 0.0}, {"at": 0.3, "by": [0, 22, 0]}, {"at": 0.75, "by": [40, 22, 0]}, {"at": 1.0, "by": [40, 13, 0]}]}]},
		{"name": "over", "beat": 1, "length": 2.0, "tracks": [{"thing": "rod", "law": "path", "jitter": 0.0, "keys": [{"at": 0.0}, {"at": 0.3, "by": [0, 16, 0]}, {"at": 1.0, "by": [-49, 16, 0]}]}]},
		{"name": "sweep", "beat": 1, "length": 6.0, "tracks": [{"thing": "rod", "law": "path", "jitter": 0.0, "keys": [{"at": 0.0}, {"at": 0.25, "by": [0, -13, 0]}, {"at": 1.0, "by": [18, -13, 0]}]}]},
		{"name": "out", "beat": 1, "length": 2.0, "tracks": [{"thing": "rod", "law": "path", "jitter": 0.0, "keys": [{"at": 0.0}, {"at": 1.0, "by": [0, 16, 0]}]}]}]}, 1)
	m._work.runs = [{"i": 0, "t0": 1.0, "t1": 4.0}, {"i": 1, "t0": 8.0, "t1": 10.0}, {"i": 2, "t0": 10.0, "t1": 16.0}, {"i": 3, "t0": 16.0, "t1": 18.0}]
	m._work._timelines()
	var ph: TablePhysics = m._work.physics
	var wi := _work_of_name(m, "feather")
	var plate := _work_of_name(m, "plate")
	var rod_key := -1 - int(m._work._thing_named("rod"))
	_ok(ph.bends(wi) and not ph.bends(plate), "a feather bends, and a plate of tin of its shape does not")
	var rod_thin := false
	for sd in ph.solids:
		if int((sd as Dictionary)["thing"]) == int(m._work._thing_named("rod")):
			rod_thin = rod_thin or bool((sd as Dictionary)["thin"])
		_ok(not (bool((sd as Dictionary)["thin"]) and String((m._work.things[int((sd as Dictionary)["thing"])] as Dictionary)["name"]) == "pot"), "a pot is no thin tool")
	_ok(rod_thin, "a rod is a thin tool")
	# ...THE ROD CANNOT STAND BETWEEN ITS POINTS: every part of it nearer a point than the rod's radius and the point's whole. The control: at the point's own thickness, as it had been, it can.
	var pts: PackedVector3Array = ph.sheet_points(wi)
	var far := _farthest_from(m, wi, pts)
	var L: Dictionary = ph.loose[int(ph._loose_of[wi])]
	var rod_r := 0.0035
	_ok(far < float(L["rad"]) + rod_r, "part of the feather lies %.1f mm from any point: a %.0f mm rod goes between them, met at %.1f mm" % [far * 1000.0, rod_r * 2000.0, float(L["rad"]) * 1000.0])
	_ok(far > float(L["contact"]) + rod_r, "the control: met at its own thickness, a rod would not go between the feather's points (%.1f mm from one at most)" % (far * 1000.0))
	var moments: Array = []
	for k in 45:
		moments.append(11.5 + float(k) * 0.1)
	m._work.tick(30.0)
	var through := _rod_through(m, wi, ph, rod_key, moments)
	var most := 0.0
	var fastest := 0.0
	var highest := 0.0
	var was := PackedVector3Array()
	var level := float((ph.frame_at(9.0) as Dictionary)["liq"][_liquid(m, "pot") * 16 + 5])
	var t := 10.0
	while t < 19.0:
		var off: PackedVector3Array = ph.bend_of(wi, t)
		for q in off:
			most = maxf(most, q.length())
		var motion: Transform3D = (ph.pose_of(wi, t) as Transform3D) * ph.loose_built(wi).affine_inverse()
		var now := PackedVector3Array()
		for k in pts.size():
			now.append(motion * (pts[k] + off[k]))
			highest = maxf(highest, now[k].y - level)
			if not was.is_empty():
				fastest = maxf(fastest, now[k].distance_to(was[k]) * 30.0)
		was = now
		t += 1.0 / 30.0
	var after := 0.0
	for q in (ph.bend_of(wi, 29.0) as PackedVector3Array):
		after = maxf(after, q.length())
	print("  the rod through the feather at %d of %d moments, bent %.1f mm at most, %.1f mm left after, fastest point %.1f cm/s, %.1f cm over the surface at most" % [through, moments.size(), most * 1000.0, after * 1000.0, fastest * 100.0, highest * 100.0])
	_ok(through <= 2, "the rod stood through the feather as drawn at %d of %d moments" % [through, moments.size()])
	_ok(most > 0.004, "met by the rod, the feather bent only %.1f mm" % (most * 1000.0))
	_ok(fastest > 0.02, "the control: the feather was hardly moved, %.1f cm a second at most" % (fastest * 100.0))
	_ok(fastest < 0.16, "the feather's fastest point went %.1f cm a second, the rod 8: a whip" % (fastest * 100.0))
	_ok(highest < 0.012, "the feather was thrown %.1f cm over the surface" % (highest * 100.0))
	_ok(after < maxf(most * 0.5, 0.004), "left alone 11 s, the feather is still bent %.1f mm of its %.1f" % [after * 1000.0, most * 1000.0])
	m._root3.free()
	return true


## A FLOATING THING IS NEVER STILL ([method Particles.current], [method Particles.swell]; 841899, feedback 0012: "it floats perfectly stable on top of the liquid ... it should be gently moving,
## according to the movement of the liquid and the weight of the object ... sometimes bob ... maybe spin a bit"): a feather afloat in a simmering pot, nothing near it, for half a minute:
## it drifts, turns and bobs, never fast, never out of the pot, never asleep - and the same moment of the same bake is the same pose. The control: a stone on the same pot's floor lies still.
func _floater_lives() -> bool:
	var m := _medium()
	_stand(m, FLOAT_SPEC, "pot", _at(Vector3(0, 0, -8)))
	_stand(m, FLOAT_SPEC, "gifts", _at(Vector3(-40, 0, -8)))
	m._work.build({"acts": [
		{"name": "in", "beat": 1, "length": 3.0, "tracks": [{"thing": "gifts", "part": "feather", "law": "path", "jitter": 0.0, "keys": [{"at": 0.0}, {"at": 0.3, "by": [0, 22, 0]}, {"at": 0.75, "by": [40, 22, 0]}, {"at": 1.0, "by": [40, 13, 0]}]}]},
		{"name": "drop", "beat": 1, "length": 3.0, "tracks": [{"thing": "gifts", "part": "stone", "law": "path", "jitter": 0.0, "keys": [{"at": 0.0}, {"at": 0.3, "by": [0, 22, 0]}, {"at": 0.75, "by": [40, 22, -12]}, {"at": 1.0, "by": [46, 13, -12]}]}]}]}, 1)
	m._work.runs = [{"i": 0, "t0": 1.0, "t1": 4.0}, {"i": 1, "t0": 4.0, "t1": 7.0}]
	m._work._timelines()
	var ph: TablePhysics = m._work.physics
	var wi := _work_of_name(m, "feather")
	var stone := _work_of_name(m, "stone")
	var water := _liquid(m, "pot")
	var vs: Vessel = (ph.liquids[water] as Dictionary)["vessel"]
	var inv: Transform3D = (ph.solids[int((ph.liquids[water] as Dictionary)["solid"])] as Dictionary)["inv"]
	m._work.tick(45.0)
	var t := 15.0
	var a: Transform3D = ph.pose_of(wi, t)
	var far := 0.0
	var turned := 0.0
	var low := INF
	var high := -INF
	var fastest := 0.0
	var out := 0
	var was := a
	while t < 45.0:
		var x: Transform3D = ph.pose_of(wi, t)
		far = maxf(far, x.origin.distance_to(a.origin))
		turned = maxf(turned, rad_to_deg(Quaternion(a.basis.orthonormalized()).angle_to(Quaternion(x.basis.orthonormalized()))))
		low = minf(low, x.origin.y)
		high = maxf(high, x.origin.y)
		fastest = maxf(fastest, x.origin.distance_to(was.origin) * 30.0)
		var mid := x * (ph.loose_built(wi).affine_inverse() * _sheet_middle(ph, wi))
		if not vs.contains(inv * mid):
			out += 1
		was = x
		t += 1.0 / 30.0
	var s0: Variant = ph.pose_of(stone, 20.0)
	var s1: Variant = ph.pose_of(stone, 44.0)
	var stone_moved := (s0 as Transform3D).origin.distance_to((s1 as Transform3D).origin) if s0 != null and s1 != null else 0.0
	var again: Transform3D = ph.pose_of(wi, 30.0)
	var bi := int((ph.loose[int(ph._loose_of[wi])] as Dictionary)["body"])
	print("  over 30 s afloat: drifted %.1f cm, turned %.0f degrees, bobbed %.1f mm, %.1f cm/s at most; the stone moved %.2f mm" % [far * 100.0, turned, (high - low) * 1000.0, fastest * 100.0, stone_moved * 1000.0])
	_ok(far > 0.01, "afloat 30 s, the feather drifted only %.1f cm" % (far * 100.0))
	_ok(turned > 5.0, "afloat 30 s, the feather turned only %.0f degrees" % turned)
	_ok(high - low > 0.0004, "afloat 30 s, the feather bobbed only %.2f mm" % ((high - low) * 1000.0))
	_ok(fastest < 0.06, "left alone, the feather went %.1f cm a second" % (fastest * 100.0))
	_ok(out == 0, "the feather's middle left the pot at %d frames" % out)
	_ok(bi >= 0 and not ph.sim.body_asleep(bi), "the feather fell asleep afloat")
	_ok(stone_moved < 0.002, "the control: the stone on the floor moved %.1f mm" % (stone_moved * 1000.0))
	_ok(again.is_equal_approx(ph.pose_of(wi, 30.0)), "the same moment asked twice is another pose")
	m._root3.free()
	return true


## A VESSEL DOES NOT TAKE PART OF A SHEET WITH IT (841899: part of the feather in the ladle's bowl rode off with the ladle, the rest left in the pot, stretched 23 cm): a feather afloat, the
## ladle lowered through where it is, tipped, and drawn away over the rim: it stays one sheet, and in the pot. The control: the ladle met it.
func _sheet_stays_whole() -> bool:
	# ...where the feather has drifted to by the time the ladle comes, the same bake without it
	var feather_in := {"name": "in", "beat": 1, "length": 3.0, "tracks": [{"thing": "gifts", "part": "feather", "law": "path", "jitter": 0.0, "keys": [{"at": 0.0}, {"at": 0.3, "by": [0, 22, 0]}, {"at": 0.75, "by": [40, 22, 0]}, {"at": 1.0, "by": [40, 13, 0]}]}]}
	var a := _medium()
	_stand(a, FLOAT_SPEC, "pot", _at(Vector3(0, 0, -8)))
	_stand(a, FLOAT_SPEC, "gifts", _at(Vector3(-40, 0, -8)))
	a._work.build({"acts": [feather_in]}, 1)
	a._work.runs = [{"i": 0, "t0": 1.0, "t1": 4.0}]
	a._work._timelines()
	a._work.tick(9.0)
	var ap: TablePhysics = a._work.physics
	var aw := _work_of_name(a, "feather")
	var there: Vector3 = (ap.pose_of(aw, 8.5) as Transform3D) * (ap.loose_built(aw).affine_inverse() * _sheet_middle(ap, aw))
	a._root3.free()
	var m := _medium()
	_stand(m, FLOAT_SPEC, "pot", _at(Vector3(0, 0, -8)))
	_stand(m, FLOAT_SPEC, "gifts", _at(Vector3(-40, 0, -8)))
	_stand(m, FLOAT_SPEC, "the ladle on its rest", _at(Vector3(40, 0, -8)))
	# ...as the show's own acts have it: lowered in under it, tipped, drawn out and laid back on its rest
	m._work.build({"acts": [feather_in,
		{"name": "under", "beat": 1, "length": 3.0, "tracks": [{"thing": "the ladle on its rest", "part": "ladle", "law": "carry", "to": [there.x * 100.0, 16.0, there.z * 100.0], "lift": 12, "turn": [0, 0, 75]}]},
		{"name": "away", "beat": 1, "length": 3.0, "tracks": [{"thing": "the ladle on its rest", "part": "ladle", "law": "carry", "lift": 6, "down": true}]}]}, 1)
	m._work.runs = [{"i": 0, "t0": 1.0, "t1": 4.0}, {"i": 1, "t0": 6.0, "t1": 9.0}, {"i": 2, "t0": 10.0, "t1": 13.0}]
	m._work._timelines()
	var ph: TablePhysics = m._work.physics
	var wi := _work_of_name(m, "feather")
	m._work.tick(18.0)
	_ok(ph.bends(wi), "the feather is no sheet that bends")
	var most := 0.0
	var t := 6.0
	while t < 18.0:
		for q in (ph.bend_of(wi, t) as PackedVector3Array):
			most = maxf(most, q.length())
		t += 0.1
	var water := _liquid(m, "pot")
	var vs: Vessel = (ph.liquids[water] as Dictionary)["vessel"]
	var inv: Transform3D = (ph.solids[int((ph.liquids[water] as Dictionary)["solid"])] as Dictionary)["inv"]
	var end: Transform3D = ph.pose_of(wi, 17.9)
	var mid := end * (ph.loose_built(wi).affine_inverse() * _sheet_middle(ph, wi))
	print("  the ladle lowered through it and drawn away, the feather stood %.1f cm from its shape at most, its middle %s" % [most * 100.0, str(mid * 100.0)])
	_ok(most > 0.004, "the control: the ladle never met the feather (%.1f mm)" % (most * 1000.0))
	_ok(most < 0.06, "the ladle drawn away pulled part of the feather %.1f cm out of shape" % (most * 100.0))
	_ok(vs.contains(inv * mid), "the ladle took the feather with it, to %s" % str(mid * 100.0))
	m._root3.free()
	return true


## Sheet [param wi]'s middle as it was built (the table's space).
func _sheet_middle(ph: TablePhysics, wi: int) -> Vector3:
	var c := Vector3.ZERO
	var pts: PackedVector3Array = ph.sheet_points(wi)
	for p in pts:
		c += p
	return c / float(pts.size())


## THE PAST IS BAKED (the-quiet-crucible 841899, 2026-10-31, scrubbed to the feather: "it totally breaks physics, every time ...
## there is a piece of some ingredient sitting on top of the recipe card"): a reading started mid-way places its earlier words
## just before 0, spaced as estimated ([member ReadingFollower.near_past]), and a stone an act carried into a bowl before then
## lies in the bowl on the first frame - the bake begun before the act ([member TablePhysics._t0]). The controls: a follower that
## keeps its past long ago places it 100000 s back; and the same act after 0 has not yet moved the stone.
func _past_baked() -> bool:
	var f := ReadingFollower.new()
	f.near_past = true
	f.reset(PackedStringArray(["one", "two", "three", "four", "five"]), 3, PackedFloat32Array([0.0, 0.5, 1.0, 1.5, 2.0]))
	_ok(absf(f.st1[2] + ReadingFollower.PAST_GAP) < 1e-4 and absf(f.st0[0] - (f.st0[2] - 1.0)) < 1e-4,
		"a mid-way start's past near 0 ends at %.2f s (not -%.1f), its first word %.2f s before its last" % [f.st1[2], ReadingFollower.PAST_GAP, f.st0[2] - f.st0[0]])
	var g := ReadingFollower.new()
	g.reset(PackedStringArray(["one", "two", "three", "four", "five"]), 3, PackedFloat32Array([0.0, 0.5, 1.0, 1.5, 2.0]))
	_ok(g.st0[0] < -1000.0, "the control: a follower keeping its past long ago placed it at %.1f s" % g.st0[0])
	var res: Array = []
	for t0 in [-8.0, 4.0]:
		var m := _medium()
		_stand(m, FILINGS_SPEC, "bowl", _at(Vector3(-5, 0, -10)))
		var dish: Node3D = _stand(m, FILINGS_SPEC, "dish", _at(Vector3(-30, 0, -10)))["node"]
		m._work.build({"acts": [{"name": "drop-stone", "beat": 1, "length": 3, "tracks": [
			{"thing": "dish", "part": "stone", "law": "carry", "to": [-5, 6.0, -10], "lift": 4, "between": [0.0, 0.6]}]}]}, 1)
		m._work.runs = [{"i": 0, "t0": t0, "t1": t0 + 3.0}]
		m._work._timelines()
		var ph: TablePhysics = m._work.physics
		var stone := _work_of_name(m, "stone")
		m._work.tick(0.5)
		var node: Node3D = (m._work.works[stone] as Dictionary)["node"]
		var at := m._work._world_of(node) * (((m._work.works[stone] as Dictionary)["w"] as Dictionary).get("middle", Vector3.ZERO) as Vector3)
		res.append([at, ph._t0, dish])
		m._root3.free()
	var bowl := _at(Vector3(-5, 0, -10))
	var past: Vector3 = res[0][0]
	_ok(float(res[0][1]) <= -8.0, "the bake of a past act at -8 s began at %.1f s" % float(res[0][1]))
	_ok(Vector2(past.x - bowl.x, past.z - bowl.z).length() < 0.06 and past.y < 0.04,
		"carried into the bowl before the show began, the stone lies at %s cm on the first frame, not in the bowl at %s" % [str(past * 100.0), str(bowl * 100.0)])
	var later: Vector3 = res[1][0]
	_ok(Vector2(later.x - bowl.x, later.z - bowl.z).length() > 0.15, "the control: the stone an act takes at 4 s was already in the bowl at 0.5 s")
	return true


const RIM_SPEC := {"things": [
	{"name": "cauldron", "parts": [
		{"at": [0.0, 4.5, 0.0], "material": "copper", "shape": "lathe", "smooth": true, "profile": [[0.0, 0.0], [3.5, 0.0], [6.5, 1.5], [8.8, 4.5],
			[9.0, 6.5], [8.3, 9.5], [7.8, 10.4], [8.4, 10.8, 0.0], [8.4, 11.2, 0.0], [7.9, 11.2, 0.0], [7.5, 10.6], [8.0, 9.5], [8.6, 6.5], [8.4, 4.5],
			[6.2, 1.8], [3.3, 0.4], [0.0, 0.4]]},
		{"shape": "box", "size": [4, 4.5, 4], "material": "copper"}]}],
	"materials": {"copper": {"kind": "metal", "color": "#b06a3a"}}}


## WHAT RESTS TOUCHES WHAT IT RESTS ON, AS DRAWN (the user, 2026-10-31: the ladle "doesn't seem to rest upon the cauldron's lip
## correctly. It floats above the lip, and you can tell because it casts a shadow" - met at 120 points of its own and 200 of the
## pot's, a handle crossing the rim between them stood 2.2 mm into it as drawn while its points said 0.4, [method RigidParts._refined]):
## 841899's own ladle, brought into 841899's own cauldron by its two ends and left there till a later act, leans on the rim with
## its drawn surface within 0.8 mm of the pot's, neither floating nor sunk. The control: the same ladle drawn 3 mm lower reads
## sunk - the measure can tell.
func _rests_on_rim() -> bool:
	var m := _medium()
	_stand(m, RIM_SPEC, "cauldron", _at(Vector3(20, 0, -8)))
	_stand(m, REST_SPEC, "the ladle on its rest", _at(Vector3(-15, 0, -8)))
	var grip := [{"at": 0.0, "by": [0.0, 0.0, 0.0]}, {"at": 0.15, "by": [0.0, 6.0, 0.0]}, {"at": 0.65, "by": [27.0, 24.0, 0.0]}, {"at": 1.0, "by": [27.0, 16.0, 0.0]}]
	var tip := [{"at": 0.0, "by": [0.0, 0.0, 0.0]}, {"at": 0.15, "by": [0.0, 6.0, 0.0]}, {"at": 0.65, "by": [43.0, 16.0, 0.0]}, {"at": 1.0, "by": [43.0, 6.5, 0.0]}]
	m._work.build({"acts": [{"name": "in", "beat": 1, "length": 4.0, "tracks": [{"thing": "the ladle on its rest", "part": "ladle", "law": "aim",
			"grip": {"point": "grip", "keys": grip}, "tip": {"point": "bowl", "keys": tip}}]},
		{"name": "again", "beat": 1, "length": 2.0, "tracks": [{"thing": "the ladle on its rest", "part": "ladle", "law": "path", "jitter": 0.0,
			"keys": [{"at": 0.0}, {"at": 1.0, "by": [0, 8, 0]}]}]}]}, 1)
	m._work.runs = [{"i": 0, "t0": 2.0, "t1": 6.0}, {"i": 1, "t0": 16.0, "t1": 18.0}]
	m._work._timelines()
	var ph: TablePhysics = m._work.physics
	var ladle := _work_of_name(m, "ladle")
	var pot: Dictionary = {}
	for sd in ph.solids:
		if String((m._work.things[int((sd as Dictionary)["thing"])] as Dictionary)["name"]) == "cauldron" and ((sd as Dictionary)["field"] as ShapeField).hollow():
			pot = sd
	m._work.tick(12.0)
	var b: Dictionary = ph.rigid.bodies[int(ph._rigid_of[ladle])]
	# ...its drawn surface, every vertex, against the pot's - as drawn, and the control 3 mm lower
	var least := func(drop: float) -> float:
		var out := INF
		var stack: Array = [(m._work.works[ladle] as Dictionary)["node"]]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			stack.append_array(n.get_children())
			var mi := n as MeshInstance3D
			if mi == null or mi.mesh == null:
				continue
			var xf := m._work._world_of(mi)
			for q in mi.mesh.get_faces():
				var v := xf * q - Vector3(0.0, drop, 0.0)
				out = minf(out, (pot["field"] as ShapeField).sample((pot["xf"] as Transform3D).affine_inverse() * v).x)
		return out
	var drawn: float = least.call(0.0)
	var lower: float = least.call(0.003)
	_ok(not pot.is_empty() and b["held"] == null, "the ladle left in the pot was not let go there")
	_ok(lower < -0.002, "the control: drawn 3 mm lower, the ladle reads only %.2f mm into the pot" % (-lower * 1000.0))
	_ok(drawn > -0.0008 and drawn < 0.0008, "let go leaning in the pot, the drawn ladle is %.2f mm from the pot's surface (under 0: in it)" % (drawn * 1000.0))
	m._root3.free()
	return true


## A POUR POURS WHAT DOES NOT FLOW (2026-11-01, 841899: a mortar of ground frankincense `pour`ed into the brew stopped at the tip an
## empty liquid's brink ends at, 62 degrees, and poured nothing - its puppeteer then tipped it by hand and threw it into the brazier's
## pan, and `act` said it went "in the copper cauldron on its brazier"): a dish with a stone in it, `pour`ed into a bowl, turns on past
## its brink to its `tip` and the stone falls into the bowl - and `act` says so, by what it went into. The controls: held to a 30 degree
## tip, nothing leaves it and `act` says so; the same pour judged as meant for the cup, `act` says it MISSED, and where it went.
func _pours_loose() -> bool:
	var res := {}
	for case in ["bowl", "short"]:
		var m := _medium()
		_stand(m, FILINGS_SPEC, "bowl", _at(Vector3(-5, 0, -10)))
		_stand(m, FILINGS_SPEC, "dish", _at(Vector3(-30, 0, -10)))
		_stand(m, FILINGS_SPEC, "cup", _at(Vector3(-5, 0, 12)))
		var tr := {"thing": "dish", "law": "pour", "into": "bowl"}
		if case == "short":
			tr["tip"] = 30.0
		m._work.build({"acts": [{"name": "tip-out", "beat": 1, "length": 6.0, "tracks": [tr]}]}, 1)
		var said := String((m._work.check("tip-out") as Dictionary)["text"])
		m._work.runs = [{"i": 0, "t0": 2.0, "t1": 8.0}]
		m._work._timelines()
		var ph: TablePhysics = m._work.physics
		m._work.tick(11.0)
		var stone := _work_of_name(m, "stone")
		var bowl := _liquid(m, "bowl")
		var pose: Variant = ph.pose_of(stone, 11.0)
		var mid: Vector3 = (((m._work.works[stone] as Dictionary)["w"] as Dictionary).get("box", AABB()) as AABB).get_center()
		var at := (pose as Transform3D) * mid if pose != null else Vector3.INF
		res[case] = [ph._inside_liquid(at) == bowl and bowl >= 0, said]
		if case == "bowl":
			# ...the same pour, judged as meant for the cup
			var ti := m._work._thing_named("dish")
			res["cup"] = [false, "\n".join(ph.report(2.0, 8.0, [{"label": "the dish", "from": ph.solids_of_mover(ti, -1), "into": "cup"}]))]
		m._root3.free()
	_ok(not bool(res["short"][0]) and String(res["short"][1]).contains("NOTHING LEFT IT"), "the control: tipped only 30 degrees, the stone left the dish, or `act` did not say nothing did:\n%s" % String(res["short"][1]))
	_ok(bool(res["bowl"][0]), "poured into the bowl, the stone is not in it:\n%s" % String(res["bowl"][1]))
	_ok(String(res["bowl"][1]).contains("POUR of dish into \"bowl\"") and not String(res["bowl"][1]).contains("MISSED"), "poured into the bowl, `act` said:\n%s" % String(res["bowl"][1]))
	_ok(String(res["cup"][1]).contains("MISSED"), "the control: poured into a cup too small for it, `act` did not say the stone missed:\n%s" % String(res["cup"][1]))
	return true


## THE WORLD IS THE TABLE'S (next/framework_audit.md): every free part and every thing that may be moved is a body as built, whatever
## the acts are - DORMANT until a hand takes it up or what holds it moves, exactly the solid it was before it was a body - so a new act
## that moves something new is baked from where it begins, never from the show's start (841899's puppeteer: each `act` that fetched a
## jar or a feather nothing had moved baked the whole show again, 95 and 126 s a call). The control: the first act moved bakes again
## from its own start.
func _world_from_table() -> bool:
	var up := [{"at": 0.0}, {"at": 0.3, "by": [0, 4, 0]}, {"at": 1.0, "by": [0, 0, 6]}]
	var m := _rod_bench([[up, 2.0, 4.0]], 45.0)
	var ph: TablePhysics = m._work.physics
	var rod := _rod(m)
	# ...every free part a body, and every thing that holds no flame (the cup on its stand, never moved, among them)
	var cup_ti := m._work._thing_named("cup on a stand")
	_ok(ph._rigid_of.has(-1 - cup_ti), "the cup on its stand, moved by no act, is no body")
	_ok(bool((ph.rigid.bodies[int(ph._rigid_of[-1 - cup_ti])] as Dictionary)["dormant"]) if ph._rigid_of.has(-1 - cup_ti) else false, "the cup on its stand is not dormant as built")
	ph.bake_until(12.0)
	var cup_at: Variant = ph.thing_pose_of(cup_ti, 12.0)
	_ok(cup_at is Transform3D and (cup_at as Transform3D).is_equal_approx(ph._rest_of(-1 - cup_ti)), "the cup on its stand, untouched, is not where it was built: %s" % str(cup_at))
	var resumed := {}
	for case in ["new", "first"]:
		var acts: Array = [{"name": "move 0", "beat": 1, "length": 2.0, "tracks": [{"thing": "tools", "part": "rod", "law": "path", "jitter": 0.0,
			"keys": up if case == "new" else [{"at": 0.0}, {"at": 0.3, "by": [0, 5, 0]}, {"at": 1.0, "by": [0, 0, 7]}]}]}]
		if case == "new":
			acts.append({"name": "move cup", "beat": 1, "length": 1.0, "tracks": [{"thing": "cup on a stand", "law": "carry", "by": [0, 0, 6], "lift": 3}]})
		m._work.rebind({"acts": acts}, 1)
		m._work.runs = [{"i": 0, "t0": 2.0, "t1": 4.0}] + ([{"i": 1, "t0": 8.0, "t1": 9.0}] if case == "new" else [])
		m._work._timelines()
		ph.bake_until(12.0)
		resumed[case] = ph.resumed_at
	m._root3.free()
	_ok(float(resumed["first"]) <= 2.0, "the control: its first act moved, the bake went back only to %.1f s" % float(resumed["first"]))
	_ok(float(resumed["new"]) >= 7.0, "an act moving a thing nothing had moved, at 8 s, baked again from %.1f s" % float(resumed["new"]))
	return true
