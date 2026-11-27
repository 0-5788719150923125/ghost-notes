extends SceneTree

## cameras_check - the list of cameras a show cuts between ([Cameras]). It holds:
##
## - a list made safe: an unknown sort and a non-entry dropped, a field kept in its bounds, a field at its default dropped, the
##   order kept (control: an empty list stays empty unless it is filled, and filled it is every sort of its format);
## - each sort is one format's: a format's list holds its sorts alone ([method Cameras.of]), a table's its own and the four of a
##   game and the Dispatch desk's its chair and the camera behind it - the table's own and the chair always seen through, put back
##   where a list leaves them off (control: no format, nothing added; a format with no cameras lists none);
## - a camera listed only where it is used ([method Cameras.seen]): those a format always sees through, and those the show
##   registers (control: nothing registered, the kept ones alone);
## - a Sway ([method Cameras.sway_at]): the table's own a tripod unless set, the chair's the desk's own wander, within [constant
##   Cameras.SWAY] times its Sway, twice the speed the same waves in half the time; turned by it ([method Cameras.swayed]), the eye
##   stays where it is and turns by the same angle whatever its reach (control: a camera set at 0 does not move);
## - every sort's fields have a label, a blurb, bounds and a default within them;
## - a field unset reads its default, and [method Cameras.rank] is the list's order;
## - a move between two sides of the table goes round it: half way from one side to the other, the eye is as far from the
##   middle as at either end (control: a straight line between them passes over the middle);
## - a blend's ends are its shots, and its lens goes straight between them.
##
##   godot --headless --path . --script tests/motion/cameras_check.gd

var _fails := 0
var _checks := 0


