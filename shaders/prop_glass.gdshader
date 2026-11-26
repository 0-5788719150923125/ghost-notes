// A modeled thing's GLASS (see src/table/props.gd): tinted, see-through at its face and silvered at
// its edges, frosted as its clarity falls - and an ornament on glass is etched, so it frosts too. ITS
// COLOR IS HOW DEEP IT IS: near white is clear; a deeper color is that tint, and a very dark one (an
// amber medicine bottle, cobalt, smoked glass) is hard to see through yet still its color, its hue
// shown at a brightness light through it has, never black.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 color : source_color = vec3(0.85, 0.9, 0.88);
uniform vec3 color2 : source_color = vec3(0.3);
uniform float polish : hint_range(0.0, 1.0) = 0.9;
uniform float wear : hint_range(0.0, 1.0) = 0.0;
uniform float pattern : hint_range(0.0, 1.0) = 0.0;
uniform float clarity : hint_range(0.0, 1.0) = 0.85;
#include "res://shaders/prop_common.gdshaderinc"

void fragment() {
	vec2 o = ornament(UV, UV2);
	float fr = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	float frosted = clamp(max(1.0 - clarity, etched(o) * orn_depth), 0.0, 1.0);
	// how deep its color is, by how dark it is (sRGB): clear glass 0, a dark bottle nearly 1
	vec3 seen_as = pow(max(color, vec3(0.0)), vec3(1.0 / 2.2));
	float deep = smoothstep(0.25, 0.95, 1.0 - dot(seen_as, vec3(0.299, 0.587, 0.114)));
	float most = max(max(color.r, color.g), max(color.b, 1e-3));
	vec3 tinted = mix(color * 0.3, color / most * max(most, 0.035), deep);
	vec3 albedo = mix(tinted, mix(color, vec3(0.92), 0.45), frosted * (1.0 - deep * 0.6));
	float alpha = mix(0.12, 0.84, deep) + 0.55 * fr * (1.0 - deep * 0.5) + frosted * 0.45;
	float metal = 0.0;
	if (play == 5) {
		// RAINBOW: an iridescent film on it, as on old buried glass
		albedo = mix(albedo, film(NORMAL, VIEW, color), 0.8);
		alpha = max(alpha, 0.35);
		metal = 0.5;
	}
	if (orn_paint > 0.0) {
		albedo = mix(albedo, orn_color, o.y * orn_paint);
		alpha = max(alpha, o.y * orn_paint * 0.9);
	}
	ALBEDO = albedo;
	ALPHA = clamp(alpha, 0.0, 0.95);
	METALLIC = metal;
	ROUGHNESS = mix(0.03 + (1.0 - polish) * 0.2, 0.5, frosted);
	SPECULAR = 0.55;
	NORMAL = bump(NORMAL, VERTEX, o.x * orn_depth * 0.0004);
}
