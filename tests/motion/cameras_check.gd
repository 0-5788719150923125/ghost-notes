extends SceneTree

## cameras_check - the list of cameras a show cuts between ([Cameras]). It holds:
##
## - a list made safe: an unknown sort and a non-entry dropped, a field kept in its bounds, a field at its default dropped, the
##   order kept (control: an empty list stays empty unless it is filled, and filled it is every sort of its format);
## - each sort is one format's: a format's list holds its sorts alone ([method Cameras.of]), a table's the four of a game and the
##   Dispatch desk's its chair and the camera behind it, which it always sees through, put back where a list leaves them off
##   (control: no format, nothing added; a format with no cameras lists none);
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
	_ok(filled.map(func(e: Dictionary) -> String: return String(e["sort"])) == ["dice", "march", "seat", "drift"],
		"filled, a table's empty list is every sort a table has, the dice first")
	var mixed := [{"sort": "drift"}, {"sort": "behind", "height": 120.0}]
	var at_table := Cameras.sanitize(mixed, true, "table")
	_ok(at_table.size() == 1 and String(at_table[0]["sort"]) == "drift", "a table's list holds a table's cameras alone")
	var at_desk := Cameras.sanitize(mixed, true, "dispatch")
	_ok(at_desk.map(func(e: Dictionary) -> String: return String(e["sort"])) == ["behind", "chair"]
		and is_equal_approx(float(at_desk[0]["height"]), 120.0),
		"the Dispatch desk's list is the camera behind the chair as set, and the chair put back")
	_ok(Cameras.sanitize(mixed).size() == 2, "control: with no format, nothing is dropped or added")
	_ok(Cameras.of("full").is_empty() and Cameras.sanitize([], true, "full").is_empty(), "control: a format with no cameras lists none")
	_ok(not Cameras.kept("chair").is_empty() and Cameras.kept("dice").is_empty(), "the chair stays; the dice can be taken off")
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
