extends SceneTree

## The gate of [Winds] and [Drifts] - the table's wind and what it carries - with no renderer.
##
##   godot --headless --path . --script res://tests/table/drifts_check.gd
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
## - A CARD COMING DOWN ON ONE BLOWS IT ASIDE (the user, 2026-10-11: a card laid on the table "clipped
##   through a leaf that had fallen" there): told a card is set down over a leaf that lies still, the
##   leaf is out from under it before the card is down, never jumping, and lies clear of it after - on
##   the table, the same whenever it is asked - against the same leaf with no card told of, which is
##   still there; and a card set down elsewhere moves nothing.
## - A WASH'S CARDS SHOVE WHAT LIES (the user, 2026-10-14: a petal on the table was "completely
##   unaffected by the card-washing: cards are clipping through the petals"): rows of cards slid across
##   the whole cloth, and no piece lying there is under one at any time sampled - shoved ahead of it,
##   ridden up on its face, or flicked over it - against the same pieces with the cards not told of,
##   most of which are; the pieces are moved, lie on the table after, never jump, and the same whenever
##   asked. A piece carried on a card is on it (the user: one "keeps following the card even while it is
##   NOT TOUCHING"): those a card's face high are within its edge, near enough all the time.
## - A PIECE HAS MOMENTUM (the user, same day: it "probably needs a little bit of momentum, such that
##   when the underlying card moves - the petal is shaken off of it"): a card that slides in under a piece
##   and is drawn off gently carries it along, and the same card hauled harder than any piece grips leaves
##   it behind, lying on the cloth within a few centimeters of where it lay - never carried on beside the
##   card (the user: one slid off "yet remain attached"). tests/table/wash_drift_check.gd holds the same
##   under the real wash's cards.
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
	for check in [_wind, _sanitize, _drift, _often, _ways, _cards, _laid, _washed, _shaken]:
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
	# A GUST LIFTS WHAT IT BLOWS ALONG: no skid hops more than its slope of the way it goes (a piece that
	# goes nowhere rises nowhere), and one carried off climbs along a slant, never straight up
	var steep := 0
	var skids := 0
	for l in pop["lives"]:
		for s in (l as Dictionary).get("segs", []):
			var d: Dictionary = s
			if String(d["kind"]) == "skid":
				skids += 1
				var run := (d["from"] as Vector3).distance_to(d["to"])
				if run < 0.01 or float(d["hop"]) > Drifts.HOP_SLOPE * run + 1e-6:
					steep += 1
			elif String(d["kind"]) == "off":
				for k in 40:
					var at := float(d["t"]) + 0.05 * k
					var a: Vector3 = Drifts._off_pos(pop, l, d, at)
					var run := Vector2(a.x - (d["from"] as Vector3).x, a.z - (d["from"] as Vector3).z).length()
					if a.y - (d["from"] as Vector3).y > Drifts.HOP * 2.0 * (1.0 - exp(-run / Drifts.OFF_RUN)) + 1e-5 \
							and at < float(d["edge"]):
						steep += 1
						break
	_ok(steep == 0, "%d lifts rose without being blown along (of %d skids)" % [steep, skids])
	# BOTH ARE POSSIBLE: how high a gust lifts follows how hard it blows past the grip - a carry-off's
	# rise is the same scale as a skid's hop, and the gusts here do not all lift to the full height
	var wrong := 0
	var gentle := 0
	var carried := 0
	for l in pop["lives"]:
		for s in (l as Dictionary).get("segs", []):
			var d: Dictionary = s
			if String(d["kind"]) == "off":
				carried += 1
				var want := Drifts._hop(pop["wind"], int(d["gust"]), float((l as Dictionary)["grip"])) * 2.0
				wrong += 0 if absf(float(d["rise"]) - want) < 1e-6 else 1
				gentle += 1 if float(d["rise"]) < Drifts.HOP * 2.0 - 1e-6 else 0
	_ok(wrong == 0, "%d carry-offs rose to a height their gust does not give" % wrong)
	print("    carried off %d, of which %d lifted less than the full height" % [carried, gentle])
	_ok(gentle > 0, "every carry-off rose to the full height, whatever the gust")
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


