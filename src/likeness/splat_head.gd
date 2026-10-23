extends Node2D
class_name SplatHead

## SplatHead - an actor's head as 3D Gaussian splats bound to their own face (next/likeness.md, "A head of
## splats"), drawn over their still: the avatar hosts/avatar/train.py learned, read from its `.json` and `.bin`.
##
## THE FACE IS POSED HERE, the splats on the graphics card: [method pose] moves the rig's neutral face by
## MediaPipe's 52 scores (the mouth's for a sound, the lids' for a blink), turns and places it as the head
## stands, and writes every binding frame - each triangle's centre, axes and unit, then the head's own - to a
## small float texture; the shader ([code]splat_head.gdshader[/code]) places each splat from it.
##
## A SPLAT CHANGES WITH THE EXPRESSION (GaussianBlendshapes; hosts/avatar/train.py): its place and colour shift
## by each of the expression's components, the 52 scores' principal components over the frames it was learned
## from ([method expr_of]); [method set_expr] hands the shader the expression a frame shows.
##
## DRAWN IN ORDER, NEVER SORTED: the camera is far and fixed and the head turns a little, so the order the
## export wrote them in - back to front as the neutral face stands straight on - stays right, and the canvas's
## own blending composites them as the trainer did.
##
## Its own pixels are the crop's at full resolution: the node stands where the crop's corner is on the still.

const SHADER := preload("res://src/likeness/splat_head.gdshader")
## MediaPipe's 52 expression scores, in its order: what [method pose] is handed, by these names.
const SCORES := ["_neutral", "browDownLeft", "browDownRight", "browInnerUp", "browOuterUpLeft", "browOuterUpRight",
	"cheekPuff", "cheekSquintLeft", "cheekSquintRight", "eyeBlinkLeft", "eyeBlinkRight", "eyeLookDownLeft",
	"eyeLookDownRight", "eyeLookInLeft", "eyeLookInRight", "eyeLookOutLeft", "eyeLookOutRight", "eyeLookUpLeft",
	"eyeLookUpRight", "eyeSquintLeft", "eyeSquintRight", "eyeWideLeft", "eyeWideRight", "jawForward", "jawLeft",
	"jawOpen", "jawRight", "mouthClose", "mouthDimpleLeft", "mouthDimpleRight", "mouthFrownLeft", "mouthFrownRight",
	"mouthFunnel", "mouthLeft", "mouthLowerDownLeft", "mouthLowerDownRight", "mouthPressLeft", "mouthPressRight",
	"mouthPucker", "mouthRight", "mouthRollLower", "mouthRollUpper", "mouthShrugLower", "mouthShrugUpper",
	"mouthSmileLeft", "mouthSmileRight", "mouthStretchLeft", "mouthStretchRight", "mouthUpperUpLeft",
	"mouthUpperUpRight", "noseSneerLeft", "noseSneerRight"]
## Texels a row of the data textures holds.
const TEX_W := 1024

var splats := 0
var verts := 0
var scores := 52
var head_unit := 16.0
## [x, y, side]: the square of the still the head was learned in, in full-resolution pixels.
var crop := PackedInt32Array()
## The side it was learned at (its splats' blur is in those pixels).
var size := 512
var tris := PackedInt32Array()
var canon := PackedFloat32Array()
var basis := PackedFloat32Array()
## The expression's components: how many, the scores' mean, the [52, K] basis and each component's spread.
var expressions := 0
var expr_mean := PackedFloat32Array()
var expr_basis := PackedFloat32Array()
var expr_scale := PackedFloat32Array()
## The most components the shader mixes.
const MOST_EXPRESSIONS := 16

var _mm: MultiMeshInstance2D
var _mat: ShaderMaterial
var _frames := PackedFloat32Array()
var _frames_img: Image
var _frames_tex: ImageTexture
var _posed := PackedFloat32Array()


## Read the avatar at [param base] (`<base>.json`, `<base>.bin`). Returns "" or why it could not.
func load_avatar(base: String) -> String:
	var head: Variant = JSON.parse_string(FileAccess.get_file_as_string(base + ".json"))
	if not (head is Dictionary):
		return "no avatar at %s" % base
	var bin := FileAccess.get_file_as_bytes(base + ".bin")
	if bin.is_empty():
		return "the avatar's %s.bin is missing" % base.get_file()
	var h := head as Dictionary
	var arr := {}
	for name in h["arrays"]:
		var at: Array = h["arrays"][name]
		var bytes := bin.slice(int(at[0]), int(at[0]) + int(at[1]) * 4)
		arr[name] = bytes.to_int32_array() if String(at[2]) == "i32" else bytes.to_float32_array()
	take(h, arr)
	return ""