func _init() -> void:
	var raw := [{"sort": "seat", "height": 999.0, "lens": 30.0}, {"sort": "nope"}, "seat", {"sort": "dice", "far": 20}]
	var safe := Cameras.sanitize(raw)
	_ok(safe.size() == 2 and String(safe[0]["sort"]) == "seat" and String(safe[1]["sort"]) == "dice", "an unknown sort and a non-entry are dropped, the order kept")
	_ok(is_equal_approx(float(safe[0]["height"]), 120.0), "a field past its bounds is kept within them")
	_ok(not (safe[0] as Dictionary).has("lens"), "a field at its default is dropped")
	_ok(Cameras.sanitize([]).is_empty(), "control: an empty list stays empty")
	var filled := Cameras.sanitize([], true, "table")
	_ok(filled.map(func(e: Dictionary) -> String: return String(e["sort"])) == ["table", "dice", "march", "seat", "drift"],
		"filled, a table's empty list is every sort a table has, its own first")
	var mixed := [{"sort": "drift"}, {"sort": "behind", "height": 120.0}]
	var at_table := Cameras.sanitize(mixed, true, "table")
	_ok(at_table.map(func(e: Dictionary) -> String: return String(e["sort"])) == ["drift", "table"],
		"a table's list holds a table's cameras alone, its own put back")
	_ok(Cameras.seen(Cameras.of("table"), PackedStringArray(["seat"])) == ["table", "seat"]
		and Cameras.seen(filled, PackedStringArray(Cameras.of("table"))).size() == 5,
		"a list as the show uses it: the table's own and what it registered")
	_ok(Cameras.seen(filled, PackedStringArray()).map(func(e: Dictionary) -> String: return String(e["sort"])) == ["table"]
		and Cameras.seen(Cameras.of("dispatch"), PackedStringArray()) == ["chair", "behind"],
		"control: nothing registered, a format's kept cameras alone")
	var at_desk := Cameras.sanitize(mixed, true, "dispatch")
	_ok(at_desk.map(func(e: Dictionary) -> String: return String(e["sort"])) == ["behind", "chair"]
		and is_equal_approx(float(at_desk[0]["height"]), 120.0),
		"the Dispatch desk's list is the camera behind the chair as set, and the chair put back")
	_ok(Cameras.sanitize(mixed).size() == 2, "control: with no format, nothing is dropped or added")
	_ok(Cameras.of("full").is_empty() and Cameras.sanitize([], true, "full").is_empty(), "control: a format with no cameras lists none")
	_ok(not Cameras.kept("chair").is_empty() and not Cameras.kept("table").is_empty() and Cameras.kept("dice").is_empty(),
		"the chair and the table's own stay; the dice can be taken off")
	_ok(Cameras.sway_at(7.3, {"sort": "table"}) == Vector3.ZERO, "the table's own camera is a tripod unless its Sway is set")
	_ok(Cameras.sway_at(7.3, {"sort": "dice"}) == Vector3.ZERO, "control: a sort with no Sway does not move")
	var wander_ok := true
	for t in [0.0, 3.7, 41.2, 600.5]:
		var was := Vector3(sin(t * 0.11 * TAU + 1.3) * 0.010, sin(t * 0.11 * 0.77 * TAU) * 0.006, sin(t * 0.11 * 0.53 * TAU + 2.1) * 0.006)
		if not Cameras.sway_at(t, {"sort": "chair"}).is_equal_approx(was):
			wander_ok = false
	_ok(wander_ok, "the chair's own Sway is the desk's slow wander, as it always was")
	var most := Vector3.ZERO
	for i in 400:
		var w := Cameras.sway_at(i * 0.37, {"sort": "table", "sway": 2.0})
		most = Vector3(maxf(most.x, absf(w.x)), maxf(most.y, absf(w.y)), maxf(most.z, absf(w.z)))
	_ok(most.x <= Cameras.SWAY.x * 2.0 + 1e-6 and most.x > Cameras.SWAY.x and most.y <= Cameras.SWAY.y * 2.0 + 1e-6,
		"a Sway of 2 wanders within twice its reach, and past once (%s)" % str(most))
	_ok(Cameras.sway_at(5.0, {"sort": "table", "sway": 1.0, "sway_speed": 2.0}).is_equal_approx(Cameras.sway_at(10.0, {"sort": "table", "sway": 1.0})),
		"twice the speed is the same waves in half the time")
	var cam := Transform3D(Basis.looking_at(Vector3(0.0, -0.6, -0.8), Vector3.UP), Vector3(0.0, 0.33, 0.37))
	var held := {"sort": "table", "sway": 1.0}
	var near := Cameras.swayed(cam, 2.4, held, 0.5)
	var far := Cameras.swayed(cam, 2.4, held, 3.0)
	var turn_near := (-near.basis.z).angle_to(-cam.basis.z)
	var turn_far := (-far.basis.z).angle_to(-cam.basis.z)
	_ok(near.origin.is_equal_approx(cam.origin) and turn_near > 0.002, "swayed, the eye stays and the camera turns (%.4f rad)" % turn_near)
	_ok(absf(turn_near - turn_far) < 0.0005, "it turns by the same angle whatever its reach (%.4f, %.4f)" % [turn_near, turn_far])
	_ok(Cameras.swayed(cam, 2.4, {"sort": "table", "sway": 0.0}, 0.5) == cam, "control: a camera set at 0 does not move")
	var bad: Array = []
	for k in Cameras.REGISTRY:
		_ok(not Registry.label(Cameras.REGISTRY, k).is_empty() and not Registry.blurb(Cameras.REGISTRY, k).is_empty(), "%s has a label and a blurb" % k)
		var fields: Dictionary = Registry.field(Cameras.REGISTRY, k, "fields", {})
		for f in fields:
			var row: Dictionary = fields[f]
			for need in ["label", "blurb", "min", "max", "default"]:
				if not row.has(need):
					bad.append("%s.%s %s" % [k, f, need])
			if row.has("min") and (float(row["default"]) < float(row["min"]) or float(row["default"]) > float(row["max"])):
				bad.append("%s.%s default" % [k, f])
	_ok(bad.is_empty(), "every field has a label, a blurb, bounds and a default within them (%s)" % ", ".join(bad))
	_ok(is_equal_approx(Cameras.value({"sort": "seat"}, "height"), 46.0) and is_equal_approx(Cameras.value(safe[1], "far"), 20.0), "unset reads its default, set reads itself")
	_ok(Cameras.rank(safe, "dice") == 1 and Cameras.rank(safe, "drift") == -1, "rank is the list's order, and a sort off it has none")

	var a := {"eye": Vector3(0.0, 0.5, -1.0), "at": Vector3.ZERO, "fov": 30.0}
	var b := {"eye": Vector3(0.0, 0.5, 1.0), "at": Vector3(0.1, 0.0, 0.0), "fov": 40.0}
	var half := Cameras.blend(a, b, 0.5)
	var r := Vector2((half["eye"] as Vector3).x, (half["eye"] as Vector3).z).length()
	_ok(absf(r - 1.0) < 0.01, "half way between two sides the eye is as far from the middle as at the ends (%.3f)" % r)
	var straight := (a["eye"] as Vector3).lerp(b["eye"], 0.5)
	_ok(Vector2(straight.x, straight.z).length() < 0.01, "control: a straight line between them passes over the middle")
	_ok((half["eye"] as Vector3).y >= 0.5, "going round, it does not dip")
	_ok(Cameras.blend(a, b, 0.0) == a and Cameras.blend(a, b, 1.0) == b, "a blend's ends are its shots")
	_ok(is_equal_approx(float(half["fov"]), 35.0) and (half["at"] as Vector3).is_equal_approx(Vector3(0.05, 0.0, 0.0)), "the lens and where it looks go straight")
	var xf := Cameras.transform_of(a)
	_ok(((-xf.basis.z) - ((a["at"] as Vector3) - (a["eye"] as Vector3)).normalized()).length() < 0.001, "a shot's transform looks where it says")

	print("cameras_check: %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _ok(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_fails += 1
		print("  FAIL: " + what)
