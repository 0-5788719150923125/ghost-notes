extends SceneTree

## The gate of THE RIDE ([Rides]): a table aboard something that moves - the lens's give, what on the table
## moves with it, the flames and the sound - with no renderer.
##
##   godot --headless --path . --script res://tests/table/ride_check.gd
##
## - A TABLE THAT STANDS STILL HAS NO RIDE: nothing written plans none, the lens never moves and a moving
##   part stands as built. A ride the table does not know is said and left off.
## - EVERYTHING IS A FUNCTION OF SHOW TIME: the same ride and seed plan the same jolts; a pose asked out of
##   order is the pose asked in order; the jolts of two windows are the jolts of both.
## - THE RAILS KNOCK IN PAIRS: each joint is struck by the car's axles in turn, close pairs a long gap apart
##   (da-da ... da-da), once a joint's length of track.
## - THE LENS ONLY GIVES (the user: "not slow, gentle movement ... because the camera is mounted"): a faint
##   buzz - under a pixel and a half rms on a rough train - a jolt of a few pixels, never past its stop, and
##   none of the slow sway: the lens is the same with the sway taken out of the plan, where a swaying flower
##   (the control) is not.
## - A JOLT IS SEEN AND HEARD AT ONCE: the lens and a flower are still just before the hardest bump and moved
##   just after; the sound of the ride rises at that same moment - and the same place on another seed (the
##   control) does not.
## - EACH KIND ANSWERS AS IT IS: a taller stalk sways slower; a pendulum swings at sqrt(g/L); a needle swings
##   at a jolt and comes back to its north (the ride turning under it); small jolts never move a rock, and the
##   turns a hard one sets it down with stay near where it was put; a liquid stays level as the deck rolls
##   while what stands goes downhill; a flame leans toward the push.
## - BUILT: a moving group is one node round all its parts, a part moving inside it a node inside that, each
##   copy its own; at rest everything stands where the still build stands it, and turned, the vase stays and
##   the flower moves. A ROCK ROCKS ON ITS EDGE: tipped, its lowest point stays on the cloth - turned about its
##   middle (the control) it sinks through.
## - MADE SAFE: the table keeps its ride; a part keeps its move (a word or an object); a part with a flame
##   never moves; and the sound hears the ride the table plans.

var _fails := 0


func _init() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		print("  FAIL: " + what)


func _run() -> void:
	for check in [_still, _pure, _knocks, _lens, _at_once, _kinds, _built, _safe]:
		var done: Variant = (check as Callable).call()
		_ok(done == true, "%s stopped part way (a script error - see above)" % (check as Callable).get_method())
	print("ride_check: %s (%d failure%s)" % ["ALL OK" if _fails == 0 else "FAILED", _fails, "" if _fails == 1 else "s"])
	quit(1 if _fails > 0 else 0)


## A ride planned as the table and the sound plan it, on episode [param seed].
static func _plan(on: String, rough: float, speed := 0.7, seed := 11) -> Dictionary:
	return Rides.plan(Rides.sanitize({"on": on, "rough": rough, "speed": speed}), hash([seed, "ride"]))


## The hardest bump between [param t0] and [param t1]: its time, or -1.
static func _hardest(p: Dictionary, t0: float, t1: float) -> float:
	var best := -1.0
	var most := 0.0
	for j in Rides.jolts(p, t0, t1):
		if int(j[2]) == 0 and (j[1] as Vector3).length() > most:
			most = (j[1] as Vector3).length()
			best = float(j[0])
	return best