## THE AVATAR FROM [param arr] (the arrays `.bin` holds, by name) and [param h] (`.json`'s counts, crop, size,
## head unit and the data texture's shape) - what [method load_avatar] reads, or a gate makes. The splats come
## as the shader's own data texture (`texels`, the trainer's export), or as their numbers one array each
## (`place`, `log_scale`, `turn`, `colour` - not its logit - `cover`, `bind`, and `place_d`, `colour_d`
## [N * K * 3] with `expressions` K), which are laid out here alike.
func take(h: Dictionary, arr: Dictionary) -> void:
	splats = int(h["splats"])
	verts = int(h["verts"])
	scores = int(h["scores"])
	head_unit = float(h["head_unit"])
	crop = PackedInt32Array(h["crop"])
	size = int(h["size"])
	expressions = int(h.get("expressions", 0))
	tris = arr["tris"]
	canon = arr["canon"]
	basis = arr["basis"]
	expr_mean = arr.get("expr_mean", PackedFloat32Array())
	expr_basis = arr.get("expr_basis", PackedFloat32Array())
	expr_scale = arr.get("expr_scale", PackedFloat32Array())
	var width := int(h.get("texel_width", TEX_W))
	var per := 4 + 2 * expressions
	var texels: PackedFloat32Array = arr["texels"] if arr.has("texels") else _texels(arr, per, width)
	_build(texels, width, per)
	position = Vector2(crop[0], crop[1])


## The data texture laid out from the splats' numbers (the trainer's export writes it whole).
func _texels(arr: Dictionary, per: int, width: int) -> PackedFloat32Array:
	var place: PackedFloat32Array = arr["place"]
	var log_scale: PackedFloat32Array = arr["log_scale"]
	var turn: PackedFloat32Array = arr["turn"]
	var colour: PackedFloat32Array = arr["colour"]
	var cover: PackedFloat32Array = arr["cover"]
	var bind: PackedInt32Array = arr["bind"]
	var place_d: PackedFloat32Array = arr.get("place_d", PackedFloat32Array())
	var colour_d: PackedFloat32Array = arr.get("colour_d", PackedFloat32Array())
	var rows := int(ceil(float(splats * per) / width))
	var data := PackedFloat32Array()
	data.resize(rows * width * 4)
	for i in splats:
		var o := i * per * 4
		for c in 3:
			data[o + c] = place[i * 3 + c]
			data[o + 4 + c] = log_scale[i * 3 + c]
			var col := clampf(colour[i * 3 + c], 1e-4, 1.0 - 1e-4)
			data[o + 12 + c] = log(col / (1.0 - col))
		data[o + 3] = float(bind[i])
		data[o + 7] = cover[i]
		for c in 4:
			data[o + 8 + c] = turn[i * 4 + c]
		for k in expressions:
			for c in 3:
				data[o + 16 + k * 8 + c] = place_d[(i * expressions + k) * 3 + c]
				data[o + 20 + k * 8 + c] = colour_d[(i * expressions + k) * 3 + c]
	return data


