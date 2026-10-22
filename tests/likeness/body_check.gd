extends SceneTree

## body_check - a Likeness's body is a skeleton that holds a posture (next/likeness.md, "The fourth pass";
## [LikenessFace], [LikenessPlan]).
##
##   godot --headless --path . --script tests/likeness/body_check.gd
##
## THE ARM BENDS AS AN ARM: when the shoulder moves and the hand stays, the elbow found keeps both bones'
## lengths and bends the way it bent ([method LikenessFace.elbow]); the shoulder and the hand unmoved, it is
## where it was. A bone moved ([method LikenessFace.bone]) takes its two ends exactly where they go.
##
## THE SKIN: at the still's own pose every vertex is where it is; with the torso leaned and the shoulders
## lifted, a vertex of a RESTING HAND stays put, one of the torso moves with it, one in the room stays, and
## one on the forearm moves part of the way its elbow does. The control: the same hand NOT resting goes with the body.
##
## THE POSTURE HOLDS AND SHIFTS ([method LikenessPlan.posture]), A PURE FUNCTION OF TIME: asked in another
## order it is the same; stepped a millisecond at a time it never jumps; over ten minutes it shifts (it
## spans a good part of its range) - and IT DOES NOT ROCK (2026-10-22, the user: "rocking weirdly back and
## forth"): what is quick in it, less its own 4-second mean, is a small share of it. The control is the
## head, played from their own quick motion, whose quick share must be large - so the measure can tell.

var _fails := 0
var _checks := 0


func _init() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_fails += 1
		print("  FAIL: " + what)


func _run() -> void:
	_arm()
	_skin()
	_posture()
	print("body_check: %d checks, %d failed" % [_checks, _fails])
	print("ALL OK" if _fails == 0 else "FAILED")
	quit(1 if _fails > 0 else 0)


# --- the arm ----------------------------------------------------------------------------------------

func _arm() -> void:
	var s := Vector2(100, 100)
	var e := Vector2(80, 220)
	var w := Vector2(180, 300)
	_ok(LikenessFace.elbow(s, e, w, s, w).distance_to(e) < 0.05, "the elbow moved with nothing else moving")
	var s2 := s + Vector2(9, -6)
	var e2 := LikenessFace.elbow(s, e, w, s2, w)
	_ok(absf(e2.distance_to(s2) - e.distance_to(s)) < 0.05 and absf(e2.distance_to(w) - w.distance_to(e)) < 0.05,
		"the elbow found does not keep the arm's lengths: %.2f, %.2f against %.2f, %.2f" % [e2.distance_to(s2),
			e2.distance_to(w), e.distance_to(s), w.distance_to(e)])
	_ok(signf((w - s2).cross(e2 - s2)) == signf((w - s).cross(e - s)), "the elbow bent the other way")
	_ok(e2.distance_to(e) > 1.0 and e2.distance_to(e) < 20.0, "the elbow did not follow its shoulder (%.2f)" % e2.distance_to(e))
	var b := LikenessFace.bone(s, e, s2, e2)
	_ok((b * s).distance_to(s2) < 0.01 and (b * e).distance_to(e2) < 0.01, "a bone moved does not take its ends where they go")


# --- the skin ---------------------------------------------------------------------------------------

