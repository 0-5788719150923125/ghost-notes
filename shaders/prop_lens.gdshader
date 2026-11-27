// A modeled thing's SOLID glass or clear crystal (see src/table/props.gd) - a crystal ball, a lens, a
// clear point: what is behind it is seen through it, bent and turned over as a lens turns it, and
// its skin catches the flames. Hollow glass (a jar, a bottle) is prop_glass, which a flame inside
// can be seen through.
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
// ...and how far away what is on the screen stands, so only what is BEHIND the glass is bent into it
uniform sampler2D depth : hint_depth_texture, filter_nearest;
uniform vec3 color : source_color = vec3(0.9, 0.93, 0.95);
uniform vec3 color2 : source_color = vec3(0.3);
uniform float polish : hint_range(0.0, 1.0) = 0.9;
uniform float wear : hint_range(0.0, 1.0) = 0.0;
uniform float pattern : hint_range(0.0, 1.0) = 0.0;
uniform float clarity : hint_range(0.0, 1.0) = 0.9;
// how much of the bend runs up and down the screen: a ball turns the view over both ways, a straight-
// sided body (water in a tumbler) bends it sideways only
uniform float bend_y : hint_range(0.0, 1.0) = 1.0;
// how much it bends at all: a pane (Props._pane - a spectacle lens, a compass's glass, a drink's skin) has
// parallel flat faces, which turn no line of sight, so it reads the screen straight through (0)
uniform float bend : hint_range(0.0, 1.0) = 1.0;
// how deep (meters) what stands behind it must be for it to bend that all the way
const float THROUGH_FULL = 0.03;
#include "res://shaders/prop_common.gdshaderinc"

void fragment() {
	vec2 o = ornament(UV, UV2);
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fr = pow(1.0 - facing, 3.0);
	float frost = clamp(max(1.0 - clarity, etched(o) * orn_depth), 0.0, 1.0);
	// Turned over: the line of sight is bent toward the middle and past it, so the edge of the
	// thing shows what lies beyond its far side - the further away it stands, the smaller the bend
	// is on the screen
	float k = bend * (0.02 + 0.025 * facing) / max(-VERTEX.z, 0.15);
	// ...as far as there is of it to look through: the bend grows with how deep it is to what stands behind it, none where it touches
	// something (water's floor on the mud it lies on, a skin of it over a stone), all of it from THROUGH_FULL on - bent as hard where it
	// is thin, it shifts what it rests on past its edge, and where its face and the other's meet they fight over the same depth
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc0 = vec3(SCREEN_UV, textureLod(depth, SCREEN_UV, 0.0).r) * 2.0 - 1.0;
#else
	vec3 ndc0 = vec3(SCREEN_UV * 2.0 - 1.0, textureLod(depth, SCREEN_UV, 0.0).r);
#endif
	vec4 behind = INV_PROJECTION_MATRIX * vec4(ndc0, 1.0);
	k *= smoothstep(0.0, THROUGH_FULL, -behind.z / behind.w + VERTEX.z);
	vec2 bent = clamp(SCREEN_UV + NORMAL.xy * vec2(-1.0, bend_y) * k, vec2(0.0), vec2(1.0));
	// Only what is behind it: the screen holds what stands in front of the glass too, so a bent sample nearer the
	// lens than this point of the glass is not seen through it; the line of sight goes straight through instead
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(bent, textureLod(depth, bent, 0.0).r) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(bent * 2.0 - 1.0, textureLod(depth, bent, 0.0).r);
#endif
	vec4 there = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	if (-there.z / there.w < -VERTEX.z) {
		bent = SCREEN_UV;
	}
	vec3 seen = textureLod(screen, bent, frost * 4.0).rgb;
	// its color is what it lets through: a clear one a hint of it, a deep one (by how dark it is) that color and little else
	vec3 seen_as = pow(max(color, vec3(0.0)), vec3(1.0 / 2.2));
	float deep = smoothstep(0.25, 0.95, 1.0 - dot(seen_as, vec3(0.299, 0.587, 0.114)));
	vec3 tint = mix(vec3(1.0), color, 0.55 + 0.45 * deep);
	// milky where it is not clear: some of its own color, lit
	ALBEDO = color * 0.6 * frost;
	EMISSION = seen * tint * (1.0 - fr * 0.55) * (1.0 - frost * 0.7);
	ROUGHNESS = mix(0.02 + (1.0 - polish) * 0.15, 0.45, frost);
	METALLIC = 0.0;
	SPECULAR = 0.6;
	if (play == 5) {
		// RAINBOW: a thin film on its skin (aura quartz) - the colors in what it reflects, and less
		// let through of what is behind it
		ALBEDO = mix(ALBEDO, film(NORMAL, VIEW, color), 0.85);
		METALLIC = 0.6;
		EMISSION *= 0.6;
	} else if (play == 7) {
		// COATED: the glare taken off - what it reflects faint and tinted by the angle, what is behind it seen as it is
		ALBEDO = coating(NORMAL, VIEW, color2) * 0.12;
		METALLIC = 1.0;
		ROUGHNESS = min(ROUGHNESS, 0.08);
	}
	if (orn_paint > 0.0) {
		ALBEDO = mix(ALBEDO, orn_color, o.y * orn_paint);
		EMISSION *= 1.0 - o.y * orn_paint;
	}
	NORMAL = bump(NORMAL, VERTEX, o.x * orn_depth * 0.0004);
	ALPHA = 1.0;
}
