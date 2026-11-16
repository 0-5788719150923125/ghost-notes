extends RefCounted
class_name PropStudio

## PropStudio - a thing photographed alone, as it is built: every part at its real size on a ground ruled in centimeters (a brighter
## line every five), lit as [StudioLook] lights it, its flames lit. The set dresser's close looks ([TablePreview]) and a prop's picture
## on the Props card and its shelves ([method picture], [method cached]) are taken here; a prop built whole to be turned in the hand
## is [method model].
##
## Rendered in this process, off screen: a SubViewport drawn only while a picture is being taken, then stopped ([method render]). A
## process with no renderer (headless) takes none ([method can_see]). A prop's picture is kept on the library's `pictures` shelf by
## the hash of what it is ([method ThingLibrary.hash_of]) with its size beside it, so a prop is pictured once wherever it stands.

## How wide the studio's lens is (degrees, vertical), and frames drawn before a picture is read back: its shadows settle in a few.
const FOV := StudioLook.FOV
const FRAMES := 3
## How many of the app's frames may run with nothing drawn before a picture draws its own: a window that cannot be seen draws
## none ([method render]); one that can draws every frame.
const UNDRAWN := 4
## A prop's picture on the Props card and the shelves (pixels), and the shelf it is kept on.
const TILE := Vector2i(320, 240)
const SHELF := "pictures"

