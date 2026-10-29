// A LIQUID IN ITS VESSEL (src/table/table_physics.gd, next/table_physics.md "Liquids"): the vessel's inside, drawn
// cut away above its surface - and, where the cut is seen through, the surface itself at its true depth, level in
// the table's space however the vessel is turned. The user, 2026-10-28: "The liquids are not liquids". The surface's
// place, its turning (the swirl), the rings on it and where a stream falls on it are handed in by the physics' bake,
// all in the mesh's own space, and the time is handed in - never TIME - so a render and a scrub agree.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec3 color : source_color = vec3(0.3, 0.2, 0.5);
uniform vec3 color2 : source_color = vec3(0.8, 0.8, 0.9);
uniform float polish : hint_range(0.0, 1.0) = 0.95;
uniform float pattern : hint_range(0.0, 1.0) = 0.25;
uniform float clarity : hint_range(0.0, 1.0) = 0.4;
uniform float grain = 1.0;
uniform float seed = 0.0;
// TableWork's: light of its own, the show's time, how hard it boils
uniform float glow = 0.0;
uniform float show_time = 0.0;
uniform float boil = 0.0;
// THE SURFACE: a point on it and its up, in the mesh's own space (meters)
uniform vec3 surface_at = vec3(0.0, 1.0, 0.0);
uniform vec3 surface_up = vec3(0.0, 1.0, 0.0);
// how far it has turned about its middle (radians), stirred
uniform float swirl = 0.0;
// RINGS running out across it: each where it began (x, y, z in the mesh's space) and when (show time) ...
uniform vec4 ring_at[12];
// ...and how high it rose (meters)
uniform float ring_size[12];
uniform int ring_count = 0;
// where a stream falls on it (the mesh's space) and how hard (meters of ripple, 0 for none)
uniform vec4 stream_at = vec4(0.0);
// THE INSIDE (Vessel.shader_tables): the mesh's space carried into the vessel's own, its warp undone, its heights, its
// radius at 32 heights (a lathe's) and at 32 bearings round its middle (an outline's) - the surface is drawn only where
// the eye crosses it within the inside (seen through the vessel's wall below it, the crossing lies outside)
uniform mat4 cavity_xf = mat4(1.0);
uniform vec3 cavity_scale = vec3(1.0);
uniform vec3 cavity_pivot = vec3(0.0);
uniform vec2 cavity_y = vec2(-100.0, 100.0);
uniform vec2 cavity_mid = vec2(0.0);
uniform float cavity_r[32];
uniform float cavity_a[32];
uniform bool cavity_known = false;

varying vec3 mpos;

#include "res://shaders/noise_common.gdshaderinc"

// A RING'S speed (meters a second), its ripples' length (meters), how long it lasts (seconds)
const float RING_SPEED = 0.17;
const float RING_WAVE = 0.0075;
const float RING_LIFE = 1.6;

void vertex() {
	mpos = VERTEX;
}

bool in_cavity(vec3 m) {
	if (!cavity_known) {
		return true;
	}
	vec3 q = (cavity_xf * vec4(m, 1.0)).xyz;
	q = cavity_pivot + (q - cavity_pivot) / cavity_scale;
	if (q.y < cavity_y.x - 0.0005 || q.y > cavity_y.y + 0.0005) {
		return false;
	}
	float fy = clamp((q.y - cavity_y.x) / max(cavity_y.y - cavity_y.x, 1e-5), 0.0, 1.0) * 31.0;
	int i = int(fy);
	float r = mix(cavity_r[i], cavity_r[min(i + 1, 31)], fract(fy));
	vec2 d = q.xz - cavity_mid;
	float fa = (atan(d.y, d.x) / 6.2831853 + 0.5) * 31.0;
	int j = int(clamp(fa, 0.0, 30.999));
	float ra = mix(cavity_a[j], cavity_a[j + 1], fract(fa));
	return length(d) <= r * ra + 0.0008;
}

// The surface's height above its plane at [q] (the mesh's space) and its slope there: rings, a stream's train, and
// the slow ripple of a liquid never quite still - each a closed form, its slope worked out with it.
vec3 waves(vec3 q, vec3 e1, vec3 e2) {
	vec2 uv = vec2(dot(q - surface_at, e1), dot(q - surface_at, e2));
	float h = 0.0;
	vec2 g = vec2(0.0);
	float k = 6.2831853 / RING_WAVE;
	for (int i = 0; i < 12; i++) {
		if (i >= ring_count) {
			break;
		}
		float tau = show_time - ring_at[i].w;
		if (tau < 0.0 || tau > RING_LIFE) {
			continue;
		}
		vec2 c = vec2(dot(ring_at[i].xyz - surface_at, e1), dot(ring_at[i].xyz - surface_at, e2));
		vec2 d = uv - c;
		float rho = length(d);
		float s = rho - RING_SPEED * tau;
		float w = 0.004 + 0.012 * tau;
		float env = exp(-(s * s) / (w * w)) * exp(-tau * 2.2) * ring_size[i] / (1.0 + 30.0 * rho);
		h += env * sin(k * s);
		float dh = env * (k * cos(k * s) - 2.0 * s / (w * w) * sin(k * s));
		g += rho > 1e-5 ? d / rho * dh : vec2(0.0);
	}
	if (stream_at.w > 0.0) {
		vec2 c = vec2(dot(stream_at.xyz - surface_at, e1), dot(stream_at.xyz - surface_at, e2));
		vec2 d = uv - c;
		float rho = length(d);
		float env = stream_at.w * exp(-rho / 0.018);
		float ph = k * rho - show_time * 26.0;
		h += env * sin(ph);
		float dh = env * (k * cos(ph) - sin(ph) / 0.018);
		g += rho > 1e-5 ? d / rho * dh : vec2(0.0);
	}
	return vec3(h, g);
}

