extends SceneTree

## The gate of WORK AT THE TABLE ([Motions], [TableWork], [Formula]; next/table_work.md), with no renderer.
##
##   godot --headless --path . --script res://tests/table/table_work_check.gd
##
## - A FORMULA IS ARITHMETIC AND NOTHING ELSE: it works its sums in order, gives 0 where the arithmetic
##   gives none, and refuses every name it does not know - `instance_from_id`, `print`, `OS` (the control:
##   Godot's own Expression runs `instance_from_id`, which is why it is not used).
## - THE CLOCK RUNS (the user, 2026-10-25: "the clock showed 3:00 precisely... but the hands never moved"):
##   a minute hand hinged at the dial's middle, running at a tenth of a degree a second, has turned 60
##   degrees ten minutes in; the hour hand, from three o'clock, 5 more; a ticking second hand stands on its
##   steps. The control: the same hands with no joint stand as built.
## - A CLOCK KEEPS THE VIDEO'S TIME (2026-10-26: the first real set dresser wrote `{"clock": "hour"}` on each
##   hand, which no law read, and its puppeteer turned them in every act, stopped between): `clock` runs each
##   hand at its own rate, clockwise, the hour hand built at twelve standing at three as the video starts; a
##   turn an act puts on a running hand is left out and said; a hand an act sets goes on running from there.
##   The control: the same act on a hand that runs nothing holds where it set it.
## - THE WORK IS DONE WHERE IT IS SEEN (2026-10-26: "the mortar and pestle was animated in the far left corner;
##   we should have brought it front-and-center"): the work's spot is near the picture's middle and clear of
##   what stands; a mortar carried to "work" stands there, and its own pestle ground round "mortar.floor"
##   circles the bowl where it now stands, pressed onto its surface there, passing through nothing; left in
##   the bowl, the pestle goes home with the mortar. The controls: the floor found where the mortar stood is
##   far from the spot; a pestle laid on the table stays where it was laid.
## - A PART THAT STARTS SEATED MAY COME OUT (the first real puppeteer was told its rack's vial passed through
##   something "0.0 s in" on 12 acts of 69): a vial built standing in a solid rack lifts out and is put back,
##   passing through nothing - the room it was built in is its own slot. The control: the same vial carried
##   into a crate is caught going in.
## - SET DOWN ON WHAT IS UNDER IT (carry's `down`): a lid laid on its side, a jar let down from too high and a jar
##   set on a book each rest on what is under them, passing through nothing. The control: the lid laid by a
##   guessed height goes into the table.
## - A TOOL GRINDS IN ITS VESSEL: a pestle aimed by its tip, circling pressed onto the mortar's floor, has
##   its tip on the bowl's surface at every moment and never passes through it ([method TableWork.check]);
##   the herbs ground away are a fifth of their size when the act is done. The control: a pestle driven down
##   through the bowl's wall is caught passing through it.
## - WHAT AN ACT LEAVES STAYS: a jar carried to a place stands there after its act, until an act carries it
##   back where it was built.
## - THE READING CUES THE WORK: `work K` lays the card and begins card K's beat, an act cued at a word
##   (`<!-- act: name -->`) starts as that word is said, an uncued one where the one before it ended, and
##   an "under" one fills what its beat leaves. The control: the cued act moved off its word is not found
##   there.
## - A PART'S COPIES ARE ONE PART (2026-10-26: a stack of slips' bottom slip lifted alone, into the four
##   above it, and the puppeteer probed for a quarter of an hour): the stack named alone lifts as one and
##   passes through nothing, every copy risen alike; its top copy by its number lifts alone; a glow on the
##   part glows every copy; the parts report says how many and how each is named. The control: the bottom
##   copy alone, lifted the same way, is caught passing into the ones above it.
## - MADE SAFE: an act with no beat, a law ghost does not know, a track naming nothing on the table are left
##   out and said; a thing holding a flame is never moved whole.

var _fails := 0


func _init() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		print("  FAIL: " + what)


func _run() -> void:
	await process_frame
	for check in [_formula, _clock, _clock_law, _grind, _at_the_spot, _seated, _set_down, _carry, _copies, _cued, _safe]:
		var done: Variant = (check as Callable).call()
		_ok(done == true, "%s stopped part way (a script error - see above)" % (check as Callable).get_method())
	print("table_work_check: %s (%d failure%s)" % ["ALL OK" if _fails == 0 else "FAILED", _fails, "" if _fails == 1 else "s"])
	quit(1 if _fails > 0 else 0)


## A medium with no stage, as far as [TableWork] reads one: its root, its still air, its plan.
static func _medium() -> TableMedium:
	var m := TableMedium.new()
	m._root3 = Node3D.new()
	m._props = Node3D.new()
	m._root3.add_child(m._props)
	m._wind = {}
	return m


## [param spec] built and stood on [param m] at [param at] (meters, the table's space): `{node, built, thing}`.
static func _stand(m: TableMedium, spec: Dictionary, name: String, at: Vector3, seed := 5) -> Dictionary:
	var safe := Props.sanitize(spec, [])
	var thing: Dictionary = {}
	for t in safe["things"]:
		if String((t as Dictionary)["name"]) == name:
			thing = t
	var b := Props.build(thing, safe["materials"], seed)
	var node: Node3D = b["node"]
	node.transform = Transform3D(Basis.IDENTITY, at)
	m._props.add_child(node)
	m._work.take(thing, b, node)
	return {"node": node, "built": b, "thing": thing}