func _still() -> bool:
	_ok(Rides.plan(Rides.sanitize(null), 3).is_empty(), "nothing written plans a ride")
	var notes := PackedStringArray()
	_ok(Rides.sanitize({"on": "zeppelin"}, notes).is_empty() and notes.size() == 1, "a ride the table does not know was kept or not said: %s" % notes)
	for t in [0.0, 12.3, 400.0]:
		_ok(Rides.camera({}, t) == Vector3.ZERO, "the lens moves on a table that stands still")
	var r := Rides.responder({}, {"kind": "sway", "amount": 0.5}, 0.12, 4)
	var q := Rides.pose({}, {}, r, 30.0, Vector3.ZERO)
	_ok((q["lean"] as Vector2) == Vector2.ZERO and float(q["turn"]) == 0.0, "a flower sways on a table that stands still in still air: %s" % q)
	# ...and in a written wind it does (the control)
	var wind := Winds.plan(Winds.sanitize({"from": "left", "strength": 0.6, "gusts": 0.0, "every": 30}), 2)
	_ok((Rides.pose({}, wind, r, 30.0, Vector3.ZERO)["lean"] as Vector2).length() > 1e-4, "a flower does not stir in the table's wind")
	return true


func _pure() -> bool:
	var a := _plan("rails", 0.6)
	var b := _plan("rails", 0.6)
	_ok(a["starts"] == b["starts"] and a["kicks"] == b["kicks"], "the same ride on the same seed planned other jolts")
	_ok(_plan("rails", 0.6, 0.7, 12)["starts"] != a["starts"], "another seed planned the same jolts")
	var r := Rides.responder(a, {"kind": "sway", "amount": 0.5}, 0.12, 7)
	var times: Array = []
	for i in 200:
		times.append(20.0 + float(i) * 0.137)
	var in_order := {}
	for t in times:
		in_order[t] = Rides.pose(a, {}, r, t, Vector3.ZERO)["lean"]
	times.shuffle()
	var same := true
	for t in times:
		same = same and (Rides.pose(a, {}, r, t, Vector3.ZERO)["lean"] as Vector2).is_equal_approx(in_order[t])
	_ok(same, "a pose asked out of order is not the pose asked in order")
	var whole := Rides.jolts(a, 10.0, 90.0)
	var halves := Rides.jolts(a, 10.0, 47.3) + Rides.jolts(a, 47.3, 90.0)
	_ok(whole.size() == halves.size() and whole.size() > 40, "two windows' jolts are not the jolts of both: %d against %d" % [whole.size(), halves.size()])
	return true


func _knocks() -> bool:
	var p := _plan("rails", 0.5, 0.7)
	var row: Dictionary = Rides.ON["rails"]
	var v := float(row["top"]) * 0.7
	_ok(absf(float(p["period"]) - float(row["joint"]) / v) < 1e-4, "a joint is not a joint's length of track apart: %s s" % p["period"])
	var ts := PackedFloat32Array()
	for j in Rides.jolts(p, 100.0, 130.0):
		if int(j[2]) == 1:
			ts.append(float(j[0]))
	var gaps := PackedFloat32Array()
	for i in range(1, ts.size()):
		gaps.append(ts[i] - ts[i - 1])
	var pair := 2.5 / v
	var close := 0
	var long := 0
	for g in gaps:
		if absf(g - pair) < 0.01:
			close += 1
		elif g > pair * 2.5:
			long += 1
	_ok(close >= gaps.size() / 2 - 1 and long >= gaps.size() / 4, "the wheels do not knock in pairs a long gap apart: %d close, %d long of %d gaps" % [close, long, gaps.size()])
	# a standing train knocks not at all
	_ok(Rides.jolts(_plan("rails", 0.5, 0.0), 0.0, 120.0).filter(func(j: Array) -> bool: return int(j[2]) == 1).is_empty(), "a standing train knocks")
	return true


