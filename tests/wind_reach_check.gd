extends SceneTree

## The gate of THE WIND'S REACH ([Winds]): what the light's wind does to everything in the air beside
## the petals - flames, lamps, motes, bursts and fog - with no renderer.
##
##   godot --headless --path . --script res://tests/wind_reach_check.gd
##
## - ONLY A WIND THE LIGHT WROTE moves anything: still air planned for what drifts moves no flame, no
##   lamp, no mote, no particle, no fog - motes stand exactly where they stand with no wind at all.
##   Two-sided: the same population in a written wind is moved.
## - THE WIND'S VELOCITY is what [method Winds.carried] sums (a numeric integral agrees), and its EDDIES
##   churn about it by [constant Winds.TURBULENCE] of its speed - alike a centimeter apart, unlike two
##   meters apart.
## - A FLAME LEANS as tan(tilt) = the draft over its draw: a candle by about that, sheltered by glass hardly
##   at all, guttering only in a strong gust; a torch's taller flame leans less than a candle's in the same
##   air, a lantern hardly; an electric lamp has no flame. A flame stands in a hurricane glass, not beside a
##   candelabra's stem, nor in its own wax.
## - WHAT RIDES THE AIR is carried downwind at the air's speed and comes round again, so the shot holds about
##   as many as it did; WHAT FLIES holds its place in a breeze it can beat, is carried off by a gust past its
##   strength and flies home after. Two-sided: the same mote with no airspeed is carried off by the breeze,
##   and with a huge one is not moved by the gust. Asked twice, a mote is where it was.
## - A BURST'S PARTICLE is born with the air's run at its birth, and the shader's closed form for a
##   particle slowed toward the wind (mirrored here) follows a stepped integration of the same drag within a
##   centimeter. Two-sided: without the lag still to make up it misses by many. In still air the run is
##   zero (else every particle would be thrown a meter by the old column).
## - FOG rolls with the wind instead of its own drift.

var _fails := 0


func _init() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		print("  FAIL: " + what)


func _run() -> void:
	for check in [_written, _velocity, _eddies, _flames, _shelter, _carried, _fliers, _bursts, _fog]:
		var done: Variant = (check as Callable).call()
		_ok(done == true, "%s stopped part way (a script error - see above)" % (check as Callable).get_method())
	print("wind_reach_check: %s (%d failure%s)" % ["ALL OK" if _fails == 0 else "FAILED", _fails, "" if _fails == 1 else "s"])
	quit(1 if _fails > 0 else 0)


## A stage like the card table's (as effects_check builds it), in [param wind].
func _stage(wind: Variant) -> Dictionary:
	var lay := CardTable.layout_of(1234)
	var cam: Transform3D = lay["camera"]
	var table := AABB(Vector3(-0.95, -0.05, -0.405), Vector3(1.9, 0.05, 0.85))
	var out := {"regions": CardTable.AIR, "camera": cam, "fov": float(lay["fov"]), "aspect": 16.0 / 9.0,
		"occluders": [table], "sharp": Vector2(0.4, 1.4), "defocus": 0.0, "deep": 2.88}
	if wind != null:
		out["wind"] = wind
	return out


func _clean(raw: Array) -> Array:
	return Effects.sanitize(raw, ["#102030"], CardTable.AIR.keys(), CardTable.MOMENTS.keys())


## A steady breeze from the reader's left, no gusts.
func _breeze(strength: float) -> Dictionary:
	return Winds.plan(Winds.sanitize({"from": "left", "strength": strength, "gusts": 0.0, "every": 30}), 11)


