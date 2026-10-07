// THE TABLE'S TOP (see src/tables.gd): boards of a wood, a slab of stone, metal, lacquer, leather,
// a baize, tiles - or the episode's painting - with a pattern inlaid in it if it has one, a band
// inlaid along its edge (the common `border`), and its relief (table_common.gdshaderinc). UV is the
// top's own space, centimeters from its middle; UV2.y is 1 on the cut edge, which takes no relief.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Props.MATERIALS' codes: 0 painted, 1 metal, 5 ceramic, 6 stone, 7 wood, 9 leather, 10 fabric;
// -1 the painting
uniform int kind = 7;
uniform vec3 color : source_color = vec3(0.36, 0.22, 0.13);
uniform vec3 color2 : source_color = vec3(0.2, 0.12, 0.07);
uniform float polish = 0.4;
uniform float wear = 0.0;
uniform float figure = 0.55;            // the material's own pattern: a wood's grain, a stone's veins
uniform float grain = 1.2;              // ...its size, cm
uniform float boards = 0.0;             // a board's width, cm (0: one piece)
uniform float board_turn = 0.0;         // radians: the boards' run, 0 side to side
uniform float tiles = 0.0;              // a tile's side, cm (0: none)
uniform vec3 grout : source_color = vec3(0.35, 0.33, 0.3);
uniform float seed = 0.0;

#include "res://shaders/table_common.gdshaderinc"

float hb(float x) {
	return fract(sin(x * 91.7 + seed * 7.3) * 43758.5453);
}

// Where [param p] is among the boards: (along the run, across it from its own board's middle, the
// board's number, how far to its nearest edge, cm)
vec4 board_at(vec2 p) {
	vec2 r = rot2(p, -board_turn);
	if (boards <= 0.0) {
		return vec4(r.x, r.y, 0.0, 1e4);
	}
	float k = floor(r.y / boards);
	float v = r.y - (k + 0.5) * boards;
	// boards are cut to lengths, their ends staggered
	float len = 60.0 + 80.0 * hb(k + 3.0);
	float along = r.x + hb(k + 11.0) * len;
	float end_d = min(fract(along / len), 1.0 - fract(along / len)) * len;
	return vec4(r.x, v, k + floor(along / len) * 31.0, min(boards * 0.5 - abs(v), end_d));
}

// FLAT-SAWN GRAIN: the growth rings of a log met at a slant - arches up each board - each board cut
// from its own log, the late wood standing a little proud of the early wood brushed away
float rings(vec2 p) {
	vec4 b = board_at(p);
	float c = (hb(b.z) - 0.5) * max(boards, 20.0) * 0.8;
	float deep = 4.0 + hb(b.z + 7.0) * 14.0;
	float r = sqrt((b.y - c) * (b.y - c) + deep * deep) + fbm(vec3(b.x * 0.04, b.y * 0.15, b.z)) * 2.2 - b.x * 0.012;
	return fract(r / max(grain, 0.1));
}

float seam(vec2 p, float aa) {
	if (tiles > 0.0) {
		vec2 f = abs(fract(rot2(p, -board_turn) / tiles) - 0.5) * tiles;
		float d = tiles * 0.5 - max(f.x, f.y);
		return 1.0 - smoothstep(0.08, 0.2 + aa, d);
	}
	if (boards > 0.0) {
		return 1.0 - smoothstep(0.03, 0.12 + aa, board_at(p).w);
	}
	return 0.0;
}

float natural(vec2 p, float aa) {
	float h = 0.0;
	float fade = 1.0 - smoothstep(0.2, 0.8, aa / max(grain, 0.1));
	if (kind == 7) {
		h = (smoothstep(0.55, 0.85, rings(p)) - 1.0) * 0.45 * fade;
	} else if (kind == 6) {
		vec2 c = cells(vec3(p / max(grain * 0.4, 0.1), seed)).xy;
		h = -(1.0 - smoothstep(0.0, 0.12, c.x)) * 0.25 * wear;
	} else if (kind == 1) {
		vec2 c = cells(vec3(p * 0.6, seed)).xy;
		h = -(1.0 - c.x * c.x) * 0.5 * figure;
	} else if (kind == 9) {
		h = (cells(vec3(p * 2.5, seed)).x - 1.0) * 0.4 * fade;
	} else if (kind == 10) {
		h = (fbm(vec3(p * 2.5, seed)) - 1.0) * 0.3;
	} else if (kind == 0) {
		h = (vnoise(vec3(p * 0.8, seed)) - 1.0) * 0.08;
	}
	// the seams between boards and the grout between tiles are cut down to the field's floor
	return min(h, -seam(p, aa));
}

#include "res://shaders/table_relief.gdshaderinc"

