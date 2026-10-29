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
## - A MOVE GOES ON THROUGH ITS PLACES (181083: the snowmelt's vial "started, and stopped ... about 4 times"): a path
##   through keys going on the same way, and carries one after another, do not stop between, and end where they end
##   with nothing overshot. The controls: a key a path holds at, and carries a pause apart, stop.
## - THE WORK AS A LIVE READING'S WORDS ARRIVE (181083, live: "absolute chaos"; scrubbed back, right): words arriving a
##   sentence at a time ahead of a voice slower than the plan's estimate plan every act where the words known up front
##   do, and nothing moved jumps in a frame (a pestle lying apart stays put while its mortar is carried). The control:
##   the estimate taken for the words not yet heard begins acts before their words.
## - A SCRUBBED READING'S CLOCK KEEPS THE READING'S TIME (181083: its chronometer began at 4:00 again): begun ten
##   minutes in, a running hour hand stands as ten minutes in has it; the control, from the top, at its start.
## - A POUR IS THE TIP'S: tests/table/physics_check.gd holds it (a vessel tipped until its liquid reaches its rim pours by
##   itself, next/table_physics.md).
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
	for check in [_formula, _clock, _clock_law, _grind, _at_the_spot, _seated, _set_down, _carry, _through_keys, _copies, _cued,
			_live_words, _safe, _write]:
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
	# A SCRUBBED READING'S CLOCK KEEPS THE READING'S TIME (181083: scrubbed back into the work, its chronometer began at
	# 4:00 again while the voice said "four oh four"): begun ten minutes in, the hour hand stands where ten minutes into
	# the video has it - the control, from the top, stands at three
	m._work.since = 600.0
	m._work.tick(0.0)
	var scrubbed := _turned(by["hour hand"])
	m._work.since = 0.0
	m._work.tick(0.0)
	_ok(absf(scrubbed - 95.0) < 0.05, "a reading begun ten minutes in shows the hour hand at %s degrees, not 95: its clock began again" % scrubbed)
	_ok(absf(_turned(by["hour hand"]) - 90.0) < 0.01, "the control: from the top, the hour hand is not at three: %s" % _turned(by["hour hand"]))
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
	# BROUGHT TO WHERE IT GRINDS WITHOUT A JUMP (181083: its pestle leapt 6 cm up in a frame as the grind began - the
	# hand's lift switched on whole as the law's place moved 2 cm off): frame by frame through the blend
	var pnode: Node3D = (m._work.works[pw] as Dictionary)["node"]
	var leap := 0.0
	var was := Vector3.INF
	for i in int((TableWork.BLEND_IN + 0.6) * 30.0):
		m._work.tick(float(g[0]) + float(i) / 30.0)
		var at: Vector3 = m._work._world_of(pnode).origin
		if was != Vector3.INF:
			leap = maxf(leap, at.distance_to(was))
		was = at
	_ok(leap < 0.012, "the pestle jumps %.1f cm in a frame as it is brought to where it grinds" % (leap * 100.0))
	# ...and the hand's lift grows with how far it has to go, never in a step: half a millimeter further never lifts it
	# more than 3 mm higher. The control: from where the law has it, no lift; from far off, a hand's whole lift
	var steepest := 0.0
	for k in 200:
		steepest = maxf(steepest, absf(TableWork.blend_lift(0.5, float(k + 1) * 0.0005) - TableWork.blend_lift(0.5, float(k) * 0.0005)))
	_ok(steepest < 0.003, "the hand's lift jumps %.1f cm for half a millimeter further to go" % (steepest * 100.0))
	var peak := Hands.LIFT_SHAPE.x / (Hands.LIFT_SHAPE.x + Hands.LIFT_SHAPE.y)
	_ok(TableWork.blend_lift(peak, 0.0) == 0.0 and is_equal_approx(TableWork.blend_lift(peak, 0.1), TableWork.BLEND_LIFT),
		"the control: the lift is not none from where the law has it and a hand's whole from far off")
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


