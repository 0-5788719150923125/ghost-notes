extends RefCounted
class_name TablePreview

## TablePreview - a table described but not yet set, SEEN: each thing alone in a studio, and the whole
## table standing on the episode's own cloth, photographed from the camera's own place. It is what
## the set dresser looks through ([SetDresserTools]): it makes a thing, looks at it, and fixes what
## it sees.
##
## THE STUDIO shows a thing as it is built - every part, at its real size - on a ground ruled in
## centimeters (a brighter line every five), lit from above and one side so its form reads, its
## flames lit. One thing from four sides (front, its right, above, and as the episode's camera looks
## down at the table), or several side by side, one tile each, each tile captioned.
##
## THE TABLE IS THE SHOW'S OWN: a [TableMedium] built on the episode's seed and pictures - its
## camera, its lamp, where the deck sits, the spread the cards are laid in (face down: the set dresser
## knows no card) - with the description being tried standing in for the episode's table. Where a
## thing stands, what is made smaller or left off for want of room, which light leads: the answers
## are the ones the show itself will give, because it is the show's own code giving them. So is THE
## OPENING ([method opening]): the show's name over the same table, thrown out of focus. The medium
## is loaded by its class name when a table is stood, and only where ghost's autoloads run (it, like
## every medium, reads the Director): naming it here would stop the gates that build prompts from
## compiling, and a command-line process cannot stand a table anyway - it says so ([method can_set]).
##
## RENDERED IN THIS PROCESS, off screen: a SubViewport per stage, drawn only while a picture is being
## taken, then stopped. A process with no renderer (headless) takes no pictures ([method can_see]),
## and the tools work from their reports alone.
##
## THE TABLE IS BUILT OFF THE MAIN THREAD ([method _stand]): built where the app draws, each picture of it
## froze the whole app for five or six seconds (measured 2026-10-08: placing the things 2.4 s, the top
## 1.3 s, the things 1.2 s). A fresh stage and medium are built on a worker thread, OUTSIDE the scene tree
## - where Godot lets a thread build nodes - and swapped in once built; nothing the main thread touches is
## shared with the build while it runs (rebuilding the stage in the tree would free its old nodes on the
## main thread under the worker). Its report and its picture are the ones a main-thread build gives,
## pixel for pixel.
##
## SO IS WHAT IS IN THINGS ([method _bake]): the work's physics is baked on a worker too, the app drawing on
## while it waits - and a table stood again with other acts takes up what the last one baked, as far as their
## plans agree ([method TablePhysics.carry]). Each of a puppeteer's `act`s had stood a table and baked the work
## from its start on the app's own thread (2026-10-28: a draft 105 s long took one to six minutes a call, and
## Ghost Notes would not close for two).

## The size of every picture handed back, and how wide the studio's lens is (degrees, vertical).
const SHEET := Vector2i(1280, 720)
const STUDIO_FOV := 28.0
## Frames drawn before a picture is read back: the studio's shadows, and the table's reflections,
## settle in a few.
const STUDIO_FRAMES := 3
const TABLE_FRAMES := 6
## How many of the app's frames may run with nothing drawn before a picture draws its own: a window that
## cannot be seen draws none ([method _render]); one that can draws every frame.
const UNDRAWN := 4
## The moment of a reading the air is shown at: some way in, its fog rolled and its motes about.
const AIR_AT := 40.0
## The moment the OPENING is shown at: the show's name up, the deck not yet shuffled.
const OPENING_AT := 2.0
## The episode's table medium, by class name: looked up when it is needed, never compiled in - it
## needs ghost's autoloads, and so would anything naming it (see the class note).
const MEDIUM := "TableMedium"
## The pictures of the episode the table is built on - copied beside the description being tried,
## never its card faces: the set dresser knows no card.
const PICTURES := ["surface.png", "height.png", "height.json", "backdrop.png", "backdrop.json", "back.png"]
## The studio's four sides of one thing: a direction from its middle toward the camera, and a caption.
const SIDES := [["front", Vector3(0.0, 0.14, 1.0)], ["its right side", Vector3(1.0, 0.14, 0.0)],
	["from above (its front at the bottom)", Vector3(0.0, 1.0, 0.0)], ["as the camera sees it", Vector3.ZERO]]

const GROUND_SHADER := """
shader_type spatial;
render_mode diffuse_burley, specular_disabled;
uniform vec3 ground : source_color = vec3(0.13, 0.135, 0.15);
uniform vec3 line : source_color = vec3(0.3, 0.31, 0.34);
uniform vec3 line5 : source_color = vec3(0.5, 0.51, 0.55);
varying vec3 world;
void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
float grid(vec2 p) {
	vec2 w = max(fwidth(p), vec2(1e-5));
	vec2 g = abs(fract(p - 0.5) - 0.5) / w;
	// a line finer than a pixel fades out instead of filling the ground
	return (1.0 - min(min(g.x, g.y), 1.0)) * clamp(1.5 - max(w.x, w.y) * 3.0, 0.0, 1.0);
}
void fragment() {
	vec2 cm = world.xz * 100.0;
	vec3 c = mix(ground, line, grid(cm) * 0.8);
	ALBEDO = mix(c, line5, grid(cm / 5.0));
	ROUGHNESS = 0.92;
}
"""

## A candle's flame, as the table draws one ([constant TableMedium.FLAME_SHADER]), turned to face
## whichever side the studio shoots from.
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


## What the table medium reads its episode from - the captions it is bound to, in a reading.
class Doc:
	extends RefCounted
	var document := {}


var episode: TableEpisode
var plan: Dictionary
## The show's name and byline, set over the table at the opening ([method opening]).
var show_name := ""
var byline := ""
var _dir := ""                   # the description being tried, beside copies of the episode's pictures
var _pitch := 38.0                # the episode's camera, looking down (degrees)

var _studio: SubViewport = null
var _studio_cam: Camera3D
var _studio_label: Label
var _held: Node3D
var _flame_mat: ShaderMaterial

var _table: SubViewport = null
var _medium = null               # a TableMedium, loaded by class name
var _doc: Doc
var _releases := 0               # how many times it was given back ([method release]): a table built across one is dropped
var _halted := false             # a bake under way given up ([method halt])


## [param dir]: the folder the preview keeps its copies in (inside the job's own). [param name] and
## [param line]: the show's name and byline.
func _init(ep: TableEpisode, episode_plan: Dictionary, dir: String, name := "", line := "") -> void:
	episode = ep
	plan = episode_plan
	_dir = dir
	show_name = name
	byline = line
	_pitch = float(CardTable.layout_of(ep.seed)["pitch"])


## Whether this process can take a picture at all.
static func can_see() -> bool:
	return DisplayServer.get_name() != "headless"


## Whether it can stand the episode's table: a picture, and ghost's autoloads for the medium.
static func can_set() -> bool:
	return can_see() and _tree().root.has_node("Director")


## Give back everything this preview built - and, when a table is being built, the stage it is built on
## once it is done ([method _stand]).
func release() -> void:
	_releases += 1
	if _studio != null and is_instance_valid(_studio):
		_studio.queue_free()
	if _table != null and is_instance_valid(_table):
		_table.queue_free()
	_studio = null
	_table = null
	_medium = null


