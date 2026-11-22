extends SceneTree

## camera_follow_check - the one follow every flown camera has ([CameraFollow]), stepped by hand on the Dispatch desk's own
## settings from where the chair looks. It holds:
##
## - the settings: the Camera card's over the format's own, each within its bounds, a row neither names at its default; a
##   card keeps only numbers; every format's own names only settings there are; a medium lays the feed's over its own;
## - a short look runs at its own pace: a 15 degree turn follows the same path quickened or not;
## - a long look runs quicker, its end included: a 90 degree turn arrives in under 0.6 of the time at Long looks 2 (control:
##   at 1 it takes as long as a short look's way), and [method CameraFollow.arrival] says about what stepping it takes;
## - a look turned elsewhere mid-way keeps its pace (the move's size is counted from rest);
## - it never turns past its top speed (control: the same look with no top speed to speak of does);
## - every move eases in: it starts slower with an ease in than without (control), and nowhere jumps;
## - a pace under 1 (what a medium makes of a moment) arrives sooner.
##
##   godot --headless --path . --script tests/motion/camera_follow_check.gd

const DT := 1.0 / 30.0
const EYE := Vector3(0.0, 1.24, 0.80)

var _fails := 0
var _checks := 0


func _init() -> void:
	var own := Medium.follow_of("dispatch")
	_ok(not own.is_empty(), "the Dispatch desk has a follow of its own")

	# the settings
	var s := CameraFollow.settings(own, {"settle": 99.0, "long": "fast"})
	_ok(is_equal_approx(float(s["settle"]), float(CameraFollow.FIELDS["settle"]["max"])), "a setting past its bounds is kept within them")
	_ok(is_equal_approx(float(s["ease_in"]), float(own["ease_in"])) and is_equal_approx(float(s["long"]),
		float(CameraFollow.FIELDS["long"]["default"])), "unset (or not a number), a row stands at the format's own, else at its default")
	_ok(CameraFollow.sanitize({"settle": 2, "long": "fast", "else": 1.0}) == {"settle": 2.0}, "a card keeps only the numbers it has rows for")
	var bad: Array = []
	for k in Medium.REGISTRY:
		for f in Medium.follow_of(String(k)):
			if not CameraFollow.FIELDS.has(f):
				bad.append("%s.%s" % [k, f])
	_ok(bad.is_empty(), "every format's own names only settings there are (%s)" % ", ".join(bad))
	var m := Medium.new()
	var fd := ShowFeed.new()
	fd.camera_follow = {"long": 3.0}
	m.key = "dispatch"
	m.feed = fd
	var laid := m.camera_follow()
	_ok(is_equal_approx(float(laid["long"]), 3.0) and is_equal_approx(float(laid["ease_in"]), float(own["ease_in"])),
		"a medium lays the card's settings over its format's own")
	m.free()
	fd.free()

	var at1 := CameraFollow.settings(own, {"long": 1.0})
	var at2 := CameraFollow.settings(own, {"long": 2.0})

	# a short look runs at its own pace
	var a := _turn(at1, 15.0)
	var b := _turn(at2, 15.0)
	_ok(absf(float(a["t"]) - float(b["t"])) < 1e-6 and float(a["peak"]) == float(b["peak"]),
		"a short look follows the same path quickened or not (%.2f s, %.2f s)" % [a["t"], b["t"]])

	# a long look runs quicker, its end included
	var slow := _turn(at1, 90.0)
	var quick := _turn(at2, 90.0)
	var short_way := _turn(at1, 15.0)
	_ok(float(quick["t"]) < 0.6 * float(slow["t"]), "a long look arrives in under 0.6 of the time (%.2f s against %.2f s)" % [quick["t"], slow["t"]])
	_ok(absf(float(slow["t"]) - float(short_way["t"])) < 1.0,
		"control: at Long looks 1 a long look takes as long as a short look's way (%.2f s, %.2f s)" % [slow["t"], short_way["t"]])
	var f := CameraFollow.new([1.0])
	f.configure(at2)
	_ok(absf(f.arrival(90.0) - float(quick["t"])) < 0.6, "arrival says about what stepping a look takes (%.2f s, %.2f s)" % [f.arrival(90.0), quick["t"]])

	# a look turned elsewhere mid-way keeps its pace
	var cf := _follow(at2)
	var to := _toward(90.0)
	for i in roundi(1.5 / DT):
		cf.step([to, EYE, 50.0], DT, EYE)
	var was := cf.quickened()
	var now: Vector3 = cf.value(0)
	var nearby := now + (to - now).normalized() * 0.05
	for i in roundi(0.6 / DT):
		cf.step([nearby, EYE, 50.0], DT, EYE)
	_ok(was > 1.5 and cf.quickened() > 1.5, "a look turned elsewhere mid-way keeps its pace (x%.2f, then x%.2f)" % [was, cf.quickened()])

	# never past its top speed
	var hard := CameraFollow.settings(own, {"settle": 0.4, "ease_in": 0.0, "long": 4.0, "top_speed": 40.0})
	var capped := _turn(hard, 120.0)
	var free_run := _turn(CameraFollow.settings(own, {"settle": 0.4, "ease_in": 0.0, "long": 4.0, "top_speed": 360.0}), 120.0)
	_ok(float(capped["peak"]) <= 40.0 * 1.1, "it never turns past its top speed (%.0f deg/s, top 40)" % capped["peak"])
	_ok(float(free_run["peak"]) > 40.0 * 1.5, "control: with no top speed to speak of it does (%.0f deg/s)" % free_run["peak"])

	# every move eases in, and nowhere jumps
	var eased := _turn(at2, 60.0)
	var sudden := _turn(CameraFollow.settings(own, {"long": 2.0, "ease_in": 0.0}), 60.0)
	_ok(float(eased["first"]) < 0.5 * float(sudden["first"]), "a move eases in: slower over its first fifth of a second (%.2f deg against %.2f with no ease in)"
		% [eased["first"], sudden["first"]])
	_ok(float(quick["jerk"]) < 0.08 * float(quick["peak"]), "nowhere does the turning speed jump (most change in a frame %.2f deg/s of a %.0f peak)"
		% [quick["jerk"], quick["peak"]])

	# a pace under 1 arrives sooner
	_ok(float(_turn(at1, 30.0, 0.5)["t"]) < 0.7 * float(_turn(at1, 30.0)["t"]), "a pace under 1 arrives sooner")

	print("camera_follow_check: %s (%d checks, %d failure%s)" % ["ALL OK" if _fails == 0 else "FAILED", _checks, _fails, "" if _fails == 1 else "s"])
	quit(1 if _fails > 0 else 0)