## A MOVE GOES ON THROUGH ITS PLACES (the-quiet-crucible 181083: the snowmelt's vial, carried the low way, "started, and
## stopped, and started, and stopped ... about 4 times"): a path through keys that go on the same way does not stop at
## them, nor a run of carries at the places where one ends and the next begins. The controls: a key the path holds at
## stops it there, and carries with a pause between them stop between.
func _through_keys() -> bool:
	var m := _medium()
	var spec := {"things": [{"name": "jar", "parts": [{"shape": "lathe", "profile": [[0, 0], [3, 0], [3, 8], [0, 8]], "material": "glass"}]}],
		"materials": {"glass": {"kind": "ceramic", "color": "#5a7a6a"}}}
	var jar: Node3D = _stand(m, spec, "jar", Vector3(Tables.ORIGIN.x - 0.2, 0.0, Tables.ORIGIN.y))["node"]
	var carry := func(to: Array, between: Array) -> Dictionary:
		return {"thing": "jar", "law": "carry", "to": to, "lift": 0, "between": between}
	m._work.build({"acts": [
		{"name": "on", "beat": 1, "length": 6, "tracks": [{"thing": "jar", "law": "path",
			"keys": [{"at": 0.0}, {"at": 0.3, "by": [6, 3, 0]}, {"at": 0.6, "by": [12, 3, 0]}, {"at": 1.0, "by": [18, 0, 0]}]}]},
		{"name": "held", "beat": 1, "length": 6, "tracks": [{"thing": "jar", "law": "path",
			"keys": [{"at": 0.0}, {"at": 0.3, "by": [-6, 3, 0]}, {"at": 0.5, "by": [-6, 3, 0]}, {"at": 1.0, "by": [-18, 0, 0]}]}]},
		{"name": "carried-on", "beat": 1, "length": 6, "tracks": [carry.call([-14, 4, 0], [0.0, 0.33]), carry.call([-8, 4, 0], [0.33, 0.66]),
			carry.call([-2, 4, 0], [0.66, 1.0])]},
		{"name": "carried-apart", "beat": 1, "length": 6, "tracks": [carry.call([-8, 4, 0], [0.0, 0.3]), carry.call([-14, 4, 0], [0.4, 0.66]),
			carry.call([-20, 4, 0], [0.66, 1.0])]}]}, 1)
	_ok((m._work.acts as Array).size() == 4, "the moves were not all kept: %s" % "; ".join(m._work.notes))
	if (m._work.acts as Array).size() != 4:
		m._root3.free()
		return true
	m._work.runs = [{"i": 0, "t0": 10.0, "t1": 16.0}, {"i": 1, "t0": 30.0, "t1": 36.0}, {"i": 2, "t0": 50.0, "t1": 56.0}, {"i": 3, "t0": 70.0, "t1": 76.0}]
	m._work._timelines()
	var speed := func(t: float) -> float:
		m._work.tick(t - 0.02)
		var a := jar.position
		m._work.tick(t + 0.02)
		return a.distance_to(jar.position) / 0.04
	var on_keys := minf(float(speed.call(10.0 + 0.3 * 6.0)), float(speed.call(10.0 + 0.6 * 6.0)))
	_ok(on_keys > 0.015, "a path stops at the keys it goes on through: %.1f cm a second there" % (on_keys * 100.0))
	# held still in the air, it is as still as a hand holds it: no faster than the hand's own drift ([method Hands.drift_most])
	var held := float(speed.call(30.0 + 0.4 * 6.0))
	_ok(held < Hands.drift_most(), "the control: a path does not hold at a key it holds at: %.1f cm a second" % (held * 100.0))
	var joins := minf(float(speed.call(50.0 + 0.33 * 6.0)), float(speed.call(50.0 + 0.66 * 6.0)))
	_ok(joins > 0.015, "carries one after another stop where one hands on to the next: %.1f cm a second there" % (joins * 100.0))
	var apart := float(speed.call(70.0 + 0.35 * 6.0))
	_ok(apart < 0.001, "the control: carries with a pause between them do not stop in it: %.1f cm a second" % (apart * 100.0))
	# ...and each still ends where it was taken, and goes nowhere past it
	m._work.tick(56.5)
	var end := Vector3(Tables.ORIGIN.x - 0.02, 0.04, Tables.ORIGIN.y)
	_ok(jar.position.distance_to(end) < 0.002, "carries gone on through do not end where the last one takes it: %s, not %s" % [jar.position, end])
	var widest := -INF
	for i in 61:
		m._work.tick(50.0 + float(i) * 0.1)
		widest = maxf(widest, jar.position.x)
	_ok(widest <= end.x + 0.0005, "carries gone on through overshoot their last place: %.1f cm past it" % ((widest - end.x) * 100.0))
	m._root3.free()
	return true