func _written() -> bool:
	_ok(Winds.blows(_breeze(0.5)), "a written wind does not blow")
	_ok(not Winds.blows(Winds.plan({}, 3)), "still air planned for what drifts blows")
	_ok(not Winds.blows({}), "no plan blows")
	# MOTES IN STILL AIR stand where they stand with no wind at all
	var fx := _clean([{"kind": "motes", "look": "dust", "where": "over the cloth", "count": 6},
		{"kind": "motes", "look": "pixie", "where": "over the cloth", "count": 6}])
	var none := Effects.build(fx, _stage(null), 9)
	var still := Effects.build(fx, _stage(Winds.plan({}, 3)), 9)
	var blown := Effects.build(fx, _stage(_breeze(0.6)), 9)
	var same := true
	var moved := 0.0
	for k in 2:
		for i in 6:
			for t in [0.0, 7.5, 31.0]:
				var a: Vector3 = Effects.mote_at(none.motes[k], none.motes[k]["each"][i], t)["pos"]
				var b: Vector3 = Effects.mote_at(still.motes[k], still.motes[k]["each"][i], t)["pos"]
				var c: Vector3 = Effects.mote_at(blown.motes[k], blown.motes[k]["each"][i], t)["pos"]
				same = same and a.is_equal_approx(b)
				moved = maxf(moved, a.distance_to(c))
	_ok(same, "motes in still air (no wind written) are not where they are with no wind at all")
	_ok(moved > 0.05, "a written wind moved no mote (at most %.3f m)" % moved)
	# NOR A LAMP'S FLAME, NOR A BURST'S AIR
	_ok(Lights.flame_in_wind("candles", Winds.plan({}, 3), 4.0, Vector3(1, 0.3, 1)).is_empty(), "a lamp's flame leans in still air")
	_ok(still.wind.is_empty() and not blown.wind.is_empty(), "the air's wind is not the written one alone")
	none.release()
	still.release()
	blown.release()
	return true


func _velocity() -> bool:
	var p := Winds.plan(Winds.sanitize({"from": "back left", "strength": 0.6, "gusts": 1.0, "every": 8}), 5)
	var sum := Vector2.ZERO
	var dt := 0.01
	for i in 9000:
		sum += Winds.velocity_at(p, (float(i) + 0.5) * dt) * dt
	var closed := Winds.carried(p, 90.0)
	_ok(sum.distance_to(closed) < 0.01 * closed.length() + 0.01, "the wind's velocity does not sum to its carry: %s against %s" % [sum, closed])
	return true


func _eddies() -> bool:
	var p := _breeze(0.6)
	var at := Vector3(0.1, 0.1, -0.1)
	var n := 4000
	var mean := Vector2.ZERO
	var sq := 0.0
	var speed := 0.0
	for i in n:
		var t := float(i) * 0.11
		var a := Winds.air_at(p, t, at)
		var v := Winds.velocity_at(p, t)
		var d := Vector2(a.x, a.z) - v
		mean += d
		sq += d.length_squared() * 0.5
		speed += v.length()
	mean /= float(n)
	var sd := sqrt(sq / float(n))
	var want := Winds.TURBULENCE * speed / float(n)
	_ok(absf(sd - want) < 0.35 * want, "the eddies churn by %.3f m/s, not %.3f (the turbulence of the wind's speed)" % [sd, want])
	_ok(mean.length() < 0.25 * want, "the eddies lean one way: %s" % mean)
	# ALIKE NEARBY, UNLIKE FAR OFF
	var near := _corr(p, at, at + Vector3(0.008, 0.0, 0.004))
	var far := _corr(p, at, at + Vector3(2.0, 0.0, 1.5))
	_ok(near > 0.8, "two places a centimeter apart feel unlike eddies (%.2f)" % near)
	_ok(far < 0.35, "two places 2.5 m apart feel the same eddies (%.2f)" % far)
	return true


## How alike the eddies at [param a] and [param b] are over time: the correlation of their across-wind part.
func _corr(p: Dictionary, a: Vector3, b: Vector3) -> float:
	var xs := PackedFloat32Array()
	var ys := PackedFloat32Array()
	for i in 1500:
		var t := float(i) * 0.13
		xs.append(Winds.eddy(p, t, a).z)
		ys.append(Winds.eddy(p, t, b).z)
	var mx := 0.0
	var my := 0.0
	for i in xs.size():
		mx += xs[i]
		my += ys[i]
	mx /= float(xs.size())
	my /= float(xs.size())
	var sxy := 0.0
	var sxx := 0.0
	var syy := 0.0
	for i in xs.size():
		sxy += (xs[i] - mx) * (ys[i] - my)
		sxx += (xs[i] - mx) * (xs[i] - mx)
		syy += (ys[i] - my) * (ys[i] - my)
	return sxy / sqrt(maxf(sxx * syy, 1e-12))


