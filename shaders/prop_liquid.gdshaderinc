// A LIQUID IN ITS VESSEL, the body both variants share: prop_liquid.gdshader (opaque - a brew, ink, wine, the user's judged
// coffee) and prop_liquid_clear.gdshader (seen through - water; `CLEAR` defined). The why is in prop_liquid.gdshader's header.
uniform vec3 color : source_color = vec3(0.3, 0.2, 0.5);
uniform vec3 color2 : source_color = vec3(0.8, 0.8, 0.9);
uniform float polish : hint_range(0.0, 1.0) = 0.95;
uniform float pattern : hint_range(0.0, 1.0) = 0.25;
uniform float clarity : hint_range(0.0, 1.0) = 0.4;
// HOW CLOUDED IT IS by what has been rinsed in it (0 clean, 1 thick with paint; TablePaint.cloud_at): a clear liquid is seen
// through less as it clouds (prop_liquid_clear.gdshader)
uniform float murk : hint_range(0.0, 1.0) = 0.0;
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
// ITS BUBBLES BREAKING (src/table/boil.gd - the very ones the work's sound hears): each (x, z) from the surface's middle in the
// mesh's space, its radius (meters), and how far it is from rising to breaking - past 1, its ring running out
uniform vec4 bubble[16];
uniform int bubble_count = 0;
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
// THE SURFACE'S SHAPE: its ripples' heights over a grid in the vessel's own space (a byte a cell, 128 its level, a step
// of wave_quantum meters) - where the grid's corner is (x, z) and how far it spans - and how it curves as it turns
// (meters a square meter from its middle, and its level's share: dip (r^2 - dip_r2))
uniform sampler2D wave_heights : filter_linear, repeat_disable;
uniform bool wave_on = false;
uniform vec2 wave_o = vec2(0.0);
uniform float wave_span = 1.0;
uniform float wave_quantum = 0.00005;
uniform float dip = 0.0;
uniform float dip_r2 = 0.0;

varying vec3 mpos;

#include "res://shaders/noise_common.gdshaderinc"

// A RING'S speed (meters a second), its ripples' length (meters), how long it lasts (seconds)
const float RING_SPEED = 0.17;
const float RING_WAVE = 0.0075;
const float RING_LIFE = 1.6;
// SEEN THROUGH (the clear variant): from what clarity a liquid lets the eye in at all and at what clarity it is clearest, how much
// of what is behind a clean one lets through then, and how much of that a grazing look takes back. Water drawn at 0.9 of it
// through each face (two faces, front and back, half of it in all) still read as milky (2026-11-07)
const float CLEAR_FROM = 0.3;
const float CLEAR_FULL = 0.8;
const float SEE_MOST = 0.92;
const float SEE_GRAZING = 0.5;
const float WATER_SPECULAR = 0.35;

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

// How far above its level the surface stands over [m] (the mesh's space): its ripples there, and its curve as it turns.
float surf_h(vec3 m) {
	float h = 0.0;
	if (wave_on) {
		vec3 q = (cavity_xf * vec4(m, 1.0)).xyz;
		vec2 uv = (q.xz - wave_o) / wave_span;
		h += (texture(wave_heights, uv).r * 255.0 - 128.0) * wave_quantum;
	}
	if (dip > 0.0) {
		vec3 d = m - surface_at;
		float along = dot(d, surface_up);
		h += dip * (dot(d, d) - along * along - dip_r2);
	}
	return h;
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
	// ABOVE ITS SURFACE THERE IS NO LIQUID - where its ripples and its turning have it
	bool shaped = wave_on || dip > 0.0;
	if (dot(mpos - surface_at, surface_up) > (shaped ? surf_h(mpos) : 0.0)) {
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
		// ...where the ray meets it as its ripples and its turning have it, found again a few times from the plane
		if (shaped && abs(den0) > 1e-7) {
			for (int it = 0; it < 4; it++) {
				t0 = dot(surface_up, surface_at + surface_up * surf_h(hit0) - eye) / den0;
				hit0 = eye + d0 * clamp(t0, 0.0, 1.0);
			}
		}
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
		// its own slope, from its heights either side
		vec2 sl = vec2(0.0);
		if (shaped) {
			float eps = max(wave_span / 96.0, 0.0015);
			sl = vec2(surf_h(hit + e1 * eps) - surf_h(hit - e1 * eps), surf_h(hit + e2 * eps) - surf_h(hit - e2 * eps)) / (2.0 * eps);
		}
		vec3 n = normalize(surface_up - e1 * (wv.y + rx * calm + sl.x) - e2 * (wv.z + rz * calm + sl.y));
		float b = 0.0;
		vec2 rel2 = (hit - surface_at).xz;
		for (int i = 0; i < 16; i++) {
			if (i >= bubble_count) {
				break;
			}
			vec4 bb = bubble[i];
			vec2 dv = rel2 - bb.xy;
			float d = length(dv);
			if (bb.w <= 1.0) {
				// a dome, swelling as it comes up, broken at 1
				float swell = smoothstep(0.0, 0.8, bb.w) * (1.0 - smoothstep(0.93, 1.0, bb.w));
				float rr = bb.z * (0.45 + 0.55 * swell);
				if (d < rr && swell > 0.0) {
					float k = d / rr;
					b = max(b, swell * (1.0 - k * k));
					n = normalize(n + vec3(dv.x, 0.0, dv.y) / rr * swell * 0.9);
				}
			} else {
				// ...and its ring running out across the surface
				float age = bb.w - 1.0;
				float rad = bb.z * (1.0 + age * 6.0);
				float ring = exp(-pow((d - rad) / (bb.z * 0.5), 2.0)) * (1.0 - age);
				b = max(b, ring * 0.5);
				n = normalize(n + vec3(dv.x, 0.0, dv.y) / max(d, 1e-5) * ring * 0.35);
			}
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
	BACKLIGHT = color * 0.25 * clarity;
	EMISSION = emit;
#ifdef CLEAR
	// ITS LIGHT AS WATER'S: its open surface gives back what water does (SPECULAR 0.35, a reflectance of 2%) and no coat over that; its
	// body behind its glass, nothing - the glass gives back that light, and a liquid against its glass hardly any (drawn whole, as the
	// opaque body's 0.5 and its coat, the clean water had shone milky all over)
	SPECULAR = cap ? WATER_SPECULAR : 0.0;
	CLEARCOAT = 0.0;
	// SEEN THROUGH AS FAR AS IT IS CLEAR, and less as it clouds - more of it at a grazing look, as water is - its light off the
	// surface kept whole (premultiplied: what it lets through dims only its own color, never its gleam)
	float see = smoothstep(CLEAR_FROM, CLEAR_FULL, clarity) * (1.0 - murk);
	float fr = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 3.0);
	ALPHA = clamp(1.0 - see * SEE_MOST + fr * see * SEE_GRAZING, 0.0, 1.0);
	PREMUL_ALPHA_FACTOR = ALPHA;
#else
	SSS_STRENGTH = 0.15 + 0.35 * clarity;
#endif
}
