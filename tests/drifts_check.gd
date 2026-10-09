extends SceneTree

## The gate of [Winds] and [Drifts] - the table's wind and what it carries - with no renderer.
##
##   godot --headless --path . --script res://tests/drifts_check.gd
##
## - THE WIND: the same wind and seed plan the same gusts; how far the air has carried a thing (closed
##   form) is the integral of its speed, summed in small steps - against a carry missing the breeze's
##   swells, which is not; gusts come about as often as asked; a still wind's gusts are gentler than a
##   gusty one's; its strength stays 0-1. Nothing written is `{}`, and a written one is kept in range.
## - MADE SAFE: an unknown look is dropped, numbers clamped, a wrong `from` is "above"; at most
##   MAX_DRIFTS in one air ([method Effects.sanitize]).
## - PURE: the pieces at a time are the same asked first or after a later time.
## - RARE: a piece every minute or so comes loose about that often - against one every six seconds, ten
##   times as many; and a gust shakes some loose (with the breeze's own put off, all start in a gust).
##   Some land on the table and lie on its top, at the cloth's height.
## - THEIR WAYS: a look's pieces fall in more than one way; one tumbling turns over and over, one falling
##   flat stays near level in still air - and a gust turns a flat one over, against one no gust can.
## - NEVER ON OR UNDER THE CARDS: with the table saying where cards lie (its `cover`), no piece comes
##   down there or lies there uncovered - against the same without it, which lands some there.
## - NEVER THROUGH A THING: no piece, at any time sampled, is inside a thing standing on the table or in
##   the table under its top - against a fall aimed through a thing, which the check finds.
## - GUSTS LIFT what lies: with a light grip on a gusty wind some lying pieces are carried off the table,
##   and with grip 1 none ever is.
## - SMOOTH: no piece jumps between one frame and the next, landing, lying, skidding or carried off.
## - LYING when the reading begins: as many as asked, on the table.

var _fails := 0


func _init() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		print("  FAIL: " + what)


func _run() -> void:
	for check in [_wind, _sanitize, _drift, _often, _ways, _cards]:
		var done: Variant = await (check as Callable).call()
		_ok(done == true, "%s stopped part way (a script error - see above)" % (check as Callable).get_method())
	print("drifts_check: %s (%d failure%s)" % ["ALL OK" if _fails == 0 else "FAILED", _fails, "" if _fails == 1 else "s"])
	quit(1 if _fails > 0 else 0)


func _wind() -> bool:
	var w := Winds.sanitize({"from": "left", "strength": 0.5, "gusts": 0.9, "every": 12})
	var a := Winds.plan(w, 7)
	var b := Winds.plan(w, 7)
	_ok(str(a["starts"]) == str(b["starts"]) and str(a["peaks"]) == str(b["peaks"]), "the same wind and seed plan other gusts")
	# THE CARRY IS THE INTEGRAL OF THE SPEED
	var dt := 0.01
	var sum := Vector2.ZERO
	var swells_only := 0.0
	var t := 0.0
	while t < 120.0:
		var mid := t + dt * 0.5
		var gv := Vector2.ZERO
		var span := Winds._blowing(a, mid)
		for i in range(span.x, span.y):
			gv += (a["dirs"] as PackedVector2Array)[i] * (a["peaks"] as PackedFloat32Array)[i] * Winds.swell(a, i, mid)
		sum += ((a["dir"] as Vector2) * Winds.breeze_at(a, mid) + gv) * dt
		swells_only += (Winds.breeze_at(a, mid) - float(a["breeze"])) * dt
		t += dt
	var closed := Winds.carried(a, 120.0)
	_ok(closed.distance_to(sum) < 0.01, "carried %s, summed %s" % [str(closed), str(sum)])
	# the control: without the breeze's swells the carry is off by their run
	var plain: Vector2 = closed - (a["dir"] as Vector2) * swells_only
	_ok(plain.distance_to(sum) > 0.01, "a carry missing the swells still matches (%.3f m of swells)" % swells_only)
	var n := 0
	for s in (a["starts"] as PackedFloat32Array):
		n += 1 if s < 1200.0 else 0
	_ok(n > 1200.0 / 12.0 * 0.7 and n < 1200.0 / 12.0 * 1.4, "%d gusts in 1200 s, every 12 asked" % n)
	var still := Winds.plan({}, 7)
	var most_still := 0.0
	for p in (still["peaks"] as PackedFloat32Array):
		most_still = maxf(most_still, p)
	var most := 0.0
	for p in (a["peaks"] as PackedFloat32Array):
		most = maxf(most, p)
	_ok(most_still < most * 0.5, "still air gusts %.2f m/s, a gusty breeze %.2f" % [most_still, most])
	for i in 400:
		var s := Winds.strength_at(a, float(i) * 0.37)
		if s < 0.0 or s > 1.0:
			_ok(false, "the wind's strength %.2f is out of 0-1" % s)
			break
	_ok(Winds.sanitize(null).is_empty() and Winds.sanitize({}).is_empty(), "no wind written is not {}")
	var odd := Winds.sanitize({"from": "upward", "strength": 9, "every": 0})
	_ok(float(odd["strength"]) == 1.0 and float(odd["every"]) >= 4.0, "a wind out of range was kept: %s" % str(odd))
	return true