func _flames() -> bool:
	var p := _breeze(0.5)
	var at := Vector3(0.0, 0.05, 0.0)
	var tilt := 0.0
	var tilt_glass := 0.0
	var want := 0.0
	var dim := 1.0
	var n := 600
	for i in n:
		var t := float(i) * 0.37
		var f := Winds.flame(p, t, at, 0.03)
		tilt += acos(clampf((f["axis"] as Vector3).y, -1.0, 1.0))
		tilt_glass += acos(clampf((Winds.flame(p, t, at, 0.03, 0.1)["axis"] as Vector3).y, -1.0, 1.0))
		want += atan(Winds.velocity_at(p, t).length() / sqrt(9.81 * 0.03))
		dim = minf(dim, float(f["bright"]))
	tilt /= float(n)
	tilt_glass /= float(n)
	want /= float(n)
	_ok(absf(tilt - want) < 0.25 * want + 0.03, "a candle in a breeze leans %.0f degrees, not about %.0f" % [rad_to_deg(tilt), rad_to_deg(want)])
	_ok(tilt > deg_to_rad(10.0), "a candle in a breeze hardly leans (%.0f degrees)" % rad_to_deg(tilt))
	_ok(tilt_glass < 0.3 * tilt, "a candle under glass leans %.0f degrees, as much as one in the open (%.0f)" % [rad_to_deg(tilt_glass), rad_to_deg(tilt)])
	_ok(dim > 0.9, "a candle gutters in a mere breeze (%.2f)" % dim)
	# A STRONG GUST guts it
	var gale := Winds.plan(Winds.sanitize({"from": "right", "strength": 1.0, "gusts": 1.0, "every": 6}), 2)
	var worst := 1.0
	var leaned := 0.0
	for i in 2000:
		var f := Winds.flame(gale, float(i) * 0.05, at, 0.03)
		worst = minf(worst, float(f["bright"]))
		leaned = maxf(leaned, acos(clampf((f["axis"] as Vector3).y, -1.0, 1.0)))
	_ok(worst < 0.75, "a candle never gutters in a gale (dimmest %.2f)" % worst)
	_ok(leaned <= Winds.FLAME_TILT + 1e-4 and leaned > 1.0, "a candle in a gale leans %.2f radians" % leaned)
	# LAMPS: a torch's tall flame leans less, a lantern's glass keeps it off, a lamp has no flame
	var lamp_at := Vector3(1.2, 0.6, 0.4)
	var candle := 0.0
	var torch := 0.0
	var lantern := 0.0
	for i in 300:
		var t := float(i) * 0.41
		candle += (Lights.flame_in_wind("candles", p, t, lamp_at)["mid"] as Vector3).length() / 0.03
		torch += (Lights.flame_in_wind("torch", p, t, lamp_at)["mid"] as Vector3).length() / 0.2
		lantern += (Lights.flame_in_wind("lantern", p, t, lamp_at)["mid"] as Vector3).length() / 0.03
	_ok(torch < 0.7 * candle, "a torch's flame leans as far as a candle's in the same air (%.2f against %.2f)" % [torch, candle])
	_ok(lantern < 0.3 * candle, "a lantern's flame leans as far as an open candle's (%.2f against %.2f)" % [lantern, candle])
	_ok(Lights.flame_in_wind("lamp", p, 3.0, lamp_at).is_empty(), "an electric lamp has a flame in the wind")
	return true