func _formula() -> bool:
	var vars := PackedStringArray(["t", "u"])
	var c := Formula.compile("90 + 30 * sin(tau * t / 1.5)", vars)
	_ok(bool(c["ok"]) and is_equal_approx(Formula.run(c["code"], {"t": 0.375}), 120.0), "90 + 30 sin(tau t / 1.5) at t = 0.375 is not 120")
	var p := Formula.compile("2 + 3 * 4 ^ 2 - -1", vars)
	_ok(bool(p["ok"]) and is_equal_approx(Formula.run(p["code"], {}), 51.0), "2 + 3 * 4^2 - -1 is not 51: %s" % str(Formula.run(p["code"], {})))
	var z := Formula.compile("1 / (t - t)", vars)
	_ok(bool(z["ok"]) and Formula.run(z["code"], {"t": 2.0}) == 0.0, "a division by zero is not 0")
	for bad in ["instance_from_id(1)", "print(1)", "OS.get_name()", "load(\"res://x\")", "t t", "sin(1, 2)", "(1", "Engine"]:
		_ok(not bool(Formula.compile(bad, vars)["ok"]), "the formula \"%s\" was not refused" % bad)
	# THE CONTROL: Godot's own Expression, with no object behind it, still reaches a live object
	var e := Expression.new()
	e.parse("instance_from_id(%d).get_class()" % root.get_instance_id())
	_ok(str(e.execute([], null, false)) == "Window", "the control: Expression no longer reaches a live object (then it might be safe - look again)")
	return true


## A wall clock: a face, and the hands named, hinged at the dial's middle (z toward the reader).
static func _clock_spec(jointed: bool) -> Dictionary:
	var hand := func(nm: String, length: float, run: Dictionary) -> Dictionary:
		var p := {"name": nm, "shape": "box", "size": [0.3, length, 0.1], "at": [0, 10, 1.2], "material": "brass"}
		if jointed:
			p["joint"] = {"kind": "hinge", "at": [0, 10, 1.2], "axis": [0, 0, 1]}
			p["runs"] = run
		return p
	return {"things": [{"name": "the clock", "parts": [
		{"shape": "lathe", "profile": [[0, 0], [6, 0], [6, 1], [0, 1]], "turn": [90, 0, 0], "at": [0, 10, 0], "material": "brass"},
		hand.call("minute hand", 4.5, {"law": "turn", "rate": -0.1}),
		hand.call("hour hand", 3.0, {"law": "turn", "rate": -1.0 / 120.0, "from": -90.0}),
		hand.call("second hand", 5.0, {"law": "turn", "rate": -6.0, "tick": 60})]}],
		"materials": {"brass": {"kind": "metal", "color": "#b08d3c"}}}


## How far a work's node is turned about z (degrees, clockwise from the reader's side positive).
static func _turned(n: Node3D) -> float:
	return -rad_to_deg(n.transform.basis.get_euler().z)


func _clock() -> bool:
	var m := _medium()
	_stand(m, _clock_spec(true), "the clock", Vector3.ZERO)
	m._work.build(null, 0)
	var works: Array = m._work.works
	var by := {}
	for w in works:
		by[String((w as Dictionary)["name"])] = (w as Dictionary)["node"]
	_ok(by.has("minute hand") and by.has("hour hand") and by.has("second hand"), "the clock's hands are not working parts: %s" % str(by.keys()))
	if by.size() < 3:
		return true
	m._work.tick(0.0)
	_ok(absf(_turned(by["minute hand"])) < 0.01, "the minute hand is turned at the opening")
	_ok(absf(_turned(by["hour hand"]) - 90.0) < 0.01, "the hour hand does not stand at three: %s" % _turned(by["hour hand"]))
	m._work.tick(600.0)
	_ok(absf(_turned(by["minute hand"]) - 60.0) < 0.05, "ten minutes in, the minute hand has turned %s degrees, not 60" % _turned(by["minute hand"]))
	_ok(absf(_turned(by["hour hand"]) - 95.0) < 0.05, "ten minutes in, the hour hand stands at %s degrees, not 95" % _turned(by["hour hand"]))
	# the hand turns about the dial's middle: its pivot stays where it was
	var pivot := Vector3(0, 0.1, 0.012)
	_ok(((by["minute hand"] as Node3D).transform * pivot).distance_to(pivot) < 1e-5, "the minute hand did not turn about the dial's middle")
	# a ticking hand stands on its steps (a second and a half past a tick it has long settled)
	m._work.tick(10.5)
	var s := _turned(by["second hand"])
	_ok(absf(s - 60.0) < 0.2, "a ticking second hand stands at %s degrees ten and a half seconds in, not on its step at 60" % s)
	# the control: the same hands, named but with no joint and nothing to run, stand as built
	var still := _medium()
	_stand(still, _clock_spec(false), "the clock", Vector3.ZERO)
	still._work.build(null, 0)
	still._work.tick(600.0)
	var moved := 0
	for w in still._work.works:
		if absf(_turned((w as Dictionary)["node"])) > 0.01:
			moved += 1
	_ok(moved == 0, "the control: %d hand(s) with no joint turned" % moved)
	return true


## A mortar (a bowl named, its floor a point, herbs in it) and its pestle (free, a tip and a grip).
static func _mortar_spec() -> Dictionary:
	return {"things": [
		{"name": "mortar", "parts": [
			{"name": "bowl", "shape": "lathe", "profile": [[0, 0], [5, 0], [6, 5], [6.5, 5.3], [5.4, 5], [4.3, 1.2], [0, 1.2]],
				"material": "stone", "points": {"floor": [0, 1.2, 0]}},
			{"name": "herbs", "shape": "ball", "size": [3, 1, 3], "at": [0, 1.2, 0], "material": "leaf"}]},
		{"name": "pestle", "parts": [
			{"name": "pestle", "shape": "lathe", "profile": [[0, 0], [1.1, 0, 0.5], [0.8, 4], [0.9, 12], [0, 12.4]], "smooth": true,
				"material": "stone", "joint": {"kind": "free"}, "points": {"tip": [0, 0, 0], "grip": [0, 12, 0]}}]}],
		"materials": {"stone": {"kind": "stone", "color": "#8a8580"}, "leaf": {"kind": "plant", "color": "#4a6a2a"}}}