## A BAKE UNDER WAY GIVEN UP ([method _bake]): the tools closed while it ran. The call it was for answers with an
## error, and nothing is baked after.
func halt() -> void:
	_halted = true
	if _medium != null and is_instance_valid(_medium) and _medium._work != null and _medium._work.physics != null:
		_medium._work.physics.halt()


# --- the studio -------------------------------------------------------------------------------------

## THE THINGS in [param spec] (a sanitized table: `things`, `materials`) named in [param names] - or
## all of them - side by side, a tile each, from the camera's angle, each captioned with its number
## ([param numbers]: name -> number, the caller's; else its place here), name and size. null when no
## picture can be taken.
func things(spec: Dictionary, names: Array = [], numbers: Dictionary = {}) -> Image:
	if not can_see():
		return null
	var list: Array = []
	for t in spec.get("things", []):
		if names.is_empty() or names.has(String((t as Dictionary).get("name", ""))):
			list.append(t)
	if list.is_empty():
		return null
	_ensure_studio()
	var cols := clampi(ceili(sqrt(float(list.size()) * 1.6)), 1, list.size())
	var rows := ceili(float(list.size()) / float(cols))
	var tile := Vector2i(SHEET.x / cols, SHEET.y / rows)
	var sheet := Image.create(SHEET.x, SHEET.y, false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.06, 0.06, 0.07))
	for i in list.size():
		var t: Dictionary = list[i]
		var box := _hold(t, spec.get("materials", {}), i)
		var cap := "%d. %s\n%s" % [int(numbers.get(String(t.get("name", "")), i + 1)), String(t.get("name", "")), TablePreview.size_text(box)]
		var img := await _shot(box, _camera_side(), tile - Vector2i(2, 2), cap)
		if img != null:
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i((i % cols) * tile.x + 1, (i / cols) * tile.y + 1))
	_clear_held()
	return sheet


## ONE THING from four sides ([constant SIDES]), in a sheet of four. null when no picture can be taken.
func thing(spec: Dictionary, name: String) -> Image:
	if not can_see():
		return null
	var t := {}
	for x in spec.get("things", []):
		if String((x as Dictionary).get("name", "")) == name:
			t = x
			break
	if t.is_empty():
		return null
	_ensure_studio()
	var box := _hold(t, spec.get("materials", {}), 0)
	var tile := Vector2i(SHEET.x / 2, SHEET.y / 2)
	var sheet := Image.create(SHEET.x, SHEET.y, false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.06, 0.06, 0.07))
	for i in SIDES.size():
		var side: Vector3 = SIDES[i][1]
		if side == Vector3.ZERO:
			side = _camera_side()
		var cap := "%s\n%s - %s" % [String(t.get("name", "")), TablePreview.size_text(box), String(SIDES[i][0])] if i == 0 else String(SIDES[i][0])
		var img := await _shot(box, side, tile - Vector2i(2, 2), cap)
		if img != null:
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i((i % 2) * tile.x + 1, (i / 2) * tile.y + 1))
	_clear_held()
	return sheet


## A thing's size as the captions and reports give it: width x height x depth, centimeters.
static func size_text(box: AABB) -> String:
	return "%s x %s x %s cm" % [_cm(box.size.x), _cm(box.size.y), _cm(box.size.z)]


static func _cm(m: float) -> String:
	var cm := snappedf(m * 100.0, 0.1) if m < 0.1 else float(roundi(m * 100.0))
	return str(roundi(cm)) if is_equal_approx(cm, roundf(cm)) else str(cm)


## From the episode's camera: looking down across the table at its pitch.
func _camera_side() -> Vector3:
	var p := deg_to_rad(_pitch)
	return Vector3(0.0, sin(p), cos(p))


func _ensure_studio() -> void:
	if _studio != null and is_instance_valid(_studio):
		return
	_studio = SubViewport.new()
	_studio.own_world_3d = true
	_studio.msaa_3d = Viewport.MSAA_4X
	_studio.size = SHEET
	_studio.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_tree().root.add_child(_studio)
	var root := Node3D.new()
	_studio.add_child(root)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.035, 0.035, 0.04)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.55, 0.58)
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.95
	# SOMETHING FOR METAL TO REFLECT: a dim room-toned sky, seen in reflections only - against the
	# flat background a polished thing reflected black and read as paint
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.42, 0.42, 0.45)
	sm.sky_horizon_color = Color(0.62, 0.58, 0.52)
	sm.ground_bottom_color = Color(0.1, 0.1, 0.11)
	sm.ground_horizon_color = Color(0.3, 0.28, 0.26)
	sky.sky_material = sm
	env.sky = sky
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.glow_enabled = true
	env.glow_hdr_threshold = 1.25
	_studio_cam = Camera3D.new()
	_studio_cam.fov = STUDIO_FOV
	_studio_cam.near = 0.002
	_studio_cam.far = 20.0
	_studio_cam.environment = env
	root.add_child(_studio_cam)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(4.0, 4.0)
	ground.mesh = pm
	var gm := ShaderMaterial.new()
	gm.shader = Shader.new()
	gm.shader.code = GROUND_SHADER
	ground.material_override = gm
	root.add_child(ground)
	# a key from above, to the left and in front, its shadows short and sharp; a cool fill opposite;
	# a rim from behind, so a dark thing keeps its outline against the dark
	for l in [[Vector3(-52.0, -35.0, 0.0), 1.5, Color(1.0, 0.95, 0.86), true],
			[Vector3(-28.0, 140.0, 0.0), 0.45, Color(0.8, 0.86, 1.0), false],
			[Vector3(-15.0, 175.0, 0.0), 0.35, Color(1.0, 1.0, 1.0), false]]:
		var d := DirectionalLight3D.new()
		d.rotation_degrees = l[0]
		d.light_energy = float(l[1])
		d.light_color = l[2]
		d.shadow_enabled = bool(l[3])
		d.directional_shadow_max_distance = 3.0
		d.shadow_bias = 0.02
		d.shadow_normal_bias = 0.6
		root.add_child(d)
	_held = Node3D.new()
	root.add_child(_held)
	_studio_label = Label.new()
	_studio_label.position = Vector2(10, 6)
	_studio_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_studio_label.add_theme_font_size_override("font_size", 18)
	_studio_label.add_theme_color_override("font_color", Color(1.0, 0.98, 0.92))
	_studio_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	_studio_label.add_theme_constant_override("outline_size", 6)
	_studio.add_child(_studio_label)
	_flame_mat = ShaderMaterial.new()
	_flame_mat.shader = Shader.new()
	_flame_mat.shader.code = FLAME_SHADER