## A card set down at [param t] and lying at [param at] (xz), as the air's `lay` moments say it.
func _lay(t: float, at: Vector2) -> Dictionary:
	return {"t": t, "dur": 0.2, "path": [[t, Transform3D(Basis.IDENTITY, Vector3(at.x, 0.001, at.y))]]}


func _laid() -> bool:
	var still := {"from": "left", "strength": 0.0, "gusts": 0.0, "every": 60}
	var fx := {"look": "leaves", "every": 600, "shake": 0, "settle": 1.0, "grip": 1.0, "lying": 12}
	var pop := _pop(fx, still)
	var control := _pop(fx, still)
	var down := 40.0
	# the first leaf lying: a card comes down with its middle a little off the leaf
	var lies: Vector3 = Drifts.pose(pop, (pop["lives"] as Array)[0], 1.0).origin
	var card := Vector2(lies.x + 0.01, lies.z - 0.02)
	var half := Vector2(TablePositions.CARD.x, TablePositions.CARD.y) * 0.5
	var under := func(p: Vector3) -> bool: return absf(p.x - card.x) < half.x and absf(p.z - card.y) < half.y
	Drifts.at(pop, 60.0)
	Drifts.laid(pop, [_lay(down, card)])
	Drifts.laid(control, [_lay(down, Vector2(card.x, card.y + 5.0))])
	var lv: Dictionary = (pop["lives"] as Array)[0]
	_ok(under.call(Drifts.pose(pop, lv, down - 2.0).origin), "before the card comes the leaf did not lie where it lay")
	var clear := true
	var t := down - Drifts.ASIDE.y
	while t < down + 30.0:
		clear = clear and not under.call(Drifts.pose(pop, lv, t).origin)
		t += 0.25
	_ok(clear, "the leaf is under the card as it comes down or after")
	var rests: Vector3 = Drifts.pose(pop, lv, down + 5.0).origin
	var table: AABB = pop["table"]
	_ok(absf(rests.y - lies.y) < 1e-4 and rests.x > table.position.x and rests.x < table.end.x
		and rests.z > table.position.z and rests.z < table.end.z and rests.distance_to(lies) < 0.2,
		"blown aside, the leaf does not lie on the table near where it lay (%s from %s)" % [str(rests), str(lies)])
	var worst := 0.0
	var prev: Vector3 = Drifts.pose(pop, lv, down - 1.5).origin
	t = down - 1.5
	while t < down + 0.5:
		t += 1.0 / 60.0
		var now: Vector3 = Drifts.pose(pop, lv, t).origin
		worst = maxf(worst, now.distance_to(prev))
		prev = now
	_ok(worst < 0.012, "the leaf jumps as it goes aside (%.1f mm in a frame)" % (worst * 1000.0))
	# PURE: told of the card first and asked after, the same
	var fresh := _pop(fx, still)
	Drifts.laid(fresh, [_lay(down, card)])
	_ok(str(Drifts.at(fresh, down + 3.0).map(func(p: Dictionary) -> String: return str(p["xf"])))
		== str(Drifts.at(pop, down + 3.0).map(func(p: Dictionary) -> String: return str(p["xf"]))),
		"the pieces after the card is down depend on when the card was told of")
	# THE CONTROL: no card there, and the leaf stays - under where the card would be
	var kept: Dictionary = (control["lives"] as Array)[0]
	_ok(under.call(Drifts.pose(control, kept, down + 5.0).origin) and Drifts.pose(control, kept, down + 5.0).origin.is_equal_approx(lies),
		"the control: with the card set down elsewhere the leaf moved")
	return true