func _grind() -> bool:
	var m := _medium()
	var mortar := _stand(m, _mortar_spec(), "mortar", Vector3(Tables.ORIGIN.x, 0.0, Tables.ORIGIN.y))
	_stand(m, _mortar_spec(), "pestle", Vector3(Tables.ORIGIN.x + 0.12, 0.0, Tables.ORIGIN.y))
	var acts := {"acts": [{"name": "grind", "beat": 1, "length": 6,
		"tracks": [{"thing": "pestle", "part": "pestle", "law": "aim",
			"tip": {"point": "tip", "around": "mortar.floor", "radius": 1.5, "period": 1.5, "press": "mortar", "gap": 0.3},
			"grip": {"point": "grip", "around": "mortar.floor", "lift": 13, "radius": 3.5, "period": 1.5}},
			{"thing": "mortar", "part": "herbs", "state": "grow", "law": "to", "value": 0.2}]},
		{"name": "smash", "beat": 2, "length": 3,
		"tracks": [{"thing": "pestle", "part": "pestle", "law": "aim",
			"tip": {"point": "tip", "around": "mortar.floor", "lift": -4.0, "radius": 5.0, "period": 3.0},
			"grip": {"point": "grip", "around": "mortar.floor", "lift": 9, "radius": 6, "period": 3.0}}]}]}
	m._work.build(acts, 2)
	_ok((m._work.acts as Array).size() == 2, "the grinding acts were not kept: %s" % "; ".join(m._work.notes))
	if (m._work.acts as Array).size() < 2:
		return true
	var times: Dictionary = m._work.rehearse(10.0)
	var g: Array = times["grind"]
	# THE TIP IS ON THE BOWL'S SURFACE, past the moment the hand brings it there
	var tm: TriangleMesh = m._work._mesh_of(m._work._thing_named("mortar"))
	var pw: int = m._work._work_of(m._work._thing_named("pestle"), "pestle")
	var worst := 0.0
	for i in 12:
		var t := float(g[0]) + TableWork.BLEND_IN + 0.1 + float(i) * 0.4
		m._work.tick(t)
		var tip: Vector3 = m._work._world_of((m._work.works[pw] as Dictionary)["node"]) * Vector3.ZERO
		var hit: Dictionary = tm.intersect_ray(tip + Vector3(0, 0.06, 0), Vector3.DOWN)
		if hit.is_empty():
			worst = INF
			break
		worst = maxf(worst, absf(tip.y - (hit["position"] as Vector3).y - 0.003))
	_ok(worst < 0.0006, "the pestle's tip leaves the bowl's surface by %s mm while it grinds" % str(snappedf(worst * 1000.0, 0.01)))
	var ok_check: Dictionary = m._work.check("grind")
	_ok(int(ok_check["through"]) == 0, "grinding pressed into the bowl is said to pass through something:\n%s" % String(ok_check["text"]))
	m._work.rehearse(10.0)
	m._work.tick(float(g[1]) + 1.0)
	var hw: int = m._work._work_of(m._work._thing_named("mortar"), "herbs")
	var herbs: Node3D = (m._work.works[hw] as Dictionary)["node"]
	_ok(absf(herbs.transform.basis.get_scale().x - 0.2) < 0.01, "the herbs ground away are %s of their size, not 0.2" % herbs.transform.basis.get_scale().x)
	# THE CONTROL: the pestle driven down through the bowl's wall is caught
	var bad: Dictionary = m._work.check("smash")
	_ok(int(bad["through"]) > 0, "a pestle driven through the bowl's wall was not caught:\n%s" % String(bad["text"]))
	m._root3.free()
	return true


