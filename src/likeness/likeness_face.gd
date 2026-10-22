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
## THE HEAD MOVES THROUGH ITS OWN 3D POINTS ([method pose]): the still's face turned about the neck - a
## pivot below and behind its middle - by the motion's yaw, pitch and roll, moved and brought nearer, and
## seen straight on. The near ring goes with it, the far ring and the frame's edge stay: the room never
## moves.
##
## THE LAYOUT: the set's first still's face. Every library mouth and eye is kept unwrapped into it (the
## box, [member box]), so a vertex's place in the layout is where it reads the library. A mouth or eye
## drawn is its own shape - the frame it came from, aligned onto the layout by the points that move with
## neither ([member steady]) - and the face moved toward it by each point's weight ([member weights] for
## the mouth, [member eye_weights] for the lids): mixed, both are morphs, never two images over each other.

const FACE := 468

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

## THE LIBRARY: every image's file (the mouths, then the eyes - one texture array), its shape in the
## layout, its cheeks' light when it was filmed (mean and spread); and which images each sound class and
## each eye state has.
var files: Array = []
var shapes: Array = []                   # PackedVector2Array per image
var lights: Array = []                   # PackedFloat32Array(6) per image
var mouths_of := {}                      # class -> [image index]
var eyes_of := {}                        # state -> [image index]

## THE STILL: its face in its frame, in 3D (pixels, the depth on the width's scale), and its cheeks' light.
var still_face := PackedVector2Array()
var still_3d := PackedVector3Array()
var still_light := PackedFloat32Array()
var _pivot := Vector3.ZERO
var _face_w := 1.0
var _uvs := PackedVector2Array()


## Read `rig.json` and `library.json`; "" when both are sound, else why not.
func load_set(rig_path: String, library_path: String) -> String:
	var r: Variant = ActorFolder.read_json(rig_path)
	if not (r is Dictionary):
		return "the rig is not made"
	var d: Dictionary = r
	if not d.has("eye_weights"):
		return "the rig is from the first build: Generate makes it again"
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
	triangles = PackedInt32Array()
	for t in d["triangles"]:
		triangles.append_array(PackedInt32Array(t))
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
	# THE FRAME'S EDGE IN THE LAYOUT too: the layout is a still's own face, so the frame is where it is
	var lay := mesh_points(layout)
	lay_uv = PackedVector2Array()
	for p in lay:
		lay_uv.append((p - box.position) / box.size)
	var l: Variant = ActorFolder.read_json(library_path)
	if not (l is Dictionary):
		return "the library is not made"
	files = []
	shapes = []
	lights = []
	mouths_of = {}
	eyes_of = {}
	for e in (l as Dictionary).get("mouths", []):
		(mouths_of.get_or_add(String((e as Dictionary)["class"]), []) as Array).append(files.size())
		_keep(e, library_path.get_base_dir().path_join("library"))
	for e in (l as Dictionary).get("eyes", []):
		(eyes_of.get_or_add(String((e as Dictionary)["state"]), []) as Array).append(files.size())
		_keep(e, library_path.get_base_dir().path_join("library"))
	return "" if not mouths_of.is_empty() else "the library has no mouths"


func _keep(e: Dictionary, dir: String) -> void:
	files.append(dir.path_join(String(e["file"])))
	shapes.append(_vecs(e["shape"]))
	lights.append(PackedFloat32Array(e["light"]))


## DRAW ON [param still] (one of `stills.json`'s): its face, in 2D and 3D, and the pivot it turns about.
func set_still(still: Dictionary) -> void:
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
	_uvs = mesh_points(still_face)
	for i in _uvs.size():
		_uvs[i] = _uvs[i] / size


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


## EVERY MESH VERTEX for [param face]: its points, its rings and the frame's edge.
func mesh_points(face: PackedVector2Array) -> PackedVector2Array:
	var out := face.duplicate()
	out.append_array(ring(face, ring1))
	out.append_array(ring(face, ring2))
	out.append_array(anchors)
	return out


## THE STILL'S FACE IN A HEAD MOVED BY [param m] - the motion's yaw, pitch and roll (degrees), across and
## down (face widths) and nearer (the log of its scale): its 3D points turned about the neck and seen
## straight on.
func pose(m: PackedFloat32Array) -> PackedVector2Array:
	if m.size() < 6 or still_3d.is_empty():
		return still_face
	var b := Basis.from_euler(Vector3(deg_to_rad(-m[1]), deg_to_rad(m[0]), deg_to_rad(m[2])))
	var k := exp(m[5])
	var shift := Vector3(m[3] * _face_w, m[4] * _face_w, 0.0)
	var out := PackedVector2Array()
	out.resize(still_3d.size())
	for i in still_3d.size():
		var q := _pivot + (b * (still_3d[i] - _pivot)) * k + shift
		out[i] = Vector2(q.x, q.y)
	return out


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


## THE MESH'S VERTICES for the still turned to [param posed] and bent to [param bent]: the face where it
## is bent to, the near ring with the head (and part of the way with the jaw), the far ring and the
## frame's edge where the still has them.
func vertices(posed: PackedVector2Array, bent: PackedVector2Array) -> PackedVector2Array:
	var out := bent.duplicate()
	var r0 := ring(posed, ring1)
	var r1 := ring(bent, ring1)
	for i in r0.size():
		out.append(r0[i].lerp(r1[i], ring_moves))
	out.append_array(ring(still_face, ring2))
	out.append_array(anchors)
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