## THE EXPRESSION OF [param blend] (MediaPipe's 52 scores): its components as the splats were learned with -
## the scores less their mean, onto each component, over its spread.
func expr_of(blend: PackedFloat32Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(expressions)
	for k in expressions:
		var v := 0.0
		for j in mini(scores, blend.size()):
			v += (blend[j] - expr_mean[j]) * expr_basis[j * expressions + k]
		out[k] = v / maxf(expr_scale[k], 1e-6)
	return out


## The expression the shader mixes each splat's shifts by ([method expr_of]).
func set_expr(e: PackedFloat32Array) -> void:
	if _mat == null:
		return
	var padded := PackedFloat32Array()
	padded.resize(MOST_EXPRESSIONS)
	for k in mini(e.size(), MOST_EXPRESSIONS):
		padded[k] = e[k]
	_mat.set_shader_parameter("expr", padded)


func _build(texels: PackedFloat32Array, width: int, per: int) -> void:
	var rows := int(ceil(float(texels.size() / 4) / width))
	var splat_tex := ImageTexture.create_from_image(
		Image.create_from_data(width, rows, false, Image.FORMAT_RGBAF, texels.to_byte_array()))
	var n_frames := tris.size() / 3 + 1
	var frame_rows := int(ceil(float(n_frames * 4) / TEX_W))
	_frames.resize(frame_rows * TEX_W * 4)
	_frames_img = Image.create_from_data(TEX_W, frame_rows, false, Image.FORMAT_RGBAF, _frames.to_byte_array())
	_frames_tex = ImageTexture.create_from_image(_frames_img)
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("splat_data", splat_tex)
	_mat.set_shader_parameter("frame_data", _frames_tex)
	_mat.set_shader_parameter("splat_width", width)
	_mat.set_shader_parameter("frame_width", TEX_W)
	_mat.set_shader_parameter("per_splat", per)
	_mat.set_shader_parameter("expressions", mini(expressions, MOST_EXPRESSIONS))
	var k := float(size) / float(crop[2])
	_mat.set_shader_parameter("low_pass", 0.3 / (k * k))
	# one quad, its corners -1..1: the shader stretches it over each splat's three sigmas
	var quad := ArrayMesh.new()
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = PackedVector2Array([Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)])
	a[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	quad.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.mesh = quad
	mm.instance_count = splats
	# identity for every instance: the shader places each one itself
	var buf := PackedFloat32Array()
	buf.resize(splats * 8)
	for i in splats:
		buf[i * 8] = 1.0
		buf[i * 8 + 5] = 1.0
	mm.buffer = buf
	mm.custom_aabb = AABB(Vector3(-crop[2], -crop[2], -1), Vector3(crop[2] * 3, crop[2] * 3, 2))
	if _mm != null:
		_mm.queue_free()
	_mm = MultiMeshInstance2D.new()
	_mm.multimesh = mm
	_mm.material = _mat
	add_child(_mm)


## THE HEAD AT A MOMENT: the neutral face moved by [param blend] (MediaPipe's 52 scores), then [param scale],
## [param rot] (the neutral face's axes into the crop's) and [param shift] (the crop's pixels) - the rig's own
## pose, as frames.py's points stand. Writes every binding frame for the shader.
func pose(blend: PackedFloat32Array, scale: float, rot: Basis, shift: Vector3) -> void:
	pose_face(face_of(blend), scale, rot, shift)


## THE FACE OF [param blend], unposed: the neutral face moved by the scores (the rig is linear in them, so a
## player mixes faces made once - a sound's, a blink's - rather than 52 scores every frame).
func face_of(blend: PackedFloat32Array) -> PackedFloat32Array:
	var n := verts * 3
	var v := canon.duplicate()
	for kk in mini(scores, blend.size()):
		var w := blend[kk]
		if absf(w) < 1e-4:
			continue
		var o := kk * n
		for j in n:
			v[j] += w * basis[o + j]
	return v


## [method pose] for a face [param v] already moved ([method face_of]).
func pose_face(v: PackedFloat32Array, scale: float, rot: Basis, shift: Vector3) -> void:
	if splats == 0:
		return
	var n := verts * 3
	_posed.resize(n)
	for i in verts:
		var p := rot * Vector3(v[i * 3], v[i * 3 + 1], v[i * 3 + 2]) * scale + shift
		_posed[i * 3] = p.x
		_posed[i * 3 + 1] = p.y
		_posed[i * 3 + 2] = p.z
	var t_n := tris.size() / 3
	for t in t_n:
		var a := _vert(tris[t * 3])
		var b := _vert(tris[t * 3 + 1])
		var c := _vert(tris[t * 3 + 2])
		var e1 := (b - a).normalized()
		var nn := (b - a).cross(c - a).normalized()
		var e2 := nn.cross(e1)
		var unit := ((b - a).length() + (c - b).length() + (a - c).length()) / 3.0
		_put_frame(t, (a + b + c) / 3.0, unit, e1, e2, nn)
	_put_frame(t_n, shift, scale * head_unit, rot.x, rot.y, rot.z)
	_frames_img.set_data(TEX_W, _frames_img.get_height(), false, Image.FORMAT_RGBAF, _frames.to_byte_array())
	_frames_tex.update(_frames_img)


func _vert(i: int) -> Vector3:
	return Vector3(_posed[i * 3], _posed[i * 3 + 1], _posed[i * 3 + 2])


func _put_frame(f: int, origin: Vector3, unit: float, e1: Vector3, e2: Vector3, nn: Vector3) -> void:
	var o := f * 16
	_frames[o] = origin.x
	_frames[o + 1] = origin.y
	_frames[o + 2] = origin.z
	_frames[o + 3] = unit
	_frames[o + 4] = e1.x
	_frames[o + 5] = e1.y
	_frames[o + 6] = e1.z
	_frames[o + 8] = e2.x
	_frames[o + 9] = e2.y
	_frames[o + 10] = e2.z
	_frames[o + 12] = nn.x
	_frames[o + 13] = nn.y
	_frames[o + 14] = nn.z
