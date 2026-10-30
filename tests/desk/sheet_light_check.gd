extends SceneTree

## A SHEET'S BACK PASSES ONLY THE LIGHT ON ITS FACE ([constant LegalPad.SHEET_SHADER]'s light(); 2026-10-29, the user:
## "You can see written text on the back of pages ... the text disappears immediately after the page turn settles ...
## at the binding ... you would not expect to see as much text as we do - because that's the header section"). Godot's
## own BACKLIGHT adds `(1/PI - diffuse) * BACKLIGHT` on whichever side a light is, so the lamp lighting a turned
## sheet's back showed the writing on its face through it - on the binding's top, where that face lies face down. A
## sheet whose face is half ink and half paper, a light square over its middle, seen from behind:
##
##   - LIT FROM BEHIND (the camera's side), ITS BACK SHOWS NONE OF THE WRITING: its two halves alike (under
##     [constant SAME_MOST]) - the control, Godot's own term (the shader without its light()), shows it (over
##     [constant SHOWN_LEAST]).
##   - LIT ON ITS FACE, ITS BACK SHOWS THE WRITING THROUGH IT (over [constant THROUGH_LEAST]) - a shader that only
##     stopped the writing would pass the first.
##   - ITS FACE IS LIT AS GODOT LIGHTS IT: seen from the front, the same picture under both (each pixel within
##     [constant FACE_MOST] of 255) - the page under the candles was tuned in Godot's own model.
##
##   tests/run_quiet.sh sheet_light_check
##
## A real renderer (xvfb), no window on screen.

const W := 320
const H := 320
## The sheet (meters; at the origin, its face toward +z), the camera this far off it on either side, and the light:
## over the sheet's middle, this high and this far off it.
const CAM := 1.4
const LIGHT_UP := 0.6
const LIGHT_OFF := 0.35
const SAME_MOST := 0.01
const SHOWN_LEAST := 0.03
const THROUGH_LEAST := 0.25
const FACE_MOST := 2.0
## Where the shader's light() begins: cut from there to its end, it is Godot's own lighting (the control).
const LIGHT_FROM := "float schlick(float u) {"

var _fails := 0


func _init() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + what)
	if not cond:
		_fails += 1


func _run() -> void:
	print("  (renderer: %s)" % RenderingServer.get_video_adapter_name())
	var face := _face()
	var now := LegalPad._sheet_material(face, true)
	var was := now.duplicate() as ShaderMaterial
	was.shader = _godots(now.shader.code)
	var back_lit := _split(await _shoot(now, -1.0, -1.0))
	var back_lit_was := _split(await _shoot(was, -1.0, -1.0))
	var face_lit := _split(await _shoot(now, -1.0, 1.0))
	_ok(back_lit < SAME_MOST, "lit from behind, a sheet's back shows none of the writing on its face: %.3f between its halves" % back_lit)
	_ok(back_lit_was > SHOWN_LEAST, "the control (Godot's own backlight term) shows it there: %.3f" % back_lit_was)
	_ok(face_lit > THROUGH_LEAST, "lit on its face, its back shows the writing through it: %.3f" % face_lit)
	var a := await _shoot(now, 1.0, 1.0)
	var b := await _shoot(was, 1.0, 1.0)
	var most := 0.0
	for y in range(0, H, 2):
		for x in range(0, W, 2):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			most = maxf(most, maxf(absf(ca.r - cb.r), maxf(absf(ca.g - cb.g), absf(ca.b - cb.b))) * 255.0)
	var lit := a.get_pixel(W / 2, H / 2)
	_ok(most <= FACE_MOST and lit.get_luminance() > 0.1,
		"its face is lit as Godot lights it: at most %.1f of 255 apart (its middle %.2f)" % [most, lit.get_luminance()])
	print("sheet_light_check: %s" % ("ALL OK" if _fails == 0 else "%d FAILED" % _fails))
	quit(0 if _fails == 0 else 1)


## The sheet's face: its left half ink, its right half paper.
func _face() -> Texture2D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for y in 64:
		for x in 64:
			img.set_pixel(x, y, Color(0.06, 0.06, 0.07) if x < 32 else Color(0.97, 0.96, 0.92))
	return ImageTexture.create_from_image(img)


## The sheet's shader with its light() cut out: Godot's own lighting, its backlight term and all.
func _godots(code: String) -> Shader:
	var a := code.find(LIGHT_FROM)
	assert(a >= 0, "the sheet's shader has its light() where this gate cuts it")
	var s := Shader.new()
	s.code = code.substr(0, a)
	return s


## How far apart the two halves of [param img]'s middle are (a share of the brighter): seen from behind, the face's
## ink half is on the right.
func _split(img: Image) -> float:
	var l := 0.0
	var r := 0.0
	var n := 0
	for y in range(H / 3, H * 2 / 3, 2):
		for x in range(W / 6, W * 5 / 12, 2):
			l += img.get_pixel(x, y).get_luminance()
			r += img.get_pixel(W - 1 - x, y).get_luminance()
			n += 1
	return absf(l - r) / maxf(maxf(l, r), 1e-6)


## The sheet in [param mat] seen from its face's side ([param cam] 1) or its back's (-1), the light on the face's
## side ([param light] 1) or the back's (-1): the picture.
func _shoot(mat: ShaderMaterial, cam: float, light: float) -> Image:
	var vp := SubViewport.new()
	vp.size = Vector2i(W, H)
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(vp)
	var world := Node3D.new()
	vp.add_child(world)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.BLACK
	env.ambient_light_energy = 0.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var c := Camera3D.new()
	c.fov = 40.0
	c.environment = env
	world.add_child(c)
	c.look_at_from_position(Vector3(0.0, 0.0, CAM * cam), Vector3.ZERO, Vector3.UP)
	var sheet := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 1.0)
	sheet.mesh = q
	sheet.material_override = mat
	world.add_child(sheet)
	var lamp := OmniLight3D.new()
	lamp.omni_range = 4.0
	lamp.light_energy = 1.5
	lamp.position = Vector3(0.0, LIGHT_UP, LIGHT_OFF * light)
	world.add_child(lamp)
	for i in 6:
		await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	return img