func _sanitize() -> bool:
	_ok(Drifts.sanitize({"look": "confetti"}).is_empty(), "an unknown look was kept")
	_ok(Drifts.sanitize({"look": "blossoms"}).is_empty(), "whole flowers still fall")
	var d := Drifts.sanitize({"look": "Petals", "from": "sideways", "every": 0, "shake": 50, "size": 2, "grip": 3, "lying": -4})
	_ok(String(d["look"]) == "petals" and String(d["from"]) == "above" and float(d["every"]) == Drifts.EVERY.y and float(d["shake"]) == Drifts.SHAKE.y,
		"made safe: %s" % str(d))
	_ok(float(d["size"]) == (Drifts.LOOKS["petals"]["sizes"] as Vector2).x and float(d["grip"]) == 1.0 and int(d["lying"]) == 0, "not clamped: %s" % str(d))
	var many := Effects.sanitize([{"kind": "drift", "look": "leaves"}, {"kind": "drift", "look": "seeds"}, {"kind": "drift", "look": "petals"}],
		["#ffffff"], CardTable.AIR.keys(), CardTable.MOMENTS.keys())
	_ok(many.size() == Drifts.MAX_DRIFTS, "%d drifts in one air" % many.size())
	return true


## A card table's stage: its camera, the table, one thing on it, and what covers the cloth when [param cover]
## says.
func _stage(wind: Dictionary, cover := Callable()) -> Dictionary:
	var cam := Transform3D(Basis.looking_at(Vector3(0.0, -0.45, -0.6), Vector3.UP), Vector3(0.0, 0.45, 0.55))
	var table := AABB(Vector3(-0.95, -0.75, -0.45), Vector3(1.9, 0.75, 0.9))
	return {"regions": CardTable.AIR, "camera": cam, "fov": 42.0, "aspect": 16.0 / 9.0,
		"occluders": [table, AABB(Vector3(0.2, 0.0, -0.3), Vector3(0.12, 0.18, 0.12))], "wind": Winds.plan(wind, 3), "cover": cover}


func _pop(fx: Dictionary, wind: Dictionary, cover := Callable()) -> Dictionary:
	var root := Node3D.new()
	get_root().add_child(root)
	var pop := Drifts.build(Drifts.sanitize(fx), _stage(wind, cover), 99, root)
	return pop


