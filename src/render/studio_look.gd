extends RefCounted
class_name StudioLook

## StudioLook - how a thing is lit when it is looked at alone: a dark room-toned background with a dim sky for metal to reflect, a
## warm key from above, left and in front (its shadows short and sharp), a cool fill opposite and a rim from behind, so a dark thing
## keeps its outline. A prop's picture ([PropStudio]) and its 3D view ([PropViewer]) are lit by it, so the two look alike.

## The lens a studio shoots with (degrees, vertical).
const FOV := 28.0

## A ground ruled in centimeters, a brighter line every five.
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

## The key, the fill and the rim: each its turn (degrees), energy, color and whether it casts shadows.
const LIGHTS := [[Vector3(-52.0, -35.0, 0.0), 1.5, Color(1.0, 0.95, 0.86), true],
	[Vector3(-28.0, 140.0, 0.0), 0.45, Color(0.8, 0.86, 1.0), false],
	[Vector3(-15.0, 175.0, 0.0), 0.35, Color(1.0, 1.0, 1.0), false]]


## The studio's air: its background, ambient light, sky for reflections, tone mapping and glow (a flame blooms).
static func environment() -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.035, 0.035, 0.04)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.55, 0.58)
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.95
	# seen in reflections only: against a flat background a polished thing reflects black
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
	return env


## The key, fill and rim ([constant LIGHTS]) added under [param root]; shadows reach [param reach] meters from the camera.
static func light(root: Node3D, reach := 3.0) -> void:
	for l in LIGHTS:
		var d := DirectionalLight3D.new()
		d.rotation_degrees = l[0]
		d.light_energy = float(l[1])
		d.light_color = l[2]
		d.shadow_enabled = bool(l[3])
		d.directional_shadow_max_distance = reach
		d.shadow_bias = 0.02
		d.shadow_normal_bias = 0.6
		root.add_child(d)


## A ruled ground [param across] meters square, at height 0.
static func ground(across := 4.0) -> MeshInstance3D:
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(across, across)
	g.mesh = pm
	var gm := ShaderMaterial.new()
	gm.shader = Shader.new()
	gm.shader.code = GROUND_SHADER
	g.material_override = gm
	return g