## A made face on a made body: the face round (400, 200), the body's points - a torso point, a resting
## hand's, a forearm's and one out in the room - weighed as the rig weighs them.
func _face(rests: bool) -> LikenessFace:
	var f := LikenessFace.new()
	f.size = Vector2(1000, 800)
	var oval := 36
	f.oval = PackedInt32Array(range(oval))
	var pts: Array = []
	var face := PackedVector2Array()
	for i in LikenessFace.FACE:
		var a := TAU * float(i) / float(oval)
		var p := Vector2(500, 200) + (Vector2(cos(a) * 50.0, sin(a) * 65.0) if i < oval else Vector2(cos(a), sin(a)) * float(i % 40))
		face.append(p)
		pts.append([p.x / 1000.0, p.y / 800.0, 0.0])
	f.layout = face
	f.weights = PackedFloat32Array()
	f.eye_weights = PackedFloat32Array()
	for i in LikenessFace.FACE:
		f.weights.append(0.0)
		f.eye_weights.append(0.0)
	f.steady = PackedInt32Array(range(LikenessFace.FACE))
	f.anchors = PackedVector2Array([Vector2(0, 0), Vector2(1000, 0), Vector2(0, 800), Vector2(1000, 800)])
	f.box = Rect2(400, 100, 200, 200)
	# the body's points: the torso, the resting hand (theirs left, on the picture's right), the forearm, the room
	var body := [[500.0, 500.0], [700.0, 700.0], [660.0, 600.0], [950.0, 100.0]]
	var rest := oval + body.size() + 4
	var skin := {}
	for b in LikenessFace.BONES:
		var col: Array = []
		col.resize(rest)
		col.fill(0.0)
		skin[b] = col
	(skin["torso"] as Array)[oval] = 1.0
	(skin["hand_l"] as Array)[oval + 1] = 1.0
	(skin["fore_l"] as Array)[oval + 2] = 1.0
	for i in oval:
		(skin["head"] as Array)[i] = 0.5
		(skin["torso"] as Array)[i] = 0.5
	var arm := {"shoulder": [620.0, 400.0], "elbow": [640.0, 560.0], "wrist": [700.0, 700.0], "tip": [740.0, 720.0], "rests": rests}
	var other := {"shoulder": [380.0, 400.0], "elbow": [360.0, 560.0], "wrist": [300.0, 700.0], "tip": [260.0, 720.0], "rests": rests}
	f._bodies = [{"body": body, "skin": skin, "triangles": [], "skeleton": {"neck": [500.0, 400.0], "hip": [500.0, 900.0],
		"width": 240.0, "l": arm, "r": other}}]
	f.set_still({"points": pts, "light": []}, 0)
	return f


func _skin() -> void:
	var f := _face(true)
	var at_rest := f.bones(f.still_face, PackedFloat32Array([0, 0, 0, 0, 0, 0, 0]))
	var still := f.vertices(f.still_face, f.still_face, at_rest)
	var plain := f.vertices(f.still_face, f.still_face)
	var first := LikenessFace.FACE + f.oval.size() + f.oval.size()
	var moved := 0.0
	for i in still.size():
		moved = maxf(moved, still[i].distance_to(f._mesh[i]))
		moved = maxf(moved, plain[i].distance_to(f._mesh[i]))
	_ok(moved < 0.01, "at the still's own pose a vertex moved %.3f px" % moved)
	# leaned aside and nearer, breathing in, the shoulders up, the hands where they rest
	var m := PackedFloat32Array([0, 0, 0, 0.05, 0.0, 0.03, 2.0])
	var bn := f.bones(f.still_face, m, 1.0, Vector2(0.01, 0.01), PackedVector2Array([Vector2.ZERO, Vector2.ZERO]))
	var v := f.vertices(f.still_face, f.still_face, bn)
	var torso_d := v[first].distance_to(f._mesh[first])
	var hand_d := v[first + 1].distance_to(f._mesh[first + 1])
	var fore_d := v[first + 2].distance_to(f._mesh[first + 2])
	var room_d := v[first + 3].distance_to(f._mesh[first + 3])
	_ok(torso_d > 3.0, "the torso did not move with its posture (%.2f px)" % torso_d)
	_ok(hand_d < 0.01, "a resting hand moved with the body (%.2f px)" % hand_d)
	var elbow_d := ((bn[5] as Transform2D) * Vector2(640, 560)).distance_to(Vector2(640, 560))
	_ok(fore_d > 0.3 and fore_d < elbow_d, "the forearm did not bend between the resting hand and the elbow (%.2f px, the elbow %.2f)" % [fore_d, elbow_d])
	_ok(room_d < 0.01, "the room moved (%.2f px)" % room_d)
	# a hand that drifts goes where it drifts
	var drift := f.bones(f.still_face, m, 1.0, Vector2.ZERO, PackedVector2Array([Vector2(0.01, 0.0), Vector2.ZERO]))
	var dv := f.vertices(f.still_face, f.still_face, drift)
	_ok(absf(dv[first + 1].x - f._mesh[first + 1].x - 2.4) < 0.01, "a resting hand did not drift where it was told")
	# THE CONTROL: the same hand not resting goes with its shoulder
	var g := _face(false)
	var gv := g.vertices(g.still_face, g.still_face, g.bones(g.still_face, m, 1.0, Vector2(0.01, 0.01)))
	_ok(gv[first + 1].distance_to(g._mesh[first + 1]) > 3.0, "a hand not in the picture stayed put: the check cannot tell")


# --- the posture ------------------------------------------------------------------------------------