func _shelter() -> bool:
	var node := Node3D.new()
	var inner := Node3D.new()
	inner.scale = Vector3(0.5, 0.5, 0.5)
	node.add_child(inner)
	node.position = Vector3(0.2, 0.0, -0.1)
	# a hurricane glass, 8 cm across and 30 cm tall (halved by its inner scale), round a wick 5 cm up
	var glass := _cylinder(0.08, 0.3, Vector3(0.0, 0.15, 0.0))
	inner.add_child(glass)
	var wick := node.position + Vector3(0.0, 0.05, 0.0)
	_ok(Props.open_to_air(wick, node, [glass]) <= Props.SHELTER.y + 1e-4, "a candle in a hurricane glass is open to the air (%.2f)" % Props.open_to_air(wick, node, [glass]))
	# a candelabra's stem beside the flame, and the candle's own wax under it
	var stem := _cylinder(0.04, 0.6, Vector3(0.0, 0.3, 0.0))
	inner.add_child(stem)
	var arm := node.position + Vector3(0.12, 0.2, 0.0)
	_ok(is_equal_approx(Props.open_to_air(arm, node, [stem]), 1.0), "a candelabra's stem shelters its arm's flame")
	var wax := _cylinder(0.05, 0.1, Vector3(0.0, 0.05, 0.0))
	inner.add_child(wax)
	_ok(Props.open_to_air(wick, node, [wax]) > 0.95, "a candle's own wax shelters its flame (%.2f)" % Props.open_to_air(wick, node, [wax]))
	node.free()
	return true


func _cylinder(width: float, height: float, at: Vector3) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = width * 0.5
	m.bottom_radius = width * 0.5
	m.height = height
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.position = at
	return mi


func _carried() -> bool:
	var p := _breeze(0.6)
	var fx := _clean([{"kind": "motes", "look": "dust", "where": "over the cloth", "count": 30, "away": 0.0}])
	var stage := _stage(p)
	var air := Effects.build(fx, stage, 4)
	var pop: Dictionary = air.motes[0]
	var d: Vector2 = p["dir"]
	# DOWNWIND AT THE AIR'S SPEED, between its comings round
	var along := 0.0
	var v := 0.0
	for m in pop["each"]:
		for i in 40:
			var t := 3.0 + float(i) * 2.0
			var a: Dictionary = Effects._blown(pop, m, t)
			var b: Dictionary = Effects._blown(pop, m, t + 0.2)
			var step := (b["off"] as Vector3) - (a["off"] as Vector3)
			# a step that came round is not one
			if step.length() < 0.4 * minf((m["spans"] as Vector2).x, (m["spans"] as Vector2).y):
				along += Vector2(step.x, step.z).dot(d) / 0.2 / float(m["carry"])
				v += Winds.velocity_at(p, t + 0.1).length()
	_ok(absf(along - v) < 0.1 * v, "dust rides downwind at %.0f%% of the air's speed" % (100.0 * along / maxf(v, 1e-6)))
	# THE SHOT KEEPS ABOUT AS MANY: seen and bright, at the start and long after
	var seen := func(t: float) -> float:
		var s := 0.0
		for m in pop["each"]:
			var at: Dictionary = Effects.mote_at(pop, m, t)
			var sp: Variant = Effects._screen(stage, at["pos"])
			if sp != null and (sp as Vector2).x > 0.0 and (sp as Vector2).x < 1.0 and (sp as Vector2).y > 0.0 and (sp as Vector2).y < 1.0:
				s += float(at["bright"])
		return s
	var first: float = seen.call(0.0)
	var later := 0.0
	for k in 12:
		later += float(seen.call(120.0 + float(k) * 37.0)) / 12.0
	_ok(first > 3.0 and later > 0.5 * first and later < 1.5 * first, "the shot held %.1f motes' worth of dust at the start and %.1f in the wind later" % [first, later])
	air.release()
	return true


