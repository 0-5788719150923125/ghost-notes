// Smoke (see src/table/effects.gd): soft puffs laid over what is behind them, lit by the scene's own
// lights - a candle warms the smoke beside it - and thinning as they grow.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled, skip_vertex_transform, specular_disabled;

#include "res://shaders/effect_sprite.gdshaderinc"

float smoke_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float smoke_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(smoke_hash(i), smoke_hash(i + vec2(1.0, 0.0)), f.x),
		mix(smoke_hash(i + vec2(0.0, 1.0)), smoke_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// how torn its edge is (1, a billow of smoke; 0, a soft round haze - powder) and how thick it is (Effects.BURSTS' `torn`, `thick`)
uniform float torn = 1.0;
uniform float thick = 0.42;
void fragment() {
	vec2 p = corner * 2.0 - 1.0;
	float r = length(p);
	// a billow: a soft disc whose edge is torn by noise - or a haze, thickest at its middle and gone by its edge
	float n = smoke_noise(p * 2.6 + tint.rg * 7.0) * 0.6 + smoke_noise(p * 5.3 + 3.1) * 0.4;
	float billow = 1.0 - smoothstep(0.25, 1.0, r + (n - 0.5) * 0.45);
	float haze = exp(-4.5 * r * r) * (1.0 - smoothstep(0.8, 1.0, r));
	float a = mix(haze, billow, clamp(torn, 0.0, 1.0));
	ALBEDO = tint.rgb;
	ROUGHNESS = 1.0;
	ALPHA = clamp(a * fade * thick, 0.0, 1.0);
}
