extends SceneTree

## Solid glass bends in only what is behind it, and a pane bends nothing. Solid glass and clear crystal
## ([code]shaders/prop_lens.gdshader[/code]) are seen through by reading the screen a little off where they stand, and the screen
## holds what stands in front of the glass too, so the bend must not pull a held card's white face into the glass beside it. A
## crystal ball as the table makes it ([method Props.material]: clear, solid, round), photographed straight on over a dark wall, a
## white card standing before its left half:
##
##   - Nothing in front is bent in: the glass just right of the card's edge, where the bend reads leftward onto the card, stays as
##     dark as the wall behind it (under [constant LEAK_MOST]).
##   - What is behind still is: the same card stood behind the ball instead shows through that glass, bent (over
##     [constant SEEN_LEAST]) - a test that only stopped bending would pass the first.
##
## Two-sided: the shader without its depth test leaks the card into the glass.
##
## A pane bends nothing: parallel flat faces turn no line of sight, and a pane told to bend reads the screen off to one side by its
## tilt, where the wire frame it sits in is. The spectacles' lens and frame as the set dresser writes them, through
## [method Props.build], turned to the camera over a bright wall:
##
##   - Only flat faces are panes: the spectacle lens, a drink's skin and a magnifying glass with a faint cone read the screen
##     straight; a ball, a domed reading glass and a thick prism still bend.
##   - Nothing of the frame in the glass: the lens's middle stays even, its darkest pixel near its median (over
##     [constant EVEN_LEAST]).
##
## Two-sided: the same lens told to bend shows the frame in it.
##
##   tests/run_quiet.sh table_lens_check
##
## A real renderer (xvfb), no window on screen.

const W := 960
const H := 540
## The ball (meters; at the origin), the camera straight in front of it, and the card: its right edge
## [constant CARD_EDGE] right of the ball's middle (where the glass bends hard, as near a held card's edge
## over the prism), nearer the camera than the ball, or farther than it.
const BALL_R := 0.1
const CAM_Z := 0.6
const CARD_EDGE := 0.04
const CARD_NEAR := 0.16
const CARD_FAR := -0.25
## The glass read: a band [constant BAND] pixels wide starting [constant GAP] right of the card's edge
## (past its antialiased edge and the frost's blur), on the rows through the ball's middle half.
const GAP := 4
const BAND := 24
const LEAK_MOST := 0.25
const SEEN_LEAST := 0.5
## The spectacles' own numbers, and the camera near enough to read them. The lens's middle ([constant MIDDLE] of its radius, clear of the
## frame's own edge) must have its darkest pixel at least [constant EVEN_LEAST] of its median.
const PANE_MATERIALS := {"glass": {"kind": "glass", "clarity": 0.95, "color": "#e8f2f0"}, "wire": {"kind": "metal", "color": "#c8a24a"}}
const PANE_THING := {"name": "the round spectacles", "parts": [
	{"at": [0.0, 2.55, 0.0], "material": "wire", "radius": 2.4, "shape": "ring", "thickness": 0.26, "turn": [90.0, 0.0, 0.0]},
	{"at": [0.0, 2.55, 0.0], "material": "glass", "shape": "lathe", "turn": [90.0, 0.0, 0.0],
		"profile": [[0.0, 0.0], [2.32, 0.0], [2.32, 0.06], [0.0, 0.06]]}]}
const PANE_R := 0.0232
const PANE_CAM := 0.16
const PANE_TURN := 20.0
const MIDDLE := 0.8
const EVEN_LEAST := 0.8
## The depth test itself, cut out of the shader for the control.
const TEST_FROM := "\tif (-there.z / there.w < -VERTEX.z) {"
const TEST_TO := "\t\tbent = SCREEN_UV;\n\t}\n"

var _fails := 0


func _init() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + what)
	if not cond:
		_fails += 1


