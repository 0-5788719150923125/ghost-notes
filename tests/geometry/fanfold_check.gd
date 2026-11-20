extends SceneTree

## The printer's paper ([Fanfold]), baked over a printer with a paper rest, a desk's end and a heap, and read at every frame of
## its fold:
##
##   It folds: each crease lands on the heap at the edge it should, one way and then the other, and the fold's end meets its
##   beginning. Control: a sheet with no creases (as stiff at a perforation as anywhere, resting straight) does not.
##
##   It bends at its creases: in what hangs free, a crease turns many times as far as a point of a panel does, over the whole
##   fold. Control: the sheet with no creases, whose turning spreads along it in an arc.
##
##   It never runs on: no point of it goes past the heap's far edge or under the heap's top, and what hangs varies by at most a
##   panel and a half as it feeds. Control: the sheet with no creases.
##
##   It shades as paper does: its strip is one smooth surface through each panel and parts at each crease, and nowhere else
##   (control: the same shape with no creases marked has no seam); each normal agrees with the faces round it, and its back
##   ([method Fanfold.turned]) faces the other way and is wound the other way (control: the back made with the front's normals,
##   as one material drawn on both sides of one surface would be).
##
##   godot --headless --path . --script tests/geometry/fanfold_check.gd

const Fold := preload("res://src/geometry/fanfold.gd")

## The scene: the printer's body and cover, a paper rest leaning back off its top, the desk under it to its end, and the heap
## past the end (the slot at the origin, x out toward the desk's end, y up; m).
const SCENE := {
	"exit": Vector2(0.2588, 0.9659),
	"solids": [
		[Vector2(-0.23, -0.125), Vector2(0.07, -0.125), Vector2(0.07, -0.005), Vector2(-0.23, -0.005)],
		[Vector2(-0.09, -0.025), Vector2(0.03, -0.025), Vector2(0.03, 0.005), Vector2(-0.09, 0.005)],
		[Vector2(0.03, -0.008), Vector2(0.169, 0.1), Vector2(0.026, -0.004)],
		[Vector2(-2.0, -0.885), Vector2(0.18, -0.885), Vector2(0.18, -0.125), Vector2(-2.0, -0.125)],
	],
	"heap": Vector2(0.20, -0.433), "floor": -0.885, "panel": 0.28, "links": 10,
}
## What hangs free: past the desk's end and this far over the heap's top (m).
const FREE_OVER := 0.02
## How many times as far as a point of a panel a crease turns, at least, in what hangs free.
const CREASE_TIMES := 4.0
## How far past the heap's far edge or under its top a point may be (m), and how many panels what hangs may vary by.
const RUN_ON := 0.01
const HANGS_PANELS := 1.5
## The most a normal is off the faces round it (degrees).
const FACE_OFF := 35.0

var _fails: Array = []


func _init() -> void:
	var scene := _scene({})
	var flat := _scene({"crease_stiff": 1.0, "crease_rest": 0.0})
	var baked := Fold.bake(scene)
	var control := Fold.bake(flat)
	_check(bool(baked["laid"]) and float(baked["gap"]) < 0.002,
		"each crease lands on the heap at its edge and the fold's end meets its beginning (gap %.4f m)" % float(baked["gap"]))
	_check(not bool(control["laid"]) or float(control["gap"]) >= 0.002,
		"control: a sheet with no creases does not fold onto the heap (laid %s, gap %.4f m)" % [str(control["laid"]), float(control["gap"])])
	var ours := _creased(baked, scene)
	var theirs := _creased(control, flat)
	_check(ours >= CREASE_TIMES, "what hangs free bends at its creases (a crease turns %.1f times as far as a point of a panel)" % ours)
	_check(theirs < CREASE_TIMES, "control: a sheet with no creases bends in an arc (%.1f times)" % theirs)
	var run := _runs_on(baked, scene)
	var run_control := _runs_on(control, flat)
	_check(run.is_empty(), "it never runs past the heap or under it, and what hangs varies by at most %.1f panels (%s)" % [HANGS_PANELS, run])
	_check(not run_control.is_empty(), "control: a sheet with no creases runs on (%s)" % run_control)
	var shape := Fold.profile(baked, 0.13)
	var front := Fold.arrays(shape, 0.38, 1.0)
	var back := Fold.turned(front)
	var wrong := front.duplicate()
	wrong[Mesh.ARRAY_INDEX] = back[Mesh.ARRAY_INDEX]
	var creases := 0
	for i in range(1, (shape["crease"] as PackedByteArray).size() - 1):
		creases += (shape["crease"] as PackedByteArray)[i]
	var plain := shape.duplicate()
	var none := PackedByteArray()
	none.resize((shape["crease"] as PackedByteArray).size())
	plain["crease"] = none
	_check(creases > 0 and _seams(front) == creases, "the strip parts at each of its %d creases and nowhere else (%d seams)" % [creases, _seams(front)])
	_check(_seams(Fold.arrays(plain, 0.38, 1.0)) == 0, "control: the same shape with no creases marked is one surface (%d seams)" % _seams(Fold.arrays(plain, 0.38, 1.0)))
	_check(_face_off(front) <= FACE_OFF and _face_off(back) <= FACE_OFF,
		"each normal agrees with the faces round it, front and back (front %.1f, back %.1f degrees)" % [_face_off(front), _face_off(back)])
	_check(_face_off(wrong) > 90.0, "control: the back drawn with the front's normals disagrees with its faces (%.1f degrees)" % _face_off(wrong))
	if _fails.is_empty():
		print("fanfold_check: ALL OK")
		quit(0)
	else:
		print("fanfold_check: %d FAILURE(S)" % _fails.size())
		for f in _fails:
			print("   ", f)
		quit(1)