func _lens() -> bool:
	var px := 1080.0 / deg_to_rad(CardTable.VFOV)
	for on in Rides.ON:
		var p := _plan(on, 1.0, 1.0)
		var sq := 0.0
		var most := 0.0
		var n := 0
		var t := 20.0
		while t < 320.0:
			var c := Rides.camera(p, t)
			sq += c.x * c.x
			most = maxf(most, maxf(absf(c.x), maxf(absf(c.y), absf(c.z))))
			n += 1
			t += 1.0 / 60.0
		var rms := sqrt(sq / float(n)) * px
		_ok(rms > 0.03 and rms < 1.6, "the lens on a rough %s buzzes %s px rms (a faint buzz is under a pixel and a half)" % [on, str(snappedf(rms, 0.01))])
		_ok(most <= Rides.MOUNT_MOST + 1e-6 and most * px > 1.0, "the lens on a rough %s turns %s px at the most" % [on, str(snappedf(most * px, 0.1))])
	# NONE OF THE SLOW SWAY: the lens is the same with the sway and the roll taken out
	var p := _plan("water", 1.0, 0.8)
	var calm := p.duplicate()
	calm["sways"] = []
	calm["rolls"] = []
	var r := Rides.responder(p, {"kind": "sway", "amount": 0.5}, 0.12, 3)
	var lens_same := true
	var flower_same := true
	for i in 60:
		var t := 30.0 + float(i) * 0.71
		lens_same = lens_same and Rides.camera(p, t).is_equal_approx(Rides.camera(calm, t))
		flower_same = flower_same and (Rides.pose(p, {}, r, t, Vector3.ZERO)["lean"] as Vector2).is_equal_approx(Rides.pose(calm, {}, r, t, Vector3.ZERO)["lean"])
	_ok(lens_same, "the lens moves with the slow sway or the roll")
	_ok(not flower_same, "the control: a flower is the same with the sway and the roll taken out")
	return true


func _at_once() -> bool:
	# ON A ROAD, whose only struck sounds are its jolts (a rail's knocks would be heard rising too)
	var p := _plan("road", 1.0, 0.8)
	var t0 := _hardest(p, 20.0, 600.0)
	_ok(t0 > 0.0, "no hard jolt in ten minutes on a rough road")
	if t0 < 0.0:
		return true
	var r := Rides.responder(p, {"kind": "sway", "amount": 0.5}, 0.12, 5)
	var before := 0.0
	var after := 0.0
	var flower_before := Vector2.ZERO
	var flower_after := 0.0
	for i in 6:
		var d := float(i) * 0.02
		before = maxf(before, Rides.camera(p, t0 - 0.002 - d).length())
		after = maxf(after, Rides.camera(p, t0 + 0.03 + d).length())
		flower_after = maxf(flower_after, ((Rides.pose(p, {}, r, t0 + 0.04 + d * 2.0, Vector3.ZERO)["lean"] as Vector2)
			- (Rides.pose(p, {}, r, t0 - 0.001, Vector3.ZERO)["lean"] as Vector2)).length())
	_ok(after > before * 2.0, "the lens is not moved by the hardest jolt (%s before, %s after)" % [before, after])
	_ok(flower_after > 0.002, "a flower is not moved by the hardest jolt: %s rad" % flower_after)
	# HEARD AT THE SAME MOMENT: the ride's sound rises there, a few milliseconds at most from the jolt
	var sr := 22050
	var table := {"ride": {"on": "road", "rough": 1.0, "speed": 0.8}, "sound": {"ride": {"level": 1.0}}}
	var made: Dictionary = Soundscape.of_table(table, 11)
	_ok((made["ride"] as Dictionary).get("starts") == p["starts"], "the sound plans another ride than the table")
	# (begun well before it: a place fades in over its first second and a half)
	var heard := _onset(Soundscape.new(made["sound"], made["wind"], 11, sr, t0 - 3.0, made["ride"]), sr)
	_ok(absf(heard - 3.0) < 0.012, "the jolt at %s s is heard %s s off it" % [str(snappedf(t0, 0.01)), str(snappedf(heard - 3.0, 0.001))])
	var other: Dictionary = Soundscape.of_table(table, 12)
	var elsewhere := _onset(Soundscape.new(other["sound"], other["wind"], 12, sr, t0 - 3.0, other["ride"]), sr)
	_ok(absf(elsewhere - 3.0) > 0.012, "the control: another seed's ride is heard at the same moment")
	return true