func _fliers() -> bool:
	# A BREEZE IT CAN BEAT moves a pixie barely, and a dust mote (no airspeed) a lot
	var calm := _breeze(0.5)
	var fx := _clean([{"kind": "motes", "look": "pixie", "where": "over the cloth", "count": 4}])
	var air := Effects.build(fx, _stage(calm), 8)
	var pop: Dictionary = air.motes[0]
	var most := 0.0
	for m in pop["each"]:
		for i in 30:
			most = maxf(most, ((Effects._blown(pop, m, 20.0 + float(i) * 3.1)["off"]) as Vector3).length())
	_ok(most < 0.12, "a pixie in a breeze it can beat is pushed %.2f m" % most)
	var ride: Dictionary = pop.duplicate()
	ride["look"] = (pop["look"] as Dictionary).merged({"airspeed": 0.0}, true)
	var m0: Dictionary = pop["each"][0]
	var rode := ((Effects._blown(ride, m0, 21.0)["off"] as Vector3) - (Effects._blown(ride, m0, 20.0)["off"] as Vector3)).length()
	_ok(rode > 0.15, "the same mote riding the air was carried only %.2f m in a second" % rode)
	# A GUST PAST ITS STRENGTH carries it off, and it flies home after
	var gale := Winds.plan(Winds.sanitize({"from": "right", "strength": 0.9, "gusts": 1.0, "every": 40}), 6)
	var g := Winds.next_gust(gale, 10.0, 1.5)
	_ok(g >= 0, "no gust past a pixie's strength to test with")
	if g < 0:
		air.release()
		return true
	var span := Winds.gust_span(gale, g)
	var windy := Effects.build(fx, _stage(gale), 8)
	var wp: Dictionary = windy.motes[0]
	var weak: Dictionary = wp["each"][0]
	for m in wp["each"]:
		if float(m["strong"]) < float(weak["strong"]):
			weak = m
	var off_peak := 0.0
	var held := 0.0
	var strong: Dictionary = wp.duplicate()
	strong["look"] = (wp["look"] as Dictionary).merged({"airspeed": 20.0}, true)
	for i in 40:
		var tg := span.x + span.y * float(i) / 39.0
		off_peak = maxf(off_peak, ((Effects._blown(wp, weak, tg)["off"]) as Vector3).length())
		held = maxf(held, ((Effects._blown(strong, weak, tg)["off"]) as Vector3).length())
	var off_after := ((Effects._blown(wp, weak, span.x + span.y + 8.0 / float((wp["look"] as Dictionary)["back"]))["off"]) as Vector3).length()
	_ok(off_peak > 0.4, "a gust of %.1f m/s pushed a pixie only %.2f m" % [float((gale["peaks"] as PackedFloat32Array)[g]), off_peak])
	_ok(off_after < 0.25 * off_peak, "a pixie did not fly home after the gust (%.2f m off, %.2f at the most)" % [off_after, off_peak])
	_ok(held < 0.3 * off_peak, "a flier far stronger than the gust was pushed %.2f m, against %.2f" % [held, off_peak])
	# ASKED TWICE - with the population's remembered wind and without - a mote is where it was
	var t := span.z
	wp["felt"] = {t: Winds.memory(gale, t, float((wp["look"] as Dictionary)["back"]))}
	var a: Vector3 = Effects.mote_at(wp, weak, t)["pos"]
	wp["felt"] = {}
	var b: Vector3 = Effects.mote_at(wp, weak, t)["pos"]
	_ok(a.is_equal_approx(b), "a pixie is not where it was when asked again")
	air.release()
	windy.release()
	return true