## Thing [param t] built and standing in the studio alone, its flames lit: its bounds.
func _hold(t: Dictionary, materials: Dictionary, salt: int) -> AABB:
	_clear_held()
	var b := Props.build(t, materials, hash([episode.seed, salt, "preview"]))
	var node: Node3D = b["node"]
	_held.add_child(node)
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
		q.material_override = _flame_mat
		q.position = (w as Vector3) + Vector3(0.0, 0.016, 0.0)
		_held.add_child(q)
		mid += w as Vector3
	if not flames.is_empty():
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.7, 0.4)
		light.omni_range = 0.5
		light.light_energy = 0.25 * float(flames.size())
		light.position = mid / float(flames.size()) + Vector3(0.0, 0.02, 0.0)
		_held.add_child(light)
	var box: AABB = b["size"]
	return box if box.size != Vector3.ZERO else AABB(Vector3(-0.02, 0.0, -0.02), Vector3(0.04, 0.04, 0.04))


func _clear_held() -> void:
	if _held == null or not is_instance_valid(_held):
		return
	for c in _held.get_children():
		c.queue_free()


## One picture of what the studio holds: framed to [param box], seen from [param side] (a direction
## from its middle toward the camera), at [param size], captioned.
func _shot(box: AABB, side: Vector3, size: Vector2i, caption: String) -> Image:
	if _studio == null or not is_instance_valid(_studio):
		return null
	_studio.size = size
	var c := box.get_center()
	var r := maxf(box.size.length() * 0.5, 0.01)
	var half := deg_to_rad(STUDIO_FOV) * 0.5
	var across := atan(tan(half) * float(size.x) / float(maxi(size.y, 1)))
	var dist := r / sin(minf(half, across)) * 1.06
	var dir := side.normalized()
	var up := Vector3.UP if absf(dir.y) < 0.99 else Vector3(0.0, 0.0, -1.0)
	_studio_cam.transform = Transform3D(Basis.looking_at(-dir, up), c + dir * dist)
	_studio_cam.far = dist + r * 6.0 + 1.0
	_studio_label.text = caption
	# a caption wraps within its tile: a long name would hide the size after it
	_studio_label.size = Vector2(size.x - 20, 0)
	return await _render(_studio, STUDIO_FRAMES)


# --- the table --------------------------------------------------------------------------------------

## THE WHOLE TABLE: [param raw] (the description as written) standing on the episode's table, the
## cards laid face down in their spread and the deck beside it, its air (fog, motes) as it is some way
## into a reading, from the camera's place.
## `{image, stood: [{name, place, at, k, tall}], left_off: [names], key, held_down: [names], cards,
## deck}` - `at` in centimeters from the cloth's middle (x to the reader's right, z toward them), `k`
## how far it was made smaller (1 = not at all), `tall` its share of the picture's height. `error`
## when the table cannot be stood here. With [param numbers] (name -> number), each thing carries its
## number in the picture, as the blueprint numbers it ([Tags]).
func table(raw: Dictionary, numbers: Dictionary = {}) -> Dictionary:
	var err: String = await _stand(raw)
	if not err.is_empty():
		return {"error": err}
	# THE TABLE AS IT MOSTLY IS: its light with the sun out and no bird crossing ([method Lights.Rig.quiet_near])
	_pose_spread()
	_medium._tick_air(AIR_AT)
	_medium._tick_ride(AIR_AT)
	var out := _placed(CardTable.sanitize_table(raw, CardTable.sanitize_look(plan.get("look", {}) if plan.get("look") is Dictionary else {})))
	var tags: Tags = null
	if not numbers.is_empty():
		tags = Tags.new()
		var cam: Transform3D = _medium._plan.cam_base
		var fov: float = (_medium._cam as Camera3D).fov
		for th in _medium._things_part.on_table:
			var box: AABB = (th as Dictionary)["box"]
			var top: Variant = CardTable.project(cam, fov, Vector3(box.get_center().x, box.end.y, box.get_center().z))
			var n: Variant = numbers.get(String((th as Dictionary)["name"]))
			if top != null and n != null:
				tags.marks.append({"at": (top as Vector2) * Vector2(SHEET) - Vector2(0.0, 14.0), "text": str(n)})
		_table.add_child(tags)
	out["image"] = await _render(_table, TABLE_FRAMES)
	if tags != null and is_instance_valid(tags):
		tags.queue_free()
	return out


## THE NUMBERS OVER A TABLE'S THINGS ([method table]): each a small tag just over the thing's top.
class Tags:
	extends Node2D
	var marks: Array = []

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		for m in marks:
			var at: Vector2 = (m as Dictionary)["at"]
			var text := String((m as Dictionary)["text"])
			var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
			var r := Rect2(at - Vector2(w * 0.5 + 5.0, 10.0), Vector2(w + 10.0, 19.0))
			draw_rect(r, Color(0.98, 0.98, 0.96, 0.85))
			draw_rect(r, Color(0.08, 0.08, 0.08), false, 1.5)
			draw_string(font, Vector2(at.x - w * 0.5, at.y + 5.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.08, 0.08, 0.08))


## ONE EFFECT IN MOTION: the effect named [param name] in [param raw]'s `effects`, on the episode's
## table, photographed four times - a burst a moment after the thing it marks happens (a card leaping
## from the deck, one held up and twirled, one laid down...: [constant CardTable.MOMENTS], staged
## here as the table stages them), fog or motes a few seconds apart, so their roll and their wander
## show. A sheet of four, `{image, frames: [seconds after]}`; `error` when it cannot be shown.
func watch(raw: Dictionary, name: String) -> Dictionary:
	var err: String = await _stand(raw)
	if not err.is_empty():
		return {"error": err}
	var air = _medium._air
	var fx := {}
	for e in (CardTable.sanitize_table(raw, CardTable.sanitize_look(plan.get("look", {}) if plan.get("look") is Dictionary else {}))["effects"] as Array):
		if String((e as Dictionary).get("name", "")) == name:
			fx = e
	if air == null or fx.is_empty():
		return {"error": "no effect called \"%s\" can be built" % name}
	var burst := String(fx["kind"]) == "burst"
	var on := String(fx.get("on", ""))
	var steps: Array = [0.08, 0.3, 0.6, 1.0] if burst else [0.0, 3.0, 6.0, 9.0]
	if String(fx["kind"]) == "drift":
		# WHAT DRIFTS, through the strongest gust of the next two minutes: falling as it comes, lifted, carried
		var g := _strongest_gust(_medium._wind, AIR_AT, AIR_AT + 120.0)
		steps = [0.0, 0.8, 1.6, 2.4] if g.x < 0.0 else [g.x - 1.0 - AIR_AT, g.z - AIR_AT, g.z + 1.0 - AIR_AT, g.x + g.y - AIR_AT]
	var moment := _staged(on) if burst else {}
	if burst:
		air.plan({on: moment["moments"]})
	var sheet := Image.create(SHEET.x, SHEET.y, false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.06, 0.06, 0.07))
	for i in steps.size():
		var t := AIR_AT + float(steps[i])
		_pose_moment(on, moment, t)
		air.tick(t)
		var img: Image = await _render(_table, TABLE_FRAMES)
		if img == null:
			return {"error": "no picture could be taken"}
		img.resize(SHEET.x / 2 - 2, SHEET.y / 2 - 2, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i((i % 2) * (SHEET.x / 2) + 1, (i / 2) * (SHEET.y / 2) + 1))
	return {"image": sheet, "frames": steps, "burst": burst}