func _plan(seed_in: int) -> LikenessPlan:
	var dir := ProjectSettings.globalize_path("user://body_check")
	DirAccess.make_dir_recursive_absolute(dir)
	var rows: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for n in 3000:
		var t := float(n) / 5.0
		rows.append([3.0 * sin(t * 1.9) + rng.randfn(0, 1), 2.0 * sin(t * 2.3 + 1.0), 1.5 * sin(t * 1.3), 0.03 * sin(t * 2.0),
			0.02 * sin(t * 1.6), 0.01 * sin(t * 2.2), 1.2 * sin(t * 1.8)])
	var f := FileAccess.open(dir.path_join("motion.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"rate": 5.0, "axes": ["yaw", "pitch", "roll", "x", "y", "near", "tilt"],
		"blinks_per_min": 20.0, "runs": [{"rows": rows}],
		"posture": {"sd": [0.04, 0.03, 0.01, 1.4], "corr": [[1, -0.3, 0, 0], [-0.3, 1, 0, -0.3], [0, 0, 1, 0], [0, -0.3, 0, 1]], "tau": 5.0}}))
	f.close()
	var p := LikenessPlan.new()
	var err := p.setup(dir.path_join("motion.json"), null, seed_in)
	_ok(err.is_empty(), "the made motion was not read: %s" % err)
	return p


func _posture() -> void:
	var p := _plan(7)
	var q := _plan(7)
	# a pure function: asked late first, then early, it is what another asked in order says
	var late := q.posture(400.0)
	q.posture(3.0)
	var same := true
	for t in [3.0, 41.7, 400.0, 0.2]:
		var a := p.posture(t)
		var b := q.posture(t)
		for k in 4:
			same = same and absf(a[k] - b[k]) < 1e-6
	_ok(same and absf(late[0] - p.posture(400.0)[0]) < 1e-6, "the posture at a moment depends on what was asked before it")
	# never a jump, and it shifts
	var step := 0.0
	var lo := PackedFloat32Array([INF, INF, INF, INF])
	var hi := PackedFloat32Array([-INF, -INF, -INF, -INF])
	var last := p.posture(0.0)
	var n := 600000
	for i in range(1, n, 7):
		var here := p.posture(float(i) * 0.001)
		for k in 4:
			step = maxf(step, absf(here[k] - last[k]) / maxf(p._posture_sd[k], 1e-9))
			lo[k] = minf(lo[k], here[k])
			hi[k] = maxf(hi[k], here[k])
		last = here
	_ok(step < 0.05, "the posture jumped %.3f of its spread in 7 ms" % step)
	_ok(hi[0] - lo[0] > 2.0 * p._posture_sd[0] and hi[3] - lo[3] > 2.0 * p._posture_sd[3],
		"over ten minutes the posture scarcely shifted: across %.4f, tilt %.3f" % [hi[0] - lo[0], hi[3] - lo[3]])
	# IT DOES NOT ROCK: the quick share of the posture against the head's
	var body := _quick_share(p, 3)
	var head := _quick_share(p, 0)
	print("  quicker than 4 s: the body's posture %.2f of it, the head %.2f" % [body, head])
	_ok(body < 0.35, "the body rocks: %.2f of its motion is quicker than 4 s" % body)
	_ok(head > 0.6, "the head's own quick motion reads as slow (%.2f): the measure cannot tell rocking" % head)
	# the shoulders and the hands stay small
	var most := 0.0
	for i in 600:
		var t := float(i) * 0.5
		var l := p.lifts(t)
		most = maxf(most, maxf(absf(l.x), absf(l.y)))
		for h in p.hands(t):
			most = maxf(most, h.length())
	_ok(most > 0.001 and most < 0.04, "the shoulders or hands moved %.4f of the shoulders' width" % most)


## How much of axis [param a] of [param p]'s motion, over ten minutes at 5 a second, is quicker than 4 s:
## the spread of it less its own 4-second mean, over its whole spread.
func _quick_share(p: LikenessPlan, a: int) -> float:
	var x := PackedFloat32Array()
	for i in 3000:
		x.append(p.motion(float(i) * 0.2)[a])
	var mean := 0.0
	for v in x:
		mean += v
	mean /= float(x.size())
	var whole := 0.0
	var quick := 0.0
	for i in range(10, x.size() - 10):
		var m := 0.0
		for j in range(i - 10, i + 11):
			m += x[j]
		m /= 21.0
		quick += (x[i] - m) * (x[i] - m)
		whole += (x[i] - mean) * (x[i] - mean)
	return sqrt(quick / maxf(whole, 1e-12))