## The loudest rise from 2 to 4 seconds into [param sc] (seconds from its start): the 5 ms window whose level,
## in the high band (each sample less the one before - the rumble's slow swells left out), most exceeds the
## 50 ms before it.
static func _onset(sc: Soundscape, sr: int) -> float:
	var a := sc.render(sr * 4)
	var w := int(0.005 * float(sr))
	var lv := PackedFloat32Array()
	for i in range(1, a.size() - w, w):
		var e := 0.0
		for k in w:
			var d := a[i + k] - a[i + k - 1]
			e += d.x * d.x + d.y * d.y
		lv.append(e)
	var best := 0
	var most := 0.0
	for i in range(int(2.0 / 0.005), lv.size()):
		var prior := 0.0
		for k in range(i - 10, i):
			prior += lv[k]
		var rise := lv[i] / (prior / 10.0 + 1e-12)
		if rise > most:
			most = rise
			best = i
	return float(best * w) / float(sr)


func _kinds() -> bool:
	var p := _plan("rails", 0.6)
	var short := Rides.responder(p, {"kind": "sway", "amount": 0.5}, 0.08, 1)
	var tall := Rides.responder(p, {"kind": "sway", "amount": 0.5}, 0.3, 1)
	_ok(float(tall["w"]) < float(short["w"]), "a taller stalk does not sway slower")
	var swing := Rides.responder(p, {"kind": "swing", "amount": 0.5}, 0.25, 1)
	_ok(absf(float(swing["w"]) - sqrt(9.81 / 0.25)) < 1e-3, "a 25 cm pendulum does not swing at sqrt(g/L)")
	# A NEEDLE swings at a jolt and comes back to its north
	var hard := _plan("track", 1.0, 0.8)
	var t0 := _hardest(hard, 30.0, 600.0)
	var nd := Rides.responder(hard, {"kind": "needle", "amount": 0.5}, 0.02, 9)
	var off := func(t: float) -> float: return absf(float(Rides.pose(hard, {}, nd, t, Vector3.ZERO)["turn"]) + Rides.heading(hard, t))
	var swung := 0.0
	for i in 20:
		swung = maxf(swung, float(off.call(t0 + 0.05 + float(i) * 0.05)))
	_ok(swung > deg_to_rad(2.0), "a needle does not swing at the hardest jolt: %s°" % rad_to_deg(swung))
	# ...and keeps to its north as the road turns under it: what it is off north is a small share of how far
	# the road turns (the control - a needle that turned with the car would be off by all of it)
	var road := _plan("road", 0.3, 0.8)
	var rn := Rides.responder(road, {"kind": "needle", "amount": 0.5}, 0.02, 9)
	var off_sq := 0.0
	var turn_sq := 0.0
	for i in 600:
		var t := 20.0 + float(i) * 1.13
		var h := Rides.heading(road, t)
		off_sq += pow(float(Rides.pose(road, {}, rn, t, Vector3.ZERO)["turn"]) + h, 2.0)
		turn_sq += h * h
	_ok(turn_sq / 600.0 > pow(deg_to_rad(2.0), 2.0), "the control: the road hardly turns (%s° rms)" % rad_to_deg(sqrt(turn_sq / 600.0)))
	_ok(off_sq < turn_sq * 0.16, "a needle does not keep to its north as the road turns: off by %s° rms, the road turning %s°" % [
		rad_to_deg(sqrt(off_sq / 600.0)), rad_to_deg(sqrt(turn_sq / 600.0))])
	# A ROCK: no small jolt moves it, a hard one does, and it is set down near where it was put
	var knocks := _plan("rails", 0.6)
	knocks["starts"] = PackedFloat32Array()
	knocks["kicks"] = PackedVector3Array()
	var rock := Rides.responder(knocks, {"kind": "rock", "amount": 0.5}, 0.02, 4)
	var moved := false
	for i in 300:
		var q := Rides.pose(knocks, {}, rock, 10.0 + float(i) * 0.31, Vector3.ZERO)
		moved = moved or (q["lean"] as Vector2) != Vector2.ZERO or float(q["turn"]) != 0.0
	_ok(not moved, "a rock moves with the knocks alone")
	var rk := Rides.responder(hard, {"kind": "rock", "amount": 0.5}, 0.02, 4)
	var rocked := 0.0
	var turned := 0.0
	for i in 20:
		rocked = maxf(rocked, (Rides.pose(hard, {}, rk, t0 + 0.01 + float(i) * 0.02, Vector3.ZERO)["lean"] as Vector2).length())
	for i in 2000:
		turned = maxf(turned, absf(float(Rides.pose(hard, {}, rk, float(i) * 3.0, Vector3.ZERO)["turn"])))
	_ok(rocked > deg_to_rad(0.3), "a rock is not rocked by the hardest jolt on a rough track: %s°" % rad_to_deg(rocked))
	_ok(turned > 0.0 and turned <= deg_to_rad(Rides.ROCK_TURN_MOST) + 1e-4, "a rock wandered %s° from where it was put" % rad_to_deg(turned))
	# A LIQUID STAYS LEVEL as the deck rolls; what stands goes downhill
	var sea := _plan("water", 1.0, 0.0)
	sea["starts"] = PackedFloat32Array()
	sea["kicks"] = PackedVector3Array()
	sea["buzz"] = 0.0
	sea["sways"] = []
	var cup := Rides.responder(sea, {"kind": "slosh", "amount": 0.5}, 0.035, 2)
	var stalk := Rides.responder(sea, {"kind": "sway", "amount": 0.5}, 0.12, 2)
	var level := 0.0
	var down := 0
	var n := 0
	for i in 100:
		var t := 20.0 + float(i) * 0.53
		var tl := Rides.tilt(sea, t)
		if tl.length() < deg_to_rad(1.0):
			continue
		n += 1
		var lq: Vector2 = Rides.pose(sea, {}, cup, t, Vector3.ZERO)["lean"]
		level = maxf(level, (lq + tl).length() / tl.length())
		if (Rides.pose(sea, {}, stalk, t, Vector3.ZERO)["lean"] as Vector2).dot(tl) > 0.0:
			down += 1
	_ok(n > 20 and level < 0.25, "a liquid does not stay level as the deck rolls: %s of the roll left" % level)
	_ok(down == n, "a stalk does not lean downhill as the deck rolls (%d of %d)" % [down, n])
	# A FLAME leans toward the push
	var pushed := 0
	var asked := 0
	var calm := _plan("road", 0.8, 0.8)
	calm["starts"] = PackedFloat32Array()
	calm["kicks"] = PackedVector3Array()
	for i in 100:
		var t := 10.0 + float(i) * 0.9
		var push := Rides.push(calm, t)
		if push.length() < 0.02:
			continue
		asked += 1
		if Rides.flame(calm, t).dot(push) > 0.0:
			pushed += 1
	_ok(asked > 20 and pushed >= asked * 9 / 10, "a flame does not lean toward the push (%d of %d)" % [pushed, asked])
	return true