void fragment() {
	vec2 p = UV;
	float hem = UV2.x;
	bool edge = UV2.y > 0.5;
	float aa = max(length(fwidth(p)), 1e-4);
	vec2 ts = vec2(textureSize(painting, 0));
	vec2 duv = fwidth(painting_uv(p)) * ts;
	float lod = max(log2(max(max(duv.x, duv.y), 1e-4)), 0.0);
	mat3 frame = surface_frame(VERTEX, NORMAL, p);
	vec3 vt = vec3(dot(VIEW, frame[0]), dot(VIEW, frame[1]), dot(VIEW, frame[2]));
	vec2 q = edge ? p : parallax(p, vt, aa, lod, hem);
	vec3 albedo = color;
	float rough = 1.0 - polish * 0.85;
	float metal = 0.0;
	float spec = 0.5;
	float coat = 0.0;
	vec3 opos = vec3(q.x, 0.0, q.y) / max(grain, 0.05) + vec3(seed * 17.31, 0.0, seed * 9.13);
	if (kind == 7) {
		// WOOD: its rings, its fibers, each board a shade of its own
		float ring = rings(q);
		float late = smoothstep(0.5, 0.9, ring) * (1.0 - smoothstep(0.92, 1.0, ring));
		vec4 b = board_at(q);
		float fiber = fbm(vec3(b.x * 0.6, b.y * 6.0, b.z));
		albedo = mix(color, color2, late * figure * 0.85) * (0.92 + 0.14 * fiber) * (0.92 + 0.16 * hb(b.z + 1.0));
		rough = mix(0.8, 0.25, polish);
		coat = polish * 0.5;
	} else if (kind == 6) {
		// STONE: veins running through it, flecks
		float n1 = fbm(opos * 0.7);
		float t = opos.x * 0.8 + opos.z * 0.3 + n1 * 4.0;
		float vein = 1.0 - smoothstep(0.0, 0.06 + 0.12 * (1.0 - figure), abs(sin(t)));
		albedo = mix(color * (0.88 + 0.24 * fbm(opos * 3.1)), color2, vein * figure);
		rough = mix(0.85, 0.1, polish);
		coat = polish * 0.4;
	} else if (kind == 1) {
		// METAL: tarnish gathering where noise says
		metal = 1.0;
		float pm = smoothstep(0.5, 0.85, fbm(opos * 0.6) * 0.6 + wear * 0.45) * wear;
		albedo = mix(color * (0.9 + 0.2 * fbm(opos * 3.1)), color2, pm);
		metal = mix(1.0, 0.15, pm);
		rough = mix(0.08 + (1.0 - polish) * 0.5, 0.8, pm);
	} else if (kind == 5) {
		// GLAZED TILE or slab
		albedo = color * (0.94 + 0.1 * fbm(opos));
		albedo = mix(albedo, color2, smoothstep(0.55, 0.85, fbm(opos * 0.5 + vec3(3.0))) * 0.35);
		rough = mix(0.8, 0.07, polish);
		coat = polish * 0.8;
	} else if (kind == 9) {
		// LEATHER, worn paler where it is handled
		albedo = color * (0.85 + 0.25 * fbm(opos * 3.1));
		albedo = mix(albedo, color2, smoothstep(0.6, 0.9, fbm(opos * 0.6)) * wear);
		rough = mix(0.78, 0.35, polish);
	} else if (kind == 10) {
		// A BAIZE: felt stretched over the top
		albedo = color * (0.9 + 0.16 * fbm(vec3(q * 0.9, seed)));
		rough = 1.0;
		spec = 0.2;
	} else if (kind == -1) {
		albedo = has_painting > 0.5 ? textureLod(painting, painting_uv(q), lod).rgb : color * (0.9 + 0.15 * fbm(opos * 0.3));
		rough = mix(0.9, 0.3, polish);
	} else {
		// PAINTED or lacquered, rubbed through to `color2` along the edge where hands go
		albedo = color * (0.95 + 0.08 * fbm(opos));
		albedo = mix(albedo, color2, (1.0 - smoothstep(0.0, 2.5, hem)) * wear);
		rough = mix(0.85, 0.12, polish);
		coat = polish * 0.6;
	}
	// AN INLAID PATTERN takes the material's own grain and shading under its colors
	float tone = clamp(lum(albedo) / max(lum(color), 0.02), 0.6, 1.4);
	if (pattern >= 1 && pattern <= 8) {
		albedo = pattern_at(q, aa, lod).rgb * tone;
	}
	albedo = mix(albedo, border_color * tone, border_at(hem, aa));
	// the grout between tiles
	if (tiles > 0.0) {
		albedo = mix(albedo, grout, seam(q, aa));
	}
	float h = edge ? 0.0 : height_mm(q, aa, lod, hem);
	float dm = max(depth_mm(), 1e-3);
	vec3 n = edge ? NORMAL : relief_normal(frame, q, aa, lod, hem);
	float hollow = clamp(-h / dm, 0.0, 1.0);
	ALBEDO = albedo * mix(1.0, 0.78, hollow * smoothstep(0.08, 0.5, dm)) * 0.84;
	AO = mix(1.0, 0.45, hollow * smoothstep(0.05, 0.6, dm));
	AO_LIGHT_AFFECT = 0.25;
	METALLIC = metal;
	ROUGHNESS = rough;
	SPECULAR = spec;
	NORMAL = n;
	CLEARCOAT = coat;
	CLEARCOAT_ROUGHNESS = 0.15;
}
