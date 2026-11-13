extends RefCounted
class_name Pen

## Pen - a pen writing by itself, as a hand would hold it: where its nib is as the hand's strokes go down, between them
## and while it points at what was written, how it leans, how it drifts when lifted, and its frame. The desk's pen
## ([DeskMedium]) and a pen at the table ([TableWork]) are this one (next/desk.md); when each thing is done is theirs -
## the desk's on the voice's words, the table's over its act's seconds.
##
## A page here is in the units of the hand's strokes (TeX points, y down the page), and a caller maps it onto its paper;
## lifts are meters. Pure functions of their arguments, so the table's bake poses a pen exactly as the show does.
##
## On a stroke the nib is where its ink has got to ([method Ink.nib_on]), so it is always at the ink's front. Between two
## strokes it lifts in an arc and travels from the end of one to the start of the next. It points at a thing written
## ([method point_path], [method pointing]): under a wide thing (a formula, a curve) it comes down near its start and
## sweeps along under it, then settles beside its right end, low on its height, where the body leans away over clean
## paper; at a small thing it comes straight to that place. Its body leans from the nib as a right hand holds it, to the
## right and a little down on the screen ([constant UP]), swaying slowly, turned a little with where the nib is across the
## page and trailing the nib's travel ([method lean]); lifted, it drifts as any held thing does ([method drift]), never
## while it writes. Through a long wait the hand settles, its palm down on the paper: the nib just over where it stopped and
## still ([constant SETTLED_LIFT], `steady`), but for a readjustment now and then ([method readjust]).

## How high the nib lifts between strokes, waits between actions, and points from (meters).
const LIFT := 0.004
const REST_LIFT := 0.022
const POINT_LIFT := 0.0035
## A hand settled through a long wait, its palm down on the paper: the nib this high, its drift and sway this share of a held
## pen's ([method drift], [method lean]'s `steady`).
const SETTLED_LIFT := 0.003
const SETTLED_SWAY := 0.02
## A settled hand readjusts the pen now and then ([method readjust]): about every [constant ADJUST_EVERY] seconds (as soon as
## 0.4 of that, as late as 1.6), some of those times not at all ([constant ADJUST_SKIP]), each move over [constant
## ADJUST_TAKES] seconds - the top turned to within [constant ADJUST_YAW] and [constant ADJUST_TILT] degrees of where the hand
## settled, the nib moved within [constant ADJUST_NIB] meters, most moves small - and still between.
const ADJUST_EVERY := 4.5
const ADJUST_SKIP := 0.35
const ADJUST_TAKES := Vector2(0.35, 0.8)
const ADJUST_YAW := 7.0
const ADJUST_TILT := 4.0
const ADJUST_NIB := 0.0005
## How it leans from its nib: up 48 degrees, and across to the right and 30 degrees toward the writer - back over the hand
## toward a right-handed writer's shoulder, on the screen to the right and a little down.
const UP := Vector3(0.582, 0.741, 0.336)
## Pointing: a thing this wide or wider is swept under, this far below it; where the nib stays, this far right of the
## thing's end (TeX points); the longest the sweep and the settle take together, and the sweep's share of that.
const POINT_WIDE := 29.0
const POINT_GAP := 4.5
const POINT_SWEEP := 0.9
const POINT_SPLIT := 0.7
## The shortest time the nib takes from one stroke to the next (seconds).
const TRAVEL_MIN := 0.05
## Where it waits once a line is written: this far right of its last stroke and below it, clear of the line (TeX points).
const REST_OFF := Vector2(42.0, 13.0)
## The hand: the lean's slow sway (degrees, about the vertical and in its rise), its turn across the page's width (degrees
## from the left edge to the right), how far the top trails the nib (seconds of its travel, at most [constant TRAIL_MAX]
## degrees), measured over [constant MOTION_DT] seconds.
const SWAY_YAW := 5.0
const SWAY_TILT := 3.0
const REACH_YAW := 10.0
const TRAIL := 1.7
const TRAIL_MAX := 7.0
const MOTION_DT := 0.1


