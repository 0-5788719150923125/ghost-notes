extends SceneTree

## fingers_check: a thing in hand is never still ([Fingers], pure).
##
##   godot --headless --path . --script res://tests/table/fingers_check.gd
##
## - Never still: every moment of a long hold, in the air or waiting over a place, it has moved within the last moment by as much as
##   can be seen. Control: the drift of [method Hands.drift] alone is called still by the same measure.
## - It is turned over, in beats: in the air, half a turn from where it began and several separate turnings, in every hold; and no
##   two holds alike. Control: with no room for its fingers, it never is.
## - No jump, whatever the room does: frame to frame through a hold whose room rises, stays and falls - a turned thing righted as
##   room runs out, past half a turn too. Control: a jump is called one.
## - Both ends are the record's: nothing done to it at the grip or as it leaves, and nothing pressed home.
## - Over things it never goes lower: its lowest corner, with little room, is never under where the record has it. Control: in the
##   air, it is.
## - It turns about its middle, which goes only where the hand goes.
## - A hand kept waiting draws back: not in a short stop; all the way in a long one, and its fingers have room only while it is all
##   the way back. Both ends of the stop are where it stopped.
## - The same moment twice: looked at out of order, the same pose.

const FPS := 60.0

var _fails := 0


func _init() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + what)
	if not cond:
		_fails += 1


func _run() -> void:
	_rows()
	_never_still()
	_turned_over()
	_no_jump()
	_ends()
	_over_things()
	_middle()
	_draws_back()
	_same_twice()
	print("fingers_check: %s (%d failure%s)" % ["ALL OK" if _fails == 0 else "FAILED", _fails, "" if _fails == 1 else "s"])
	quit(1 if _fails > 0 else 0)


func _rows() -> void:
	var sum := 0.0
	for key in Fingers.BEATS:
		sum += float((Fingers.BEATS[key] as Dictionary)["share"])
	_ok(absf(sum - 1.0) < 1e-6, "the beats' shares come to all of them: %.3f" % sum)


## How much a hold has moved inside a window, at its worst: `[least the most it moved in any window (meters), ...turned (degrees)]`. A pose is `[move, turn]`.
static func _least_in_windows(poses: Array, window: int) -> Vector2:
	var least := Vector2(INF, INF)
	var i := 0
	while i + window < poses.size():
		var most := Vector2.ZERO
		var a: Array = poses[i]
		for j in range(i + 1, i + window + 1):
			var b: Array = poses[j]
			most.x = maxf(most.x, (a[0] as Vector3).distance_to(b[0] as Vector3))
			most.y = maxf(most.y, rad_to_deg((a[1] as Quaternion).angle_to(b[1] as Quaternion)))
		least.x = minf(least.x, most.x)
		least.y = minf(least.y, most.y)
		i += 3
	return least


static func _hold(seed: int, seconds: float, room: float, free_too: bool) -> Array:
	var poses: Array = []
	var n := int(seconds * FPS)
	for i in n:
		var h := float(i) / FPS
		poses.append(Fingers.at(h + 1.0, 100.0, room, h if free_too else 0.0, 0.0, seed, Vector3.RIGHT, 0.016))
	return poses


## Never still: 1.5 seconds is long enough to see stillness in a brick. A window is still if it neither moved nor turned by as much as
## can be seen: a little over a pixel on a brick on the plate, at 1080p (36 pixels a centimeter there, more nearer the lens).
func _never_still() -> void:
	var window := int(1.5 * FPS)
	var worst_air := Vector2(INF, INF)
	var worst_over := Vector2(INF, INF)
	var worst_was := Vector2.ZERO
	for seed in 24:
		var air := _least_in_windows(_hold(seed, 30.0, Fingers.ROOM_FREE, true), window)
		worst_air = Vector2(minf(worst_air.x, air.x), minf(worst_air.y, air.y))
		var over := _least_in_windows(_hold(seed, 30.0, Fingers.ROOM_HOVER, false), window)
		worst_over = Vector2(minf(worst_over.x, over.x), minf(worst_over.y, over.y))
		var was: Array = []
		for i in int(30.0 * FPS):
			var dr: Array = Hands.drift(float(i) / FPS, seed, 1.0)
			was.append([dr[0], (dr[1] as Basis).get_rotation_quaternion()])
		var w := _least_in_windows(was, window)
		worst_was = Vector2(maxf(worst_was.x, w.x), maxf(worst_was.y, w.y))
	_ok(worst_air.x > 0.002 and worst_air.y > 2.0, "in the air it is never still: over any 1.5 s at least %.1f mm and %.1f degrees" % [worst_air.x * 1000.0, worst_air.y])
	_ok(worst_over.x > 0.0008 and worst_over.y > 0.4, "over a place it is never still: over any 1.5 s at least %.1f mm and %.1f degrees" % [worst_over.x * 1000.0, worst_over.y])
	_ok(worst_was.x < 0.002 and worst_was.y < 2.0, "control: the drift alone, what was there before, is still by the same measure: even its liveliest hold has %.1f mm and %.1f degrees over some 1.5 s" % [worst_was.x * 1000.0, worst_was.y])


