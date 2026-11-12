extends SceneTree

## mug_check: what steams cools, and what is drunk from goes down ([Motions], [TableWork]; next/table_work.md "Heat and a drink").
##
## - Heat: a mug starts at 85 C and is near 41 C at 40 minutes, as real coffee in a mug is; what is larger holds it longer; its steam
##   is whole when hot, gone by the time it stops - within 15 to 25 minutes. Controls: what is kept hot, and smoke, which is not heat,
##   go on as they are.
## - The plume says so: a real mug's plume is whole at the start, thin and short-lived at ten minutes, and at twenty-five nothing is
##   born. Controls: the same mug `kept_hot`, and one that boils, steam at two hours.
## - A drink: at the mouth every corner of the mug is out of the frame by its foot; it comes back to within a hair of where it stood;
##   the liquid has lost what the sip says and nothing else, none of it spilled; a second drink takes its share of what is left. Its
##   steam does not cross the picture. Controls: at rest it is in the frame, and a carry takes nothing from it; a thing with no liquid
##   is drunk from, and said.
##
## Run: godot --headless --path . --script tests/table/mug_check.gd

const SPEC := {"things": [
	{"name": "mug", "parts": [
		{"name": "cup", "shape": "lathe", "material": "clay", "profile": [[0, 0], [3.7, 0], [4.1, 0.5], [4.2, 9.6], [3.8, 9.5], [3.5, 0.7], [0, 0.6]], "points": {"mouth": [0, 8.2, 0]},
			"emits": {"kind": "steam", "at": "mouth", "rate": 1.2}},
		{"name": "coffee", "shape": "lathe", "material": "brew", "profile": [[0, 0.6], [3.5, 0.7], [3.72, 8.2], [0, 8.2]]}]},
	{"name": "kept mug", "parts": [
		{"name": "cup", "shape": "lathe", "material": "clay", "profile": [[0, 0], [3.7, 0], [4.2, 9.6], [3.8, 9.5], [3.5, 0.7], [0, 0.6]], "points": {"mouth": [0, 8.2, 0]},
			"emits": {"kind": "steam", "at": "mouth", "kept_hot": true}}]},
	{"name": "boiling mug", "parts": [
		{"name": "cup", "shape": "lathe", "material": "clay", "profile": [[0, 0], [3.7, 0], [4.2, 9.6], [3.8, 9.5], [3.5, 0.7], [0, 0.6]], "points": {"mouth": [0, 8.2, 0]}, "start": {"boil": 0.5},
			"emits": {"kind": "steam", "at": "mouth"}}]},
	{"name": "censer", "parts": [
		{"name": "bowl", "shape": "lathe", "material": "clay", "profile": [[0, 0], [3, 0], [3, 3], [0, 3]], "points": {"top": [0, 3, 0]}, "emits": {"kind": "smoke", "at": "top"}}]},
	{"name": "empty mug", "parts": [
		{"shape": "lathe", "material": "clay", "profile": [[0, 0], [3.7, 0], [4.2, 9.6], [3.8, 9.5], [3.5, 0.7], [0, 0.6]]}]}],
	"materials": {"clay": {"kind": "ceramic", "color": "#5a7a6a"}, "brew": {"kind": "liquid", "color": "#2e1a0e"}}}
const LENS_AT := Vector3(0.0, 0.62, 0.62)

var _fails := 0


func _init() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + what)
	if not cond:
		_fails += 1


func _run() -> void:
	_heat()
	_plume()
	_drink()
	_over_the_build()
	_told()
	_no_liquid()
	print("mug_check: %s (%d failure%s)" % ["ALL OK" if _fails == 0 else "FAILED", _fails, "" if _fails == 1 else "s"])
	quit(1 if _fails > 0 else 0)


static func _medium() -> TableMedium:
	var m := TableMedium.new()
	m._root3 = Node3D.new()
	m._props = Node3D.new()
	m._root3.add_child(m._props)
	m._wind = {}
	m._plan.cam_base = Transform3D(Basis.looking_at(-LENS_AT.normalized(), Vector3.UP), LENS_AT)
	m._plan.fov = 40.0
	return m


