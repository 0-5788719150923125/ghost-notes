extends RefCounted
class_name LikenessFace

## LikenessFace - a set's rig and library, and the still a Likeness is drawn on (next/likeness.md, "The
## second build"). Read from `rig.json`, `library.json` and one of `stills.json`'s stills, which `actor.py
## rig`, `library` and `stills` make.
##
## THE MESH: the face's 468 points, two rings round the face oval (1.35 and 2 times as far from its middle
## - over the hair and beard, and out where any change has faded to nothing) and anchors on the frame's
## edge, joined by one triangulation made once on the set's first still. Drawn over the whole frame, it
## covers every pixel.
##
## THE HEAD TURNS ON THE NECK, THE BODY CARRIES IT (the third pass, 2026-10-22: "the body doesn't shift
## at all, the head doesn't really pivot at all (it just sort of floats around)"): the still's face turned
## through its own 3D points about the neck - a pivot below and behind its middle - by the motion's yaw,
## pitch and roll ([method pose]).
##
## THE BODY IS A SKELETON (the fourth pass, 2026-10-22, the user: "the actor's body is completely rigid
## ... we're not modeling the body - we're just shifting it around a bunch"): each still's own, from its
## pose (`rig.json`'s `stills`: the hips, the neck, each shoulder, elbow, wrist and the hand's end), and
## every vertex of its mesh weighed to its [constant BONES] - the room's what the weights leave. THE TORSO
## leans, settles and breathes about the hips ([method torso_xf]); each SHOULDER lifts on it; a HAND THAT
## RESTS in the picture stays where it rests, but for its own small drift, and its ARM BENDS between it
## and the moved shoulder - the elbow found as an arm's would be (two bones of their lengths, bending the
## way it bent) - a hand not in the picture goes with its shoulder ([method bones]). The frame's edge stays;
## the room is drawn under them, apart ([LikenessMedium]), so it never moves.
##
## THE LAYOUT: the set's first still's face. Every library mouth and eye is kept unwrapped into it (the
## box, [member box]), so a vertex's place in the layout is where it reads the library. A mouth or eye
## drawn is its own shape - the frame it came from, aligned onto the layout by the points that move with
## neither ([member steady]) - and the face moved toward it by each point's weight ([member weights] for
## the mouth, [member eye_weights] for the lids): mixed, both are morphs, never two images over each other.

const FACE := 468
## How far the chest's breath stretches the torso upward from the hips, from empty to full.
const BREATH := 0.008
## THE BONES a vertex is weighed to, as the rig names them (actor.py's `BONES`).
const BONES := ["torso", "head", "shoulder_l", "shoulder_r", "upper_l", "fore_l", "hand_l", "upper_r", "fore_r", "hand_r"]

var size := Vector2(1920, 1080)
var layout := PackedVector2Array()       # the 468 points of the first still, in its frame
var weights := PackedFloat32Array()      # how far each face point moves with the mouth
var eye_weights := PackedFloat32Array()  # ...and with the lids
var steady := PackedInt32Array()         # the points a face is aligned by
var oval := PackedInt32Array()
var ring1 := 1.35
var ring2 := 2.0
var ring_moves := 0.6
var anchors := PackedVector2Array()      # pixels
var triangles := PackedInt32Array()      # three indices each, the moving ones last
var box := Rect2()                       # the library's box in the layout
var image := Vector2i(512, 512)
var lay_uv := PackedVector2Array()       # every mesh vertex's place in the box's image, 0..1
var mask_mouth := ""
var mask_eyes := ""
## EACH STILL'S BODY, as the rig made it: `[{body, skin, skeleton, triangles}]`.
var _bodies: Array = []