## A reading's words for [method _live_words]: a slow voice (a word 0.55 s, a sentence's rest 0.6 s) - every spoken
## word with its sentence.
static func _slow_words(parse: Dictionary) -> Array:
	var ends: Array = []
	for p in parse["passages"]:
		for w in String((p as Dictionary)["text"]).split(" ", false):
			for piece in String(w).split("\n", false):
				if not TabletScript.norm(piece).is_empty():
					ends.append(String(piece).ends_with(".") or String(piece).ends_with("?"))
	var rests := {}
	for a in parse["actions"]:
		rests[int((a as Dictionary)["after"])] = float((a as Dictionary)["dur"]) + 0.5
	var out: Array = []
	var t := 1.0
	var sentence := 0
	var spoken: PackedStringArray = parse["spoken"]
	for i in spoken.size():
		if rests.has(i):
			t += float(rests[i])
			sentence += 1
		out.append({"text": spoken[i], "t0": t, "t1": t + 0.45, "sentence": sentence})
		t += 0.55
		if i < ends.size() and bool(ends[i]):
			t += 0.6
			sentence += 1
	return out


## The bench [method _live_words] works: a mortar with its pestle lying apart in a corner of it, and a jar.
func _reading_bench() -> TableMedium:
	var m := _medium()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	m._plan.cam_base = CardTable.sample_layout(rng)["camera"]
	m._plan.cards_from = "none"
	var spec := _mortar_spec()
	var mortar: Dictionary = (spec["things"] as Array)[0]
	var pestle: Dictionary = ((((spec["things"] as Array)[1] as Dictionary)["parts"] as Array)[0] as Dictionary).duplicate(true)
	pestle["at"] = [16, 0, -6]
	pestle["turn"] = [0, 0, 90]
	pestle["points"] = {"tip": [16, 0.9, -6], "grip": [4, 0.9, -6]}
	mortar["parts"] = [(mortar["parts"] as Array)[0], (mortar["parts"] as Array)[1], pestle]
	(spec["things"] as Array).append({"name": "jar", "parts": [{"shape": "lathe", "profile": [[0, 0], [3, 0], [3, 8], [0, 8]], "material": "stone"}]})
	_stand(m, spec, "mortar", Vector3(Tables.ORIGIN.x - 0.3, 0.0, Tables.ORIGIN.y - 0.14))
	_stand(m, spec, "jar", Vector3(Tables.ORIGIN.x + 0.3, 0.0, Tables.ORIGIN.y - 0.14))
	m._work.build({"acts": [
		{"name": "fetch-mortar", "beat": 1, "length": 3, "tracks": [{"thing": "mortar", "law": "carry", "to": "work", "lift": 4}]},
		{"name": "fetch-jar", "beat": 1, "length": 3, "tracks": [{"thing": "jar", "law": "carry", "to": "work", "by": [14, 0, 0], "lift": 4}]},
		{"name": "take-pestle", "beat": 1, "length": 3, "tracks": [{"thing": "mortar", "part": "pestle", "law": "carry",
			"to": "mortar.floor", "by": [0, 7, 0], "turn": [0, 0, 0], "lift": 6}]},
		{"name": "grind", "beat": 1, "length": "under", "tracks": [{"thing": "mortar", "part": "pestle", "law": "aim",
			"tip": {"point": "tip", "around": "mortar.floor", "radius": 1.5, "period": 1.5, "press": "mortar", "gap": 0.3},
			"grip": {"point": "grip", "around": "mortar.floor", "lift": 12, "radius": 3.5, "period": 1.5}}]},
		{"name": "jar-home", "beat": 1, "length": 3, "tracks": [{"thing": "jar", "law": "carry", "lift": 4}]}]}, 1)
	return m