static func _stand(m: TableMedium, name: String, at: Vector3) -> Dictionary:
	var safe := Props.sanitize(SPEC, [])
	var thing: Dictionary = {}
	for t in safe["things"]:
		if String((t as Dictionary)["name"]) == name:
			thing = t
	m._work.materials = safe["materials"]
	var b := Props.build(thing, safe["materials"], 5)
	var node: Node3D = b["node"]
	node.transform = Transform3D(Basis.IDENTITY, at)
	m._props.add_child(node)
	m._work.take(thing, b, node)
	return {"node": node, "built": b, "thing": thing}


func _heat() -> void:
	var mug := {"kind": "steam", "hot": 85.0}
	var across := 0.084
	var at_40 := Motions.temperature(mug, across, 2400.0)
	_ok(is_equal_approx(Motions.temperature(mug, across, 0.0), 85.0) and at_40 > 38.0 and at_40 < 44.0, "a mug starts at 85 C and is %.1f C at 40 minutes" % at_40)
	_ok(Motions.temperature(mug, 0.3, 2400.0) > 60.0, "what is larger holds its heat: a pot 30 cm across is %.1f C then" % Motions.temperature(mug, 0.3, 2400.0))
	var stops := Motions.steam_stops_at(mug, across)
	_ok(stops > 900.0 and stops < 1500.0, "a mug stops steaming %.0f minutes in" % (stops / 60.0))
	_ok(is_equal_approx(Motions.steam_share(Motions.temperature(mug, across, 0.0)), 1.0) and Motions.steam_share(Motions.temperature(mug, across, stops + 1.0)) == 0.0, "its steam is whole at the start and none once it has stopped")
	var last := 2.0
	var falls := true
	for k in 60:
		var v := Motions.steam_share(Motions.temperature(mug, across, float(k) * 60.0))
		falls = falls and v <= last
		last = v
	_ok(falls, "it only ever thins")
	_ok(is_equal_approx(Motions.temperature({"kept_hot": true, "hot": 90.0}, across, 7200.0), 90.0), "the control: what is kept hot stays so")
	_ok(is_inf(Motions.steam_stops_at({"kind": "smoke"}, across)), "the control: smoke is not heat")
	var notes := PackedStringArray()
	var safe := Motions.sanitize_law({"law": "drink", "sip": 9.0, "between": [0.1, 0.9]}, notes)
	_ok(String(safe.get("law", "")) == "drink" and float(safe["sip"]) == 1.0 and safe["between"] == Vector2(0.1, 0.9), "a drink's fields are made safe: %s" % str(safe))


## How strong each plume stands at [param t], and how long the puffs it has just born live.
static func _plume_at(m: TableMedium, wi_plume: int, t: float) -> Array:
	var p: Dictionary = m._work._plumes[wi_plume]
	m._work.tick(t)
	var most := 0.0
	var alive := 0
	for life in (p["lives"] as PackedVector2Array):
		if life.x > t - life.y and life.x <= t + 0.01:
			alive += 1
			most = maxf(most, life.y)
	return [float(p["strength"]), alive, most]


func _plume() -> void:
	var m := _medium()
	for nm in ["mug", "kept mug", "boiling mug", "censer"]:
		_stand(m, String(nm), Vector3(0.0, 0.0, 0.0))
	m._work.build({"acts": []}, 1)
	m._work.runs = []
	m._work._timelines()
	var names := ["mug", "kept", "boiling", "smoke"]
	var by := {}
	for i in m._work._plumes.size():
		by[names[i]] = i
	var start := _plume_at(m, int(by["mug"]), 30.0)
	var mid := _plume_at(m, int(by["mug"]), 600.0)
	var late := _plume_at(m, int(by["mug"]), 1500.0)
	_ok(is_equal_approx(float(start[0]), 1.0) and int(start[1]) > 0, "a mug's steam is whole at the start: %.2f, %d in the air" % [float(start[0]), int(start[1])])
	_ok(float(mid[0]) > 0.02 and float(mid[0]) < 0.8 and float(mid[2]) < float(start[2]), "at 10 minutes it is thin, %.2f, and short-lived, %.2f s against %.2f" % [float(mid[0]), float(mid[2]), float(start[2])])
	_ok(float(late[0]) == 0.0 and int(late[1]) == 0, "at 25 minutes nothing rises from it: %.2f, %d in the air" % [float(late[0]), int(late[1])])
	for nm in ["kept", "boiling", "smoke"]:
		var other := _plume_at(m, int(by[nm]), 7200.0)
		_ok(is_equal_approx(float(other[0]), 1.0) and int(other[1]) > 0, "the control: at two hours the %s one still rises, %.2f" % [nm, float(other[0])])
	m._root3.free()