## A flower in a bud vase: the vase, and a group - its stem and its head - that sways, its petals trembling.
static func _flower(move := true) -> Dictionary:
	var mats := {"glass": {"kind": "glass", "color": "#c8d8e0"}, "stem": {"kind": "plant", "color": "#3a6a30"}, "petal": {"kind": "plant", "color": "#d04060"}}
	var group := {"parts": [
		{"shape": "tube", "material": "stem", "path": [[0, 0.8, 0], [0.2, 6, 0], [0.4, 12.4, 0.3]], "radius": 0.18},
		{"shape": "bloom", "material": "petal", "at": [0.4, 12.4, 0.3], "radius": 1.8, "petals": 8, "move": "tremble" if move else null}]}
	if move:
		group["move"] = {"kind": "sway", "at": [0, 8.6, 0]}
	var thing := {"name": "a flower", "parts": [
		{"shape": "lathe", "material": "glass", "profile": [[0, 0], [2.2, 0], [2.5, 3], [1.0, 8.6], [0.8, 10], [0.6, 10], [0.6, 8.6], [2.2, 3], [2.0, 0.8], [0, 0.8]]},
		group]}
	return Props.sanitize({"things": [thing], "materials": mats}, [])


## Every vertex of [param mi]'s mesh where its node and those above it (to [param top]) put it.
static func _placed(mi: MeshInstance3D, top: Node) -> PackedVector3Array:
	var xf := mi.transform
	var up := mi.get_parent()
	while up != null and up != top:
		xf = (up as Node3D).transform * xf
		up = up.get_parent()
	var out := PackedVector3Array()
	var arrays := mi.mesh.surface_get_arrays(0)
	for v in (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array):
		out.append(xf * v)
	return out