## THE WORK AS A LIVE READING'S WORDS ARRIVE (the-quiet-crucible 181083, live: "absolute chaos ... the green dish moved
## on top of the crucible, then floated back to its position ... tipped-over"; scrubbed back and played again, it was
## right): a reading's words arriving a sentence at a time, a few seconds before they are said, by a voice slower than
## the plan's estimate, plan every act exactly where the same words known from the first frame (an export's) do, and
## nothing the work moves jumps from one frame to the next - the pestle lying apart stays where it lies while its mortar
## is carried, though the act that takes it is not yet placed. The control: the estimate taken for words not yet heard,
## as the plan had taken it, begins acts before their words are said.
func _live_words() -> bool:
	var script := "\n\n".join(PackedStringArray([
		"<!-- table: shuffle -->", "Welcome back to the bench tonight. It is late, and the house is quiet, and the kettle has gone cold.",
		"<!-- table: draw 1 -->", "Here is the first card of the night. It asks for the mortar, and for the ink, and for a little patience.",
		"<!-- table: work 1 -->", "<!-- act: fetch-mortar --> First the mortar comes over to us. It is heavy, and cold to the touch. " +
			"<!-- act: fetch-jar --> Then the jar of ink comes over beside it. " +
			"<!-- act: take-pestle --> The pestle comes out of its corner, where it has been lying all evening. " +
			"<!-- act: grind --> And we grind it round and round, slowly, until it is soft and fine. " +
			"<!-- act: jar-home --> The jar goes back home now. That is all it needs from us tonight.",
		"<!-- table: spread -->", "And that is the brew for tonight. Sleep well."]))
	var parse := CardReading.parse(script)
	var spoken: PackedStringArray = parse["spoken"]
	var words := _slow_words(parse)
	var plan := TablePlan.new()
	plan.parse = parse
	plan.hold = 1.0
	var est := plan.estimated_times(spoken.size())
	var end := float((words.back() as Dictionary)["t1"]) + 2.0
	_ok(est[est.size() - 1] < end - 15.0, "the voice is not slower than the plan's estimate, as a hushed one is: %.0f s against %.0f" % [end, est[est.size() - 1]])
	var played := {}
	for mode in ["known", "arriving", "guessed"]:
		var m := _reading_bench()
		var f := ReadingFollower.new()
		f.reset(spoken)
		var heard: Array = []
		var next := 0
		if mode == "known":
			f.extend(words)
			m._work.schedule(f.place(parse["actions"], 1.0, TableMedium.LEAD, TableMedium.TAIL), parse, f.said0, f.said1, est, 0.0)
		var last := {}
		var most := 0.0
		var most_at := ""
		var t := 0.0
		while t < end:
			t += 1.0 / 30.0
			var arrived := false
			# a sentence's words come together, 3 s before its first is said
			while mode != "known" and next < words.size() and float((words[next] as Dictionary)["t0"]) - 3.0 <= t:
				var sn := int((words[next] as Dictionary)["sentence"])
				while next < words.size() and int((words[next] as Dictionary)["sentence"]) == sn:
					heard.append(words[next])
					next += 1
				arrived = true
			if arrived:
				f.extend(heard)
				var s0 := f.said0
				var s1 := f.said1
				if mode == "guessed":
					s0 = s0.duplicate()
					s1 = s1.duplicate()
					for i in s0.size():
						if s0[i] == ReadingFollower.NO_TIME:
							s0[i] = est[i]
							s1[i] = est[i] + 0.4
				m._work.schedule(f.place(parse["actions"], 1.0, TableMedium.LEAD, TableMedium.TAIL), parse, s0, s1, est, t)
			m._work.tick(t)
			var nodes: Array = (m._work.things as Array).map(func(th: Dictionary) -> Node3D: return th["node"])
			nodes.append_array((m._work.works as Array).map(func(wk: Dictionary) -> Node3D: return wk["node"]))
			for n in nodes:
				var at: Vector3 = m._work._world_of(n).origin
				if last.has(n):
					var step := at.distance_to(last[n])
					if step > most:
						most = step
						most_at = "%s at %.2f s" % [String(n.name), t]
				last[n] = at
		var runs := {}
		for r in m._work.runs:
			runs[String((m._work.acts[int((r as Dictionary)["i"])] as Dictionary)["name"])] = Vector2(float(r["t0"]), float(r["t1"]))
		played[mode] = {"runs": runs, "most": most, "at": most_at}
		m._root3.free()
	var known: Dictionary = played["known"]["runs"]
	var arriving: Dictionary = played["arriving"]["runs"]
	_ok(known.size() == 5, "the work's acts were not all planned from the words known up front: %s" % str(known.keys()))
	var off := 0.0
	for nm in known:
		var b: Vector2 = arriving.get(nm, Vector2(INF, INF))
		off = maxf(off, maxf(absf(b.x - (known[nm] as Vector2).x), absf(b.y - (known[nm] as Vector2).y)))
	_ok(off < 0.01, "as the words arrived the work was planned otherwise than from them all: %.2f s off\n  known up front %s\n  as they arrived %s" % [off, str(known), str(arriving)])
	for mode in ["known", "arriving"]:
		_ok(float(played[mode]["most"]) < 0.03, "%s: something the work moves jumped %.1f cm in a frame (%s)" % [mode, float(played[mode]["most"]) * 100.0, played[mode]["at"]])
	# the control: acts begun on the estimate begin before their words
	var cues := {}
	var f2 := ReadingFollower.new()
	f2.reset(spoken)
	f2.extend(words)
	for c in parse["cues"]:
		cues[String((c as Dictionary)["name"])] = f2.said0[int((c as Dictionary)["si"])]
	var early := 0.0
	for nm in (played["guessed"]["runs"] as Dictionary):
		if cues.has(nm):
			early = maxf(early, float(cues[nm]) - ((played["guessed"]["runs"] as Dictionary)[nm] as Vector2).x)
	_ok(early > 2.0, "the control: acts begun on the estimate did not begin before their words: at most %.1f s early" % early)
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