func _bursts() -> bool:
	var p := _breeze(0.7)
	var fx := _clean([{"kind": "burst", "look": "smoke", "on": "shuffle"}])
	var moments := {"shuffle": [{"t": 12.0, "dur": 0.5, "from": "point", "path": [[12.0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0))]]}]}
	var air := Effects.build(fx, _stage(p), 3)
	air.plan(moments)
	var mm: MultiMesh = (air.bursts[0]["layer"] as Dictionary)["mm"]
	var born := Effects.births(fx[0], moments["shuffle"], int(air.bursts[0]["salt"]))
	_ok(mm.instance_count == born.size() and born.size() > 0, "the burst holds %d particles of %d born" % [mm.instance_count, born.size()])
	var ok := true
	for i in mini(born.size(), 20):
		var c := Winds.carried(p, float(born[i]["born"]))
		var xf := Effects.particle_xform(born[i], air.wind)
		ok = ok and xf.basis.y.is_equal_approx(Vector3(c.x, 0.0, c.y)) and xf.basis.x == (born[i]["vel"] as Vector3) and xf.origin == (born[i]["pos"] as Vector3)
	_ok(ok, "a particle is not born with its place, its velocity and the air's run at its birth")
	var still := Effects.build(fx, _stage(Winds.plan({}, 3)), 3)
	_ok(Effects.particle_xform(born[0], still.wind).basis.y == Vector3.ZERO, "in still air a particle is born with a run")
	# THE SHADER'S CLOSED FORM against a stepped integration of the same drag
	var look: Dictionary = Effects.BURSTS["smoke"]
	var k := float(look["drag"])
	var gravity := Vector3(0.0, float(look["gravity"]), 0.0)
	var worst := 0.0
	var worst_nolag := 0.0
	for i in mini(born.size(), 8):
		var b0: Dictionary = born[i]
		var t0 := float(b0["born"])
		var life := float(b0["life"])
		var pos: Vector3 = b0["pos"]
		var vel: Vector3 = b0["vel"]
		var dt := 0.0005
		var t := t0
		while t < t0 + life:
			var va := Winds.velocity_at(p, t + dt * 0.5)
			vel += (gravity - k * (vel - Vector3(va.x, 0.0, va.y))) * dt
			pos += vel * dt
			t += dt
		var closed := _shader_pos(b0, t, k, gravity, p, true)
		worst = maxf(worst, closed.distance_to(pos))
		worst_nolag = maxf(worst_nolag, _shader_pos(b0, t, k, gravity, p, false).distance_to(pos))
	_ok(worst < 0.01, "the shader's carried particle misses the stepped one by %.3f m" % worst)
	_ok(worst_nolag > 5.0 * maxf(worst, 0.002), "the lag term changes nothing (%.3f m without, %.3f with)" % [worst_nolag, worst])
	air.release()
	still.release()
	return true


## Where shaders/effect_sprite.gdshaderinc puts burst particle [param b] at [param t]: line for line.
func _shader_pos(b: Dictionary, t: float, k: float, gravity: Vector3, p: Dictionary, lag: bool) -> Vector3:
	var age := t - float(b["born"])
	var e := exp(-k * age)
	var v0: Vector3 = b["vel"]
	var pos: Vector3 = (b["pos"] as Vector3) + v0 * (1.0 - e) / k + gravity * (age - (1.0 - e) / k) / k
	var c0 := Winds.carried(p, float(b["born"]))
	var c := Winds.carried(p, t)
	var v := Winds.velocity_at(p, t)
	pos += Vector3(c.x - c0.x, 0.0, c.y - c0.y) - (Vector3(v.x, 0.0, v.y) * (1.0 - e) / k if lag else Vector3.ZERO)
	return pos


func _fog() -> bool:
	var fx := _clean([{"kind": "fog", "where": "beyond the table", "drift": 0.8}])
	var blown := Effects.build(fx, _stage(_breeze(0.5)), 1)
	var still := Effects.build(fx, _stage(null), 1)
	var bw: Vector3 = (blown.fogs[0]["mat"] as ShaderMaterial).get_shader_parameter("wind")
	var sw: Vector3 = (still.fogs[0]["mat"] as ShaderMaterial).get_shader_parameter("wind")
	_ok(is_zero_approx(bw.x) and is_zero_approx(bw.z) and sw.x > 0.05, "fog keeps its own drift in a wind (%s), or loses it in still air (%s)" % [bw, sw])
	blown.tick(30.0)
	still.tick(30.0)
	var bc: Vector3 = (blown.fogs[0]["mat"] as ShaderMaterial).get_shader_parameter("carried")
	var sc: Variant = (still.fogs[0]["mat"] as ShaderMaterial).get_shader_parameter("carried")
	_ok(bc.length() > 1.0, "the wind did not carry the fog (%s)" % bc)
	_ok(sc == null or (sc as Vector3) == Vector3.ZERO, "still air carried the fog (%s)" % sc)
	blown.release()
	still.release()
	return true