func _clock_law() -> bool:
	var m := _medium()
	var spec := _clock_spec(true)
	var parts: Array = ((spec["things"] as Array)[0] as Dictionary)["parts"]
	# written as the clock it is - the minute hand as the first real set dresser wrote it - the hour hand built at
	# twelve and the video starting at three
	(parts[1] as Dictionary)["runs"] = {"clock": "minute"}
	(parts[2] as Dictionary)["runs"] = {"law": "clock", "hand": "hour", "shows": "12:00", "time": "3:00"}
	(parts[3] as Dictionary)["runs"] = {"law": "clock", "hand": "second"}
	_stand(m, spec, "the clock", Vector3.ZERO)
	m._work.build({"acts": [
		{"name": "set-it", "beat": "intro", "length": 4, "tracks": [{"thing": "the clock", "part": "minute hand", "law": "to", "value": -30}]},
		{"name": "turn-it", "beat": "intro", "length": 4, "tracks": [{"thing": "the clock", "part": "second hand", "law": "turn", "rate": -6}]}]}, 0)
	var by := {}
	for w in m._work.works:
		by[String((w as Dictionary)["name"])] = (w as Dictionary)["node"]
	var kept: Array = (m._work.acts as Array).map(func(a: Dictionary) -> String: return String(a["name"]))
	_ok(kept == ["set-it"], "a turn on a hand that runs was not left out: %s" % str(kept))
	_ok("; ".join(m._work.notes).contains("already runs all the time"), "a turn left out on a running hand was not said: %s" % "; ".join(m._work.notes))
	m._work.tick(0.0)
	_ok(absf(_turned(by["hour hand"]) - 90.0) < 0.01, "the hour hand built at twelve does not stand at three as the video starts: %s" % _turned(by["hour hand"]))
	m._work.tick(600.0)
	_ok(absf(_turned(by["hour hand"]) - 95.0) < 0.05, "ten minutes in, the clock's hour hand stands at %s degrees, not 95" % _turned(by["hour hand"]))
	m._work.tick(10.5)
	_ok(absf(_turned(by["second hand"]) - 60.0) < 0.2, "the clock's second hand does not tick: %s degrees ten and a half seconds in" % _turned(by["second hand"]))
	# A HAND SET BY AN ACT GOES ON RUNNING from where it was set: set to 30 past at 104 s, then 49.6 more by 600 s
	m._work.rehearse(100.0)
	m._work.tick(104.0)
	_ok(absf(_turned(by["minute hand"]) - 30.0) < 0.05, "the act did not set the minute hand to 30 degrees: %s" % _turned(by["minute hand"]))
	m._work.tick(600.0)
	_ok(absf(_turned(by["minute hand"]) - 79.6) < 0.05, "a minute hand an act set stood %s degrees at 600 s, not 79.6: it stopped" % _turned(by["minute hand"]))
	# the control: the same act on a hinge that runs nothing holds where it was set
	var still := _medium()
	var spec2 := _clock_spec(true)
	((((spec2["things"] as Array)[0] as Dictionary)["parts"] as Array)[1] as Dictionary).erase("runs")
	_stand(still, spec2, "the clock", Vector3.ZERO)
	still._work.build({"acts": [{"name": "set-it", "beat": "intro", "length": 4,
		"tracks": [{"thing": "the clock", "part": "minute hand", "law": "to", "value": -30}]}]}, 0)
	still._work.rehearse(100.0)
	still._work.tick(600.0)
	var mh: Node3D = null
	for w in still._work.works:
		if String((w as Dictionary)["name"]) == "minute hand":
			mh = (w as Dictionary)["node"]
	_ok(mh != null and absf(_turned(mh) - 30.0) < 0.05, "the control: a hand that runs nothing moved on after its act: %s" % (_turned(mh) if mh != null else "none"))
	m._root3.free()
	still._root3.free()
	return true


## A mortar off to the left, its pestle its own part (as the first real set dresser built one): [param laid] -
## after the grinding the pestle is laid down on the table beside it, rather than left in the bowl.
func _bench(laid: bool) -> TableMedium:
	var m := _medium()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	m._plan.cam_base = CardTable.sample_layout(rng)["camera"]
	m._plan.cards_from = "none"
	var spec := _mortar_spec()
	var mortar: Dictionary = (spec["things"] as Array)[0]
	var pestle: Dictionary = ((((spec["things"] as Array)[1] as Dictionary)["parts"] as Array)[0] as Dictionary).duplicate(true)
	# standing in the bowl, its points in the mortar's own centimeters
	pestle["at"] = [0, 1.2, 0]
	pestle["points"] = {"tip": [0, 1.2, 0], "grip": [0, 13.2, 0]}
	mortar["parts"] = [(mortar["parts"] as Array)[0], pestle]
	_stand(m, spec, "mortar", Vector3(Tables.ORIGIN.x - 0.29, 0.0, Tables.ORIGIN.y - 0.12))
	var acts: Array = [
		{"name": "bring-mortar", "beat": "intro", "length": 3, "tracks": [{"thing": "mortar", "law": "carry", "to": "work", "lift": 4}]},
		{"name": "grind", "beat": "intro", "length": 6, "tracks": [{"thing": "mortar", "part": "pestle", "law": "aim",
			"tip": {"point": "tip", "around": "mortar.floor", "radius": 1.5, "period": 1.5, "press": "mortar", "gap": 0.3},
			"grip": {"point": "grip", "around": "mortar.floor", "lift": 13, "radius": 3.5, "period": 1.5}}]}]
	if laid:
		acts.append({"name": "lay-pestle", "beat": "intro", "length": 2, "tracks": [{"thing": "mortar", "part": "pestle", "law": "carry",
			"to": [12, 1, 6], "turn": [0, 0, 90], "lift": 5}]})
	acts.append({"name": "mortar-home", "beat": "intro", "length": 3, "tracks": [{"thing": "mortar", "law": "carry", "lift": 4}]})
	m._work.build({"acts": acts}, 0)
	return m