func _run() -> void:
	print("  (renderer: %s)" % RenderingServer.get_video_adapter_name())
	var lens := Props.material({"kind": "glass", "clarity": 0.9, "color": "#c9e6dc"}, {}, 1.0, 1.0, 0, true, true)
	_ok(lens.shader.resource_path == "res://shaders/prop_lens.gdshader", "a clear solid ball is drawn by the lens shader")
	var before := lens.duplicate() as ShaderMaterial
	before.shader = _without_test(lens.shader.code)
	var front := await _shoot(lens, CARD_NEAR)
	var behind := await _shoot(lens, CARD_FAR)
	var was := await _shoot(before, CARD_NEAR)
	_ok(float(front["wall"]) < LEAK_MOST and float(front["band"]) < LEAK_MOST,
		"a card in front of the glass is not bent into it: %.3f beside its edge (the wall %.3f)" % [float(front["band"]), float(front["wall"])])
	_ok(float(behind["band"]) > SEEN_LEAST, "a card behind the glass is bent into it: %.3f" % float(behind["band"]))
	_ok(float(was["band"]) > SEEN_LEAST, "the control (the bend without its depth test) leaks the card: %.3f" % float(was["band"]))
	for row in [["a flat lens", {"shape": "lathe", "profile": [[0.0, 0.0], [2.32, 0.0], [2.32, 0.06], [0.0, 0.06]]}, true],
			["a drink's flat skin", {"shape": "lathe", "profile": [[0.0, 0.0], [3.94, 0.0], [3.94, 0.05], [0.0, 0.05]]}, true],
			["a magnifying glass, a faint cone", {"shape": "lathe", "profile": [[0.0, 0.0], [3.9, 0.0], [3.9, 0.35], [0.0, 0.5]]}, true],
			["a ball", {"shape": "ball", "size": [7.4, 7.4, 7.4]}, false],
			["a domed reading glass", {"shape": "lathe", "smooth": true, "profile": [[0.0, 0.0], [3.25, 0.0], [3.35, 0.16], [2.4, 0.42], [0.0, 0.52]]}, false],
			["a thick prism", {"shape": "extrude", "outline": "rect", "size": [21.0, 6.0], "height": 3.8}, false]]:
		var part: Dictionary = (row[1] as Dictionary).duplicate()
		part["material"] = "glass"
		var built := _built({"name": row[0], "parts": [part]})
		var read_straight: bool = _glass_of(built).get_shader_parameter("bend") == 0.0
		_ok(read_straight == bool(row[2]), "%s %s" % [row[0], "reads the screen straight" if row[2] else "still bends"])
		(built["node"] as Node).free()
	var even := await _shoot_pane(false)
	var told := await _shoot_pane(true)
	_ok(even >= EVEN_LEAST, "nothing of its frame is in a pane: the darkest of its middle %.3f of its median" % even)
	_ok(told < EVEN_LEAST, "the control (the same pane told to bend) shows its frame: %.3f" % told)
	print("table_lens_check: %s" % ("ALL OK" if _fails == 0 else "%d FAILED" % _fails))
	quit(0 if _fails == 0 else 1)


## The lens shader with its depth test cut out (the control).
func _without_test(code: String) -> Shader:
	var a := code.find(TEST_FROM)
	var b := code.find(TEST_TO, a)
	assert(a >= 0 and b > a, "the lens shader's depth test is where this gate cuts it")
	var s := Shader.new()
	s.code = code.substr(0, a) + code.substr(b + TEST_TO.length())
	return s


## The ball in [param mat] over a dark wall, a white card's right edge [constant CARD_EDGE] right of its
## middle, [param card_z] from it:
## the brightest the glass gets in the band right of the card's edge (`band`), and the wall's own level
## beside the ball (`wall`).
func _shoot(mat: ShaderMaterial, card_z: float) -> Dictionary:
	var vp := SubViewport.new()
	vp.size = Vector2i(W, H)
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	for key in TableMedium.STAGE:
		vp.set(key, TableMedium.STAGE[key])
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
	var cam := Camera3D.new()
	cam.fov = 40.0
	cam.near = 0.05
	cam.far = 10.0
	cam.environment = env
	cam.position = Vector3(0.0, 0.0, CAM_Z)
	world.add_child(cam)
	var wall := MeshInstance3D.new()
	var wm := QuadMesh.new()
	wm.size = Vector2(4.0, 4.0)
	wall.mesh = wm
	wall.material_override = _flat(Color(0.08, 0.08, 0.08))
	wall.position = Vector3(0.0, 0.0, -0.6)
	world.add_child(wall)
	var ball := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = BALL_R
	sm.height = BALL_R * 2.0
	sm.radial_segments = 96
	sm.rings = 48
	ball.mesh = sm
	ball.material_override = mat
	world.add_child(ball)
	# the card: white, its right edge over the ball's right half, standing well past the ball to the left
	var card := MeshInstance3D.new()
	var cm := QuadMesh.new()
	cm.size = Vector2(0.4, 0.4)
	card.mesh = cm
	card.material_override = _flat(Color.WHITE)
	card.position = Vector3(CARD_EDGE - 0.2, 0.0, card_z)
	world.add_child(card)
	for i in 8:
		await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	var edge := cam.unproject_position(Vector3(CARD_EDGE, 0.0, card_z))
	var top := cam.unproject_position(Vector3(0.0, BALL_R * 0.5, 0.0))
	var foot := cam.unproject_position(Vector3(0.0, -BALL_R * 0.5, 0.0))
	var rim := cam.unproject_position(Vector3(BALL_R, 0.0, 0.0))
	vp.queue_free()
	var band := 0.0
	for y in range(int(top.y), int(foot.y)):
		for x in range(int(edge.x) + GAP, int(edge.x) + GAP + BAND):
			band = maxf(band, img.get_pixel(x, y).get_luminance())
	var lit := 0.0
	for y in range(int(top.y), int(foot.y)):
		lit = maxf(lit, img.get_pixel(mini(int(rim.x) + 30, W - 1), y).get_luminance())
	return {"band": band, "wall": lit}