func _drift() -> bool:
	var breeze := {"from": "left", "strength": 0.35, "gusts": 0.9, "every": 10}
	var pop := _pop({"look": "petals", "every": 8, "shake": 3, "settle": 1.0, "grip": 0.2, "lying": 6}, breeze)
	var t_build := Time.get_ticks_msec()
	Drifts.at(pop, 300.0)
	print("  planned 302 s of petals in %d ms, %d lives" % [Time.get_ticks_msec() - t_build, (pop["lives"] as Array).size()])
	# PURE: asked late first, then early - the same as asked early first
	var fresh := _pop({"look": "petals", "every": 8, "shake": 3, "settle": 1.0, "grip": 0.2, "lying": 6}, breeze)
	Drifts.at(pop, 300.0)
	var late_first := Drifts.at(pop, 37.3)
	var early := Drifts.at(fresh, 37.3)
	_ok(late_first.size() == early.size() and str(late_first.map(func(p: Dictionary) -> String: return str(p["xf"]))) == str(early.map(func(p: Dictionary) -> String: return str(p["xf"]))),
		"the pieces at 37.3 s depend on what was asked before (%d against %d)" % [late_first.size(), early.size()])
	var rest_y := float(pop["rest_y"])
	var table: AABB = pop["table"]
	var thing: AABB = (pop["things"] as Array)[0]
	# IN THE AIR, LYING, NEVER THROUGH A THING, SMOOTH
	var airborne := 0.0
	var frames := 0
	var through := 0
	var jumps := 0
	var lying_seen := 0
	var prev := {}
	var t := 0.0
	while t < 240.0:
		var now := {}
		var lives: Array = pop["lives"]
		var bin: Array = (pop["bins"] as Dictionary).get(floori(t / Drifts.BIN), [])
		for id in bin:
			var lv: Dictionary = lives[int(id)]
			if t < float(lv["t0"]) or t >= float(lv["end"]):
				continue
			var xf := Drifts.pose(pop, lv, t)
			now[int(id)] = xf.origin
			if t < float(lv["t1"]):
				airborne += 1.0
			elif absf(xf.origin.y - rest_y) < 0.004:
				lying_seen += 1
			if thing.grow(-0.002).has_point(xf.origin) or (xf.origin.y < rest_y - 0.004 and table.grow(-0.002).has_point(xf.origin)):
				through += 1
				if through <= 4:
					print("    through at %.2f: %s %s, t0 %.2f t1 %.2f end %.2f segs %s" % [t, str(xf.origin), "thing" if thing.has_point(xf.origin) else "table", float(lv["t0"]), float(lv["t1"]), float(lv["end"]), str((lv.get("segs", []) as Array).map(func(z: Dictionary) -> String: return "%s %.2f-%.2f" % [z["kind"], z["t"], z["end"]]))])
			if prev.has(int(id)) and (prev[int(id)] as Vector3).distance_to(xf.origin) > 0.12:
				jumps += 1
				if jumps <= 4:
					print("    jump at %.2f: %s -> %s, t0 %.2f t1 %.2f end %.2f segs %s" % [t, str(prev[int(id)]), str(xf.origin), float(lv["t0"]), float(lv["t1"]), float(lv["end"]), str((lv.get("segs", []) as Array).map(func(z: Dictionary) -> String: return "%s %.2f-%.2f" % [z["kind"], z["t"], z["end"]]))])
		prev = now
		frames += 1
		t += 1.0 / 30.0
	_ok(airborne > 0.0, "nothing was ever in the air")
	_ok(lying_seen > 0, "nothing ever lay on the table")
	_ok(through == 0, "%d times a piece was inside a thing or the table" % through)
	_ok(jumps == 0, "%d jumps between frames" % jumps)
	# the control: a fall aimed straight down through the thing is found
	var lv := Drifts._body(pop, RandomNumberGenerator.new())
	lv["t0"] = 0.0
	lv["fall"] = 0.5
	lv["sway"] = 0.0
	lv["c"] = 0.0
	lv["p0"] = Vector3(thing.get_center().x, 1.0, thing.get_center().z)
	lv["t1"] = INF
	_ok(Drifts._hits(pop, lv, rest_y), "a fall straight through the thing was not found")
	# GUSTS LIFT what lies - and with grip 1, nothing ever does
	var offs := 0
	for l in pop["lives"]:
		for s in (l as Dictionary).get("segs", []):
			offs += 1 if String((s as Dictionary)["kind"]) == "off" else 0
	_ok(offs > 0, "no gust carried anything off a light grip")
	var held := _pop({"look": "petals", "every": 8, "shake": 3, "settle": 1.0, "grip": 1.0, "lying": 6}, breeze)
	Drifts.at(held, 240.0)
	var lifted := 0
	for l in held["lives"]:
		var segs: Array = (l as Dictionary).get("segs", [])
		if bool((l as Dictionary).get("settled", true)) and segs.size() > 1:
			lifted += 1
	_ok(lifted == 0, "%d pieces lifted at grip 1" % lifted)
	# LYING when the reading begins
	var at0 := 0
	for l in pop["lives"]:
		if float((l as Dictionary)["t0"]) <= -Lights.HORIZON:
			var p: Vector3 = Drifts.pose(pop, l, 0.0).origin
			at0 += 1 if absf(p.y - rest_y) < 0.004 and Drifts._on_top(pop, Vector2(p.x, p.z)) else 0
	_ok(at0 == 6, "%d of 6 lying on the table at the start" % at0)
	return true