static func _box(pts: PackedVector3Array) -> AABB:
	var b := AABB(pts[0], Vector3.ZERO)
	for q in pts:
		b = b.expand(q)
	return b


func _built() -> bool:
	var safe := _flower()
	var b := Props.build(safe["things"][0], safe["materials"], 5)
	var still := _flower(false)
	var s := Props.build(still["things"][0], still["materials"], 5)
	var movers: Array = b["movers"]
	_ok(movers.size() == 2 and (s["movers"] as Array).is_empty(), "a swaying flower with trembling petals is not two movers (%d), or a still one has some" % movers.size())
	if movers.size() != 2:
		return true
	_ok(int((movers[1] as Dictionary)["parent"]) == 0 and ((movers[1] as Dictionary)["node"] as Node).get_parent() == (movers[0] as Dictionary)["node"],
		"the petals' node is not inside the flower's")
	_ok(((movers[0] as Dictionary)["pivot"] as Vector3).is_equal_approx(Vector3(0, 0.086, 0)), "the flower is not held where its move says: %s" % (movers[0] as Dictionary)["pivot"])
	# AT REST everything stands where the still build stands it
	var rest_same := true
	for i in (b["meshes"] as Array).size():
		var a := _box(_placed(b["meshes"][i], b["node"]))
		var c := _box(_placed(s["meshes"][i], s["node"]))
		rest_same = rest_same and a.position.is_equal_approx(c.position) and a.size.is_equal_approx(c.size)
	_ok(rest_same and (b["meshes"] as Array).size() == (s["meshes"] as Array).size(), "a moving thing at rest does not stand where the still one does")
	# TURNED, through the table: the vase stays, the flower moves
	var m := TableMedium.new()
	var node: Node3D = b["node"]
	node.transform = Transform3D(Basis(Vector3.UP, 0.7), Vector3(0.2, 0.0, -0.1))
	m._ride = _plan("track", 1.0, 0.8)
	m._wind = {}
	m._movers = []
	m._take_movers(b, node)
	var t0 := _hardest(m._ride, 20.0, 600.0)
	var vase0 := _box(_placed(b["meshes"][0], node))
	var head0 := _box(_placed(b["meshes"][(b["meshes"] as Array).size() - 1], node))
	m._tick_ride(t0 + 0.08)
	var vase1 := _box(_placed(b["meshes"][0], node))
	var head1 := _box(_placed(b["meshes"][(b["meshes"] as Array).size() - 1], node))
	_ok(vase0.position.is_equal_approx(vase1.position), "the vase moved with the flower in it")
	_ok(head0.get_center().distance_to(head1.get_center()) > 0.0003, "the flower's head did not move at the hardest jolt: %s m" % head0.get_center().distance_to(head1.get_center()))
	node.free()
	# A ROCK ROCKS ON ITS EDGE: tipped, its lowest point stays on the cloth
	var stone := Props.sanitize({"things": [{"name": "a slab", "parts": [{"shape": "box", "size": [5, 2, 4], "round": 0.1, "material": "slate", "move": "rock"}]}],
		"materials": {"slate": {"kind": "stone", "color": "#4a4a50"}}}, [])
	var sb := Props.build(stone["things"][0], stone["materials"], 3)
	var sn: Node3D = sb["node"]
	m._movers = []
	m._take_movers(sb, sn)
	var low := INF
	var tipped := 0.0
	for i in 30:
		m._tick_ride(t0 + 0.005 + float(i) * 0.01)
		tipped = maxf(tipped, Basis((sb["movers"][0] as Dictionary)["node"].transform.basis).get_euler().length())
		low = minf(low, _box(_placed(sb["meshes"][0], sn)).position.y)
	_ok(tipped > 0.01, "the slab was not rocked a half degree by the hardest jolt on a rough track: %s°" % rad_to_deg(tipped))
	_ok(low > -0.00005, "a rocked slab sank %s mm through the cloth" % str(snappedf(-low * 1000.0, 0.01)))
	# the control: turned as far about its middle, it sinks
	var mv: Node3D = (sb["movers"][0] as Dictionary)["node"]
	var mid: Vector3 = _box(_placed(sb["meshes"][0], sn)).get_center()
	var tilt := Basis(Vector3(1, 0, 0), tipped)
	mv.transform = Transform3D(tilt, mid - tilt * mid)
	_ok(_box(_placed(sb["meshes"][0], sn)).position.y < -0.0002, "the control: a slab turned about its middle does not sink")
	sn.free()
	m.free()
	# EACH COPY ITS OWN: three stones copied, each rocks on its own
	var three := Props.sanitize({"things": [{"name": "stones", "parts": [{"shape": "ball", "size": [3, 2, 2.5], "material": "slate", "move": "rock",
		"copies": {"line": {"count": 3, "step": [4, 0, 0]}}}]}], "materials": {"slate": {"kind": "stone", "color": "#4a4a50"}}}, [])
	var tb := Props.build(three["things"][0], three["materials"], 3)
	_ok((tb["movers"] as Array).size() == 3, "three copied stones are not three movers: %d" % (tb["movers"] as Array).size())
	(tb["node"] as Node).free()
	(s["node"] as Node).free()
	return true