## A MOVING PART OF THE LIGHT ([Lights]) photographed four times on the episode's table: "clouds" as one
## passes over the sun - the sun out, the cloud coming over it, under it, the sun back; "birds" as a
## shadow crosses the table; something the sun falls through as it stirs; a lamp as it flickers, fails,
## cuts, passes or flashes. `{image, frames: [seconds], what}`; `error` when it cannot be shown.
func watch_light(raw: Dictionary, name: String) -> Dictionary:
	var err: String = await _stand(raw)
	if not err.is_empty():
		return {"error": err}
	var m = _medium
	var rig = m._light_part._rig
	if rig == null:
		return {"error": "the table has no light of its own"}
	var plan := _light_moment(rig, name)
	if plan.has("error"):
		return plan
	var steps: Array = plan["times"]
	var sheet := Image.create(SHEET.x, SHEET.y, false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.06, 0.06, 0.07))
	for i in steps.size():
		var t := float(steps[i])
		_pose_spread(t)
		m._tick_ride(t)
		m._light_part.tick_props(t)
		m._tick_air(t)
		var img: Image = await _render(_table, TABLE_FRAMES)
		if img == null:
			return {"error": "no picture could be taken"}
		img.resize(SHEET.x / 2 - 2, SHEET.y / 2 - 2, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i((i % 2) * (SHEET.x / 2) + 1, (i / 2) * (SHEET.y / 2) + 1))
	return {"image": sheet, "frames": steps, "what": plan["what"]}


## THE STRONGEST GUST of [param wind] ([method Winds.plan]) between [param t0] and [param t1]: its start, how
## long it blows and its peak's time - x below 0 when none blows.
static func _strongest_gust(wind: Dictionary, t0: float, t1: float) -> Vector3:
	if wind.is_empty():
		return Vector3(-1.0, 0.0, 0.0)
	var starts: PackedFloat32Array = wind["starts"]
	var peaks: PackedFloat32Array = wind["peaks"]
	var best := -1
	for i in range(starts.bsearch(t0), starts.bsearch(t1)):
		if best < 0 or peaks[i] > peaks[best]:
			best = i
	return Winds.gust_span(wind, best) if best >= 0 else Vector3(-1.0, 0.0, 0.0)


## WHEN TO PHOTOGRAPH [param name] of [param rig]'s light: `{times: [four seconds], what}`, or `{error}`.
func _light_moment(rig, name: String) -> Dictionary:
	var low := name.to_lower()
	if low == "wind":
		var g := _strongest_gust(rig.wind, AIR_AT, AIR_AT + 300.0)
		if g.x < 0.0:
			return {"error": "the light has no wind, or it never gusts"}
		return {"times": [maxf(g.x - 0.5, 0.0), g.x + (g.z - g.x) * 0.5, g.z, g.z + (g.x + g.y - g.z) * 0.6],
			"what": "The strongest gust of the first five minutes, %.0f s in: before it, rising, at its height, dying away." % g.x}
	if low == "clouds":
		var field: Dictionary = rig.field
		if field.is_empty():
			return {"error": "the sky has no clouds"}
		if float(field["thr"]) < -0.5:
			return {"times": [AIR_AT, AIR_AT + 4.0, AIR_AT + 8.0, AIR_AT + 12.0],
				"what": "The sky is covered: the sun is behind cloud all the while, four seconds apart."}
		# the first cloud over the sun from a clear sky: the last clear moment, half way in, deepest, back out
		var t := 0.0
		var clear_at := -1.0
		while t < 1200.0:
			var c := Lights.cloud_at(field, t)
			if c < 0.02:
				clear_at = t
			elif c > 0.98 and clear_at >= 0.0:
				var into := t
				var out := into
				while out < into + 300.0 and Lights.cloud_at(field, out) > 0.02:
					out += 0.25
				var mid := (clear_at + into) * 0.5
				return {"times": [maxf(clear_at - 1.0, 0.0), mid, minf(into + 3.0, (into + out) * 0.5), out + 1.0],
					"what": "A cloud passing over the sun, %.0f s in: the sun out, the cloud coming over it, under it, the sun back (it is in cloud for %.0f s)." % [into, out - mid]}
			t += 0.25
		return {"error": "no cloud crosses the sun in the first twenty minutes - give the clouds more cover"}
	if low == "birds":
		var flights: Array = rig.flights
		for c in flights:
			var tc := float((c as Dictionary)["t"])
			var over: Array = []
			var tt := tc - 2.0
			var until := tc + (float((c as Dictionary)["dur"]) + 2.0 if String((c as Dictionary)["path"]) == "circle" else 2.0)
			var middle: Vector3 = rig.stage.get("middle", Vector3.ZERO)
			while tt < until:
				for b in Lights.birds_at(flights, rig.bird_look, tt):
					var at: Vector2 = (b as Dictionary)["at"]
					# over the table where the sun reaches it: a shadow inside a shade is not seen
					if absf(at.x) < 0.55 and at.y > -0.55 and at.y < 0.35 \
							and Lights.sunlit(rig.geom, rig.sun_vec, middle + Vector3(at.x, 0.0, at.y), tt):
						over.append(tt)
						break
				tt += 0.01
			if over.size() >= 4:
				var a := float(over[0])
				var z := float(over[over.size() - 1])
				return {"times": [a, lerpf(a, z, 0.33), lerpf(a, z, 0.66), z],
					"what": "A bird's shadow crossing the table, %.1f s in - over it for %.2f s." % [a, z - a]}
		return {"error": "no bird's shadow crosses the table in the reading"}
	for g in rig.screens:
		var sc: Dictionary = ((g as Dictionary)["g"] as Dictionary)["screen"]
		if String(sc["name"]) == name:
			if not bool((g as Dictionary)["moves"]):
				return {"error": "\"%s\" does not move: set shows it" % name}
			return {"times": [AIR_AT, AIR_AT + 1.5, AIR_AT + 3.0, AIR_AT + 4.5], "what": "\"%s\" stirring, a second and a half apart." % name}
	for c in rig.casters:
		var cs: Dictionary = (c as Dictionary)["spec"]
		if String(cs["name"]) != name:
			continue
		match String((c as Dictionary)["kind"]):
			"swing":
				return {"times": [AIR_AT, AIR_AT + 0.6, AIR_AT + 1.2, AIR_AT + 1.8], "what": "\"%s\" swinging, six tenths of a second apart." % name}
			"spin":
				return {"times": [AIR_AT, AIR_AT + 0.12, AIR_AT + 0.24, AIR_AT + 0.36], "what": "\"%s\" turning, an eighth of a second apart." % name}
			"flutter":
				return {"times": [AIR_AT, AIR_AT + 0.25, AIR_AT + 0.5, AIR_AT + 0.75], "what": "\"%s\" rippling, a quarter of a second apart." % name}
		return {"error": "\"%s\" does not move: set shows its shadow" % name}
	for l in rig.lamps:
		var spec: Dictionary = (l as Dictionary)["spec"]
		if String(spec["name"]) != name:
			continue
		var fk: Dictionary = (l as Dictionary)["fk"]
		var style := String((Lights.LAMPS[String(spec["look"])] as Dictionary)["flicker"])
		if fk.has("spells"):
			# A FAILING LIGHT through its first bad spell: before it, at its deepest sag, later in it, and after
			for k in (fk["spells"] as PackedFloat32Array).size():
				var s0 := float((fk["spells"] as PackedFloat32Array)[k])
				if s0 < AIR_AT:
					continue
				var length := float((fk["spell_lens"] as PackedFloat32Array)[k])
				var deep := s0
				var least := INF
				var t := s0
				while t < s0 + length:
					var b := float(Lights.flicker(String(spec["look"]), fk, t)["bright"])
					if b < least:
						least = b
						deep = t
					t += 1.0 / 60.0
				return {"times": [s0 - 0.5, deep, s0 + length * 0.75, s0 + length + 1.5],
					"what": "\"%s\" failing at %.1f s: before, at its deepest sag, later in the spell, and after." % [name, s0]}
		match style:
			"pass":
				for e in (fk["events"] as PackedFloat32Array):
					if e >= 1.0:
						return {"times": [e - 0.5, e + 0.64, e + 1.6, e + 2.56], "what": "\"%s\" at %.1f s: before, and as it passes." % [name, e]}
				return {"error": "\"%s\" never comes in the reading" % name}
			"lightning":
				var m := Lights.flash_moments(fk, 1.0)
				if m.is_empty():
					return {"error": "\"%s\" never comes in the reading" % name}
				return {"times": [float(m[0]) - 0.5, m[1], m[2], float(m[2]) + 0.5],
					"what": "\"%s\" at %.1f s: before, at its brightest flickers, and after." % [name, float(m[0])]}
			"beam":
				var every := float(fk["every"])
				var t0 := (floorf(AIR_AT / every + float(fk["seed"])) + 0.5 - float(fk["seed"])) * every
				if t0 < AIR_AT:
					t0 += every
				return {"times": [t0 - 0.3, t0 - 0.1, t0 + 0.1, t0 + 0.3], "what": "\"%s\" sweeping across the table." % name}
			"steady":
				return {"error": "\"%s\" is steady: set shows it" % name}
			"screen":
				return {"times": [AIR_AT, AIR_AT + 2.5, AIR_AT + 5.0, AIR_AT + 7.5], "what": "\"%s\" through its cuts, two and a half seconds apart." % name}
			_:
				return {"times": [AIR_AT, AIR_AT + 0.3, AIR_AT + 0.6, AIR_AT + 0.9], "what": "\"%s\" flickering, a third of a second apart." % name}
	return {"error": "nothing called \"%s\" moves in the light" % name}