## THE LIBRARY: every image's file (the mouths, then the eyes - one texture array), its shape in the
## layout, its cheeks' light when it was filmed (mean and spread); and which images each sound class and
## each eye state has.
var files: Array = []
var shapes: Array = []                   # PackedVector2Array per image
var lights: Array = []                   # PackedFloat32Array(6) per image
var mouths_of := {}                      # class -> [image index]
var eyes_of := {}                        # state -> [image index]
## Each mouth image's shape as their blendshapes say it (the library's `names`), by image; and how far
## past their own the library's were chosen (its Articulation).
var mouth_blends := {}
var articulation := 1.0

## THE STILL: its face in its frame, in 3D (pixels, the depth on the width's scale), and its cheeks' light.
var still_face := PackedVector2Array()
var still_3d := PackedVector3Array()
var still_light := PackedFloat32Array()
var _pivot := Vector3.ZERO
var _face_w := 1.0
var _uvs := PackedVector2Array()
## The still's mesh where it stands - face, rings, body, the frame's edge - and each vertex past the near
## ring's weights on the bones, kept sparse: vertex i's are [_skin_at[i], _skin_at[i + 1]).
var _mesh := PackedVector2Array()
var _skin_at := PackedInt32Array()
var _skin_bone := PackedInt32Array()
var _skin_w := PackedFloat32Array()
## THE SKELETON: the hips (what the torso leans and breathes about), the shoulders' width, and each arm
## (`l` theirs, on the picture's right; then `r`) as `{shoulder, elbow, wrist, rests}`.
var _hip := Vector2.ZERO
var _width := 1.0
var _arms: Array = []


## Read `rig.json` and `library.json`; "" when both are sound, else why not.
func load_set(rig_path: String, library_path: String) -> String:
	var r: Variant = ActorFolder.read_json(rig_path)
	if not (r is Dictionary):
		return "the rig is not made"
	var d: Dictionary = r
	if not d.has("eye_weights"):
		return "the rig is from the first build: Generate makes it again"
	if not (d.get("stills") is Array) or (d["stills"] as Array).is_empty() or not ((d["stills"] as Array)[0] as Dictionary).has("skin"):
		return "the rig is from before their body had bones: Generate makes it again"
	size = Vector2(float(d["size"][0]), float(d["size"][1]))
	layout = _vecs(d["layout"])
	weights = PackedFloat32Array(d["weights"])
	eye_weights = PackedFloat32Array(d["eye_weights"])
	oval = PackedInt32Array(d["oval"])
	ring1 = float(d.get("ring1", 1.35))
	ring2 = float(d.get("ring2", 2.0))
	ring_moves = float(d.get("ring_moves", 0.6))
	anchors = PackedVector2Array()
	for a in d["anchors"]:
		anchors.append(Vector2(float(a[0]) * size.x, float(a[1]) * size.y))
	triangles = _flat(d["triangles"])
	_bodies = d.get("stills", []) if d.get("stills") is Array else []
	var b: Array = d["box"]
	box = Rect2(float(b[0]), float(b[1]), float(b[2]) - float(b[0]), float(b[3]) - float(b[1]))
	image = Vector2i(int(d["image"][0]), int(d["image"][1]))
	var masks: Dictionary = d.get("masks", {})
	mask_mouth = rig_path.get_base_dir().path_join(String(masks.get("mouth", "mask_mouth.png")))
	mask_eyes = rig_path.get_base_dir().path_join(String(masks.get("eyes", "mask_eyes.png")))
	steady = PackedInt32Array()
	for i in FACE:
		if weights[i] < 0.2 and eye_weights[i] < 0.2:
			steady.append(i)
	var l: Variant = ActorFolder.read_json(library_path)
	if not (l is Dictionary):
		return "the library is not made"
	files = []
	shapes = []
	lights = []
	mouths_of = {}
	eyes_of = {}
	mouth_blends = {}
	articulation = float((l as Dictionary).get("articulation", 1.0))
	for e in (l as Dictionary).get("mouths", []):
		(mouths_of.get_or_add(String((e as Dictionary)["class"]), []) as Array).append(files.size())
		mouth_blends[files.size()] = PackedFloat32Array((e as Dictionary).get("blend", []))
		_keep(e, library_path.get_base_dir().path_join("library"))
	for e in (l as Dictionary).get("eyes", []):
		(eyes_of.get_or_add(String((e as Dictionary)["state"]), []) as Array).append(files.size())
		_keep(e, library_path.get_base_dir().path_join("library"))
	return "" if not mouths_of.is_empty() else "the library has no mouths"