## Whether any corner of what [param box] gives, at [param x], is in the frame.
static func _in_frame(m: TableMedium, box: AABB, x: Transform3D) -> bool:
	var inv: Transform3D = m._plan.cam_base.affine_inverse()
	var k := tan(deg_to_rad(float(m._plan.fov) * 0.5))
	for i in 8:
		var p: Vector3 = inv * (x * box.get_endpoint(i))
		if p.z < 0.0 and absf(p.y) < -p.z * k and absf(p.x) < -p.z * k * 16.0 / 9.0:
			return true
	return false


static func _volume(m: TableMedium, li: int, t: float) -> float:
	var f: Variant = m._work.physics.frame_at(t)
	return float(((f as Dictionary)["liq"] as PackedFloat32Array)[li * 16]) if f != null else -1.0


func _drink() -> void:
	var res := {}
	for how in ["drink", "carry"]:
		var m := _medium()
		var at := Vector3(-0.2, 0.0, -0.1)
		var st := _stand(m, "mug", at)
		var node: Node3D = st["node"]
		var tracks: Array = [{"thing": "mug", "law": "drink", "sip": 0.2}] if how == "drink" else [{"thing": "mug", "law": "carry", "to": [-10, 0, 0], "down": true, "between": [0.0, 0.4]}, {"thing": "mug", "law": "carry", "down": true, "between": [0.6, 1.0]}]
		var acts: Array = [{"name": "sip", "beat": 1, "length": 2.0 if how == "drink" else 7.0, "tracks": tracks}]
		if how == "drink":
			acts.append({"name": "sip-again", "beat": 1, "length": 7.0, "tracks": [{"thing": "mug", "law": "drink", "sip": 0.5}]})
		m._work.build({"acts": acts}, 1)
		var first: Dictionary = m._work.acts[0]
		if how == "drink":
			_ok(float(first["length"]) >= TableWork.DRINK_LEAST, "an act too short for a drink is made long enough: %.1f s" % float(first["length"]))
		var d1 := float(first["length"])
		m._work.runs = [{"i": 0, "t0": 2.0, "t1": 2.0 + d1}]
		if how == "drink":
			m._work.runs.append({"i": 1, "t0": 12.0, "t1": 19.0})
		m._work._timelines()
		var ph: TablePhysics = m._work.physics
		var li := -1
		for k in ph.liquids.size():
			if bool((ph.liquids[k] as Dictionary)["made"]):
				li = k
		_ok(li >= 0, "%s: the coffee is a liquid in its cup: %s" % [how, "; ".join(m._work.notes)])
		var box: AABB = (m._work.things[0] as Dictionary)["box"]
		m._work.tick(21.0)
		var v0 := _volume(m, li, 1.0)
		var v1 := _volume(m, li, 11.0)
		var v2 := _volume(m, li, 21.0)
		m._work.tick(1.0)
		var seen_at_rest := _in_frame(m, box, node.transform)
		m._work.tick(2.0 + d1 * 0.5)
		var seen_mid := _in_frame(m, box, node.transform)
		var mid_at := node.transform.origin
		var plume: Dictionary = m._work._plumes[0]
		var strength := float(plume["strength"])
		m._work.tick(11.0)
		var back := node.transform.origin.distance_to(at)
		var spilled := 0
		for k in 160:
			var f: Variant = ph.frame_at(2.0 + 18.0 * float(k) / 159.0)
			if f != null:
				spilled += ((f as Dictionary).get("streams", []) as Array).size()
		res[how] = {"v0": v0, "v1": v1, "v2": v2, "rest": seen_at_rest, "mid": seen_mid, "back": back, "spilled": spilled, "strength": strength, "mid_at": mid_at}
		m._root3.free()
	var a: Dictionary = res["drink"]
	var c: Dictionary = res["carry"]
	_ok(bool(a["rest"]) and bool(c["rest"]), "the control: stood on the table it is in the frame")
	_ok(not bool(a["mid"]), "at the mouth all of it is out of the frame, at %s" % str(a["mid_at"]))
	_ok(bool(c["mid"]), "the control: carried about the table it stays in it")
	_ok(float(a["strength"]) == 0.0, "its steam does not cross the picture from there: %.2f" % float(a["strength"]))
	_ok(float(a["back"]) < 0.002, "it comes back where it stood, %.2f mm off" % (float(a["back"]) * 1000.0))
	var one := float(a["v1"]) / float(a["v0"])
	var two := float(a["v2"]) / float(a["v0"])
	_ok(float(a["v0"]) > 1e-5 and absf(one - 0.8) < 0.03, "a drink of 0.2 leaves %.3f of it (%.0f ml of %.0f)" % [one, float(a["v1"]) * 1e6, float(a["v0"]) * 1e6])
	_ok(absf(two - 0.4) < 0.03, "a second of 0.5 leaves %.3f of it" % two)
	_ok(int(a["spilled"]) == 0, "none of it spilled: %d streams seen" % int(a["spilled"]))
	_ok(absf(float(c["v1"]) / float(c["v0"]) - 1.0) < 0.01, "the control: a carry takes nothing from it: %.3f" % (float(c["v1"]) / float(c["v0"])))