func _safe() -> bool:
	var t := CardTable.sanitize_table({"things": [{"name": "a candle", "parts": [{"shape": "lathe", "profile": [[0, 0], [2, 0], [2, 8], [0, 8]],
		"material": "wax", "wick": true, "move": "sway"}, {"shape": "ball", "size": [2, 2, 2], "material": "wax", "move": {"kind": "rock", "amount": 0.9}}]}],
		"materials": {"wax": {"kind": "wax", "color": "#e8dcc0"}}, "ride": {"on": "Rails", "rough": 3}}, {})
	_ok((t["ride"] as Dictionary).get("on") == "rails" and float(t["ride"]["rough"]) == 1.0, "the table did not keep its ride, made safe: %s" % t["ride"])
	var parts: Array = (t["things"][0] as Dictionary)["parts"]
	_ok((parts[0]["move"] as Dictionary).is_empty(), "a part with a flame moves")
	_ok(String(parts[1]["move"]["kind"]) == "rock" and float(parts[1]["move"]["amount"]) == 0.9, "a part's move was not kept: %s" % parts[1]["move"])
	_ok((CardTable.sanitize_table({"things": []}, {})["ride"] as Dictionary).is_empty(), "a table with no ride rides")
	var notes := PackedStringArray()
	_ok(Rides.sanitize_move("wobble", notes).is_empty() and notes.size() == 1, "a move the table does not know was kept or not said")
	# THE SOUND HEARS THE RIDE THE TABLE PLANS - only when it names it
	var felt: Dictionary = Soundscape.of_table({"ride": {"on": "rails"}, "sound": {"wind": {"through": "eaves"}}}, 5)
	_ok((felt["ride"] as Dictionary).is_empty(), "a ride the sound does not name is heard")
	var heard: Dictionary = Soundscape.of_table({"ride": {"on": "rails"}, "sound": {"ride": {}}}, 5)
	_ok((heard["ride"] as Dictionary).get("kicks") == Rides.plan(Rides.sanitize({"on": "rails"}), hash([5, "ride"]))["kicks"],
		"the sound hears another ride than the table plans")
	return true