func _keep(e: Dictionary, dir: String) -> void:
	files.append(dir.path_join(String(e["file"])))
	shapes.append(_vecs(e["shape"]))
	lights.append(PackedFloat32Array(e["light"]))


static func _flat(tris: Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	for t in tris:
		out.append_array(PackedInt32Array(t))
	return out


## DRAW ON [param still], the set's still [param k] (one of `stills.json`'s): its face, in 2D and 3D, the
## pivot it turns about, and its body's mesh.
func set_still(still: Dictionary, k := 0) -> void:
	var pts: Array = still.get("points", [])
	still_face = PackedVector2Array()
	still_3d = PackedVector3Array()
	for i in mini(FACE, pts.size()):
		var p: Array = pts[i]
		still_face.append(Vector2(float(p[0]) * size.x, float(p[1]) * size.y))
		still_3d.append(Vector3(float(p[0]) * size.x, float(p[1]) * size.y, float(p[2]) * size.x))
	still_light = PackedFloat32Array(still.get("light", []))
	# THE NECK: below the face's middle by most of its half height, and behind it
	var c := Vector3.ZERO
	var lo := INF
	var hi := -INF
	var left := INF
	var right := -INF
	for p in still_3d:
		c += p
		lo = minf(lo, p.y)
		hi = maxf(hi, p.y)
		left = minf(left, p.x)
		right = maxf(right, p.x)
	c /= float(maxi(1, still_3d.size()))
	var half := (hi - lo) * 0.5
	_pivot = c + Vector3(0.0, half * 0.9, half * 0.6)
	_face_w = maxf(1.0, right - left)
	# ITS BODY, as the rig made it for this still: its mesh, its skin and its skeleton
	var b: Dictionary = _bodies[k] if k < _bodies.size() and _bodies[k] is Dictionary else {}
	var body := _vecs(b.get("body", []))
	_mesh = still_face.duplicate()
	_mesh.append_array(ring(still_face, ring1))
	_mesh.append_array(ring(still_face, ring2))
	_mesh.append_array(body)
	_mesh.append_array(anchors)
	_skin(b.get("skin", {}) if b.get("skin") is Dictionary else {}, _mesh.size() - FACE - oval.size())
	if b.has("triangles"):
		triangles = _flat(b["triangles"])
	var sk: Dictionary = b.get("skeleton", {}) if b.get("skeleton") is Dictionary else {}
	_hip = _vec(sk.get("hip", [c.x, size.y]))
	_width = maxf(1.0, float(sk.get("width", _face_w * 2.0)))
	_arms = []
	for side in ["l", "r"]:
		var a: Dictionary = sk.get(side, {}) if sk.get(side) is Dictionary else {}
		_arms.append({"shoulder": _vec(a.get("shoulder", [c.x, c.y])), "elbow": _vec(a.get("elbow", [c.x, c.y])),
			"wrist": _vec(a.get("wrist", [c.x, c.y])), "rests": bool(a.get("rests", false))})
	_uvs = PackedVector2Array()
	for p in _mesh:
		_uvs.append(p / size)
	# EVERY VERTEX'S PLACE IN THE LIBRARY'S BOX: the face and its rings where the layout has them, the
	# rest as the still's face sits on the layout (outside the box, read by no mask)
	var to_lay := similarity(still_face, layout, steady)
	var lay := layout.duplicate()
	lay.append_array(ring(layout, ring1))
	lay.append_array(ring(layout, ring2))
	for i in range(lay.size(), _mesh.size()):
		lay.append(to_lay * _mesh[i])
	lay_uv = PackedVector2Array()
	for p in lay:
		lay_uv.append((p - box.position) / box.size)


## THE SKIN [param skin] (`{bone: [weight per vertex]}`) over the [param rest] vertices past the near
## ring, kept sparse; none (or not as many) leaves every one of them where it is.
func _skin(skin: Dictionary, rest: int) -> void:
	_skin_at = PackedInt32Array()
	_skin_bone = PackedInt32Array()
	_skin_w = PackedFloat32Array()
	var cols: Array = []
	for b in BONES:
		var col: Array = skin.get(b, []) if skin.get(b) is Array else []
		cols.append(col if col.size() == rest else [])
	for i in rest:
		_skin_at.append(_skin_w.size())
		for k in BONES.size():
			var col: Array = cols[k]
			if col.is_empty():
				continue
			var w := float(col[i])
			if w > 0.0005:
				_skin_bone.append(k)
				_skin_w.append(w)
	_skin_at.append(_skin_w.size())


static func _vec(a: Variant) -> Vector2:
	return Vector2(float(a[0]), float(a[1])) if a is Array and (a as Array).size() >= 2 else Vector2.ZERO


static func _vecs(a: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(a.size())
	for i in a.size():
		out[i] = Vector2(float(a[i][0]), float(a[i][1]))
	return out


## THE RING round [param face]'s oval at [param s] times its distance from the oval's middle.
func ring(face: PackedVector2Array, s: float) -> PackedVector2Array:
	var c := Vector2.ZERO
	for i in oval:
		c += face[i]
	c /= float(oval.size())
	var out := PackedVector2Array()
	for i in oval:
		out.append(c + (face[i] - c) * s)
	return out


## THE STILL'S FACE TURNED BY [param m] - the motion's yaw, pitch and roll against the shoulders (degrees):
## its 3D points turned about the neck and seen straight on. Where the head goes besides is the body's.
func pose(m: PackedFloat32Array) -> PackedVector2Array:
	if m.size() < 3 or still_3d.is_empty():
		return still_face
	var b := Basis.from_euler(Vector3(deg_to_rad(-m[1]), deg_to_rad(m[0]), deg_to_rad(m[2])))
	var out := PackedVector2Array()
	out.resize(still_3d.size())
	for i in still_3d.size():
		var q := _pivot + b * (still_3d[i] - _pivot)
		out[i] = Vector2(q.x, q.y)
	return out


## THE TORSO'S POSTURE [param m] (the motion's across, down - face widths - nearer, and tilt) with the
## chest [param breath] full (0..1), as one transform of the picture: about the hips, turned by the tilt,
## scaled by the nearness (and upward by the breath), moved.
func torso_xf(m: PackedFloat32Array, breath := 0.5) -> Transform2D:
	if m.size() < 7:
		return Transform2D.IDENTITY
	var near := exp(m[5])
	var up := 1.0 + BREATH * (breath - 0.5)
	var t := Transform2D(deg_to_rad(m[6]), Vector2(near, near * up), 0.0, Vector2.ZERO)
	var shift := Vector2(m[3], m[4]) * _face_w
	return Transform2D(0.0, _hip + shift) * t * Transform2D(0.0, -_hip)


## EVERY BONE'S TRANSFORM ([constant BONES]' order) for the face turned to [param posed] on a torso at
## [param m] ([method torso_xf]) breathing [param breath], the shoulders lifted by [param lifts] (x theirs
## left, y right; shares of the shoulders' width, up is more) and the resting hands moved by [param hands]
## (each a share of the shoulders' width): the head turned on the torso; each arm's elbow found between its
## lifted shoulder and its hand, so the hand stays where it rests.
func bones(posed: PackedVector2Array, m: PackedFloat32Array, breath := 0.5, lifts := Vector2.ZERO,
		hands := PackedVector2Array()) -> Array:
	var torso := torso_xf(m, breath)
	var out: Array = [torso, torso * similarity(still_face, posed, steady)]
	var lifted: Array = []
	for side in 2:
		var l := torso * Transform2D(0.0, Vector2(0.0, -(lifts.x if side == 0 else lifts.y) * _width))
		lifted.append(l)
		out.append(l)
	for side in 2:
		var lift: Transform2D = lifted[side]
		var a: Dictionary = _arms[side] if side < _arms.size() else {}
		if a.is_empty() or not bool(a["rests"]):
			out.append_array([lift, lift, lift])
			continue
		var s: Vector2 = a["shoulder"]
		var e: Vector2 = a["elbow"]
		var w: Vector2 = a["wrist"]
		var s2 := lift * s
		var w2 := w + (hands[side] * _width if side < hands.size() else Vector2.ZERO)
		var e2 := elbow(s, e, w, s2, w2)
		out.append(bone(s, e, s2, e2))
		out.append(bone(e, w, e2, w2))
		out.append(Transform2D(0.0, w2 - w))
	return out


## WHERE AN ELBOW GOES when its shoulder [param s] goes to [param s2] and its wrist [param w] to [param
## w2]: the arm's two bones keep their lengths (as far as they can reach) and bend the way they bent at
## [param e].
static func elbow(s: Vector2, e: Vector2, w: Vector2, s2: Vector2, w2: Vector2) -> Vector2:
	var l1 := s.distance_to(e)
	var l2 := e.distance_to(w)
	if l1 < 1.0 or l2 < 1.0 or s2.distance_to(w2) < 1.0:
		return e + (s2 - s)
	var d := clampf(s2.distance_to(w2), absf(l1 - l2) + 0.01, l1 + l2 - 0.01)
	var a := acos(clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0))
	var bend := 1.0 if (w - s).cross(e - s) >= 0.0 else -1.0
	return s2 + (w2 - s2).normalized().rotated(a * bend) * l1


## THE BONE from [param a] to [param b] moved to lie from [param a2] to [param b2]: turned and scaled about
## its start, and moved.
static func bone(a: Vector2, b: Vector2, a2: Vector2, b2: Vector2) -> Transform2D:
	var v := b - a
	var v2 := b2 - a2
	var den := v.length_squared()
	if den < 1e-6:
		return Transform2D(0.0, a2 - a)
	var c := v.dot(v2) / den
	var sn := v.cross(v2) / den
	var t := Transform2D(Vector2(c, sn), Vector2(-sn, c), Vector2.ZERO)
	t.origin = a2 - t * a
	return t


## The similarity (scale, turn, shift) taking [param src]'s [member steady] points onto [param dst]'s.
func align(src: PackedVector2Array, dst: PackedVector2Array) -> Transform2D:
	return similarity(src, dst, steady)


## THE SIMILARITY (scale, turn, shift) that best takes [param src]'s points [param idx] onto [param
## dst]'s, least squares.
static func similarity(src: PackedVector2Array, dst: PackedVector2Array, idx: PackedInt32Array) -> Transform2D:
	var ms := Vector2.ZERO
	var md := Vector2.ZERO
	for i in idx:
		ms += src[i]
		md += dst[i]
	ms /= float(idx.size())
	md /= float(idx.size())
	var den := 0.0
	var c := 0.0
	var s := 0.0
	for i in idx:
		var a := src[i] - ms
		var b := dst[i] - md
		den += a.length_squared()
		c += a.x * b.x + a.y * b.y
		s += a.x * b.y - a.y * b.x
	if den <= 0.0:
		return Transform2D(0.0, md - ms)
	c /= den
	s /= den
	var x := Vector2(c, s)
	var y := Vector2(-s, c)
	var t := Transform2D(x, y, Vector2.ZERO)
	t.origin = md - t * ms
	return t


## THE FACE [param posed] BENT TO ITS MOUTH AND EYES: [param mouth] and [param eyes] (`[[image, weight]]`,
## image -1 for the still's own) - aligned to the layout, each point moved toward the images' own shapes
## by its weight, and set back.
func target(posed: PackedVector2Array, mouth: Array, eyes: Array) -> PackedVector2Array:
	var t := align(posed, layout)
	var back := t.affine_inverse()
	var out := posed.duplicate()
	for i in FACE:
		var wm := weights[i]
		var we := eye_weights[i]
		if wm <= 0.0 and we <= 0.0:
			continue
		var here := t * posed[i]
		var p := here
		if wm > 0.0:
			p = p.lerp(_want(i, here, mouth), wm)
		if we > 0.0:
			p = p.lerp(_want(i, here, eyes), we)
		out[i] = back * p
	return out


## Where point [param i] goes for [param mix]: its images' shapes there, weighed - the still's own place
## ([param here]) for image -1.
func _want(i: int, here: Vector2, mix: Array) -> Vector2:
	var want := Vector2.ZERO
	var total := 0.0
	for e in mix:
		var w := float(e[1])
		want += (here if int(e[0]) < 0 else (shapes[int(e[0])] as PackedVector2Array)[i]) * w
		total += w
	return want / total if total > 0.0 else here


## THE MESH'S VERTICES for the still turned to [param posed], bent to [param bent], its bones at [param
## at] ([method bones]; none, the still's own pose): the face where it is bent to and the near ring with the
## head (part of the way with the jaw), both on the torso; every other vertex by its weights on the bones,
## the room's share staying where it is.
func vertices(posed: PackedVector2Array, bent: PackedVector2Array, at: Array = []) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(_mesh.size())
	var torso: Transform2D = at[0] if not at.is_empty() else Transform2D.IDENTITY
	for i in FACE:
		out[i] = torso * bent[i]
	var r0 := ring(posed, ring1)
	var r1 := ring(bent, ring1)
	for i in r0.size():
		out[FACE + i] = torso * r0[i].lerp(r1[i], ring_moves)
	var xf := at
	if xf.is_empty():
		xf = [Transform2D.IDENTITY, similarity(still_face, posed, steady)]
		for k in BONES.size() - 2:
			xf.append(Transform2D.IDENTITY)
	var first := FACE + oval.size()
	for i in range(first, _mesh.size()):
		var p := _mesh[i]
		var j := i - first
		var q := Vector2.ZERO
		var left := 1.0
		if j + 1 < _skin_at.size():
			for k in range(_skin_at[j], _skin_at[j + 1]):
				var w := _skin_w[k]
				q += ((xf[_skin_bone[k]] as Transform2D) * p) * w
				left -= w
		out[i] = q + p * left
	return out


## Every vertex's place in the still, 0..1.
func base_uvs() -> PackedVector2Array:
	return _uvs


## AN IMAGE MATCHED TO THE STILL'S LIGHT: `[gain, offset]` (each a Vector3, r g b) taking image [param m]'s
## cheeks - their mean and spread when it was filmed - to the still's. ONE GAIN FOR ALL THREE CHANNELS, so
## the lips keep their hue: a gain per channel turned a red lip teal (2026-10-21, the first look) - the
## mean is matched per channel, the spread only as a whole, and only so far.
func match_light(m: int) -> Array:
	var ml: PackedFloat32Array = lights[m] if m >= 0 and m < lights.size() else PackedFloat32Array()
	var light := still_light
	if light.size() < 6 or ml.size() < 6:
		return [Vector3.ONE, Vector3.ZERO]
	var g := clampf((light[3] + light[4] + light[5]) / maxf(ml[3] + ml[4] + ml[5], 0.01), 0.8, 1.25)
	return [Vector3(g, g, g), Vector3(light[0] - ml[0] * g, light[1] - ml[1] * g, light[2] - ml[2] * g)]