func _check(ok: bool, msg: String) -> void:
	print(("   ok   " if ok else "   FAIL ") + msg)
	if not ok:
		_fails.append(msg)


static func _scene(more: Dictionary) -> Dictionary:
	var out := SCENE.duplicate(true)
	var solids: Array = []
	for poly in SCENE["solids"]:
		solids.append(PackedVector2Array(poly))
	out["solids"] = solids
	out.merge(more, true)
	return out


## Over the fold's frames, how many times as far a crease turns as a point of a panel does, on the whole, in what hangs free.
static func _creased(baked: Dictionary, scene: Dictionary) -> float:
	var frames: Array = baked["frames"]
	var cycle := 2.0 * float(scene["panel"])
	var end := float((scene["solids"][3] as PackedVector2Array)[1].x)
	var top := float((scene["heap"] as Vector2).y)
	var at := Vector2.ZERO           # turning at creases, and how many
	var off := Vector2.ZERO          # elsewhere
	for f in frames.size():
		var shape := Fold.profile(baked, cycle * float(f) / float(frames.size()))
		var pts: PackedVector2Array = shape["points"]
		var crease: PackedByteArray = shape["crease"]
		for i in range(1, pts.size() - 1):
			if pts[i].x <= end or pts[i].y < top + FREE_OVER:
				continue
			var e1 := pts[i] - pts[i - 1]
			var e2 := pts[i + 1] - pts[i]
			var turn := absf(atan2(e1.cross(e2), e1.dot(e2)))
			if crease[i] == 1:
				at += Vector2(turn, 1.0)
			else:
				off += Vector2(turn, 1.0)
	if at.y == 0.0 or off.y == 0.0 or off.x == 0.0:
		return 0.0
	return (at.x / at.y) / (off.x / off.y)


## What runs on, over the fold's frames: a point past the heap's far edge or under its top, or what hangs varying by more than a
## panel; empty where nothing does.
static func _runs_on(baked: Dictionary, scene: Dictionary) -> String:
	var frames: Array = baked["frames"]
	var panel := float(scene["panel"])
	var heap: Vector2 = scene["heap"]
	var lo := INF
	var hi := -INF
	var out := ""
	for f in frames.size():
		var shape := Fold.profile(baked, 2.0 * panel * float(f) / float(frames.size()))
		var pts: PackedVector2Array = shape["points"]
		var along: PackedFloat32Array = shape["along"]
		var hangs := along[along.size() - 1]
		for i in pts.size():
			if pts[i].x > heap.x + panel + RUN_ON or pts[i].y < heap.y - RUN_ON:
				out = "frame %d: a point at %s" % [f, str(pts[i])]
			if pts[i].y < heap.y + 0.004 and pts[i].x >= heap.x - RUN_ON:
				hangs = minf(hangs, along[i])
		lo = minf(lo, hangs)
		hi = maxf(hi, hangs)
	if out.is_empty() and hi - lo > panel * HANGS_PANELS:
		out = "what hangs runs from %.3f to %.3f m" % [lo, hi]
	return out if not out.is_empty() else ""


## How many times strip [param arr] parts: rows laid twice at one place, a run ending and the next beginning there.
static func _seams(arr: Array) -> int:
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var count := 0
	for r in range(2, verts.size() - 1, 2):
		if verts[r].is_equal_approx(verts[r - 2]) and verts[r + 1].is_equal_approx(verts[r - 1]):
			count += 1
	return count


## The most any vertex normal of strip [param arr] is off the faces round it (degrees).
static func _face_off(arr: Array) -> float:
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var most := 0.0
	for t in range(0, indices.size(), 3):
		var a := verts[indices[t]]
		var b := verts[indices[t + 1]]
		var c := verts[indices[t + 2]]
		# (Godot's front face is wound clockwise: its normal is (c - a) x (b - a))
		var face := (c - a).cross(b - a)
		if face.length_squared() < 1.0e-14:
			continue
		face = face.normalized()
		for k in 3:
			most = maxf(most, rad_to_deg(normals[indices[t + k]].angle_to(face)))
	return most