## THE TABLE FROM STRAIGHT ABOVE - its top, its edge and its layers as they are laid, the things on it
## and the cards in their spread, the reader at the bottom - with the stretch the camera sees outlined:
## a plan, for laying a runner square or a cloth as a diamond. Lit as the show lights it. `{image}`;
## `error` when the table cannot be stood here.
func overhead(raw: Dictionary) -> Dictionary:
	var err: String = await _stand(raw)
	if not err.is_empty():
		return {"error": err}
	_pose_spread()
	var m = _medium
	var bounds: AABB = (m._furniture as Dictionary).get("bounds", AABB(Vector3(-0.95, 0.0, -0.4), Vector3(1.9, 0.05, 0.85)))
	var mid := bounds.get_center()
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	var aspect := float(SHEET.x) / float(SHEET.y)
	cam.size = maxf(bounds.size.z, bounds.size.x / aspect) * 1.08
	cam.near = 0.05
	cam.far = 6.0
	cam.environment = (m._cam as Camera3D).environment
	(m._root3 as Node3D).add_child(cam)
	cam.transform = Transform3D(Basis.looking_at(Vector3.DOWN, Vector3(0.0, 0.0, -1.0)), Vector3(mid.x, 2.0, mid.z))
	var seen := _frame_on_table(m)
	seen.position.y = 0.002
	(m._root3 as Node3D).add_child(seen)
	cam.make_current()
	var img: Image = await _render(_table, TABLE_FRAMES)
	(m._cam as Camera3D).make_current()
	cam.queue_free()
	seen.queue_free()
	if img == null:
		return {"error": "no picture could be taken"}
	return {"image": img}


## THE BLUEPRINT ([TableBlueprint]): [param raw] stood on the episode's own table and drawn from above as
## a plan, each thing numbered by [param numbers] (name -> number). `{image, placed}` - `placed` as
## [method table] says where each thing stood - or `error` when the table cannot be stood here.
func blueprint(raw: Dictionary, numbers: Dictionary) -> Dictionary:
	var err: String = await _stand(raw)
	if not err.is_empty():
		return {"error": err}
	var data: Dictionary = _medium._things_part.blueprint()
	data["numbers"] = numbers
	var placed := _placed(CardTable.sanitize_table(raw, CardTable.sanitize_look(plan.get("look", {}) if plan.get("look") is Dictionary else {})))
	var vp := SubViewport.new()
	vp.size = TableBlueprint.SHEET
	vp.transparent_bg = false
	vp.msaa_2d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var paper := TableBlueprint.new()
	paper.data = data
	vp.add_child(paper)
	_tree().root.add_child(vp)
	var img: Image = await _render(vp, 2)
	if is_instance_valid(vp):
		vp.queue_free()
	if img == null:
		return {"error": "no picture could be taken"}
	return {"image": img, "placed": placed}


## The stretch of the table the episode's camera sees, as a thin line laid on it.
func _frame_on_table(m) -> MeshInstance3D:
	var pts := TableBlueprint.seen(m._plan.cam_base, (m._cam as Camera3D).fov)
	pts.append(pts[0])
	var im := ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.85, 0.2)
	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, mat)
	for q in pts:
		im.surface_add_vertex(Vector3(q.x, 0.0, q.y))
	im.surface_end()
	var mi := MeshInstance3D.new()
	mi.mesh = im
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## THE OPENING - the video's first seconds, and its thumbnail - over this table: the deck squared in
## the middle, the flames lit, the whole frame thrown out of focus as the intro throws it, and the
## show's name over it in the color [param raw]'s `title` names. `{image, contrast}`: `contrast` is
## the WCAG contrast between that color and the table behind the name - the worst of the left,
## middle and right of its lines - read off the same frame without the name. `error` when the table
## cannot be stood here.
func opening(raw: Dictionary) -> Dictionary:
	var err: String = await _stand(raw)
	if not err.is_empty():
		return {"error": err}
	var m = _medium
	m._pose(OPENING_AT)
	m._tick_camera(0.0)
	m._light_part.tick_props(OPENING_AT)
	m._light_part.tick(_quiet(OPENING_AT))
	m._tick_air(OPENING_AT)
	(m._env as Environment).adjustment_brightness = 1.0
	m._lens(0.0)
	var title = m._title
	title.alpha = 0.0
	title.queue_redraw()
	var bare: Image = await _render(_table, TABLE_FRAMES)
	if bare == null or not is_instance_valid(title):
		return {"error": "no picture could be taken"}
	title.alpha = 1.0
	title.queue_redraw()
	var img: Image = await _render(_table, TABLE_FRAMES)
	if not is_instance_valid(title):
		return {"error": "no picture could be taken"}
	title.alpha = 0.0
	title.queue_redraw()
	m._lens(1.0)
	if img == null or bare == null:
		return {"error": "no picture could be taken"}
	var lay := CardTable.title_layout(title.face, title.italic, String(title.channel), String(title.byline), Vector2(SHEET))
	return {"image": img, "contrast": title_contrast(bare, title.ink, lay, title.face)}