## Turned over: for every hold, in 20 seconds of it in the air.
func _turned_over() -> void:
	var least_far := INF
	var least_beats := 1000
	var ends := {}
	for seed in 40:
		var far := 0.0
		var beats := 0
		var was := Quaternion.IDENTITY
		var turning := false
		for i in int(20.0 * FPS):
			var q := Fingers.turned(float(i) / FPS, seed, Vector3.RIGHT)
			far = maxf(far, rad_to_deg(q.angle_to(Quaternion.IDENTITY)))
			var moving := rad_to_deg(q.angle_to(was)) > 0.05
			if moving and not turning:
				beats += 1
			turning = moving
			was = q
		least_far = minf(least_far, far)
		least_beats = mini(least_beats, beats)
		ends[str(Vector4(was.x, was.y, was.z, was.w).snappedf(0.01))] = true
	_ok(least_far >= 90.0, "20 s in the air turns it a long way from how it began, in every hold: at least %.0f degrees" % least_far)
	_ok(least_beats >= 4, "...in separate turnings, with fingers still between them: at least %d" % least_beats)
	_ok(ends.size() >= 36, "no two holds are alike: %d of 40" % ends.size())
	var no_room: Array = Fingers.at(10.0, 100.0, Fingers.TURN_FROM, 0.0, 0.0, 3, Vector3.RIGHT, 0.016)
	var some_room: Array = Fingers.at(10.0, 100.0, Fingers.TURN_FROM, 10.0, 0.0, 3, Vector3.RIGHT, 0.016)
	_ok((no_room[1] as Quaternion).is_equal_approx(some_room[1] as Quaternion), "control: with no room for them, however long they have had, fingers do nothing")


## A hold of [param seconds] at room rising, staying and falling, frame by frame: the fingers' clock runs only at full room, as [method Assembly.held_at] has it.
static func _through_room(seed: int, long: Vector3) -> Array:
	var out: Array = []
	var free := 0.0
	var i := 0
	var whole := 11.0
	while float(i) / FPS < whole:
		var h := float(i) / FPS
		var room := minf(Hands.smooth(h / 1.2), Hands.smooth((whole - h) / 0.9))
		if room >= 1.0:
			free += 1.0 / FPS
		out.append(Fingers.at(h, whole - h, room, free, 0.0, seed, long, 0.016))
		i += 1
	return out


## The largest step between two frames: `[meters, degrees]`.
static func _largest_step(poses: Array) -> Vector2:
	var most := Vector2.ZERO
	for i in range(1, poses.size()):
		most.x = maxf(most.x, ((poses[i][0]) as Vector3).distance_to(poses[i - 1][0] as Vector3))
		most.y = maxf(most.y, rad_to_deg((poses[i][1] as Quaternion).angle_to(poses[i - 1][1] as Quaternion)))
	return most