## THE WORK IS DONE WHERE IT IS SEEN (2026-10-26: "the mortar and pestle was animated in the far left corner; we
## should have brought it front-and-center").
func _at_the_spot() -> bool:
	var m := _bench(false)
	_ok((m._work.acts as Array).size() == 3, "the work at the spot was not kept: %s" % "; ".join(m._work.notes))
	if (m._work.acts as Array).size() != 3:
		m._root3.free()
		return true
	var spot: Vector3 = m._work.work_spot()
	var fwd := -m._plan.cam_base.basis.z
	var middle: Vector3 = m._plan.cam_base.origin + fwd * (-m._plan.cam_base.origin.y / fwd.y)
	_ok(Vector2(spot.x - middle.x, spot.z - middle.z).length() < 0.15, "the work's spot is %.0f cm from the picture's middle" % (Vector2(spot.x - middle.x, spot.z - middle.z).length() * 100.0))
	var rest_box: AABB = m._work._world_rest_thing(0) * ((m._work.things[0] as Dictionary)["box"] as AABB)
	_ok(not Rect2(rest_box.position.x, rest_box.position.z, rest_box.size.x, rest_box.size.z).grow(0.05).has_point(Vector2(spot.x, spot.z)),
		"the work's spot is where the mortar stands")
	_ok(m._work.parts_report().contains("THE WORK'S SPOT"), "the parts report does not say where the work is done")
	var times: Dictionary = m._work.rehearse(10.0)
	var mortar: Node3D = (m._work.things[0] as Dictionary)["node"]
	m._work.tick(float((times["bring-mortar"] as Array)[1]) + 0.1)
	_ok(Vector2(mortar.position.x - spot.x, mortar.position.z - spot.z).length() < 0.005, "the mortar carried to \"work\" stands %.1f cm from the spot" % (Vector2(mortar.position.x - spot.x, mortar.position.z - spot.z).length() * 100.0))
	# GROUND WHERE IT NOW STANDS: the pestle's tip on the moved bowl's floor, pressed onto its surface there
	var pw: int = m._work._work_of(0, "pestle")
	var tip_at: Vector3 = ((m._work.works[pw] as Dictionary)["w"]["points"] as Dictionary)["tip"]
	var g: Array = times["grind"]
	var worst := 0.0
	for i in 10:
		var t := float(g[0]) + TableWork.BLEND_IN + 0.1 + float(i) * 0.45
		m._work.tick(t)
		var tip: Vector3 = m._work._world_of((m._work.works[pw] as Dictionary)["node"]) * tip_at
		worst = maxf(worst, Vector2(tip.x - mortar.position.x, tip.z - mortar.position.z).length())
		# ...and on the bowl's floor, 1.2 cm up, its gap of 3 mm over it
		worst = maxf(worst, absf(tip.y - 0.012 - 0.003) * 10.0)
	_ok(worst < 0.03, "the pestle grinding round the mortar's floor strays %.1f cm from the moved bowl" % (worst * 100.0))
	var c: Dictionary = m._work.check("grind")
	_ok(int(c["through"]) == 0, "grinding in the moved mortar passes through something:\n%s" % String(c["text"]))
	# the control: the mortar's floor found where it stood (as places were found) is far from where it is ground
	var then: Vector3 = m._work.place_of("mortar.floor", Vector3.ZERO)
	_ok(Vector2(then.x - spot.x, then.z - spot.z).length() > 0.1, "the control: the floor where the mortar stood is near the spot")
	# A PESTLE LEFT IN ITS MORTAR GOES HOME WITH IT
	m._work.tick(float((times["mortar-home"] as Array)[1]) + 0.1)
	var tip_home: Vector3 = m._work._world_of((m._work.works[pw] as Dictionary)["node"]) * tip_at
	_ok(Vector2(tip_home.x - mortar.position.x, tip_home.z - mortar.position.z).length() < 0.03, "a pestle left in its mortar stayed behind when the mortar was carried home: %.0f cm off" % (Vector2(tip_home.x - mortar.position.x, tip_home.z - mortar.position.z).length() * 100.0))
	m._root3.free()
	# ...and the control: one laid down on the table stays where it was laid
	var l := _bench(true)
	var lt: Dictionary = l._work.rehearse(10.0)
	var lw: int = l._work._work_of(0, "pestle")
	l._work.tick(float((lt["lay-pestle"] as Array)[1]) + 0.1)
	var laid_at: Vector3 = l._work._world_of((l._work.works[lw] as Dictionary)["node"]).origin
	l._work.tick(float((lt["mortar-home"] as Array)[1]) + 0.1)
	var after: Vector3 = l._work._world_of((l._work.works[lw] as Dictionary)["node"]).origin
	_ok(after.distance_to(laid_at) < 0.001, "the control: a pestle laid on the table went with the mortar: %.1f cm" % (after.distance_to(laid_at) * 100.0))
	l._root3.free()
	return true


## A PART THAT STARTS SEATED MAY COME OUT (the first real puppeteer was told its rack's vial passed through something
## "0.0 s in" on 12 acts of 69): a vial built standing in a solid rack lifts out of it, and is put back, passing
## through nothing. The control: the same vial carried into a crate beside it is caught going in.
func _seated() -> bool:
	var m := _medium()
	var spec := {"things": [{"name": "rack", "parts": [
		{"shape": "box", "size": [12, 4, 4], "at": [0, 0, 0], "material": "wood"},
		{"name": "vial", "shape": "lathe", "profile": [[0, 0], [1, 0], [1, 8], [0, 8]], "at": [0, 1, 0], "material": "glass", "joint": {"kind": "free"}}]},
		{"name": "crate", "parts": [{"shape": "box", "size": [10, 10, 10], "material": "wood"}]}],
		"materials": {"wood": {"kind": "wood", "color": "#6a4a2a"}, "glass": {"kind": "ceramic", "color": "#9ab"}}}
	_stand(m, spec, "rack", Vector3(Tables.ORIGIN.x, 0.0, Tables.ORIGIN.y))
	_stand(m, spec, "crate", Vector3(Tables.ORIGIN.x + 0.2, 0.0, Tables.ORIGIN.y))
	m._work.build({"acts": [
		{"name": "lift-out", "beat": 1, "length": 2, "tracks": [{"thing": "rack", "part": "vial", "law": "path", "keys": [{"at": 0}, {"at": 1, "by": [0, 10, 0]}]}]},
		{"name": "put-back", "beat": 1, "length": 2, "tracks": [{"thing": "rack", "part": "vial", "law": "path", "keys": [{"at": 0}, {"at": 1, "by": [0, -10, 0]}]}]},
		{"name": "into-crate", "beat": 1, "length": 3, "tracks": [{"thing": "rack", "part": "vial", "law": "path", "keys": [{"at": 0}, {"at": 0.3, "by": [0, 4, 0]}, {"at": 1, "by": [20, 4, 0]}]}]}]}, 1)
	_ok((m._work.acts as Array).size() == 3, "the rack's acts were not kept: %s" % "; ".join(m._work.notes))
	if (m._work.acts as Array).size() != 3:
		m._root3.free()
		return true
	var out: Dictionary = m._work.check("lift-out")
	_ok(int(out["through"]) == 0, "a vial lifted out of its rack passes through it:\n%s" % String(out["text"]))
	var back: Dictionary = m._work.check("put-back")
	_ok(int(back["through"]) == 0, "a vial put back where it was built passes through its rack:\n%s" % String(back["text"]))
	var bad: Dictionary = m._work.check("into-crate")
	_ok(int(bad["through"]) > 0, "the control: a vial carried into a crate was not caught:\n%s" % String(bad["text"]))
	m._root3.free()
	return true


