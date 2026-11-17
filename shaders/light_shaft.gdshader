// A shaft of light through haze ([Surroundings].rays): a cone drawn added over the scene, brightest through its middle as seen,
// fading to nothing at its edges, in below where it comes through and out toward where it lands, and soft where it meets what is
// behind it - a few motes of dust drifting down it. Drawn, never worked out in the volumetric fog, whose grid blurs a narrow shaft.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled, fog_disabled;

uniform vec3 color : source_color = vec3(1.0);
// how bright it is through its middle
uniform float strength = 0.3;
// show time (s), for the dust drifting in it
uniform float t = 0.0;
// its length (m): the mesh runs +length/2 (where it comes through) to -length/2 (where it lands)
uniform float span = 3.0;
// how far (m) behind it a surface may stand before the shaft is whole: soft where it meets things
uniform float soft = 0.2;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;

varying float along;
// the way round the shaft as a direction across it (never an angle, which jumps where it wraps and squeezes the dust into one strip)
varying vec2 round_dir;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	along = clamp(0.5 - VERTEX.y / span, 0.0, 1.0);
	round_dir = VERTEX.xz / max(length(VERTEX.xz), 1e-5);
}

void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float core = facing * facing * facing;
	float ends = smoothstep(0.0, 0.3, along) * (1.0 - smoothstep(0.65, 1.0, along));
	float depth = texture(depth_tex, SCREEN_UV).r;
	vec4 behind = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	behind.xyz /= behind.w;
	float meets = clamp((VERTEX.z - behind.z) / soft, 0.0, 1.0);
	float drift = along * 7.0 - t * 0.08;
	float dust = 0.82 + 0.09 * (noise(vec2(round_dir.x * 2.5, drift)) + noise(vec2(round_dir.y * 2.5 + 17.0, drift + 5.0)));
	ALBEDO = color * strength * core * ends * meets * dust;
}
