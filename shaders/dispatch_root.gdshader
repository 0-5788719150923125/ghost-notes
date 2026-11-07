shader_type spatial;
render_mode cull_back;

// A ROOT IN THE HOLLOW (DispatchRoots): dark bark, its fibers running along it, a little damp. `growth` is how much of
// each root is grown (UV.x runs 0 at its base to 1 at its tip): past it the root is drawn in onto its own line (CUSTOM0,
// the line's point), so it ends in a taper that moves on as it grows.

uniform float growth = 1.0;
uniform vec3 bark : source_color = vec3(0.16, 0.12, 0.09);
uniform vec3 bark2 : source_color = vec3(0.38, 0.30, 0.22);
uniform float damp : hint_range(0.0, 1.0) = 0.55;

varying vec2 along;

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	along = UV2;
	float keep = 1.0 - smoothstep(growth - 0.06, growth, UV.x);
	VERTEX = mix(CUSTOM0.xyz, VERTEX, keep);
}

void fragment() {
	// fibers: noise stretched along the root (meters along, and round it)
	vec2 p = vec2(along.x * 9.0, along.y * 14.0);
	float fib = vnoise(p * vec2(1.0, 3.0)) * 0.6 + vnoise(p * vec2(3.0, 9.0)) * 0.4;
	float knot = smoothstep(0.78, 0.95, vnoise(vec2(along.x * 2.2, along.y * 2.0)));
	vec3 col = mix(bark, bark2, fib * 0.8 + knot * 0.3);
	ALBEDO = col;
	ROUGHNESS = mix(0.8, 0.32, damp * fib);
	SPECULAR = 0.5;
	// a sheen along it, where the light grazes it: a root reads by its edges in the dark
	RIM = 0.35;
	RIM_TINT = 0.6;
	// the fibers' ridges catch the light
	float e = 0.02;
	float fx = vnoise((p + vec2(e, 0.0)) * vec2(1.0, 3.0)) - vnoise(p * vec2(1.0, 3.0));
	float fy = vnoise((p + vec2(0.0, e)) * vec2(3.0, 9.0)) - vnoise(p * vec2(3.0, 9.0));
	NORMAL_MAP = normalize(vec3(fx * 6.0, fy * 6.0, 1.0)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.2;
}