## SET DOWN ON WHAT IS UNDER IT (carry's `down`; the first real puppeteer laid a stopper, a lid and a pestle down by
## heights worked out by hand, and was told each passed through the table).
func _set_down() -> bool:
	var m := _medium()
	var spec := {"things": [
		{"name": "jar", "parts": [{"shape": "lathe", "profile": [[0, 0], [3, 0], [3, 8], [0, 8]], "material": "glass"},
			{"name": "lid", "shape": "lathe", "profile": [[0, 0], [3.4, 0], [3.4, 1.2], [0, 1.2]], "at": [0, 8, 0], "material": "glass", "joint": {"kind": "free"}}]},
		{"name": "book", "parts": [{"shape": "box", "size": [14, 4, 10], "material": "glass"}]}],
		"materials": {"glass": {"kind": "ceramic", "color": "#5a7a6a"}}}
	_stand(m, spec, "jar", Vector3(Tables.ORIGIN.x, 0.0, Tables.ORIGIN.y))
	_stand(m, spec, "book", Vector3(Tables.ORIGIN.x + 0.25, 0.0, Tables.ORIGIN.y))
	m._work.build({"acts": [
		{"name": "lid-off", "beat": 1, "length": 2, "tracks": [{"thing": "jar", "part": "lid", "law": "carry", "to": [9, 0, 6], "turn": [90, 0, 0], "lift": 4, "down": true}]},
		{"name": "lid-guessed", "beat": 1, "length": 2, "tracks": [{"thing": "jar", "part": "lid", "law": "carry", "to": [-9, 0, 6], "turn": [90, 0, 0], "lift": 4}]},
		{"name": "jar-high", "beat": 1, "length": 2, "tracks": [{"thing": "jar", "law": "carry", "to": [0, 3, 12], "lift": 4, "down": true}]},
		{"name": "jar-on-book", "beat": 1, "length": 2, "tracks": [{"thing": "jar", "law": "carry", "to": "book.top", "lift": 8, "down": true}]}]}, 1)
	_ok((m._work.acts as Array).size() == 4, "the setting-down acts were not kept: %s" % "; ".join(m._work.notes))
	if (m._work.acts as Array).size() != 4:
		m._root3.free()
		return true
	var times: Dictionary = m._work.rehearse(10.0)
	var lw: int = m._work._work_of(0, "lid")
	var lowest := func(node: Node3D, box: AABB) -> float:
		var xf: Transform3D = m._work._world_of(node)
		var y := INF
		for i in 8:
			y = minf(y, (xf * box.get_endpoint(i)).y)
		return y
	m._work.tick(float((times["lid-off"] as Array)[1]))
	var lid: Node3D = (m._work.works[lw] as Dictionary)["node"]
	var lid_box: AABB = ((m._work.works[lw] as Dictionary)["w"] as Dictionary)["box"]
	_ok(absf(float(lowest.call(lid, lid_box)) - TableWork.SET_GAP) < 0.001, "a lid laid on its side, set down, rests %.1f mm off the table" % (float(lowest.call(lid, lid_box)) * 1000.0))
	_ok(int(m._work.check("lid-off")["through"]) == 0, "a lid set down passes through something:\n%s" % String(m._work.check("lid-off")["text"]))
	# the control: laid by a guessed height, the same lid goes into the table
	_ok(int(m._work.check("lid-guessed")["through"]) > 0, "the control: a lid laid by a guessed height was not caught in the table")
	m._work.rehearse(10.0)
	var jar: Node3D = (m._work.things[0] as Dictionary)["node"]
	var jar_box: AABB = (m._work.things[0] as Dictionary)["box"]
	m._work.tick(float((times["jar-high"] as Array)[1]))
	_ok(absf(float(lowest.call(jar, jar_box)) - TableWork.SET_GAP) < 0.001, "a jar set down from too high rests %.1f mm off the table" % (float(lowest.call(jar, jar_box)) * 1000.0))
	m._work.tick(float((times["jar-on-book"] as Array)[1]))
	_ok(absf(float(lowest.call(jar, jar_box)) - 0.04 - TableWork.SET_GAP) < 0.001, "a jar set down on a book rests %.1f mm off it" % ((float(lowest.call(jar, jar_box)) - 0.04) * 1000.0))
	m._root3.free()
	return true


func _carry() -> bool:
	var m := _medium()
	var spec := {"things": [{"name": "jar", "parts": [{"shape": "lathe", "profile": [[0, 0], [3, 0], [3, 8], [0, 8]], "material": "glass"}]}],
		"materials": {"glass": {"kind": "ceramic", "color": "#5a7a6a"}}}
	var at := Vector3(0.3, 0.0, -0.2)
	var jar := _stand(m, spec, "jar", at)
	var acts := {"acts": [{"name": "fetch", "beat": 1, "length": 3, "tracks": [{"thing": "jar", "law": "carry", "to": [0, 0, 5], "lift": 6}]},
		{"name": "back", "beat": 2, "length": 3, "tracks": [{"thing": "jar", "law": "carry", "lift": 6}]}]}
	m._work.build(acts, 2)
	# two acts a while apart, as a reading spaces them
	m._work.runs = [{"i": 0, "t0": 20.0, "t1": 23.0}, {"i": 1, "t0": 40.0, "t1": 43.0}]
	m._work._timelines()
	var node: Node3D = jar["node"]
	var target := Vector3(Tables.ORIGIN.x, 0.0, Tables.ORIGIN.y + 0.05)
	m._work.tick(21.5)
	_ok(node.position.y > 0.03, "a jar carried was not lifted on the way: %s" % node.position)
	m._work.tick(30.0)
	_ok(node.position.distance_to(target) < 0.001, "the jar did not stay where it was carried: %s, not %s" % [node.position, target])
	m._work.tick(50.0)
	_ok(node.position.distance_to(at) < 0.001, "the jar was not carried back where it was built: %s" % node.position)
	m._root3.free()
	return true