func _follow(s: Dictionary) -> CameraFollow:
	var f := CameraFollow.new([1.0, 1.0, 1.0], 0, 0.1)
	f.configure(s)
	f.snap([_toward(0.0), EYE, 50.0])
	return f


## Where the chair looks [param deg] degrees round from straight ahead, at the eye's height.
func _toward(deg: float) -> Vector3:
	var r := deg_to_rad(deg)
	return EYE + Vector3(sin(r), 0.0, -cos(r)) * 0.9


## A turn of [param deg] from rest under [param s]: when it arrives ([constant CameraFollow.ARRIVED]), its peak turning speed,
## the most that speed changes in a frame, and how far it turned in its first fifth of a second.
func _turn(s: Dictionary, deg: float, pace := 1.0) -> Dictionary:
	var f := _follow(s)
	var to := _toward(deg)
	var t := 0.0
	var last := CameraFollow.apart(EYE, f.value(0), to)
	var speed := 0.0
	var out := {"t": INF, "peak": 0.0, "jerk": 0.0, "first": 0.0}
	while t < 40.0:
		f.step([to, EYE, 50.0], DT, EYE, pace)
		t += DT
		var ap := CameraFollow.apart(EYE, f.value(0), to)
		var sp := (last - ap) / DT
		out["peak"] = maxf(float(out["peak"]), sp)
		out["jerk"] = maxf(float(out["jerk"]), absf(sp - speed))
		speed = sp
		last = ap
		if t <= 0.2 + 1e-6:
			out["first"] = deg - ap
		if ap <= maxf(deg * CameraFollow.ARRIVED, CameraFollow.REST) and out["t"] == INF:
			out["t"] = t
			break
	return out


func _ok(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_fails += 1
		print("  FAIL: " + what)
