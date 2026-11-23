// The table seen as a tilt-shift photograph of a model ([TableGame], `miniature`): a band across the frame in focus where the
// camera looks, softer and softer above and below it, and the colors a little richer, as a miniature photographed close is.
// A sheet in front of the lens reading what is drawn behind it; the pages of the night's book draw over it.
shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
// Where the band in focus is, up the frame from its bottom (0-1), how far either side of it is sharp, and how strong (0 none).
uniform float focus = 0.5;
uniform float band = 0.15;
uniform float strength = 0.0;

// Twelve taps round a disc, as wide as how far out of the band it is: a lens's blur, never the steps of a coarse mip.
const vec2 DISC[12] = vec2[](vec2(-0.326, -0.406), vec2(-0.840, -0.074), vec2(-0.696, 0.457), vec2(-0.203, 0.621),
	vec2(0.962, -0.195), vec2(0.473, -0.480), vec2(0.519, 0.767), vec2(0.185, -0.893), vec2(0.507, 0.064),
	vec2(0.896, 0.412), vec2(-0.322, -0.933), vec2(-0.792, -0.598));

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 size = vec2(textureSize(screen, 0));
	float d = max(abs((1.0 - uv.y) - focus) - band, 0.0);
	// ...how wide the disc is (pixels), growing smoothly out of the band, never wider than a fortieth of the frame
	float radius = min(smoothstep(0.0, 0.45, d) * 0.025 * size.y * strength * 2.0, size.y * 0.025);
	float lod = log2(max(radius / 4.0, 1.0));
	vec3 c = textureLod(screen, uv, 0.0).rgb;
	if (radius > 0.5) {
		c = vec3(0.0);
		for (int i = 0; i < 12; i++) {
			vec2 at = clamp(uv + DISC[i] * radius / size, vec2(0.5) / size, vec2(1.0) - vec2(0.5) / size);
			c += textureLod(screen, at, lod).rgb;
		}
		c /= 12.0;
	}
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	ALBEDO = mix(vec3(l), c, 1.0 + 0.3 * strength);
	ALPHA = 1.0;
}