## How far [param ink] stands out from [param frame] behind the name's lines in [param lay] (set in
## [param face]): the WCAG contrast against the mean color of the left, middle and right third of
## each line's capitals - the lowest of them.
static func title_contrast(frame: Image, ink: Color, lay: Dictionary, face: Font) -> float:
	var worst := INF
	for l in lay.get("lines", []):
		var d: Dictionary = l
		if bool(d["italic"]):
			continue
		var size := int(d["size"])
		var w := face.get_string_size(String(d["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var top := float(d["y"]) - size * CardTable.TITLE_CAP
		for third in 3:
			var x0 := (frame.get_width() - w) * 0.5 + w * third / 3.0
			var r := Rect2i(Vector2i(roundi(x0), roundi(top)), Vector2i(roundi(w / 3.0), roundi(size * CardTable.TITLE_CAP)))
			r = r.intersection(Rect2i(Vector2i.ZERO, frame.get_size()))
			if r.size.x <= 0 or r.size.y <= 0:
				continue
			worst = minf(worst, CardTable.contrast(ink, _mean(frame, r)))
	return worst if worst < INF else 0.0


## The mean color of [param img] over [param r], read every few pixels.
static func _mean(img: Image, r: Rect2i) -> Color:
	var sum := Color(0, 0, 0, 0)
	var n := 0
	for y in range(r.position.y, r.end.y, 3):
		for x in range(r.position.x, r.end.x, 3):
			sum += img.get_pixel(x, y)
			n += 1
	return Color(sum.r / n, sum.g / n, sum.b / n) if n > 0 else Color.BLACK


## The episode's table built over [param raw] on a stage of its own, built on a worker thread and swapped
## in for the last one (see the class note): "" when it stands. Awaited. [param acts]: the work done on it
## (`acts.json` as written, [TableWork]) - none for a table only set.
func _stand(raw: Dictionary, acts: Variant = null) -> String:
	if not can_set():
		return "this process cannot stand the table (%s)" % ("no renderer" if not can_see() else "no ghost session")
	_sync_pictures()
	var err := TextGen.put(_dir.path_join("table.json"), JSON.stringify(raw, "\t"))
	if not err.is_empty():
		return err
	if acts != null:
		err = TextGen.put(_dir.path_join("acts.json"), JSON.stringify(acts, "\t"))
		if not err.is_empty():
			return err
	elif FileAccess.file_exists(_dir.path_join("acts.json")):
		DirAccess.remove_absolute(_dir.path_join("acts.json"))
	var cards: Array = []
	for i in episode.card_count():
		cards.append({"key": "card %d" % (i + 1), "name": "", "numeral": "", "reversed": false, "jumper": false,
			"position": {}, "booklet": {}, "art": ""})
	var images := {}
	for k in ["back", "surface", "backdrop"]:
		if FileAccess.file_exists(_dir.path_join(k + ".png")):
			images[k] = _dir.path_join(k + ".png")
	var doc := Doc.new()
	# the show's name stands over the table only at the opening: its alpha is 0 for every other picture
	doc.document = {"source": "", "title": show_name, "byline": byline, "table": {"show": episode.show, "seed": episode.seed,
		"dir": _dir, "plan": plan, "images": images, "cards": cards}}
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.size = SHEET
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var m = TablePreview._load(MEDIUM)
	if m == null:
		vp.free()
		return "the table medium could not be loaded"
	# THE PICTURES ALREADY DECODED are handed on: decoding the cloth and the room again is seconds of work
	if _medium != null and is_instance_valid(_medium):
		m._textures = (_medium._textures as Dictionary).duplicate()
		m._mtimes = (_medium._mtimes as Dictionary).duplicate()
	m.aside = true
	# WHAT THE LAST TABLE BAKED goes on to this one ([method TablePhysics.carry]): stood over the same table, it bakes
	# only from where the two plans part - with acts only (a table only set has no plan to carry)
	var carried: Variant = null
	if acts != null and _medium != null and is_instance_valid(_medium) and _medium._work != null and _medium._work.physics != null:
		carried = _medium._work.physics.carry()
	var build := func() -> void:
		m.mount(vp)
		m.bind_captions(doc)
		m._key = ""
		m._ensure_doc()
	var releases := _releases
	var task := WorkerThreadPool.add_task(build, false, "the set dresser's table")
	while not WorkerThreadPool.is_task_completed(task):
		await _tree().process_frame
	WorkerThreadPool.wait_for_task_completion(task)
	if _releases != releases:
		vp.free()
		return "the table's stage was given back while it was built"
	if carried != null and m._work != null and m._work.physics != null:
		m._work.physics.adopt(carried)
	_tree().root.add_child(vp)
	if _table != null and is_instance_valid(_table):
		_table.queue_free()
	_table = vp
	_medium = m
	_doc = doc
	return ""


## A MOMENT STAGED for a burst `on` [param on], at [constant AIR_AT], the way the table stages it: where
## its emitter is through it (`moments`, as [method TableMedium._air_moments] gives them) and how the
## card in it moves (`card`: `[[t, Transform3D], ...]`, empty for none).
func _staged(on: String) -> Dictionary:
	var m = _medium
	var consts := (m.get_script() as Script).get_script_constant_map()
	var t0 := AIR_AT
	var card: Array = []
	var moments: Array = []
	match on:
		"shuffle":
			m._cur_base = m._plan.mid
			moments.append({"t": t0, "dur": 0.5, "from": "point",
				"path": [[t0, Transform3D(Basis.IDENTITY, (m._plan.mid as Vector3) + Vector3(0.0, 0.03, 0.0))]]})
		"jumper":
			# a card springing off the deck in the middle and flying to land, as a jumper does
			m._cur_base = m._plan.mid
			var fly: Vector2 = consts.get("JUMP_FLY", Vector2(1.15, 2.25))
			var path: Array = []
			for i in 9:
				var u := lerpf(fly.x, fly.y, float(i) / 8.0)
				path.append([t0 + (u - fly.x), m._card_poses._jump_xf(0, u, Transform3D.IDENTITY)])
			card = path
			moments.append({"t": t0, "dur": fly.y - fly.x, "from": "card", "path": path})
		"reveal":
			var xf: Transform3D = m._card_poses._present_xf(0, t0)
			card = [[t0, xf]]
			moments.append({"t": t0, "dur": 0.3, "from": "card", "path": card})
		"pirouette":
			# a card held up and twirled round three times, winding down as a hand's flourish does
			var held: Transform3D = m._card_poses._present_xf(0, t0)
			var up: Vector3 = (m._plan.cam_base as Transform3D).basis.y
			var path: Array = []
			for i in 17:
				var u := float(i) / 16.0
				var turn := PI + 5.0 * PI * (1.0 - pow(1.0 - u, 2.2))
				path.append([t0 + u * 1.8, Transform3D(Basis(up, turn) * held.basis, held.origin)])
			card = path
			moments.append({"t": t0, "dur": 1.8, "from": "card", "path": path})
		"lay":
			card = [[t0, m._slot_xf(0)]]
			moments.append({"t": t0, "dur": 0.2, "from": "card", "path": card})
		"close":
			for k in (m._cards as Array).size():
				moments.append({"t": t0, "dur": 0.8, "from": "card", "path": [[t0, m._slot_xf(k)]]})
	return {"moments": moments, "card": card}


## The table as it is at [param t] in a staged moment ([method _staged]): the spread laid and the deck
## at its side - or, for a shuffle or a jumper, the deck in the middle - and the moment's card where
## the moment has it.
func _pose_moment(on: String, moment: Dictionary, t: float) -> void:
	var m = _medium
	_pose_spread()
	if on == "shuffle" or on == "jumper":
		m._cur_base = m._plan.mid
		for i in (m._deck as Array).size():
			(m._deck[i] as MeshInstance3D).transform = m._rest_xf(i)
		for k in (m._cards as Array).size():
			(m._cards[k] as MeshInstance3D).visible = false
	var card: Array = moment.get("card", [])
	if not card.is_empty() and (m._cards as Array).size() > 0:
		var c: MeshInstance3D = m._cards[0]
		c.visible = true
		c.transform = Effects._along(card, t)


## THE WORK ON THE TABLE ([TableWork], next/table_work.md), for the puppeteer: the table [param raw] stood
## with [param acts] - `{parts (what on it can be worked, in words), notes (what of the acts could not be
## kept), acts (the names kept)}`, or `{error}`.
func work(raw: Dictionary, acts: Variant) -> Dictionary:
	var err: String = await _stand(raw, acts)
	if not err.is_empty():
		return {"error": err}
	var w = _medium._work
	return {"parts": w.parts_report(), "notes": Array(w.notes), "acts": (w.acts as Array).map(func(a: Dictionary) -> String: return String(a["name"]))}


## ACTS [param names] OF [param acts] played on the table [param raw], in numbers ([method TableWork.check]) - ONE
## table stood for them all, and what is in things baked once through the last of them: `{texts: {name: text},
## notes}` (what of the acts could not be kept), or `{error}`.
func work_checks(raw: Dictionary, acts: Variant, names: Array) -> Dictionary:
	var err: String = await _stand(raw, acts)
	if not err.is_empty():
		return {"error": err}
	var w = _medium._work
	if not names.is_empty() and not await _bake(w.checks_reach(w.rehearsed(), names)):
		return {"error": "the work's tools were closed while it was baked"}
	var texts := {}
	for nm in names:
		texts[String(nm)] = String((w.check(String(nm)) as Dictionary)["text"])
		# ...the app drawing between one act's check and the next's
		await _tree().process_frame
		if _halted:
			return {"error": "the work's tools were closed while it was checked"}
	return {"texts": texts, "notes": Array(w.notes)}


## ACT [param name] OF [param acts] played on the table [param raw] and photographed from the camera's place
## [param n] times through it, start to end: a sheet, `{image, frames: [seconds into it]}`, or `{error}`.
func work_watch(raw: Dictionary, acts: Variant, name: String, n := 6) -> Dictionary:
	var err: String = await _stand(raw, acts)
	if not err.is_empty():
		return {"error": err}
	var m = _medium
	var times: Dictionary = m._work.rehearsed()
	if not times.has(name):
		return {"error": "no act called \"%s\" was kept%s" % [name, (": " + "; ".join(m._work.notes)) if not (m._work.notes as PackedStringArray).is_empty() else ""]}
	var t0 := float((times[name] as Array)[0])
	var t1 := float((times[name] as Array)[1])
	if not await _bake(t1):
		return {"error": "the work's tools were closed while it was baked"}
	var cols := 3
	var rows := int(ceil(float(n) / float(cols)))
	var sheet := Image.create(SHEET.x, SHEET.y, false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.06, 0.06, 0.07))
	var tw := SHEET.x / cols - 2
	var th := SHEET.y / rows - 2
	var frames: Array = []
	for i in n:
		var t := lerpf(t0, t1, float(i) / float(maxi(n - 1, 1)))
		frames.append(t - t0)
		_pose_spread(t)
		m._tick_ride(t)
		m._work.tick(t)
		m._light_part.tick_props(t)
		m._tick_air(t)
		var img: Image = await _render(_table, TABLE_FRAMES)
		if img == null:
			return {"error": "no picture could be taken"}
		img.resize(tw, th, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i((i % cols) * (SHEET.x / cols) + 1, (i / cols) * (SHEET.y / rows) + 1))
	return {"image": sheet, "frames": frames}


## WHAT IS IN THINGS BAKED through rehearsal time [param t] ([method TablePhysics.bake_until]) on a worker, the app's own
## thread drawing on while it waits: false when it was given up ([method halt]) or the preview given back. What is
## asked of the table after finds it baked.
func _bake(t: float) -> bool:
	var ph = _medium._work.physics if _medium != null and _medium._work != null else null
	if ph == null or _halted:
		return not _halted
	var releases := _releases
	var task := WorkerThreadPool.add_task(Callable(ph, "bake_until").bind(t, true), false, "what is in things, baked")
	while not WorkerThreadPool.is_task_completed(task):
		await _tree().process_frame
	WorkerThreadPool.wait_for_task_completion(task)
	return not _halted and _releases == releases and _medium != null


## The episode's pictures beside the description, copied again when the episode's change (the room
## may still be being painted while the table is set).
func _sync_pictures() -> void:
	DirAccess.make_dir_recursive_absolute(_dir)
	for f in PICTURES:
		var src := episode.dir.path_join(String(f))
		var dst := _dir.path_join(String(f))
		if FileAccess.file_exists(src):
			if not FileAccess.file_exists(dst) or FileAccess.get_modified_time(src) > FileAccess.get_modified_time(dst):
				DirAccess.copy_absolute(src, dst)
		elif FileAccess.file_exists(dst):
			DirAccess.remove_absolute(dst)


## The table at the end of a reading: every card down in the spread, face down; the deck squared at
## its side; the flames burning; its light at [param light_at] - or, unless told, as it mostly is (the sun
## out, no bird crossing); the channel's title off.
func _pose_spread(light_at := -1.0) -> void:
	var m = _medium
	var card_t := float((m.get_script() as Script).get_script_constant_map().get("CARD_T", 0.0007))
	m._cur_base = m._plan.deck_base
	for i in (m._deck as Array).size():
		(m._deck[i] as MeshInstance3D).transform = m._rest_xf(i)
	for k in (m._cards as Array).size():
		var s: Dictionary = m._plan.slots[k]
		var card: MeshInstance3D = m._cards[k]
		card.visible = true
		card.transform = Transform3D(Basis(Vector3.UP, float(s["yaw"])), (s["pos"] as Vector3) + Vector3(0.0, card_t * 0.5, 0.0))
	(m._page as Node3D).visible = false
	m._tick_camera(0.0)
	m._light_part.tick_props(30.0)
	m._light_part.tick(light_at if light_at >= 0.0 else _quiet(AIR_AT))
	(m._env as Environment).adjustment_brightness = 1.0
	m._lens(1.0)


## A moment at or after [param t] when the table's light is as it mostly is: the sun out, no bird
## crossing - [param t] itself for a table with no light of its own.
func _quiet(t: float) -> float:
	var rig = _medium._light_part._rig if _medium != null else null
	return rig.quiet_near(t) if rig != null else t


## What the medium made of [param spec] (the table made safe): where each thing stood, what found no
## room, which light leads.
func _placed(spec: Dictionary) -> Dictionary:
	var m = _medium
	var consts := (m.get_script() as Script).get_script_constant_map()
	var stood: Array = []
	var used := {}
	var left_off: Array = []
	var left_why := {}
	var by_light := {}
	for u in m._things_part.unstood:
		left_why[String((u as Dictionary)["name"])] = String((u as Dictionary)["why"])
	var cam: Transform3D = m._plan.cam_base
	var fov: float = (m._cam as Camera3D).fov
	for t in spec.get("things", []):
		var name := String((t as Dictionary).get("name", ""))
		var found := -1
		for i in (m._things_part.on_table as Array).size():
			if not used.has(i) and String((m._things_part.on_table[i] as Dictionary)["name"]) == name:
				found = i
				break
		if found < 0:
			left_off.append(name)
			continue
		used[found] = true
		var th: Dictionary = m._things_part.on_table[found]
		var node: Node3D = th["node"]
		var rect: Rect2 = th["rect"]
		var entry := {"name": name, "place": String(th["place"]),
			"at": Vector2((node.position.x - Tables.ORIGIN.x) * 100.0, (node.position.z - Tables.ORIGIN.y) * 100.0),
			"k": node.transform.basis.get_scale().x, "tall": rect.size.y}
		# WRITTEN WHERE IT STANDS: where, how far it had to move and why, its foot and height against what
		# its spot shows, and how much of it the frame keeps
		var written: Variant = th.get("written")
		if written != null:
			var bb: Rect2 = th["bb"]
			entry["written"] = ((written as Vector2) - Tables.ORIGIN) * 100.0
			entry["moved"] = float(th.get("moved", 0.0)) * 100.0
			entry["why"] = String(th.get("why", ""))
			entry["foot"] = bb.size * 100.0
			entry["height"] = (th["box"] as AABB).end.y * 100.0
			entry["room"] = CardTable.headroom_at(cam, fov, Vector2(node.position.x, node.position.z)) * 100.0
			entry["shown"] = rect.intersection(Rect2(0.0, 0.0, 1.0, 1.0)).get_area() / maxf(rect.get_area(), 1e-9)
			var half := float(consts.get("WORKSPACE_HALF", 0.25))
			var mid: Vector3 = m._plan.mid
			entry["hands"] = bb.intersects(Rect2(mid.x - half, mid.z + float(consts.get("WORKSPACE_FROM", 0.14)), half * 2.0, 1.0))
		stood.append(entry)
		for li in th.get("lights", []):
			by_light[int(li)] = name
	var key: String = m._light_part.lead_name(by_light)
	var held: Array = []
	for i in (m._lights as Array).size():
		var l: Dictionary = m._lights[i]
		var full := float(consts.get("KEY_ENERGY" if i == int(m._light_part._key_flame) else "FILL_ENERGY", 0.35)) * float((l["flames"] as Array).size())
		if float(l["energy"]) < full * 0.9 and by_light.has(i):
			held.append(by_light[i])
	var deck: Vector3 = m._plan.deck_base
	# (no deck at all in a show that draws no cards)
	return {"stood": stood, "left_off": left_off, "left_why": left_why, "key": key, "held_down": held,
		"cards": (m._cards as Array).size(), "deck": "" if String(m._plan.cards_from) == "none" else ("front right" if deck.x > 0.0 else "front left")}


# --- the shutter ------------------------------------------------------------------------------------

## [param vp] drawn for [param frames] frames, read back, then stopped again.
## null when the stage is given back while it waits ([method release]).
##
## A HIDDEN WINDOW DRAWS NOTHING (reported 2026-10-19: "the set dresser stopped without handing its table
## in"): while Ghost Notes is minimized or on another desktop, Godot runs its frames and draws none, and a
## picture that waited for frames to be drawn waited until the window came back - a `put` 35 minutes, every
## call behind it timed out, and the agent gave up. Measured in a virtual KWin, on X11 and on Wayland: 435
## frames run in 3 s, none drawn. So once [constant UNDRAWN] frames pass with nothing drawn, the picture
## draws its own ([method _draw_unseen]).
func _render(vp: SubViewport, frames: int) -> Image:
	if vp == null or not is_instance_valid(vp):
		return null
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var drawn := [0]
	var count := func() -> void: drawn[0] += 1
	RenderingServer.frame_post_draw.connect(count)
	var seen := 0
	var idle := 0
	while int(drawn[0]) < frames and is_instance_valid(vp):
		await _tree().process_frame
		idle = idle + 1 if int(drawn[0]) == seen else 0
		seen = int(drawn[0])
		if idle >= UNDRAWN and is_instance_valid(vp):
			TablePreview._draw_unseen(frames - seen)
	RenderingServer.frame_post_draw.disconnect(count)
	if not is_instance_valid(vp):
		return null
	var img := vp.get_texture().get_image()
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if img == null or img.is_empty():
		return null
	img.convert(Image.FORMAT_RGB8)
	return img


## [param n] frames drawn now, for a window that draws none ([method _render]): every viewport but the
## window's own, which is set aside for them - its picture would go to a screen that takes none, and on
## Wayland a hidden window's screen can keep the draw waiting. Set inactive instead, it takes the viewports
## under it out of the draw too (measured: the picture came back stale).
static func _draw_unseen(n: int) -> void:
	var root := _tree().root.get_viewport_rid()
	var was := RenderingServer.viewport_get_update_mode(root)
	RenderingServer.viewport_set_update_mode(root, RenderingServer.VIEWPORT_UPDATE_DISABLED)
	for i in n:
		RenderingServer.force_draw(false, 1.0 / 60.0)
	RenderingServer.viewport_set_update_mode(root, was)


static func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


## A new instance of the script whose class is [param class_name_], or null.
static func _load(class_name_: String) -> Object:
	for c in ProjectSettings.get_global_class_list():
		if String((c as Dictionary).get("class", "")) == class_name_:
			var script := load(String((c as Dictionary)["path"])) as Script
			return script.new() if script != null else null
	return null