## How many pieces of [param pop] start between [param a] and [param b].
func _started(pop: Dictionary, a: float, b: float) -> int:
	Drifts.at(pop, b)
	var n := 0
	for l in pop["lives"]:
		n += 1 if float((l as Dictionary)["t0"]) >= a and float((l as Dictionary)["t0"]) < b else 0
	return n


func _often() -> bool:
	var still := {"from": "left", "strength": 0.3, "gusts": 0.0, "every": 20}
	var rare := _started(_pop({"look": "petals", "every": 60, "shake": 0}, still), 0.0, 600.0)
	var thick := _started(_pop({"look": "petals", "every": 6, "shake": 0}, still), 0.0, 600.0)
	print("  in ten minutes: %d petals at one a minute, %d at one every six seconds" % [rare, thick])
	_ok(rare >= 4 and rare <= 22, "%d petals started in ten minutes at one a minute" % rare)
	_ok(thick >= rare * 5, "one every six seconds started %d, against %d" % [thick, rare])
	# A GUST SHAKES SOME LOOSE: with the breeze's own ten minutes apart, nearly all start in a gust
	var gusty := {"from": "left", "strength": 0.6, "gusts": 1.0, "every": 15}
	var pop := _pop({"look": "petals", "every": 600, "shake": 4}, gusty)
	Drifts.at(pop, 600.0)
	var wind: Dictionary = pop["wind"]
	var in_gust := 0
	var all := 0
	for l in pop["lives"]:
		var t0 := float((l as Dictionary)["t0"])
		if t0 < 0.0 or t0 >= 600.0:
			continue
		all += 1
		for i in (wind["starts"] as PackedFloat32Array).size():
			var span := Winds.gust_span(wind, i)
			if t0 >= span.x - 1.0 and t0 <= span.x + span.y:
				in_gust += 1
				break
	_ok(all >= 10 and in_gust >= all - 1, "%d of %d shaken loose in a gust" % [in_gust, all])
	return true


## How far from level [param b]'s face is (radians).
func _tilt(b: Basis) -> float:
	return b.orthonormalized().y.angle_to(Vector3.UP)