## ROWS OF CARDS sliding across the whole cloth from [param w0] for eight seconds, as the table's wash
## [method TableShuffle.sweeps] hands them: seven rows, from off the cloth on one side to off it on the other,
## each card five floats a frame - its middle, its turn, how spread out it is (gone off the cloth for the
## last half second) and its place in the order.
func _rows(w0: float) -> Dictionary:
	var frames := 161
	var n := 7
	var data := PackedFloat32Array()
	data.resize(frames * n * 5)
	for f in frames:
		for k in n:
			var o := (f * n + k) * 5
			data[o] = lerpf(-0.8, 0.8, float(f) / float(frames - 1))
			data[o + 1] = -0.36 + 0.12 * float(k)
			data[o + 2] = 0.0
			data[o + 3] = 1.0 if f < 150 else -1.0
			data[o + 4] = float(k)
	return {"t": w0, "hz": 20.0, "cards": n, "frames": frames, "data": data}


## Whether a piece at [param o] is under one of [param sw]'s cards at [param t] - on the cloth (not up on
## a card's face, a card's thickness above it), inside the card's edge by more than a millimeter.
func _under_wash(sw: Dictionary, o: Vector3, base: float, t: float) -> bool:
	if o.y > base + 0.0001 or t < float(sw["t"]):
		return false
	var data: PackedFloat32Array = sw["data"]
	var n := int(sw["cards"])
	var f := clampf((t - float(sw["t"])) * float(sw["hz"]), 0.0, float(int(sw["frames"]) - 1))
	var half := Vector2(TablePositions.CARD.x, TablePositions.CARD.y) * 0.5 - Vector2.ONE * 0.001
	for k in n:
		var a := (int(f) * n + k) * 5
		if data[a + 3] < 0.0:
			continue
		var l := Drifts._local(Vector2(o.x, o.z), Vector2(data[a], data[a + 1]), data[a + 2])
		if absf(l.x) < half.x and absf(l.y) < half.y:
			return true
	return false


## Whether [param o] (xz) is within [param slack] of the face of a card of [param sw] on the cloth at [param t].
func _on_wash(sw: Dictionary, o: Vector3, t: float, slack: float) -> bool:
	var data: PackedFloat32Array = sw["data"]
	var n := int(sw["cards"])
	var f := clampf((t - float(sw["t"])) * float(sw["hz"]), 0.0, float(int(sw["frames"]) - 1))
	var half := Vector2(TablePositions.CARD.x, TablePositions.CARD.y) * 0.5 + Vector2.ONE * slack
	for k in n:
		var a := (int(f) * n + k) * 5
		if data[a + 3] < 0.0:
			continue
		var l := Drifts._local(Vector2(o.x, o.z), Vector2(data[a], data[a + 1]), data[a + 2])
		if absf(l.x) <= half.x and absf(l.y) <= half.y:
			return true
	return false


