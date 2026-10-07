// A LAYER LAID ON THE TABLE (see src/tables.gd): a tablecloth, a runner, a square, a mat - woven in
// a fabric and a pattern (table_common.gdshaderinc), hanging over the table's edge where it passes it
// (the drape is geometry; UV is the cloth's own flat space, cm), its ends fringed.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

// Tables.FABRICS: 1 linen, 2 cotton, 3 wool, 4 felt, 5 velvet, 6 silk, 7 brocade, 8 lace, 9 burlap
uniform int fabric = 2;
uniform float sheen = 0.0;              // velvet's light at the edges, silk's along the threads
uniform float fringe = 0.0;             // cm: tassels past its two ends (UV2.y is how far out)
uniform float seed = 0.0;

#include "res://shaders/table_common.gdshaderinc"

// A thread's pitch, cm, for each fabric
float pitch() {
	if (fabric == 1) return 0.09;
	if (fabric == 3) return 0.16;
	if (fabric == 5 || fabric == 6) return 0.04;
	if (fabric == 7) return 0.07;
	if (fabric == 8) return 0.08;
	if (fabric == 9) return 0.32;
	return 0.06;
}

// THE THREADS: over and under, warp and weft - a linen's a little uneven, a burlap's coarse; a felt
// has none, only its fuzz. Faded where a thread is finer than a pixel.
float natural(vec2 p, float aa) {
	if (fabric == 4) {
		return (fbm(vec3(p * 2.5, seed)) - 1.0) * 0.6;
	}
	float tp = pitch();
	float fade = 1.0 - smoothstep(0.35, 0.9, aa / tp);
	if (fade <= 0.0) {
		return -0.5;
	}
	float slub = fabric == 1 || fabric == 9 ? (vnoise(vec3(p.x * 1.3, floor(p.y / tp), seed)) - 0.5) * 0.5 : 0.0;
	float wx = sin(6.2831853 * p.x / tp);
	float wz = sin(6.2831853 * (p.y / tp + slub));
	float over = 0.5 + 0.5 * wx * wz;
	return mix(-0.5, over - 1.0, fade);
}

#include "res://shaders/table_relief.gdshaderinc"

// LACE: a net of round holes, a ring of smaller ones round each - kept whole along the hem
float lace_holes(vec2 p, float hem) {
	vec2 c = p / 1.1;
	float row = floor(c.y);
	vec2 l = fract(vec2(c.x + 0.5 * mod(row, 2.0), c.y)) - 0.5;
	float d = length(l);
	float hole = 1.0 - smoothstep(0.2, 0.24, d);
	float ring = smoothstep(0.32, 0.34, d) * (1.0 - smoothstep(0.38, 0.4, d)) * step(0.5, fract(atan(l.y, l.x) * 1.91));
	return max(hole, ring) * smoothstep(1.2, 2.0, hem);
}

void fragment() {
	vec2 p = UV;
	float hem = UV2.x;
	float out_fringe = UV2.y;
	float aa = max(length(fwidth(p)), 1e-4);
	vec2 ts = vec2(textureSize(painting, 0));
	vec2 duv = fwidth(painting_uv(p)) * ts;
	float lod = max(log2(max(max(duv.x, duv.y), 1e-4)), 0.0);
	mat3 frame = surface_frame(VERTEX, NORMAL, p);
	// on its underside (a fringe turned up, the inside of the drape) the frame faces the other way
	if (!FRONT_FACING) {
		frame = mat3(frame[0], -frame[1], -frame[2]);
	}
	vec3 vt = vec3(dot(VIEW, frame[0]), dot(VIEW, frame[1]), dot(VIEW, frame[2]));
	vec2 q = out_fringe > 0.0 ? p : parallax(p, vt, aa, lod, hem);
	vec4 pt = pattern_at(q, aa, lod);
	vec3 albedo = pt.rgb;
	float b = border_at(hem, aa);
	albedo = mix(albedo, border_color, b);
	float h = height_mm(q, aa, lod, hem);
	float dm = max(depth_mm(), 1e-3);
	vec3 n = relief_normal(frame, q, aa, lod, hem);
	float rough = 0.9;
	float spec = 0.3;
	float metal = 0.0;
	float rim = 0.0;
	float aniso = 0.0;
	float alpha = 1.0;
	if (fabric == 1) {
		rough = 0.86;
		albedo *= 0.95 + 0.1 * vnoise(vec3(p * 0.7, seed));
	} else if (fabric == 3) {
		rough = 1.0;
		albedo *= 0.9 + 0.18 * fbm(vec3(p * 1.5, seed));
		rim = 0.2;
	} else if (fabric == 4) {
		rough = 1.0;
		spec = 0.15;
		albedo *= 0.92 + 0.14 * fbm(vec3(p * 0.9, seed + 3.0));
	} else if (fabric == 5) {
		// VELVET: darker seen straight on, the pile catching the light at the edges
		rough = 0.95;
		albedo *= mix(0.72, 1.0, pow(1.0 - clamp(dot(n, VIEW), 0.0, 1.0), 2.0));
		rim = 0.6 + 0.4 * sheen;
	} else if (fabric == 6) {
		// SILK: smooth, its light drawn out along the threads
		rough = 0.32;
		spec = 0.6;
		aniso = 0.55 + 0.4 * sheen;
	} else if (fabric == 7) {
		// BROCADE: the figure woven in lustrous thread over a satin ground
		float f = max(pt.a, b);
		rough = mix(0.45, 0.3, f);
		metal = f * 0.55;
		spec = 0.55;
		aniso = 0.35;
	} else if (fabric == 8) {
		rough = 0.85;
		alpha = 1.0 - lace_holes(p, hem);
	} else if (fabric == 9) {
		rough = 1.0;
		albedo *= 0.85 + 0.25 * vnoise(vec3(p * 3.0, seed));
	}
	// THE FRINGE: loose threads in tassels past the end, thinning out toward their tips
	if (out_fringe > 0.0) {
		float across = p.y;
		float tassel = abs(fract(across / 1.2) - 0.5);
		float spread = mix(0.12, 0.42, clamp(out_fringe / max(fringe, 0.1), 0.0, 1.0));
		float thread = step(0.5, fract(across / 0.18 + out_fringe * 0.15));
		alpha = (1.0 - smoothstep(spread - 0.05, spread, tassel)) * mix(1.0, thread, smoothstep(0.15, 0.5, out_fringe / max(fringe, 0.1)));
		alpha *= 1.0 - smoothstep(fringe * 0.85, fringe, out_fringe);
		albedo = mix(albedo, border > 0.0 ? border_color : pal(0), 0.5);
	}
	// the hollows are in shade: what light reaches the bottom of a fold or a stitch is less
	float hollow = clamp(-h / dm, 0.0, 1.0);
	ALBEDO = albedo * mix(1.0, 0.8, hollow * smoothstep(0.08, 0.5, dm)) * 0.84;
	AO = mix(1.0, 0.45, hollow * smoothstep(0.05, 0.6, dm));
	AO_LIGHT_AFFECT = 0.25;
	METALLIC = metal;
	ROUGHNESS = rough;
	SPECULAR = spec;
	NORMAL = n;
	TANGENT = frame[0];
	BINORMAL = frame[1];
	ANISOTROPY = aniso;
	ANISOTROPY_FLOW = vec2(1.0, 0.0);
	RIM = rim;
	RIM_TINT = 0.5;
	ALPHA = alpha;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