func _no_jump() -> void:
	var most := Vector2.ZERO
	var far_when_falling := 0.0
	for seed in 60:
		for long in [Vector3.RIGHT, Vector3.BACK]:
			var poses := _through_room(seed, long)
			var s := _largest_step(poses)
			most = Vector2(maxf(most.x, s.x), maxf(most.y, s.y))
			far_when_falling = maxf(far_when_falling, rad_to_deg((poses[int(10.0 * FPS)][1] as Quaternion).angle_to(Quaternion.IDENTITY)))
	_ok(most.y < 16.0, "it turns without a jump, room rising and falling: at most %.1f degrees between frames at 60 a second" % most.y)
	_ok(most.x < 0.008, "...and moves without one: at most %.1f mm" % (most.x * 1000.0))
	_ok(far_when_falling > 120.0, "control: and some of those were righted from far round: %.0f degrees" % far_when_falling)
	var jumps: Array = _through_room(5, Vector3.RIGHT)
	jumps[300] = [(jumps[300][0] as Vector3) + Vector3(0.0, 0.02, 0.0), Quaternion(Vector3.UP, 1.0) * (jumps[300][1] as Quaternion)]
	var j := _largest_step(jumps)
	_ok(j.x >= 0.008 and j.y >= 16.0, "control: a jump is called one: %.1f mm, %.0f degrees" % [j.x * 1000.0, j.y])


func _ends() -> void:
	var worst := 0.0
	for seed in 20:
		for pair in [[0.0, 10.0], [10.0, 0.0]]:
			var off: Array = Fingers.at(float(pair[0]), float(pair[1]), 1.0, 5.0, 0.0, seed, Vector3.RIGHT, 0.016)
			worst = maxf(worst, (off[0] as Vector3).length())
			# ...right after a grip and right before it leaves, the fingers are the room's to bring on: a knot is 0 there
		var pressed: Array = Fingers.at(5.0, 5.0, 0.0, 5.0, 0.0, seed, Vector3.RIGHT, 0.016)
		worst = maxf(worst, (pressed[0] as Vector3).length() + (pressed[1] as Quaternion).angle_to(Quaternion.IDENTITY))
	_ok(worst == 0.0, "at a grip, as it leaves, and pressed home, it is exactly where the record has it: %.5f off" % worst)
	var near_end: Array = Fingers.at(5.0, 0.02, 1.0, 5.0, 0.0, 4, Vector3.RIGHT, 0.016)
	_ok((near_end[0] as Vector3).length() < 0.001, "and it comes there without a jump: %.2f mm a moment before" % ((near_end[0] as Vector3).length() * 1000.0))


## Its lowest corner, in the world, as the record has it at [param x] and turned as [param off] says.
static func _lowest(x: Transform3D, half: Vector3, off: Array) -> float:
	var up := Vector3(0.0, half.y, 0.0)
	var b := x.basis * Basis(off[1] as Quaternion)
	var mid := x * up + (off[0] as Vector3)
	var low := INF
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				low = minf(low, (mid + b * Vector3(float(sx) * half.x, float(sy) * half.y, float(sz) * half.z)).y)
	return low


func _over_things() -> void:
	var shapes := [[Vector3(0.016, 0.0048, 0.008), Vector3.RIGHT, 0.016], [Vector3(0.032, 0.0016, 0.008), Vector3.RIGHT, 0.032], [Vector3(0.004, 0.0048, 0.024), Vector3.BACK, 0.024]]
	var x := Transform3D.IDENTITY
	for room in [Fingers.ROOM_TRIED, Fingers.ROOM_HOVER, Fingers.ROOM_DRAWN, Fingers.ROOM_CARRY]:
		var worst := INF
		for sh in shapes:
			var half: Vector3 = sh[0]
			var rest := _lowest(x, half, [Vector3.ZERO, Quaternion.IDENTITY])
			for seed in 16:
				for i in int(20.0 * 20.0):
					var off: Array = Fingers.at(float(i) / 20.0 + 1.0, 100.0, float(room), 0.0, 0.0, seed, sh[1], float(sh[2]))
					worst = minf(worst, _lowest(x, half, off) - rest)
		_ok(worst > -0.0035, "with room %.2f it goes no lower than an arm's sway under where the record has it: %.1f mm at most" % [float(room), -worst * 1000.0])
	var worst_air := INF
	var half: Vector3 = shapes[0][0]
	var rest := _lowest(x, half, [Vector3.ZERO, Quaternion.IDENTITY])
	for seed in 16:
		for i in int(20.0 * 20.0):
			var off: Array = Fingers.at(float(i) / 20.0 + 1.0, 100.0, 1.0, float(i) / 20.0, 0.0, seed, Vector3.RIGHT, 0.016)
			worst_air = minf(worst_air, _lowest(x, half, off) - rest)
	_ok(worst_air < -0.008, "control: in the air it is free to: %.0f mm under" % (-worst_air * 1000.0))