func _copies() -> bool:
	var m := _medium()
	var spec := {"things": [{"name": "inkpot and slips", "parts": [
		{"shape": "lathe", "profile": [[0, 0], [3, 0], [3, 4], [0, 4]], "material": "clay"},
		{"name": "slips", "shape": "box", "size": [7, 0.12, 3], "at": [-8, 0, 0], "material": "paper", "joint": {"kind": "free"},
			"copies": {"line": {"count": 4, "step": [0, 0.13, 0]}}}]}],
		"materials": {"clay": {"kind": "ceramic", "color": "#6a5a4a"}, "paper": {"kind": "paper", "color": "#eee6d0"}}}
	_stand(m, spec, "inkpot and slips", Vector3(Tables.ORIGIN.x, 0.0, Tables.ORIGIN.y))
	var lift := func(part: String) -> Dictionary:
		return {"name": "lift " + part, "beat": 1, "length": 2, "tracks": [{"thing": "inkpot and slips", "part": part, "law": "path",
			"keys": [{"at": 0.0}, {"at": 1.0, "by": [0, 4, 0]}]}]}
	m._work.build({"acts": [lift.call("slips"), lift.call("slips 4"), lift.call("slips 1"),
		{"name": "glow", "beat": 1, "length": 2, "tracks": [{"thing": "inkpot and slips", "part": "slips", "state": "glow", "law": "to", "value": 1.0}]}]}, 1)
	var g: Array = m._work.groups
	_ok(g.size() == 1 and ((g[0] as Dictionary)["members"] as Array).size() == 4, "the slips are not one part of four copies: %s" % str(g))
	_ok((m._work.acts as Array).size() == 4, "not every act was kept: %s" % "; ".join(m._work.notes))
	if g.size() != 1 or (m._work.acts as Array).size() != 4:
		m._root3.free()
		return true
	var members: Array = (g[0] as Dictionary)["members"]
	var report: String = m._work.parts_report()
	_ok(report.contains("4 copies") and report.contains("\"slips 1\" to \"slips 4\""), "the parts report does not say how the copies are named:\n%s" % report)
	var all: Dictionary = m._work.check("lift-slips")
	_ok(int(all["through"]) == 0, "the stack lifted as one passed through something:\n%s" % String(all["text"]))
	var top: Dictionary = m._work.check("lift-slips-4")
	_ok(int(top["through"]) == 0, "the top slip lifted alone passed through something:\n%s" % String(top["text"]))
	var bottom: Dictionary = m._work.check("lift-slips-1")
	_ok(int(bottom["through"]) > 0, "the control: the bottom slip lifted alone was not caught passing into the ones above it:\n%s" % String(bottom["text"]))
	# played in turn: the stack risen whole, then the top copy again on its own
	m._work.runs = [{"i": 0, "t0": 10.0, "t1": 12.0}, {"i": 1, "t0": 20.0, "t1": 22.0}, {"i": 3, "t0": 30.0, "t1": 32.0}]
	m._work._timelines()
	var rest: Array = members.map(func(wi: int) -> Vector3: return (m._work._rest["w%d:pose" % wi] as Transform3D).origin)
	m._work.tick(15.0)
	var risen := true
	for k in members.size():
		var y: float = m._work._world_of((m._work.works[members[k]] as Dictionary)["node"]).origin.y - (rest[k] as Vector3).y
		risen = risen and absf(y - 0.04) < 0.001
	_ok(risen, "the stack lifted as one did not lift every copy 4 cm")
	m._work.tick(25.0)
	var y_top: float = m._work._world_of((m._work.works[members[3]] as Dictionary)["node"]).origin.y - (rest[3] as Vector3).y
	var y_low: float = m._work._world_of((m._work.works[members[0]] as Dictionary)["node"]).origin.y - (rest[0] as Vector3).y
	_ok(absf(y_top - 0.08) < 0.001 and absf(y_low - 0.04) < 0.001, "the top copy alone did not rise from where the stack left it: top %.3f, bottom %.3f" % [y_top, y_low])
	var glows := members.map(func(wi: int) -> float: return float(m._work.value("w%d:glow" % wi, 40.0)))
	_ok(glows.all(func(v: float) -> bool: return absf(v - 1.0) < 1e-4), "a glow on the part did not glow every copy: %s" % str(glows))
	m._root3.free()
	return true