## WORDS ARE WRITTEN, NEVER LAID ON (the-quiet-crucible 707668's poison "name on a slip", a blank white square - the user:
## "The slip should show writing, if the script says it should"): a slip written "Mandrake" by an act is blank before
## it, half way through has its first letters down and not its last, and after it is written whole - its words in ink, on
## the slip's top. The controls: a `write` on a part that is no sheet is refused, and before the pen begins there are no
## words at all.
func _write() -> bool:
	var m := _medium()
	var spec := {"things": [{"name": "dish", "parts": [
		{"shape": "lathe", "profile": [[0, 0], [5, 0], [5, 1], [0, 1]], "material": "clay"},
		{"name": "slip", "shape": "sheet", "outline": "rect", "size": [4.2, 1.8], "material": "paper", "at": [0, 1.0, 0], "joint": {"kind": "free"}},
		{"name": "lid", "shape": "lathe", "profile": [[0, 0], [2, 0], [2, 0.3], [0, 0.3]], "material": "clay", "at": [8, 0, 0], "joint": {"kind": "free"}}]}],
		"materials": {"clay": {"kind": "ceramic", "color": "#8a6a4a"}, "paper": {"kind": "paper", "color": "#efe6d2"}}}
	var dish := _stand(m, spec, "dish", Vector3(0.2, 0.0, -0.1))
	m._work.build({"acts": [{"name": "name-it", "beat": 1, "length": 4, "tracks": [
		{"thing": "dish", "part": "slip", "law": "write", "text": "Mandrake", "between": [0.25, 0.75]},
		{"thing": "dish", "part": "lid", "law": "write", "text": "Lid"}]}]}, 1)
	m._work.runs = [{"i": 0, "t0": 10.0, "t1": 14.0}]
	m._work._timelines()
	_ok(" ".join(m._work.notes).contains("is not a sheet"), "the control: a write on the lid, no sheet, was not refused: %s" % "; ".join(m._work.notes))
	var wi := -1
	for i in m._work.works.size():
		if String((m._work.works[i] as Dictionary)["name"]) == "slip":
			wi = i
	var slip: Node3D = (m._work.works[wi] as Dictionary)["node"]
	m._work.tick(10.5)
	_ok(slip.get_node_or_null("written") == null, "the control: before the pen begins, the slip carries words")
	m._work.tick(12.0)
	var words: MeshInstance3D = slip.get_node_or_null("written")
	_ok(words != null, "half way through its write, the slip carries no words")
	if words == null:
		m._root3.free()
		return true
	var mat := words.material_override as ShaderMaterial
	_ok(absf(float(mat.get_shader_parameter("written")) - 0.5) < 0.02, "half way through its write, the pen has got %.2f of the way" % float(mat.get_shader_parameter("written")))
	# the picture: ink, put down left to right - what is down at 0.5 is the word's left half
	var img: Image = (mat.get_shader_parameter("words") as ImageTexture).get_image()
	var ink := 0
	var left := 0.0
	var right := 0.0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.r > 0.5:
				ink += 1
				if x < img.get_width() / 4:
					left = maxf(left, c.g)
				elif x > img.get_width() * 3 / 4:
					right = maxf(right, c.g)
	_ok(ink > 200 and left < 0.4 and right > 0.6, "the words' picture: %d points of ink, put down by %.2f at the left and %.2f at the right" % [ink, left, right])
	# on the slip's top, within it
	var box: AABB = ((m._work.works[wi] as Dictionary)["w"] as Dictionary)["box"]
	var lay := words.mesh.get_aabb()
	_ok(lay.position.x >= box.position.x and lay.end.x <= box.end.x and lay.position.z >= box.position.z and lay.end.z <= box.end.z
		and absf(lay.position.y - box.end.y) < 0.0005, "the words lie at %s, the slip at %s" % [lay, box])
	m._work.tick(15.0)
	_ok(is_equal_approx(float(mat.get_shader_parameter("written")), 1.0), "after its write, the slip's words are %.2f written" % float(mat.get_shader_parameter("written")))
	m._root3.free()
	return true