void fragment() {
	// ABOVE ITS SURFACE THERE IS NO LIQUID
	if (dot(mpos - surface_at, surface_up) > 0.0) {
		discard;
	}
	mat4 mv = VIEW_MATRIX * MODEL_MATRIX;
	vec3 eye = (inverse(MODEL_MATRIX) * vec4(INV_VIEW_MATRIX[3].xyz, 1.0)).xyz;
	vec3 albedo = color;
	float rough = 0.03 + (1.0 - polish) * 0.35;
	vec3 emit = color * glow * 1.6;
	bool cap = false;
	vec3 hit0 = vec3(0.0);
	if (!FRONT_FACING) {
		vec3 d0 = mpos - eye;
		float den0 = dot(d0, surface_up);
		float t0 = abs(den0) > 1e-7 ? dot(surface_up, surface_at - eye) / den0 : -1.0;
		hit0 = eye + d0 * clamp(t0, 0.0, 1.0);
		cap = t0 > 0.0 && t0 <= 1.0 && in_cavity(hit0);
	}
	if (cap) {
		// THE SURFACE, where the eye's ray through this far wall crossed it - within the inside (crossed outside it, the eye
		// came in through a wall below the surface, and what it sees is the liquid's body: the branch below)
		vec3 hit = hit0;
		vec3 e1 = normalize(abs(surface_up.y) < 0.95 ? cross(surface_up, vec3(0.0, 1.0, 0.0)) : cross(surface_up, vec3(1.0, 0.0, 0.0)));
		vec3 e2 = cross(surface_up, e1);
		vec3 wv = waves(hit, e1, e2);
		// the slow ripple and the foam, turned with the swirl about the surface's middle
		vec2 uv = vec2(dot(hit - surface_at, e1), dot(hit - surface_at, e2));
		float ca = cos(-swirl);
		float sa = sin(-swirl);
		vec2 tu = vec2(uv.x * ca - uv.y * sa, uv.x * sa + uv.y * ca) * 100.0;
		vec3 cq = vec3(tu.x, 0.0, tu.y);
		float st = show_time;
		float rip = vnoise(cq * 0.35 + vec3(st * 0.31, 0.0, st * 0.23)) * 0.6 + vnoise(cq * 0.9 - vec3(st * 0.52, 0.0, -st * 0.17)) * 0.4;
		float rx = vnoise((cq + vec3(0.3, 0.0, 0.0)) * 0.35 + vec3(st * 0.31, 0.0, st * 0.23)) - vnoise((cq - vec3(0.3, 0.0, 0.0)) * 0.35 + vec3(st * 0.31, 0.0, st * 0.23));
		float rz = vnoise((cq + vec3(0.0, 0.0, 0.3)) * 0.35 + vec3(st * 0.31, 0.0, st * 0.23)) - vnoise((cq - vec3(0.0, 0.0, 0.3)) * 0.35 + vec3(st * 0.31, 0.0, st * 0.23));
		float calm = 0.06 * (0.35 + boil * 1.4);
		vec3 n = normalize(surface_up - e1 * (wv.y + rx * calm) - e2 * (wv.z + rz * calm));
		float b = 0.0;
		if (boil > 0.0) {
			// each cell a bubble on its own clock: it swells, then breaks
			vec3 c = cellsid(cq * vec3(0.7, 0.0, 0.7));
			float life = fract(st * (0.35 + boil * 0.9) + c.z * 7.0);
			float r = (1.0 - smoothstep(0.08, 0.3, c.x)) * smoothstep(0.0, 0.7, life) * (1.0 - smoothstep(0.85, 1.0, life));
			b = r * step(1.0 - min(boil, 1.0) * 0.6, c.z);
		}
		albedo = color * (0.82 + 0.2 * rip);
		albedo = mix(albedo, color2, clamp(smoothstep(0.62, 0.9, fbm(cq * 0.25 + vec3(st * 0.05)) + b * 0.4) * pattern, 0.0, 1.0));
		NORMAL = normalize((mv * vec4(n, 0.0)).xyz);
		vec3 view_hit = (mv * vec4(hit, 1.0)).xyz;
		LIGHT_VERTEX = view_hit;
		vec4 clip = PROJECTION_MATRIX * vec4(view_hit, 1.0);
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
		DEPTH = clip.z / clip.w * 0.5 + 0.5;
#else
		DEPTH = clip.z / clip.w;
#endif
		CLEARCOAT = 0.8;
		CLEARCOAT_ROUGHNESS = 0.02;
		SPECULAR = 0.6;
	} else {
		// ITS BODY, seen through a glass wall (from the front or, below the surface, from the back): deeper, the light in it
		albedo = color * 0.72;
		rough = 0.12;
		DEPTH = FRAGCOORD.z;
		SPECULAR = 0.5;
	}
	ALBEDO = albedo * 0.84;
	ROUGHNESS = rough;
	METALLIC = 0.0;
	SSS_STRENGTH = 0.15 + 0.35 * clarity;
	BACKLIGHT = color * 0.25 * clarity;
	EMISSION = emit;
}