func _cued() -> bool:
	var script := "\n\n".join(PackedStringArray([
		"<!-- table: shuffle -->", "Welcome back to the bench tonight.",
		"<!-- table: draw 1 -->", "Here is the first card.",
		"<!-- table: work 1 -->", "Into the mortar it goes and now we <!-- act: grind --> grind it slowly, round and round, until it is fine.",
		"<!-- table: spread -->", "And that is the brew."]))
	var parse := CardReading.parse(script)
	var cues: Array = parse["cues"]
	_ok(cues.size() == 1 and String((cues[0] as Dictionary)["name"]) == "grind", "the act cued at a word was not found: %s" % str(cues))
	_ok(not String(parse["speakable"]).contains("act:"), "the voice was handed an act's mark")
	var spoken: PackedStringArray = parse["spoken"]
	var si := int((cues[0] as Dictionary)["si"]) if not cues.is_empty() else -1
	_ok(si >= 0 and si < spoken.size() and spoken[si] == "grind", "the cue is not on the word after it: %s" % (spoken[si] if si >= 0 and si < spoken.size() else "none"))
	var m := _medium()
	_stand(m, _mortar_spec(), "mortar", Vector3(Tables.ORIGIN.x, 0.0, Tables.ORIGIN.y))
	_stand(m, _mortar_spec(), "pestle", Vector3(Tables.ORIGIN.x + 0.12, 0.0, Tables.ORIGIN.y))
	m._work.build({"acts": [
		{"name": "drop", "beat": 1, "length": 2, "tracks": [{"thing": "mortar", "part": "herbs", "state": "grow", "law": "to", "value": 1.2}]},
		{"name": "grind", "beat": 1, "length": "under", "tracks": [{"thing": "mortar", "part": "herbs", "state": "grow", "law": "to", "value": 0.3}]},
		{"name": "settle", "beat": 1, "length": 1.5, "tracks": [{"thing": "mortar", "part": "herbs", "state": "glow", "law": "to", "value": 0.5}]}]}, 1)
	# every word said 0.4 s after the last, the actions placed as the follower places them
	var f := ReadingFollower.new()
	f.reset(spoken)
	var words: Array = []
	var t := 5.0
	for i in spoken.size():
		words.append({"text": spoken[i], "t0": t, "t1": t + 0.3})
		t += 0.4
	f.extend(words)
	var sched := f.place(parse["actions"], 1.0, 0.25, 0.2)
	m._work.schedule(sched, parse, f.said0, f.said1, PackedFloat32Array(), 0.0)
	var runs := {}
	for r in m._work.runs:
		runs[String((m._work.acts[int((r as Dictionary)["i"])] as Dictionary)["name"])] = r
	_ok(runs.size() == 3, "the work's three acts were not all scheduled: %s" % str(runs.keys()))
	if runs.size() < 3:
		return true
	_ok(absf(float(runs["grind"]["t0"]) - f.said0[si]) < 0.01, "the cued act starts at %s, not as its word is said (%s)" % [runs["grind"]["t0"], f.said0[si]])
	_ok(absf(float(runs["drop"]["t1"]) - float(runs["drop"]["t0"]) - 2.0) < 0.01, "the uncued act before it does not run its own length")
	var spread_after := 0
	for a in parse["actions"]:
		if String((a as Dictionary)["kind"]) == "spread":
			spread_after = int((a as Dictionary)["after"])
	var last_word := f.said1[spread_after - 1]
	_ok(absf(float(runs["settle"]["t1"]) - last_word) < 0.05, "the under act does not leave the act after it the end of the beat: settle ends %s, the beat's last word %s" % [runs["settle"]["t1"], last_word])
	_ok(absf(float(runs["settle"]["t0"]) - float(runs["grind"]["t1"])) < 0.01, "the act after an under one does not start where it ends")
	# the control: the cue moved one word on is not found at the first word
	_ok(absf(float(runs["grind"]["t0"]) - f.said0[si + 1]) > 0.1, "the control: the cue is as near the next word as its own")
	m._root3.free()
	return true


func _safe() -> bool:
	var made := Motions.sanitize_acts({"acts": [
		{"name": "no-beat", "length": 2, "tracks": [{"thing": "x", "law": "to", "state": "glow", "value": 1}]},
		{"name": "bad-law", "beat": 1, "tracks": [{"thing": "x", "law": "teleport"}]},
		{"name": "kept", "beat": "close", "tracks": [{"thing": "x", "part": "y", "law": "swing", "amount": "10 * sin(t)", "period": 2}]}]}, 3)
	var names: Array = (made["acts"] as Array).map(func(a: Dictionary) -> String: return String(a["name"]))
	_ok(names == ["kept"], "made safe, the acts kept are %s, not [kept]" % str(names))
	_ok((made["notes"] as PackedStringArray).size() >= 2, "what was left out was not said: %s" % str(made["notes"]))
	# a formula in a law is kept compiled, and held to the law's range
	var amount: Variant = (((made["acts"] as Array)[0] as Dictionary)["tracks"][0] as Dictionary)["amount"]
	_ok(amount is Dictionary and absf(Motions.num(amount, {"t": PI / 2.0}) - 10.0) < 1e-4, "a law's formula is not worked: %s" % str(amount))
	# A THING HOLDING A FLAME IS NEVER MOVED WHOLE
	var m := _medium()
	var spec := {"things": [{"name": "candle", "parts": [{"shape": "lathe", "profile": [[0, 0], [1, 0], [1, 8], [0, 8]], "material": "wax", "wick": true}]}],
		"materials": {"wax": {"kind": "wax", "color": "#eee6d0"}}}
	var safe := Props.sanitize(spec, [])
	var b := Props.build(safe["things"][0], safe["materials"], 3)
	b["wicks"] = [Vector3(0, 0.08, 0)]
	var node: Node3D = b["node"]
	m._props.add_child(node)
	m._work.take(safe["things"][0], b, node)
	m._work.build({"acts": [{"name": "move-candle", "beat": 1, "length": 2, "tracks": [{"thing": "candle", "law": "carry", "to": [10, 0, 0]}]}]}, 1)
	_ok((m._work.acts as Array).is_empty() and "\n".join(m._work.notes).contains("flame"), "a lit candle was carried: %s" % str(m._work.notes))
	m._root3.free()
	return true