## A candle's flame, as the table draws one ([constant TableMedium.FLAME_SHADER]), turned to face whichever side the studio shoots
## from.
const FLAME_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
uniform vec3 color = vec3(1.0, 0.65, 0.3);
uniform float energy = 4.0;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	vec2 p = UV - vec2(0.5, 0.62);
	p.x *= 2.2;
	float body = 1.0 - smoothstep(0.0, 0.42, length(vec2(p.x, p.y * (p.y < 0.0 ? 0.55 : 1.0))));
	float core = 1.0 - smoothstep(0.0, 0.16, length(vec2(p.x * 1.4, p.y + 0.12)));
	ALBEDO = mix(color, vec3(1.0, 0.97, 0.88), core) * energy * body;
	ALPHA = body;
}
"""

var _vp: SubViewport = null
var _cam: Camera3D
var _label: Label
var _held: Node3D

## The studio a prop's picture is taken in ([method picture]): one for the app, built when first asked for.
static var _shared: PropStudio = null
static var _busy := false
static var _flame_mat: ShaderMaterial = null


## Whether this process can take a picture at all.
static func can_see() -> bool:
	return DisplayServer.get_name() != "headless"


static func tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


## The studio's viewport, built in the tree's root the first time it is asked for.
func ensure() -> void:
	if _vp != null and is_instance_valid(_vp):
		return
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.size = TILE
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	tree().root.add_child(_vp)
	var root := Node3D.new()
	_vp.add_child(root)
	_cam = Camera3D.new()
	_cam.fov = FOV
	_cam.near = 0.002
	_cam.far = 20.0
	_cam.environment = StudioLook.environment()
	root.add_child(_cam)
	root.add_child(StudioLook.ground())
	StudioLook.light(root)
	_held = Node3D.new()
	root.add_child(_held)
	_label = Label.new()
	_label.position = Vector2(10, 6)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("font_size", 18)
	_label.add_theme_color_override("font_color", Color(1.0, 0.98, 0.92))
	_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	_label.add_theme_constant_override("outline_size", 6)
	_vp.add_child(_label)


## Give back the viewport.
func release() -> void:
	if _vp != null and is_instance_valid(_vp):
		_vp.queue_free()
	_vp = null


## Thing [param t] built of [param materials] on [param seed] and standing in the studio alone, its flames lit: its bounds.
func hold(t: Dictionary, materials: Dictionary, seed: int) -> AABB:
	return hold_built(Props.build(t, materials, seed))


## A thing already built ([method Props.build]'s answer) standing in the studio alone, its flames lit: its bounds.
func hold_built(b: Dictionary) -> AABB:
	ensure()
	clear()
	_held.add_child(lit(b))
	return bounds_of(b)


## A thing built ([method Props.build]'s answer) with its flames lit: its node, a flame over each wick and their light, under one
## node of its own, out of any tree.
static func lit(b: Dictionary) -> Node3D:
	var out := Node3D.new()
	out.add_child(b["node"] as Node3D)
	var flames: Array = b["wicks"]
	for g in b.get("glows", []):
		if g is ShaderMaterial:
			(g as ShaderMaterial).set_shader_parameter("flame", 1.0)
	var mid := Vector3.ZERO
	for w in flames:
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.012, 0.03)
		q.mesh = qm
		q.material_override = _flame()
		q.position = (w as Vector3) + Vector3(0.0, 0.016, 0.0)
		out.add_child(q)
		mid += w as Vector3
	if not flames.is_empty():
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.7, 0.4)
		light.omni_range = 0.5
		light.light_energy = 0.25 * float(flames.size())
		light.position = mid / float(flames.size()) + Vector3(0.0, 0.02, 0.0)
		out.add_child(light)
	return out


## The bounds of a thing built ([method Props.build]'s answer), a small cube where it has none.
static func bounds_of(b: Dictionary) -> AABB:
	var box: AABB = b["size"]
	return box if box.size != Vector3.ZERO else AABB(Vector3(-0.02, 0.0, -0.02), Vector3(0.04, 0.04, 0.04))


## The flame's material, made once.
static func _flame() -> ShaderMaterial:
	if _flame_mat == null:
		var m := ShaderMaterial.new()
		m.shader = Shader.new()
		m.shader.code = FLAME_SHADER
		_flame_mat = m
	return _flame_mat


## Nothing left standing in the studio.
func clear() -> void:
	if _held == null or not is_instance_valid(_held):
		return
	_held.scale = Vector3.ONE
	for c in _held.get_children():
		c.queue_free()


## One picture of what the studio holds: framed to [param box], seen from [param side] (a direction from its middle toward the
## camera), at [param size], captioned.
func shot(box: AABB, side: Vector3, size: Vector2i, caption: String) -> Image:
	if _vp == null or not is_instance_valid(_vp):
		return null
	_vp.size = size
	var c := box.get_center()
	var r := maxf(box.size.length() * 0.5, 0.01)
	var half := deg_to_rad(FOV) * 0.5
	var across := atan(tan(half) * float(size.x) / float(maxi(size.y, 1)))
	var dist := r / sin(minf(half, across)) * 1.06
	var dir := side.normalized()
	var up := Vector3.UP if absf(dir.y) < 0.99 else Vector3(0.0, 0.0, -1.0)
	_cam.transform = Transform3D(Basis.looking_at(-dir, up), c + dir * dist)
	_cam.far = dist + r * 6.0 + 1.0
	_label.text = caption
	_label.visible = not caption.is_empty()
	# a caption wraps within its tile: a long name would hide the size after it
	_label.size = Vector2(size.x - 20, 0)
	return await render(_vp, FRAMES)


# --- a prop's picture ----------------------------------------------------------------------------

## The picture of the prop whose hash is [param h], once taken: `{image, size}` (size as [method size_text] says it),
## {} until then.
static func cached(h: String) -> Dictionary:
	var path := Library.shelf(SHELF).path_join(h + ".png")
	if h.is_empty() or not FileAccess.file_exists(path):
		return {}
	var img := Image.load_from_file(path)
	if img == null or img.is_empty():
		return {}
	var size := FileAccess.get_file_as_string(path.get_basename() + ".txt").strip_edges()
	return {"image": img, "size": size}


## Thing [param thing] built of [param materials], pictured from a little above its front and kept by [param h] ([method cached])
## where [param store] (a session that may write the library): `{image, size}`, {} where no picture can be taken. Built on a worker;
## pictures are taken one at a time.
static func picture(thing: Dictionary, materials: Dictionary, h: String, store := true) -> Dictionary:
	var have := cached(h)
	if not have.is_empty() or not can_see():
		return have
	while _busy:
		await tree().process_frame
	have = cached(h)
	if not have.is_empty():
		return have
	_busy = true
	var out := {}
	var got := await _built(thing, materials, h)
	if not got.is_empty():
		var b: Dictionary = got["built"]
		if b.get("node") is Node3D:
			if _shared == null:
				_shared = PropStudio.new()
			var k := float(got["scale"])
			var box: AABB = _shared.hold_built(b)
			_shared._held.scale = Vector3(k, k, k)
			box = AABB(box.position * k, box.size * k)
			var img: Image = await _shared.shot(box, Vector3(0.0, 0.55, 1.0), TILE, "")
			_shared.clear()
			if img != null and not store:
				out = {"image": img, "size": size_text(box)}
			elif img != null:
				var size := size_text(box)
				DirAccess.make_dir_recursive_absolute(Library.shelf(SHELF))
				var path := Library.shelf(SHELF).path_join(h + ".png")
				img.save_png(path)
				var f := FileAccess.open(path.get_basename() + ".txt", FileAccess.WRITE)
				if f != null:
					f.store_string(size)
					f.close()
				out = {"image": img, "size": size}
	_busy = false
	return out


## Thing [param thing] built of [param materials] (made safe first, [method Props.sanitize]) on a worker, seeded by [param h]:
## `{built: Props.build's answer, scale}`, {} where nothing is left to build.
static func _built(thing: Dictionary, materials: Dictionary, h: String) -> Dictionary:
	var safe := Props.sanitize({"things": [thing], "materials": materials}, [])
	if (safe["things"] as Array).is_empty():
		return {}
	var t: Dictionary = (safe["things"] as Array)[0]
	var built := [{}]
	var task := WorkerThreadPool.add_task(func() -> void:
		built[0] = Props.build(t, safe["materials"], hash(h)))
	while not WorkerThreadPool.is_task_completed(task):
		await tree().process_frame
	WorkerThreadPool.wait_for_task_completion(task)
	return {"built": built[0], "scale": float(t.get("scale", 1.0))}


## Thing [param thing] built of [param materials] whole, to be looked at and turned ([PropViewer]): `{node, box, size}` - its node
## with its flames lit, at its own scale, out of any tree; its bounds there; its size as [method size_text] says it. {} where nothing
## can be built. Built on a worker, seeded by [param h] as its picture is.
static func model(thing: Dictionary, materials: Dictionary, h: String) -> Dictionary:
	var got := await _built(thing, materials, h)
	if got.is_empty() or not ((got["built"] as Dictionary).get("node") is Node3D):
		return {}
	var b: Dictionary = got["built"]
	var k := float(got["scale"])
	var node := lit(b)
	node.scale = Vector3(k, k, k)
	var box := bounds_of(b)
	box = AABB(box.position * k, box.size * k)
	return {"node": node, "box": box, "size": size_text(box)}


## A thing's size as captions and reports give it: width x height x depth, centimeters.
static func size_text(box: AABB) -> String:
	return "%s x %s x %s cm" % [cm(box.size.x), cm(box.size.y), cm(box.size.z)]


## [param m] meters as centimeters are written: whole, or to a tenth below 10.
static func cm(m: float) -> String:
	var c := snappedf(m * 100.0, 0.1) if m < 0.1 else float(roundi(m * 100.0))
	return str(roundi(c)) if is_equal_approx(c, roundf(c)) else str(c)


# --- drawing off screen --------------------------------------------------------------------------

## [param vp] drawn [param frames] times and read back: its picture, null when it went. Drawn only while the picture is taken. A
## picture that waited for frames to be drawn waited until the window came back (measured in a virtual KWin, on X11 and on
## Wayland: 435 frames run in 3 s, none drawn). So once [constant UNDRAWN] frames pass with nothing drawn, the picture draws its own
## ([method draw_unseen]).
static func render(vp: SubViewport, frames: int) -> Image:
	if vp == null or not is_instance_valid(vp):
		return null
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var drawn := [0]
	var count := func() -> void: drawn[0] += 1
	RenderingServer.frame_post_draw.connect(count)
	var seen := 0
	var idle := 0
	while int(drawn[0]) < frames and is_instance_valid(vp):
		await tree().process_frame
		idle = idle + 1 if int(drawn[0]) == seen else 0
		seen = int(drawn[0])
		if idle >= UNDRAWN and is_instance_valid(vp):
			draw_unseen(frames - seen)
	RenderingServer.frame_post_draw.disconnect(count)
	if not is_instance_valid(vp):
		return null
	var img := vp.get_texture().get_image()
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if img == null or img.is_empty():
		return null
	img.convert(Image.FORMAT_RGB8)
	return img


## [param n] frames drawn now, for a window that draws none ([method render]): every viewport but the window's own, which is set
## aside for them - its picture would go to a screen that takes none, and on Wayland a hidden window's screen can keep the draw
## waiting. Set inactive instead, it takes the viewports under it out of the draw too (measured: the picture came back stale).
static func draw_unseen(n: int) -> void:
	var root := tree().root.get_viewport_rid()
	var was := RenderingServer.viewport_get_update_mode(root)
	RenderingServer.viewport_set_update_mode(root, RenderingServer.VIEWPORT_UPDATE_DISABLED)
	for i in n:
		RenderingServer.force_draw(false, 1.0 / 60.0)
	RenderingServer.viewport_set_update_mode(root, was)