func _middle() -> void:
	var piece := {"kind": "brick", "w": 2, "d": 4}
	var x := Transform3D(Basis(Vector3.UP, 0.7) * Basis(Vector3.RIGHT, 0.4), Vector3(0.1, 0.3, -0.2))
	var held := {"h": 10.0, "left": 10.0, "room": 1.0, "back": 0.0, "free": 8.0, "seed": 11}
	var on := Fingers.on(x, held, piece)
	var off: Array = Fingers.at(10.0, 10.0, 1.0, 8.0, 0.0, 11, Vector3.BACK, 0.016)
	var up := Vector3(0.0, float((Assembly.KINDS["brick"] as Dictionary)["h"]) * Assembly.PLATE * 0.5, 0.0)
	_ok((on * up).distance_to(x * up + (off[0] as Vector3)) < 1e-5, "it turns about its own middle, which goes only where the hand does")
	_ok(on.origin.distance_to(x.origin + (off[0] as Vector3)) > 1e-4, "control: and what it stands on swings round that")
	_ok(absf(on.basis.determinant() - 1.0) < 1e-3, "and it is still that shape: %.4f" % on.basis.determinant())


func _draws_back() -> void:
	_ok(Fingers.drawn_back(1.0, Fingers.BACK_AFTER - 0.01) == 0.0, "a short stop over a place, the hand stays")
	var d := 8.0
	_ok(Fingers.drawn_back(0.0, d) == 0.0 and Fingers.drawn_back(d, d) == 0.0, "a long one begins and ends where it stopped")
	_ok(Fingers.drawn_back(d * 0.5, d) >= 0.999, "and in its middle it is all the way back")
	_ok(Fingers.drawn_back(1.3, Fingers.BACK_AFTER + 0.1) < 0.6 and Fingers.drawn_back(1.1, Fingers.BACK_AFTER + 0.1) > 0.1, "what is not much longer draws back not far")
	_ok(Fingers.free_in(d, d) > 0.0 and Fingers.free_in(Fingers.BACK_DELAY, d) == 0.0, "its fingers have room only once it is back")
	var went := 0.0
	var i := 0
	while float(i) / FPS < d:
		var s := float(i) / FPS
		if Fingers.drawn_back(s, d) < 0.999:
			var was := Fingers.free_in(s, d)
			var next := Fingers.free_in(s + 1.0 / FPS, d)
			went = maxf(went, next - was)
		i += 1
	_ok(went <= 1.01 / FPS, "...the fingers' clock and the hand's way agree")
	_ok(Fingers.free_in(1.0, Fingers.BACK_WHOLE - 0.01) == 0.0, "control: a stop too short to get all the way back has none")


func _same_twice() -> void:
	var order: Array = []
	for i in 60:
		order.append(float(i) * 0.37)
	var first := {}
	for t in order:
		first[t] = Fingers.at(float(t), 100.0, 1.0, float(t), 0.0, 9, Vector3.RIGHT, 0.016)
	order.reverse()
	var same := true
	for t in order:
		var again: Array = Fingers.at(float(t), 100.0, 1.0, float(t), 0.0, 9, Vector3.RIGHT, 0.016)
		same = same and (again[0] as Vector3) == (first[t][0] as Vector3) and (again[1] as Quaternion) == (first[t][1] as Quaternion)
	_ok(same, "the same moment twice is the same pose, however it was reached")
	var other: Array = Fingers.at(20.0, 100.0, 1.0, 20.0, 0.0, 10, Vector3.RIGHT, 0.016)
	var mine: Array = Fingers.at(20.0, 100.0, 1.0, 20.0, 0.0, 9, Vector3.RIGHT, 0.016)
	_ok(not (other[1] as Quaternion).is_equal_approx(mine[1] as Quaternion), "control: another hold is another pose")
