extends RefCounted
class_name ModelStudio

## ModelStudio - A MODEL SEEN BEFORE ANY TABLE STANDS ([AssemblyModel], [ModelTools]): its real parts on its plate, from four sides and from above by a plain, even light, so a designer can
## judge the shape it has made, and what a viewer will see of it. Off screen: a [SubViewport] of its own, drawn for the picture and then gone. A process with no renderer takes no pictures.

const SHEET := Vector2i(1280, 720)
const FRAMES := 4
## How far off the four views stand, as a share of what just fills the picture's height.
const STAND_OFF := 0.8
const FOV := 32.0
const GROUND := Color(0.62, 0.6, 0.57)


## THE MODEL [param m] AS FAR AS [param upto] parts (-1: all of it), from four sides: `{image}` or `{error}`.
static func views(m: Dictionary, upto := -1) -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or DisplayServer.get_name() == "headless":
		return {"error": "no pictures can be taken in this run"}
	var vp := SubViewport.new()
	vp.size = SHEET / 2
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	tree.root.add_child(vp)
	var root := Node3D.new()
	vp.add_child(root)
	_stand(root, m, upto)
	var cam := Camera3D.new()
	cam.fov = FOV
	cam.near = 0.02
	cam.far = 20.0
	root.add_child(cam)
	var size: Array = m["size"]
	var top := float(m["top"]) * Assembly.PLATE
	var reach := Vector2(float(size[0]), float(size[1])).length() * Assembly.STUD * 0.5
	var aim := Vector3(0.0, top * 0.38, 0.0)
	var far := (maxf(reach, top * 0.7) + 0.01) / tan(deg_to_rad(FOV * 0.5)) * STAND_OFF
	var sheet := Image.create(SHEET.x, SHEET.y, false, Image.FORMAT_RGB8)
	for i in 4:
		var dir := (Basis(Vector3.UP, TAU * float(i) / 4.0 + deg_to_rad(25.0)) * Vector3(0.0, 0.55, 0.83)).normalized()
		cam.transform = Transform3D(Basis.looking_at(-dir, Vector3.UP), aim + dir * far)
		# ...AS EVERY PICTURE AN AGENT TAKES IS TAKEN: a window that is minimized draws nothing by itself
		var img: Image = await TablePreview._render(vp, FRAMES)
		if img == null or img.is_empty():
			vp.queue_free()
			return {"error": "no picture could be taken"}
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i((i % 2) * (SHEET.x / 2), (i / 2) * (SHEET.y / 2)))
	vp.queue_free()
	return {"image": sheet}


static func _stand(root: Node3D, m: Dictionary, upto: int) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = GROUND
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.95, 0.96, 1.0)
	env.ambient_light_energy = 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -35.0, 0.0)
	sun.light_energy = 0.95
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 3.0
	root.add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(6.0, 6.0)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = GROUND
	gm.roughness = 0.95
	ground.material_override = gm
	root.add_child(ground)
	var colors: Dictionary = m["colors"]
	var size: Array = m["size"]
	var base := MeshInstance3D.new()
	base.mesh = AssemblyMeshes.base_of(int(size[0]), int(size[1]))
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color.html(String(colors.get(String(m["base_color"]), "#888888")))
	bm.roughness = 0.34
	base.material_override = bm
	root.add_child(base)
	var by := {}
	var parts: Array = m["parts"]
	var n: int = parts.size() if upto < 0 else mini(upto, parts.size())
	for i in n:
		var q: Dictionary = parts[i]
		var key := "%s %dx%d" % [String(q["kind"]), int(q["w"]), int(q["d"])]
		if not by.has(key):
			by[key] = []
		(by[key] as Array).append(q)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/plastic.gdshader")
	for key in by:
		var list: Array = by[key]
		var first: Dictionary = list[0]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		mm.mesh = AssemblyMeshes.mesh_of(String(first["kind"]), int(first["w"]), int(first["d"]))
		mm.instance_count = list.size()
		for i in list.size():
			var q: Dictionary = list[i]
			mm.set_instance_transform(i, Assembly.xf_on(size, int(q["x"]), int(q["z"]), int(q["l"]), int(q["w"]), int(q["d"]), int(q["turn"])))
			mm.set_instance_color(i, Color.html(String(colors.get(String(q["color"]), "#888888"))).srgb_to_linear())
			mm.set_instance_custom_data(i, Color(0.3, 0.0, 0.0, 0.0))
		var node := MultiMeshInstance3D.new()
		node.multimesh = mm
		node.material_override = mat
		root.add_child(node)