func _ways() -> bool:
	var pop := _pop({"look": "petals", "every": 6, "shake": 0}, {"from": "left", "strength": 0.3, "gusts": 0.0, "every": 20})
	Drifts.at(pop, 600.0)
	var ways := {}
	for l in pop["lives"]:
		ways[String((l as Dictionary)["way"])] = true
	_ok(ways.size() >= 3, "petals fall only %s" % str(ways.keys()))
	var r := RandomNumberGenerator.new()
	r.seed = 5
	# ONE TUMBLING turns over and over; ONE FLAT stays near level in still air
	var calm := Winds.plan({"from": "left", "strength": 0.0, "gusts": 0.0, "every": 20}, 1)
	var flat := Drifts._body(pop, r)
	flat.merge({"way": "flat", "t0": 0.0, "p0": Vector3(0.0, 1.0, 0.0), "rock": 0.1, "tumble": 0.0, "twirl": 0.0, "whirl": 5.0}, true)
	var tumbling := flat.duplicate()
	tumbling.merge({"way": "tumble", "tumble": 7.0}, true)
	var still_pop := pop.duplicate()
	still_pop["wind"] = calm
	var most_flat := 0.0
	var most_tumble := 0.0
	for i in 60:
		var t := float(i) * 0.05
		most_flat = maxf(most_flat, _tilt(Drifts._falling_basis(still_pop, flat, t)))
		most_tumble = maxf(most_tumble, _tilt(Drifts._falling_basis(still_pop, tumbling, t)))
	_ok(most_flat < 0.4, "a flat piece tipped %.2f rad in still air" % most_flat)
	_ok(most_tumble > 2.5, "a tumbling piece turned only %.2f rad" % most_tumble)
	# A GUST TURNS A FLAT ONE OVER - against one no gust turns
	var wind: Dictionary = pop["wind"]
	var gusty := Winds.plan({"from": "left", "strength": 0.5, "gusts": 1.0, "every": 10}, 4)
	var g := Winds.gust_span(gusty, 0)
	var in_gust := pop.duplicate()
	in_gust["wind"] = gusty
	flat["t0"] = g.x
	var calm_one := flat.duplicate()
	calm_one["whirl"] = 0.0
	var turned := 0.0
	var unturned := 0.0
	for i in 60:
		var t := g.x + g.y * float(i) / 59.0
		turned = maxf(turned, _tilt(Drifts._falling_basis(in_gust, flat, t)))
		unturned = maxf(unturned, _tilt(Drifts._falling_basis(in_gust, calm_one, t)))
	_ok(turned > 1.5, "a gust turned a flat piece only %.2f rad" % turned)
	_ok(unturned < 0.4, "with no whirl, a flat piece still tipped %.2f rad in a gust" % unturned)
	return true


## WHERE CARDS LIE in this check: a spread of them, the deck among them, from the start.
const SPREAD := Rect2(-0.35, -0.15, 0.45, 0.3)
const SPREAD_TOP := 0.031


func _cards() -> bool:
	var gusty := {"from": "left", "strength": 0.35, "gusts": 0.9, "every": 10}
	var cover := func(p: Vector2, _t: float, r: float) -> float:
		return SPREAD_TOP if SPREAD.grow(r).has_point(p) else -INF
	var covered := _pop({"look": "petals", "every": 6, "shake": 3, "settle": 1.0, "grip": 0.2, "lying": 20}, gusty, cover)
	var bare := _pop({"look": "petals", "every": 6, "shake": 3, "settle": 1.0, "grip": 0.2, "lying": 20}, gusty)
	var counts: Array = []
	for pop in [covered, bare]:
		Drifts.at(pop, 300.0)
		var rest_y := float(pop["rest_y"])
		var on := 0
		var t := 0.0
		while t < 300.0:
			for l in pop["lives"]:
				var lv: Dictionary = l
				if t < float(lv["t0"]) or t >= float(lv["end"]):
					continue
				var o := Drifts.pose(pop, lv, t).origin
				if SPREAD.has_point(Vector2(o.x, o.z)) and o.y < rest_y + SPREAD_TOP:
					on += 1
			t += 0.5
		counts.append(on)
	_ok(int(counts[0]) == 0, "%d times a piece was on or under the cards" % int(counts[0]))
	_ok(int(counts[1]) > 0, "the control: with no cover, no piece ever came down where the cards are")
	return true