## Where the nib is [param t] seconds into a hand's schedule ([param strokes], [method Ink.schedule]'s): `{at (the strokes'
## units), lift (meters)}` - over the first stroke before it, on a stroke as far as its ink, in the air between two, and
## lifted over the last once it is done.
static func on_strokes(strokes: Array, t: float) -> Dictionary:
	var prev := Vector2.INF
	var prev_t1 := 0.0
	for s in strokes:
		var st: Dictionary = s
		var pts: PackedVector2Array = st["points"]
		if pts.is_empty():
			continue
		var t0 := float(st["t0"])
		if t < t0:
			var from: Vector2 = prev if prev != Vector2.INF else pts[0]
			var u := clampf((t - prev_t1) / maxf(t0 - prev_t1, TRAVEL_MIN), 0.0, 1.0)
			return {"at": from.lerp(pts[0], smoothstep(0.0, 1.0, u)), "lift": sin(u * PI) * LIFT}
		if t <= float(st["t1"]):
			return {"at": Ink.nib_on(st, t), "lift": 0.0}
		prev = pts[pts.size() - 1]
		prev_t1 = float(st["t1"])
	return {"at": prev if prev != Vector2.INF else Vector2.ZERO, "lift": LIFT}


## Where the nib waits after writing at [param p] ([constant REST_OFF]), in [param p]'s units, which are [param per_pt] to a
## TeX point.
static func rest_near(p: Vector2, per_pt := 1.0) -> Vector2:
	return p + REST_OFF * per_pt


## The nib's way while it points at the thing in [param box]: `[down, along, stays]`, in the box's units, which are
## [param per_pt] to a TeX point.
static func point_path(box: Rect2, per_pt := 1.0) -> Array:
	var gap := POINT_GAP * per_pt
	var stays := Vector2(box.end.x + gap * 0.5, box.position.y + box.size.y * 0.7)
	if box.size.x >= POINT_WIDE * per_pt:
		var y := box.end.y + gap * 0.5
		return [Vector2(box.position.x + box.size.x * 0.1, y), Vector2(box.end.x - box.size.x * 0.05, y), stays]
	return [stays, stays, stays]


## Where the nib is along [param path] ([method point_path]) [param since] seconds after it arrived at its start, the
## point lasting [param lasts] seconds from there: swept along, then settled where it stays, within [constant
## POINT_SWEEP].
static func pointing(path: Array, since: float, lasts: float) -> Vector2:
	var u := clampf(since / clampf(lasts, TRAVEL_MIN, POINT_SWEEP), 0.0, 1.0)
	if u < POINT_SPLIT:
		return (path[0] as Vector2).lerp(path[1], smoothstep(0.0, 1.0, u / POINT_SPLIT))
	return (path[1] as Vector2).lerp(path[2], smoothstep(0.0, 1.0, (u - POINT_SPLIT) / (1.0 - POINT_SPLIT)))


## The pen's lean at [param now]: [param base] swayed slowly about the vertical and in its rise (the phases the hand's
## [param seed]'s), turned toward the page's top as the nib goes left ([param x_share], 0 at the page's left edge, 1 at its
## right - a forearm pivoting at the elbow), and its top trailing [param motion], the nib's travel (meters a second). A
## unit vector, always within a few degrees of [param base]. The same moment is the same lean.
static func lean(base: Vector3, now: float, seed: int, x_share: float, motion: Vector3, steady := 0.0) -> Vector3:
	var ph := _phases(seed)
	var up := base.normalized()
	var sway := _sway(steady)
	up = turned(up, SWAY_YAW * sway * (0.65 * sin(TAU * now / 7.3 + ph[0]) + 0.35 * sin(TAU * now / 3.1 + ph[1]))
		+ REACH_YAW * (0.7 - clampf(x_share, 0.0, 1.0)), SWAY_TILT * sway * sin(TAU * now / 5.7 + ph[2]))
	var trail := Vector3(motion.x, 0.0, motion.z) * -TRAIL
	var most := tan(deg_to_rad(TRAIL_MAX))
	if trail.length() > most:
		trail = trail.normalized() * most
	return (up + trail).normalized()


## The nib's drift at [param now], [param lift] meters off the paper (meters, in the table's space): a held thing's drift
## ([method Hands.drift]) as a hand holding a pen up sways - full at [constant REST_LIFT], slight while it points, none
## while it writes, where the nib is the ink's - and a settled hand's ([param steady], 0 to 1) that much less.
static func drift(now: float, seed: int, lift: float, steady := 0.0) -> Vector3:
	return Hands.drift(now, seed, Hands.HOLD_SWAY * clampf(lift / REST_LIFT, 0.0, 1.0) * _sway(steady))[0]