## Over what is built ([method TableWork.lift_over]; the bricks are in another world from what an act moves): the way a drink would go
## comes over a finished tower, and the lift found clears it. Control: a hand's own lift would have gone through it, and a way that never
## comes near it needs none.
func _over_the_build() -> void:
	var a := Vector3(-0.29, 0.05, -0.21)
	var b := Vector3(0.0, 0.33, 0.61)
	var tower := {"at": Vector2(-0.12, 0.055), "reach": 0.2, "top": 0.3}
	var lift := TableWork.lift_over(a, b, 7, tower, 0.05)
	var lowest := func(with_lift: float) -> float:
		var out := INF
		for k in range(1, 200):
			var p := Hands.carried(a, b, Vector3.ZERO, Vector3.ZERO, with_lift, float(k) / 200.0, 7)
			if Vector2(p.x, p.z).distance_to(tower["at"]) < float(tower["reach"]):
				out = minf(out, p.y - 0.05)
		return out
	_ok(lift > TableWork.DRINK_LIFT and float(lowest.call(lift)) >= float(tower["top"]), "a cup's way clears a finished tower of %.0f cm: its foot no lower than %.1f cm on a lift of %.0f cm" % [float(tower["top"]) * 100.0, float(lowest.call(lift)) * 100.0, lift * 100.0])
	_ok(float(lowest.call(TableWork.DRINK_LIFT)) < float(tower["top"]), "the control: on a hand's own lift its foot came down to %.1f cm, in the tower" % (float(lowest.call(TableWork.DRINK_LIFT)) * 100.0))
	var off_to_one_side := {"at": Vector2(0.6, -0.3), "reach": 0.2, "top": 0.3}
	_ok(TableWork.lift_over(a, b, 7, off_to_one_side, 0.05) == 0.0, "the control: a way that never comes over it needs nothing")


## What the puppeteer is told of one: that it was done, with nothing passing through anything, and never that it ends in the air.
func _told() -> void:
	var m := _medium()
	_stand(m, "mug", Vector3(-0.2, 0.0, -0.1))
	m._work.build({"acts": [{"name": "sip", "beat": 1, "length": 7.0, "tracks": [{"thing": "mug", "law": "drink"}]}]}, 1)
	var said: Dictionary = m._work.check("sip")
	var text := String(said["text"])
	print(text.indent("      "))
	_ok(int(said["through"]) == 0 and not text.contains("ENDS IN THE AIR") and not text.contains("HELD BACK"), "the act's report finds nothing wrong with it")
	m._root3.free()


func _no_liquid() -> void:
	var m := _medium()
	_stand(m, "empty mug", Vector3(0.1, 0.0, -0.1))
	m._work.build({"acts": [{"name": "dry", "beat": 1, "length": 7.0, "tracks": [{"thing": "empty mug", "law": "drink"}]}]}, 1)
	var said := "\n".join(m._work.notes)
	_ok(said.contains("no liquid") and m._work.acts.size() == 1, "what has nothing in it is drunk from all the same, and said: %s" % said)
	m._root3.free()