## A thing as the table builds one, from what the set dresser wrote.
func _built(thing: Dictionary) -> Dictionary:
	var spec := Props.sanitize({"materials": PANE_MATERIALS, "things": [thing]}, [])
	return Props.build((spec["things"] as Array)[0], spec["materials"], 1)


## The part of a built thing drawn by the lens shader.
func _glass_of(built: Dictionary) -> ShaderMaterial:
	for mi in built["meshes"]:
		var mat := (mi as MeshInstance3D).material_override as ShaderMaterial
		if mat.shader.resource_path == "res://shaders/prop_lens.gdshader":
			return mat
	assert(false, "a clear solid part is drawn by the lens shader")
	return null


## The spectacle lens in its frame, turned to the camera over a bright wall ([param bends]: told to bend as a
## ball does): the darkest pixel of the lens's middle, as a share of the median there.
func _shoot_pane(bends: bool) -> float:
	var vp := SubViewport.new()
	vp.size = Vector2i(W, H)
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	for key in TableMedium.STAGE:
		vp.set(key, TableMedium.STAGE[key])
	get_root().add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.BLACK
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var world := Node3D.new()
	vp.add_child(world)
	var cam := Camera3D.new()
	cam.fov = 40.0
	cam.near = 0.02
	cam.far = 10.0
	cam.environment = env
	cam.position = Vector3(0.0, 0.0, PANE_CAM)
	world.add_child(cam)
	var wall := MeshInstance3D.new()
	var wm := QuadMesh.new()
	wm.size = Vector2(4.0, 4.0)
	wall.mesh = wm
	wall.material_override = _flat(Color(0.8, 0.8, 0.8))
	wall.position = Vector3(0.0, 0.0, -0.5)
	world.add_child(wall)
	var built := _built(PANE_THING)
	var node := built["node"] as Node3D
	world.add_child(node)
	var glass := _glass_of(built)
	if bends:
		glass.set_shader_parameter("bend", 1.0)
	node.rotation_degrees.y = PANE_TURN
	var lens: MeshInstance3D
	for mi in built["meshes"]:
		if (mi as MeshInstance3D).material_override == glass:
			lens = mi
	node.global_position -= lens.global_transform * lens.mesh.get_aabb().get_center()
	for i in 8:
		await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	var mid := cam.unproject_position(Vector3.ZERO)
	var across := absf(cam.unproject_position(Vector3(PANE_R * MIDDLE * cos(deg_to_rad(PANE_TURN)), 0.0, 0.0)).x - mid.x)
	var up := absf(cam.unproject_position(Vector3(0.0, PANE_R * MIDDLE, 0.0)).y - mid.y)
	vp.queue_free()
	var seen := PackedFloat32Array()
	for y in range(int(mid.y - up), int(mid.y + up) + 1):
		for x in range(int(mid.x - across), int(mid.x + across) + 1):
			if pow((x - mid.x) / across, 2.0) + pow((y - mid.y) / up, 2.0) <= 1.0:
				seen.append(img.get_pixel(x, y).get_luminance())
	seen.sort()
	return seen[0] / maxf(seen[seen.size() / 2], 0.001)


func _flat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	return m
