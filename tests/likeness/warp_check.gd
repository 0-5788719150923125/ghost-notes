extends SceneTree

## warp_check - the Likeness's one pass (next/likeness.md, "Rendering"): a still read through a mesh,
## by `src/likeness/likeness_warp.gdshader` and the medium's own drawing of it ([LikenessMedium.Warp]).
##
##   tests/run_quiet.sh warp_check
##
## NOT `--headless`: every claim is a rendered frame read back.
##
## THE IDENTITY: a made frame (noise, so a pixel out of place shows) drawn through a mesh whose every
## vertex sits where it reads comes back within 1/255. The control moves the inner vertices 2 px, and
## the frame must come back different.
##
## THE LAYOUT COORDINATE RIDES IN THE VERTEX COLOR, and must arrive as a float: the question M4 was to
## answer first. A library image of noise, read through the layout coordinates with the mouth's mask full
## on, must come back as itself - at 8 bits a coordinate would be off by up to a texel of a 256-texel
## image, and the noise would not match - and so must it through the eyes' mask (the second build's
## blinks). Its control reads the coordinates rounded to 8 bits, and must not match.

const SIZE := Vector2i(256, 256)
const GRID := 9

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
	var base := _noise(11)
	var mouths := _noise(23)
	var pts := _grid()
	# THE IDENTITY: every vertex where it reads
	var same := await _render(base, mouths, pts, pts, pts, "")
	var d := _diff(same, base)
	_ok(d <= 1.0 / 255.0 + 1e-4, "the mesh drawn as itself came back %.4f off the frame" % d)
	# the control: the inner vertices moved 2 px
	var moved := pts.duplicate()
	for i in moved.size():
		var gx := i % GRID
		var gy := i / GRID
		if gx > 0 and gx < GRID - 1 and gy > 0 and gy < GRID - 1:
			moved[i] += Vector2(2.0, 0.0)
	var off := await _render(base, mouths, moved, pts, pts, "")
	_ok(_diff(off, base) > 4.0 / 255.0, "a mesh moved 2 px came back the frame unchanged (%.4f)" % _diff(off, base))
	# THE LAYOUT COORDINATE AS A FLOAT: the mouths read through it come back as themselves
	var read := await _render(base, mouths, pts, pts, pts, "mouth")
	var dm := _diff(read, mouths)
	_ok(dm <= 2.0 / 255.0 + 1e-4, "the mouths read through the vertex color came back %.4f off - the coordinate is not a float" % dm)
	var eyes := await _render(base, mouths, pts, pts, pts, "eyes")
	var de := _diff(eyes, mouths)
	_ok(de <= 2.0 / 255.0 + 1e-4, "the library read through the eyes' mask came back %.4f off" % de)
	# the control: the same coordinates rounded to 8 bits miss
	var coarse := pts.duplicate()
	for i in coarse.size():
		coarse[i] = (coarse[i] / Vector2(SIZE) * 255.0).round() / 255.0 * Vector2(SIZE) + Vector2(0.7, 0.4)
	var miss := await _render(base, mouths, pts, pts, coarse, "mouth")
	_ok(_diff(miss, mouths) > 8.0 / 255.0, "coordinates off by a part of a texel read the same mouths (%.4f)" % _diff(miss, mouths))
	print("warp_check: %s (%d checks, %d failure%s)" % ["ALL OK" if _fails == 0 else "FAILED", _checks, _fails, "" if _fails == 1 else "s"])
	quit(1 if _fails > 0 else 0)


## A grid of vertices over the frame, edge to edge.
func _grid() -> PackedVector2Array:
	var out := PackedVector2Array()
	for gy in GRID:
		for gx in GRID:
			out.append(Vector2(float(gx) / float(GRID - 1) * SIZE.x, float(gy) / float(GRID - 1) * SIZE.y))
	return out


func _triangles() -> PackedInt32Array:
	var out := PackedInt32Array()
	for gy in GRID - 1:
		for gx in GRID - 1:
			var a := gy * GRID + gx
			out.append_array(PackedInt32Array([a, a + 1, a + GRID, a + 1, a + GRID + 1, a + GRID]))
	return out


func _noise(seed_in: int) -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_in
	var img := Image.create(SIZE.x, SIZE.y, false, Image.FORMAT_RGB8)
	for y in SIZE.y:
		for x in SIZE.x:
			img.set_pixel(x, y, Color(rng.randf(), rng.randf(), rng.randf()))
	return img


## [param base] drawn through the mesh: each vertex at [param at], reading the frame at [param reads]
## and the library at [param lay] (pixels); [param which] ("mouth" or "eyes") draws the library's one
## image in, whole, with that mask full on and the other empty.
func _render(base: Image, mouths: Image, at: PackedVector2Array, reads: PackedVector2Array,
		lay: PackedVector2Array, which: String) -> Image:
	var vp := SubViewport.new()
	vp.size = SIZE
	vp.disable_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var w := LikenessMedium.Warp.new()
	var mat := ShaderMaterial.new()
	mat.shader = LikenessMedium.SHADER
	w.material = mat
	w.tex = ImageTexture.create_from_image(base)
	w.points = at
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	for i in at.size():
		uvs.append(reads[i] / Vector2(SIZE))
		var l := lay[i] / Vector2(SIZE)
		colors.append(Color(l.x, l.y, 0.0, 1.0))
	w.uvs = uvs
	w.colors = colors
	w.indices = _triangles()
	var arr := Texture2DArray.new()
	arr.create_from_images([mouths])
	var full := Image.create(8, 8, false, Image.FORMAT_L8)
	full.fill(Color.WHITE)
	var none := Image.create(8, 8, false, Image.FORMAT_L8)
	none.fill(Color.BLACK)
	mat.set_shader_parameter("library", arr)
	mat.set_shader_parameter("mouth_mask", ImageTexture.create_from_image(full if which == "mouth" else none))
	mat.set_shader_parameter("eye_mask", ImageTexture.create_from_image(full if which == "eyes" else none))
	mat.set_shader_parameter("library_on", 0.0 if which.is_empty() else 1.0)
	mat.set_shader_parameter("m_weights", Vector2(1.0, 0.0))
	mat.set_shader_parameter("m_layers", Vector2.ZERO)
	mat.set_shader_parameter("e_weights", Vector2(1.0, 0.0))
	mat.set_shader_parameter("e_layers", Vector2.ZERO)
	vp.add_child(w)
	root.add_child(vp)
	for i in 4:
		await process_frame
	var got := vp.get_texture().get_image()
	vp.queue_free()
	return got


## The mean absolute difference of two images, away from the outermost pixel (an edge's texel is
## clamped, not wrapped, and is no claim of the mesh's).
static func _diff(a: Image, b: Image) -> float:
	if a == null or b == null:
		return 1.0
	var sum := 0.0
	var n := 0
	for y in range(2, SIZE.y - 2):
		for x in range(2, SIZE.x - 2):
			var p := a.get_pixel(x, y)
			var q := b.get_pixel(x, y)
			sum += (absf(p.r - q.r) + absf(p.g - q.g) + absf(p.b - q.b)) / 3.0
			n += 1
	return sum / float(maxi(n, 1))