func _washed() -> bool:
	var still := {"from": "left", "strength": 0.0, "gusts": 0.0, "every": 60}
	var fx := {"look": "petals", "every": 600, "shake": 0, "settle": 1.0, "grip": 1.0, "lying": 12}
	var w0 := 10.0
	var sw := _rows(w0)
	var pop := _pop(fx, still)
	var control := _pop(fx, still)
	var fresh := _pop(fx, still)
	for p in [pop, control, fresh]:
		Drifts.at(p, 60.0)
	var lives: Array = pop["lives"]
	_ok(lives.size() >= 8, "only %d pieces lie to be washed" % lives.size())
	var was: Array = []
	for lv in lives:
		was.append(Drifts.pose(pop, lv, 1.0).origin)
	Drifts.laid(pop, [], [sw])
	Drifts.laid(fresh, [], [sw])
	var table: AABB = pop["table"]
	var under := 0
	var under_control := 0
	var worst := 0.0
	var moved := 0
	var airborne := 0
	var carried := 0
	var adrift := 0
	for i in lives.size():
		var lv: Dictionary = lives[i]
		var base := float((((lv["planned"] as Dictionary)["segs"] as Array)[0] as Dictionary)["from"].y)
		var prev: Vector3 = Drifts.pose(pop, lv, w0 - 1.0).origin
		var t := w0 - 1.0
		while t < w0 + 14.0:
			t += 1.0 / 60.0
			var o: Vector3 = Drifts.pose(pop, lv, t).origin
			worst = maxf(worst, o.distance_to(prev))
			prev = o
			airborne += 1 if o.y > base + 0.004 else 0
			if o.y > base + 0.0005 and o.y < base + 0.0009 and t >= w0 and t < w0 + 7.5:
				# up on a card's face (a card's thickness and the clearance over it): its middle is within
				# the card's edge, and the margin it came on with
				carried += 1
				if not _on_wash(sw, o, t, 0.006):
					adrift += 1
			if int(round(t * 60.0)) % 2 == 0:
				under += 1 if _under_wash(sw, o, base, t) else 0
				under_control += 1 if _under_wash(sw, Drifts.pose(control, control["lives"][i], t).origin, base, t) else 0
		var after: Vector3 = Drifts.pose(pop, lv, w0 + 14.0).origin
		_ok(absf(after.y - base) < 1e-3 and after.x > table.position.x and after.x < table.end.x
			and after.z > table.position.z and after.z < table.end.z, "piece %d does not lie on the table after the wash (%s)" % [i, str(after)])
		moved += 1 if Vector2(after.x - (was[i] as Vector3).x, after.z - (was[i] as Vector3).z).length() > 0.02 else 0
	_ok(under == 0, "%d times a piece was under a washed card" % under)
	_ok(under_control > 20, "the control: with the cards not told of, pieces were under one only %d times" % under_control)
	_ok(moved * 2 >= lives.size(), "only %d of %d pieces were moved by a wash that crossed the whole cloth" % [moved, lives.size()])
	_ok(airborne > 0, "no piece was ever lifted: a wash only slid them")
	_ok(carried > 30, "no piece was ever carried on a card (%d samples)" % carried)
	_ok(adrift * 10 <= carried, "%d of %d samples of a piece carried on a card were off every card's edge" % [adrift, carried])
	_ok(worst < 0.03, "a piece jumps %.1f mm in a frame" % (worst * 1000.0))
	# PURE: told of the wash before the piece was asked at all, the same
	var same := true
	for t in [9.0, 12.3, 17.7, 25.0]:
		same = same and str(Drifts.at(fresh, t).map(func(p: Dictionary) -> String: return str(p["xf"]))) \
			== str(Drifts.at(pop, t).map(func(p: Dictionary) -> String: return str(p["xf"])))
	_ok(same, "the pieces under a wash depend on when it was told of")
	return true


## A card for each of [param at] (the middles; [param slot] the card's place in the wash, the rest kept
## off the cloth): it slides in along x from beside the piece until it lies under it - easing in and
## out, so it takes the piece on as a card can, edge first - rests, and from [param w0] + 1.5 s is hauled
## on along x at [param a] m/s each second: wash [param sw]'s own format.
func _hauled(at: Array, slot: Array, a: float, w0: float) -> Dictionary:
	var frames := 81
	var n := 0
	for k in slot:
		n = maxi(n, int(k) + 1)
	var data := PackedFloat32Array()
	data.resize(frames * n * 5)
	var come := TablePositions.CARD.x * 0.5 + 0.02
	for f in frames:
		var v := float(f) / 20.0
		for k in n:
			var o := (f * n + k) * 5
			data[o] = 9.0
			data[o + 1] = 9.0
			data[o + 3] = -1.0
		for i in at.size():
			var o := (f * n + int(slot[i])) * 5
			var e := clampf(v / 1.0, 0.0, 1.0)
			var h := maxf(v - 1.5, 0.0)
			data[o] = (at[i] as Vector3).x - come * (1.0 - e * e * (3.0 - 2.0 * e)) + 0.5 * a * h * h
			data[o + 1] = (at[i] as Vector3).z
			data[o + 2] = 0.0
			data[o + 3] = 1.0
			data[o + 4] = float(i)
	return {"t": w0, "hz": 20.0, "cards": n, "frames": frames, "data": data}