## [param up] turned [param yaw] degrees about the vertical, then [param tilt] degrees in its rise.
static func turned(up: Vector3, yaw: float, tilt: float) -> Vector3:
	var v := up.rotated(Vector3.UP, deg_to_rad(yaw))
	var flat := Vector3(v.x, 0.0, v.z)
	return v.rotated(Vector3.UP.cross(flat).normalized(), deg_to_rad(tilt)) if flat.length() > 0.001 else v


## How a settled hand holds the pen at [param now], from where it settled: `{yaw, tilt}` (degrees, its top turned, [method
## turned]) and `nib` (meters, the nib moved across the paper) - still most of the time, moved to a new hold now and then
## over a moment, eased ([constant ADJUST_EVERY]). A pure function of the time and the hand's [param seed].
static func readjust(now: float, seed: int) -> Dictionary:
	var k := floori(now / ADJUST_EVERY)
	if now < _adjusts_at(k, seed):
		k -= 1
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["pen-adjust-takes", seed, k])
	var u := smoothstep(0.0, 1.0, (now - _adjusts_at(k, seed)) / rng.randf_range(ADJUST_TAKES.x, ADJUST_TAKES.y))
	var a := _hold(k - 1, seed)
	var b := _hold(k, seed)
	return {"yaw": lerpf(a[0], b[0], u), "tilt": lerpf(a[1], b[1], u), "nib": Vector3(lerpf(a[2], b[2], u), 0.0, lerpf(a[3], b[3], u))}


## When the hand's [param k]th readjustment begins (seconds).
static func _adjusts_at(k: int, seed: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["pen-adjust-at", seed, k])
	return (float(k) + rng.randf_range(0.0, 0.6)) * ADJUST_EVERY


## The hold the hand comes to at its [param k]th readjustment, or the one before where it makes none ([constant ADJUST_SKIP]):
## [yaw, tilt, nib x, nib z], most of each near where it settled.
static func _hold(k: int, seed: int) -> PackedFloat32Array:
	for j in range(k, k - 8, -1):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(["pen-adjust-hold", seed, j])
		if rng.randf() < ADJUST_SKIP:
			continue
		var out := PackedFloat32Array()
		for most in [ADJUST_YAW, ADJUST_TILT, ADJUST_NIB, ADJUST_NIB]:
			var r := rng.randf_range(-1.0, 1.0)
			out.append(float(most) * signf(r) * pow(absf(r), 1.6))
		return out
	return PackedFloat32Array([0.0, 0.0, 0.0, 0.0])


## How much of a held pen's sway and drift a hand [param steady] settled (0 to 1) keeps.
static func _sway(steady: float) -> float:
	return lerpf(1.0, SETTLED_SWAY, clampf(steady, 0.0, 1.0))


## A pen built with its nib at its origin and its body up along +Y, its nib at [param nib] and its body along [param up].
static func frame(nib: Vector3, up: Vector3) -> Transform3D:
	var y := up.normalized()
	var x := y.cross(Vector3.FORWARD)
	if x.length() < 0.01:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	return Transform3D(Basis(x, y, x.cross(y).normalized()), nib)


## A pen held by its tip at [param nib], its body along [param up]: turned from where it rests ([param rest]) so the way
## from its [param tip] to its [param grip] (its own space) lies along [param up].
static func held(rest: Transform3D, tip: Vector3, grip: Vector3, nib: Vector3, up: Vector3) -> Transform3D:
	var a0 := rest * tip
	var v0 := (rest * grip - a0).normalized()
	var v := up.normalized()
	var r := Basis(Quaternion(v0, v)) if v0.length() > 0.5 and v0.dot(v) > -0.999 else Basis.IDENTITY
	return Transform3D(r, nib - r * a0) * rest


## The hand's phases, from its seed: eight angles. Their salt is the desk's: another would change how every letter's pen
## sways.
static func _phases(seed: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for k in 8:
		out.append(TAU * float(absi(hash(["desk-cam", seed, 700 + k])) % 10007) / 10006.0)
	return out