## Whether the card in place [param k] of the wash lets piece [param lv] ride when it meets it (its die).
func _lets_ride(pop: Dictionary, lv: Dictionary, k: int) -> bool:
	var dice: Array = lv.get("dice", [0, 0])
	var u := Drifts._dice(pop, int(dice[0]), int(dice[1]), "card %d" % k).randf()
	return u >= Drifts.SHOVE_ODDS.x and u < Drifts.SHOVE_ODDS.y


func _shaken() -> bool:
	var still := {"from": "left", "strength": 0.0, "gusts": 0.0, "every": 60}
	var fx := {"look": "petals", "every": 600, "shake": 0, "settle": 1.0, "grip": 1.0, "lying": 30}
	var w0 := 10.0
	var rode := 0
	var kept := 0
	var left := 0
	var dragged := 0
	var tried := 0
	for a in [0.3, 16.0]:
		var pop := _pop(fx, still)
		Drifts.at(pop, 60.0)
		# a card to a piece, none of them in another's way: lanes a card's length and more apart, each
		# piece its own card, one whose die lets it ride
		var picks: Array = []
		var spots: Array = []
		var slots: Array = []
		for i in (pop["lives"] as Array).size():
			var o: Vector3 = Drifts.pose(pop, pop["lives"][i], 1.0).origin
			if spots.all(func(q: Vector3) -> bool: return absf(q.z - o.z) > TablePositions.CARD.y):
				var k := 0
				while slots.has(k) or not _lets_ride(pop, pop["lives"][i], k):
					k += 1
				picks.append(i)
				spots.append(o)
				slots.append(k)
		_ok(picks.size() >= 4, "only %d pieces lie in lanes of their own" % picks.size())
		var sw := _hauled(spots, slots, a, w0)
		Drifts.laid(pop, [], [sw])
		for k in picks.size():
			var lv: Dictionary = pop["lives"][picks[k]]
			var base := float((((lv["planned"] as Dictionary)["segs"] as Array)[0] as Dictionary)["from"].y)
			var lay: Vector3 = Drifts.pose(pop, lv, w0 + 1.5).origin
			if a < 1.0:
				# taken on, and drawn gently: it goes with the card (the card is a long way on by now)
				var t := w0 + 1.5 + 0.8
				var o: Vector3 = Drifts.pose(pop, lv, t).origin
				var up: bool = o.y > base + 0.0003 and _on_wash(sw, o, t, 0.0)
				rode += 1 if lay.y > base + 0.0003 else 0
				kept += 1 if up and Vector2(o.x - lay.x, o.z - lay.z).length() > 0.05 else 0
			else:
				# hauled hard, the card goes on without it: it slides off its back edge and lies on the
				# cloth near where it lay - never carried on beside the card
				var o: Vector3 = Drifts.pose(pop, lv, w0 + 4.0).origin
				tried += 1
				left += 1 if absf(o.y - base) < 0.0002 and not _on_wash(sw, o, w0 + 4.0, 0.0) else 0
				dragged += 1 if Vector2(o.x - lay.x, o.z - lay.z).length() > 0.04 else 0
	print("    taken onto a card %d, carried by one drawn gently %d; left by one hauled hard %d of %d" % [rode, kept, left, tried])
	_ok(rode >= 2, "only %d pieces were taken onto a card that lets them ride" % rode)
	_ok(kept == rode, "of %d carried, only %d went with a card drawn gently" % [rode, kept])
	_ok(left == tried, "only %d of %d pieces were left lying on the cloth by a card hauled hard" % [left, tried])
	_ok(dragged == 0, "%d pieces went on with a card hauled harder than any piece grips" % dragged)
	return true
